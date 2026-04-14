#!/usr/bin/env bash
set -ex

# Firefox natif (pas snap) via le dépôt APT officiel Mozilla
# On évite add-apt-repository qui appelle api.launchpad.net (DNS échoue dans Docker build)

install -d -m 0755 /etc/apt/keyrings

wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg \
    -O /etc/apt/keyrings/packages.mozilla.org.asc

echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    > /etc/apt/sources.list.d/mozilla.list

cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

apt-get update
apt-get install -y firefox

mkdir -p $HOME/Desktop
printf '[Desktop Entry]\nName=Firefox\nExec=firefox %%u\nIcon=firefox\nTerminal=false\nType=Application\nCategories=Network;\n' \
    > $HOME/Desktop/firefox.desktop
chmod +x $HOME/Desktop/firefox.desktop

apt-get clean
rm -rf /var/lib/apt/lists/*
