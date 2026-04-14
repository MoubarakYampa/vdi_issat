#!/usr/bin/env bash
set -ex

# Raccourcis bureau supplémentaires
mkdir -p $HOME/Desktop

printf '[Desktop Entry]\nName=Terminal\nExec=xfce4-terminal\nIcon=utilities-terminal\nTerminal=false\nType=Application\nCategories=System;\n' \
    > $HOME/Desktop/terminal.desktop

printf '[Desktop Entry]\nName=Fichiers\nExec=thunar\nIcon=thunar\nTerminal=false\nType=Application\nCategories=System;\n' \
    > $HOME/Desktop/thunar.desktop

printf '[Desktop Entry]\nName=GIMP\nExec=gimp %%U\nIcon=gimp\nTerminal=false\nType=Application\nCategories=Graphics;\n' \
    > $HOME/Desktop/gimp.desktop

printf '[Desktop Entry]\nName=VLC\nExec=vlc %%U\nIcon=vlc\nTerminal=false\nType=Application\nCategories=AudioVideo;\n' \
    > $HOME/Desktop/vlc.desktop

printf '[Desktop Entry]\nName=Thunderbird\nExec=thunderbird %%u\nIcon=thunderbird\nTerminal=false\nType=Application\nCategories=Network;\n' \
    > $HOME/Desktop/thunderbird.desktop

chmod +x $HOME/Desktop/*.desktop
chown -R etudiant:etudiant $HOME/Desktop

# Thème GTK Arc-Dark + icônes Papirus
mkdir -p $HOME/.config/gtk-3.0
cat > $HOME/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Ubuntu 11
gtk-cursor-theme-name=Adwaita
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-xft-dpi=98304
EOF

cat > $HOME/.gtkrc-2.0 << 'EOF'
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Ubuntu 11"
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintslight"
gtk-xft-rgba="rgb"
gtk-xft-dpi=98304
EOF

# Fontconfig : antialiasing subpixel + hinting léger
mkdir -p $HOME/.config/fontconfig
cat > $HOME/.config/fontconfig/fonts.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
    <edit name="autohint" mode="assign"><bool>false</bool></edit>
  </match>
</fontconfig>
EOF

apt-get update && apt-get install -y arc-theme && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

gtk-update-icon-cache -f /usr/share/icons/Papirus-Dark 2>/dev/null || true

# Autostart : appliquer le fond d'écran depuis la session XFCE
mkdir -p $HOME/.config/autostart
cat > $HOME/.config/autostart/set-wallpaper.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Set Wallpaper
Exec=/bin/bash /usr/local/bin/set-wallpaper.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown -R etudiant:etudiant $HOME/.config $HOME/.gtkrc-2.0
