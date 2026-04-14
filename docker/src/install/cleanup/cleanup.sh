#!/usr/bin/env bash
set -ex

# Supprimer lightdm (display manager inutile dans Docker, cause un écran de login)
apt-get remove -y lightdm lightdm-gtk-greeter 2>/dev/null || true

apt-get autoremove -y
apt-get autoclean -y

rm -rf \
    /tmp/* \
    /var/tmp/* \
    /var/lib/apt/lists/* \
    $HOME/.cache

# Supprimer les autostart qui causent des erreurs dans Docker
rm -f \
    /etc/xdg/autostart/light-locker.desktop \
    /etc/xdg/autostart/xfce4-power-manager.desktop \
    /etc/xdg/autostart/xfce4-screensaver.desktop \
    /etc/xdg/autostart/xscreensaver.desktop \
    /etc/xdg/autostart/xiccd.desktop \
    /etc/xdg/autostart/xfsettingsd.desktop \
    /etc/xdg/autostart/xfce4-notifyd.desktop \
    /etc/xdg/autostart/geoclue-demo-agent.desktop \
    /etc/xdg/autostart/gnome-keyring-pkcs11.desktop \
    /etc/xdg/autostart/gnome-keyring-secrets.desktop \
    /etc/xdg/autostart/gnome-keyring-ssh.desktop \
    2>/dev/null || true
