#!/bin/bash
USER_NAME=$1

CONTAINER=$(docker ps --filter "name=${USER_NAME}" --filter "status=running" \
            --format "{{.Names}}" | head -1)

if [ -n "$CONTAINER" ]; then
    docker stop "$CONTAINER"
    echo "Container $CONTAINER arrêté."
    if [ -f "/etc/nginx/kasm-locations/${CONTAINER}.conf" ]; then
        sudo rm "/etc/nginx/kasm-locations/${CONTAINER}.conf"
        sudo nginx -t && sudo systemctl reload nginx
        echo "Config Nginx supprimée pour $CONTAINER"
    fi
else
    echo "Aucun container actif pour $USER_NAME"
fi
