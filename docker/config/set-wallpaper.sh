#!/bin/bash
# Ce script tourne dans la session XFCE (via autostart), donc il a accès à dbus/xfconf
sleep 3
WALLPAPER="/usr/share/backgrounds/custom-wallpaper.png"

# Appliquer le wallpaper sur tous les moniteurs/workspaces possibles
for monitor in screen monitorscreen monitorVNC-0 monitor0 HDMI-0 VNC-0; do
    for ws in 0 1 2 3; do
        xfconf-query -c xfce4-desktop \
            -p "/backdrop/screen0/${monitor}/workspace${ws}/last-image" \
            -s "$WALLPAPER" --create -t string 2>/dev/null || true
        xfconf-query -c xfce4-desktop \
            -p "/backdrop/screen0/${monitor}/workspace${ws}/image-style" \
            -s 5 --create -t int 2>/dev/null || true
        xfconf-query -c xfce4-desktop \
            -p "/backdrop/screen0/${monitor}/workspace${ws}/color-style" \
            -s 0 --create -t int 2>/dev/null || true
    done
done

xfdesktop --reload 2>/dev/null || true
