#!/bin/bash

echo "==> Démarrage VDI étudiant (LXDE)..."

# Nettoyer les verrous X
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# 1. Xvfb
Xvfb :1 -screen 0 ${RESOLUTION:-1280x800x24} &
sleep 2

export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR && chmod 700 $XDG_RUNTIME_DIR

xhost +local: 2>/dev/null || true

# 2. DBus
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address 2>/dev/null)
sleep 0.5

# 3. Lancer LXDE complet
startlxde &
sleep 4

echo "==> Bureau LXDE démarré"

# 4. x11vnc sans mot de passe
x11vnc \
    -display :1 \
    -nopw \
    -forever \
    -shared \
    -rfbport ${VNC_PORT:-5901} \
    -quiet &

echo "==> Accès: http://localhost:${NOVNC_PORT:-6080}/vnc.html?autoconnect=true&resize=scale"

# 5. noVNC (bloquant)
exec websockify \
    --web /usr/share/novnc \
    ${NOVNC_PORT:-6080} \
    localhost:${VNC_PORT:-5901}
