#!/bin/bash
# =============================================================================
# fix_nginx_configs.sh — Régénération d'urgence des configurations Nginx
# Usage : sudo bash fix_nginx_configs.sh
#
# Cas d'usage : après un redémarrage du serveur, les fichiers Nginx dans
# /etc/nginx/kasm-locations/ ont disparu mais les containers sont peut-être
# encore présents. Ce script les régénère automatiquement.
# =============================================================================

set -e

NGINX_DIR="/etc/nginx/kasm-locations"
COUNT=0

echo "[INFO] Régénération des configurations Nginx pour tous les containers kasm-*..."
mkdir -p "$NGINX_DIR"

# ─── Parcourir tous les containers dont le nom commence par kasm- ─────────────
for CONTAINER in $(docker ps -a --format '{{.Names}}' | grep '^kasm-'); do
    USER_NAME="${CONTAINER#kasm-}"

    echo "[INFO] Traitement : $CONTAINER (utilisateur : $USER_NAME)"

    # Démarrer le container s'il est arrêté
    if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
        echo "[INFO]   → Container arrêté, démarrage..."
        docker start "$CONTAINER" || { echo "[WARN]   → Échec du démarrage de $CONTAINER"; continue; }
        sleep 1
    fi

    # Récupérer le port mappé depuis Docker inspect
    PORT=$(docker inspect "$CONTAINER" \
        --format '{{range $p, $conf := .NetworkSettings.Ports}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)

    if [ -z "$PORT" ]; then
        echo "[WARN]   → Impossible de déterminer le port pour $CONTAINER — ignoré"
        continue
    fi

    echo "[INFO]   → Port détecté : $PORT"

    # Générer la configuration Nginx
    cat > "${NGINX_DIR}/kasm-${USER_NAME}.conf" << EOF
# Configuration VDI automatique pour l'utilisateur : ${USER_NAME}
# Régénérée le : $(date)

location = /kasm/${USER_NAME}/ {
    return 302 /kasm/${USER_NAME}/vnc_auto.html?autoconnect=true&reconnect=true&reconnect_delay=1000&resize=scale&quality=6&path=kasm/${USER_NAME}/websockify;
}

location ^~ /kasm/${USER_NAME}/websockify {
    proxy_pass http://127.0.0.1:${PORT}/websockify;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_buffering off;
}

location ^~ /kasm/${USER_NAME}/ {
    proxy_pass http://127.0.0.1:${PORT}/;
    proxy_http_version 1.1;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_read_timeout 3600s;
}
EOF

    echo "[OK]   → Config Nginx générée : kasm-${USER_NAME}.conf"
    COUNT=$((COUNT + 1))
done

# ─── Recharger Nginx ──────────────────────────────────────────────────────────
if [ $COUNT -gt 0 ]; then
    echo ""
    echo "[INFO] $COUNT configuration(s) régénérée(s) — rechargement de Nginx..."
    nginx -t && systemctl reload nginx
    echo "[OK] Nginx rechargé avec succès"
else
    echo "[INFO] Aucun container kasm-* trouvé"
fi

echo ""
echo "✓ Récupération terminée ($COUNT containers configurés)"
echo ""
