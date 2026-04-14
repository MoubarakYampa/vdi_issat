#!/bin/bash
# Script pour builder et pousser l'image sur Docker Hub
# Usage: ./build-push.sh <ton-username-dockerhub>

set -e

USERNAME=${1:-""}
IMAGE_NAME="issatmh-desktop"
TAG="latest"

if [ -z "$USERNAME" ]; then
    echo "Usage: ./build-push.sh <username-dockerhub>"
    echo "Exemple: ./build-push.sh monutilisateur"
    exit 1
fi

FULL_IMAGE="${USERNAME}/${IMAGE_NAME}:${TAG}"

echo "==> Build de l'image: ${FULL_IMAGE}"
docker build -t ${FULL_IMAGE} .

echo "==> Login Docker Hub (entre tes identifiants si demandé)"
docker login

echo "==> Push de l'image vers Docker Hub"
docker push ${FULL_IMAGE}

echo ""
echo "✓ Image disponible: ${FULL_IMAGE}"
echo ""
echo "Pour l'utiliser sur ton serveur:"
echo "  docker pull ${FULL_IMAGE}"
echo "  docker run -d -p 6080:6080 --shm-size=256m ${FULL_IMAGE}"
echo ""
echo "Accès: http://<ip-serveur>:6080/vnc.html?autoconnect=true&resize=scale"
