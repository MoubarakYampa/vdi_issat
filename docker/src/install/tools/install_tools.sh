#!/usr/bin/env bash
set -ex

apt-get update

# sudo séparé (problème de setuid dans Docker build)
apt-get install -y sudo || dpkg --configure -a && apt-get install -yf sudo || true

apt-get install -y \
    xfce4 xfce4-terminal xfce4-goodies thunar \
    x11vnc xvfb novnc websockify \
    supervisor dbus-x11 x11-utils net-tools \
    fonts-ubuntu fonts-noto \
    ubuntu-wallpapers ubuntu-wallpapers-focal \
    hicolor-icon-theme adwaita-icon-theme papirus-icon-theme \
    git build-essential python3 python3-pip nodejs npm \
    vim nano curl wget iputils-ping unzip htop \
    gimp vlc thunderbird \
    feh x11-xserver-utils

apt-get clean
rm -rf /var/lib/apt/lists/*
