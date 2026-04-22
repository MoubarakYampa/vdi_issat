#!/bin/bash

USER_NAME=$1
GROUPS_RAW=$2
TP_NAME=$3
ANNEE_UNIV=$4
NIVEAU=$5
SOUS_GROUPE=$6

[ -z "$ANNEE_UNIV" ]  && ANNEE_UNIV="25-26"
[ -z "$TP_NAME" ]     && TP_NAME="desktop"
[ -z "$NIVEAU" ]      && NIVEAU="L1"
[ -z "$SOUS_GROUPE" ] && SOUS_GROUPE=""

PREMIER_GROUPE=$(echo "$GROUPS_RAW" | cut -d',' -f1)
IMAGE="moubarakyampa/issatmh-${TP_NAME}"
CONTAINER_NAME="${TP_NAME}-${USER_NAME}-${ANNEE_UNIV}"

echo "==> Lancement TP=$TP_NAME pour $USER_NAME"
echo "==> Image: $IMAGE | Container: $CONTAINER_NAME"

# Stop ancien container si différent (changement de TP)
RUNNING=$(docker ps --filter "name=${USER_NAME}" --filter "status=running" --format "{{.Names}}" | head -1)
if [ -n "$RUNNING" ] && [ "$RUNNING" != "$CONTAINER_NAME" ]; then
    echo "==> Stop ancien container: $RUNNING"
    docker stop "$RUNNING"
    sudo rm -f /etc/nginx/kasm-locations/${RUNNING}.conf
    sudo nginx -t && sudo systemctl reload nginx
fi

# Si le container existe déjà → restart
if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
    echo "Container existe → restart"
    docker start "$CONTAINER_NAME"
    sleep 3
    PORT=$(docker inspect ${CONTAINER_NAME} --format '{{(index (index .NetworkSettings.Ports "6901/tcp") 0).HostPort}}')
else
    # Créer les dossiers de données persistantes
    for DIR in Documents Downloads Music Pictures Videos PDF Uploads; do
        sudo mkdir -p "/home/docker/kasm-data/$USER_NAME/$DIR"
    done
    sudo chown -R 1000:1000 "/home/docker/kasm-data/$USER_NAME"
    sudo chmod -R 755 "/home/docker/kasm-data/$USER_NAME"

    # Trouver un port libre entre 7000 et 8000
    for PORT in $(seq 7000 8000); do
        USED=$(ss -Htan | awk '{print $4}' | grep -oE '[0-9]+$' | grep -xF "$PORT")
        DOCKER_USED=$(docker inspect $(docker ps -aq) --format '{{json .HostConfig.PortBindings}}' 2>/dev/null | grep -oE 'HostPort":"[0-9]+' | grep -oE '[0-9]+$' | grep -xF "$PORT")
        if [ -z "$USED" ] && [ -z "$DOCKER_USED" ]; then break; fi
        PORT=""
    done

    if [ -z "$PORT" ]; then
        echo "ERREUR: aucun port libre"
        exit 1
    fi

    echo "Port: $PORT"

    docker run -d \
        --security-opt seccomp=unconfined \
        --shm-size="600m" \
        --memory="10g" \
        --restart=no \
        -p "$PORT:6901" \
        -v "/home/docker/kasm-data/$USER_NAME/Documents:/home/etudiant/Documents" \
        -v "/home/docker/kasm-data/$USER_NAME/Downloads:/home/etudiant/Downloads" \
        -v "/home/docker/kasm-data/$USER_NAME/Music:/home/etudiant/Music" \
        -v "/home/docker/kasm-data/$USER_NAME/Pictures:/home/etudiant/Pictures" \
        -v "/home/docker/kasm-data/$USER_NAME/Videos:/home/etudiant/Videos" \
        -v "/home/docker/kasm-data/$USER_NAME/PDF:/home/etudiant/PDF" \
        -v "/home/docker/kasm-data/$USER_NAME/Uploads:/home/etudiant/Uploads" \
        --name "$CONTAINER_NAME" \
        --label app=kasm \
        --label etudiant="$USER_NAME" \
        --label tp="$TP_NAME" \
        --label groupe="$PREMIER_GROUPE" \
        --label groupes="$GROUPS_RAW" \
        --label annee_univ="$ANNEE_UNIV" \
        --label niveau="$NIVEAU" \
        --label sous_groupe="$SOUS_GROUPE" \
        "$IMAGE"

    sleep 3
    PORT=$(docker inspect ${CONTAINER_NAME} --format '{{(index (index .NetworkSettings.Ports "6901/tcp") 0).HostPort}}')
fi

# Générer la config Nginx pour ce container
sudo mkdir -p /etc/nginx/kasm-locations

sudo tee /etc/nginx/kasm-locations/${CONTAINER_NAME}.conf > /dev/null << NGINX
location = /kasm/${CONTAINER_NAME}/ {
    return 302 /kasm/${CONTAINER_NAME}/vnc_auto.html?autoconnect=true&reconnect=true&reconnect_delay=1000&resize=scale&quality=6&path=kasm/${CONTAINER_NAME}/websockify;
}

location ^~ /kasm/${CONTAINER_NAME}/websockify {
    proxy_pass http://127.0.0.1:${PORT}/websockify;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    proxy_buffering off;
}

location ^~ /kasm/${CONTAINER_NAME}/ {
    proxy_pass http://127.0.0.1:${PORT}/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    proxy_buffering off;
}
NGINX

sudo nginx -t && sudo systemctl reload nginx

echo "OK → http://labo.issat.local/kasm/${CONTAINER_NAME}/"
