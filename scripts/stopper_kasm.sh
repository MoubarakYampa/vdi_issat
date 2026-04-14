#!/bin/bash
# =============================================================================
# stopper_kasm.sh — Arrêt du bureau VDI d'un étudiant
# Usage : sudo bash stopper_kasm.sh <nom_utilisateur>
# Exemple : sudo bash stopper_kasm.sh malek
# Déclenché automatiquement par le webhook Authentik lors d'un logout.
# =============================================================================

set -e

USER_NAME="$1"
NGINX_DIR="/etc/nginx/kasm-locations"

# ─── Vérification des arguments ───────────────────────────────────────────────
if [ -z "$USER_NAME" ]; then
    echo "[ERREUR] Usage : $0 <nom_utilisateur>"
    exit 1
fi

echo "[INFO] Arrêt du bureau VDI pour : $USER_NAME"

# ─── Arrêter le container Docker ─────────────────────────────────────────────
if docker inspect "kasm-${USER_NAME}" &>/dev/null; then
    if [ "$(docker inspect -f '{{.State.Running}}' kasm-${USER_NAME})" = "true" ]; then
        echo "[INFO] Arrêt du container kasm-${USER_NAME}..."
        docker stop "kasm-${USER_NAME}"
        echo "[OK] Container arrêté"
    else
        echo "[INFO] Container kasm-${USER_NAME} déjà arrêté"
    fi
else
    echo "[INFO] Container kasm-${USER_NAME} introuvable — rien à arrêter"
fi

# ─── Supprimer la configuration Nginx ────────────────────────────────────────
CONF_FILE="${NGINX_DIR}/kasm-${USER_NAME}.conf"
if [ -f "$CONF_FILE" ]; then
    echo "[INFO] Suppression de la configuration Nginx..."
    rm -f "$CONF_FILE"
    nginx -t && systemctl reload nginx
    echo "[OK] Configuration Nginx supprimée et rechargée"
else
    echo "[INFO] Aucune configuration Nginx pour ${USER_NAME}"
fi

echo ""
echo "✓ Bureau VDI de ${USER_NAME} arrêté et ressources libérées"
echo ""
