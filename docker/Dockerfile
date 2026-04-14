FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/etudiant \
    USER=etudiant \
    INST_DIR=/tmp/install \
    INST_SCRIPTS="tools/install_tools.sh \
                  firefox/install_firefox.sh \
                  vscode/install_vscode.sh \
                  desktop/setup_desktop.sh \
                  cleanup/cleanup.sh"

# Utilisateur étudiant
RUN apt-get update && apt-get install -y sudo && apt-get clean && \
    useradd -m -s /bin/bash etudiant && \
    echo "etudiant ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/etudiant/Desktop \
             /home/etudiant/Documents \
             /home/etudiant/Downloads \
             /home/etudiant/.config/xfce4/xfconf/xfce-perchannel-xml

# Scripts d'installation (architecture modulaire)
COPY src/install $INST_DIR
RUN for SCRIPT in $INST_SCRIPTS; do \
        echo "==> $SCRIPT" && \
        bash ${INST_DIR}/${SCRIPT} || exit 1; \
    done && rm -rf ${INST_DIR}

# Configuration XFCE (fond d'écran, screensaver désactivé)
COPY config/wallpaper.png /usr/share/backgrounds/custom-wallpaper.png
COPY config/set-wallpaper.sh /usr/local/bin/set-wallpaper.sh
RUN chmod +x /usr/local/bin/set-wallpaper.sh
COPY config/xfce4-desktop.xml \
     /home/etudiant/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
COPY config/xfce4-screensaver.xml \
     /home/etudiant/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml
COPY config/xfwm4.xml \
     /home/etudiant/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
COPY config/xsettings.xml \
     /home/etudiant/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
COPY config/xfce4-terminal.xml \
     /home/etudiant/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml
COPY config/xfce4-session.xml \
     /home/etudiant/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml

# Supervisord + startup
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/startup.sh /startup.sh
RUN chmod +x /startup.sh && \
    chown -R etudiant:etudiant /home/etudiant/ && \
    # lancer_kasm.sh redirige vers vnc_auto.html — on crée le symlink
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/vnc_auto.html

EXPOSE 6901

CMD ["/startup.sh"]
