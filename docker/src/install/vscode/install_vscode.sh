#!/usr/bin/env bash
set -ex

apt-get update
apt-get install -y apt-transport-https ca-certificates gnupg

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor > /usr/share/keyrings/microsoft.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list

apt-get update
apt-get install -y code

mkdir -p $HOME/Desktop
# Utiliser le .desktop système qui a le bon chemin d'icône
cp /usr/share/applications/code.desktop $HOME/Desktop/vscode.desktop
# Forcer --no-sandbox
sed -i 's|/usr/bin/code|/usr/bin/code --no-sandbox --user-data-dir=/home/etudiant/.vscode|g' \
    $HOME/Desktop/vscode.desktop
chmod +x $HOME/Desktop/vscode.desktop

apt-get clean
rm -rf /var/lib/apt/lists/*
