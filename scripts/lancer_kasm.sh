#!/bin/bash
# =============================================================================
# lancer_kasm.sh — Démarrage d'un bureau VDI pour un étudiant
# Usage : sudo bash lancer_kasm.sh <nom_utilisateur>
# Exemple : sudo bash lancer_kasm.sh malek
# =============================================================================

set -e

USER_NAME="$1"
IMAGE="moubarakyampa/vdi-etudiant:latest"
DATA_DIR="/home/docker/kasm-data"
NGINX_DIR="/etc/nginx/kasm-locations"
PORT_START=7000
PORT_END=8000

# ─── Vérification des arguments ───────────────────────────────────────────────
if [ -z "$USER_NAME" ]; then
    echo "[ERREUR] Usage : $0 <nom_utilisateur>"
    exit 1
fi

echo "[INFO] Démarrage du bureau VDI pour : $USER_NAME"

# ─── Si le container existe déjà → le redémarrer ─────────────────────────────
if docker inspect "kasm-${USER_NAME}" &>/dev/null; then
    echo "[INFO] Container kasm-${USER_NAME} existant — redémarrage..."
    docker start "kasm-${USER_NAME}"

    # Récupérer le port depuis Docker inspect
    PORT=$(docker inspect "kasm-${USER_NAME}" \
        --format '{{range $p, $conf := .NetworkSettings.Ports}}{{(index $conf 0).HostPort}}{{end}}')

    echo "[OK] Container redémarré sur le port $PORT"
else
    # ─── Créer les dossiers de données persistantes ───────────────────────────
    echo "[INFO] Création des volumes de données..."
    for DIR in Documents Downloads Music Pictures Videos PDF Uploads; do
        mkdir -p "${DATA_DIR}/${USER_NAME}/${DIR}"
    done
    chown -R 1000:1000 "${DATA_DIR}/${USER_NAME}"
    chmod -R 755 "${DATA_DIR}/${USER_NAME}"

    # ─── Trouver un port libre entre 7000 et 8000 ─────────────────────────────
    PORT=""
    for P in $(seq $PORT_START $PORT_END); do
        USED_SYS=$(ss -Htan | awk '{print $4}' | grep -oE '[0-9]+$' | grep -xF "$P" || true)
        USED_DOCKER=$(docker ps --format '{{.Ports}}' | grep -oE '0\.0\.0\.0:[0-9]+' \
            | grep -oE '[0-9]+$' | grep -xF "$P" || true)
        if [ -z "$USED_SYS" ] && [ -z "$USED_DOCKER" ]; then
            PORT="$P"
            break
        fi
    done

    if [ -z "$PORT" ]; then
        echo "[ERREUR] Aucun port libre entre $PORT_START et $PORT_END"
        exit 1
    fi

    echo "[INFO] Port sélectionné : $PORT"

    # ─── Lancer le container Docker ───────────────────────────────────────────
    docker run -d \
        --name "kasm-${USER_NAME}" \
        --security-opt seccomp=unconfined \
        --shm-size="512m" \
        --memory="1g" \
        --restart=no \
        -p "${PORT}:6901" \
        -v "${DATA_DIR}/${USER_NAME}/Documents:/home/etudiant/Documents" \
        -v "${DATA_DIR}/${USER_NAME}/Downloads:/home/etudiant/Downloads" \
        -v "${DATA_DIR}/${USER_NAME}/Music:/home/etudiant/Music" \
        -v "${DATA_DIR}/${USER_NAME}/Pictures:/home/etudiant/Pictures" \
        -v "${DATA_DIR}/${USER_NAME}/Videos:/home/etudiant/Videos" \
        -v "${DATA_DIR}/${USER_NAME}/PDF:/home/etudiant/PDF" \
        -v "${DATA_DIR}/${USER_NAME}/Uploads:/home/etudiant/Uploads" \
        "$IMAGE"

    echo "[OK] Container kasm-${USER_NAME} démarré sur le port $PORT"
fi

# ─── Générer la configuration Nginx dynamique ────────────────────────────────
echo "[INFO] Génération de la configuration Nginx..."
mkdir -p "$NGINX_DIR"

cat > "${NGINX_DIR}/kasm-${USER_NAME}.conf" << EOF
# Configuration VDI automatique pour l'utilisateur : ${USER_NAME}
# Générée le : $(date)

# Redirection vers l'interface noVNC complète
location = /kasm/${USER_NAME}/ {
    return 302 /kasm/${USER_NAME}/vnc_auto.html?autoconnect=true&reconnect=true&reconnect_delay=1000&resize=scale&quality=6&path=kasm/${USER_NAME}/websockify;
}

# Tunnel WebSocket pour le flux VNC temps réel
location ^~ /kasm/${USER_NAME}/websockify {
    proxy_pass http://127.0.0.1:${PORT}/websockify;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_buffering off;
}

# Proxy des ressources statiques noVNC
location ^~ /kasm/${USER_NAME}/ {
    proxy_pass http://127.0.0.1:${PORT}/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_read_timeout 3600s;
}
EOF

# ─── Recharger Nginx ──────────────────────────────────────────────────────────
echo "[INFO] Rechargement de Nginx..."
nginx -t && systemctl reload nginx

echo ""
echo "✓ Bureau VDI disponible pour ${USER_NAME}"
echo "  URL : http://labo.issat.local/kasm/${USER_NAME}/"
echo ""
