# Image Docker personnalisée — issat-desktop / vdi-etudiant

Fichier source : `/home/docker/issat-desktop/Dockerfile`  
Image publiée : `moubarakyampa/vdi-etudiant:latest`

Cette image est la **base du bureau étudiant**. Elle est construite depuis Ubuntu 22.04 et installe un environnement de bureau complet accessible via navigateur.

## Couches de construction

### Couche 1 — Système de base + Bureau XFCE4

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
```

Paquets installés :
- `xfce4`, `xfce4-terminal`, `xfce4-goodies` → Bureau XFCE4 complet
- `x11vnc` → Serveur VNC (capture l'écran X11)
- `xvfb` → Serveur X virtuel (pas d'écran physique nécessaire)
- `novnc`, `websockify` → Interface web noVNC (VNC via navigateur)
- `supervisor` → Gestionnaire de processus (lance et supervise tous les services)
- `dbus-x11` → Bus de messages nécessaire pour XFCE4
- `fonts-ubuntu`, `fonts-noto` → Polices de caractères
- Thèmes d'icônes : `adwaita`, `papirus`, `hicolor`

### Couche 2 — Applications utilisateur

| Application | Usage |
|---|---|
| `curl`, `wget` | Téléchargements |
| `git` | Versioning de code |
| `vim`, `nano` | Éditeurs texte |
| `htop` | Moniteur de ressources |
| `net-tools`, `iputils-ping` | Outils réseau |
| `python3`, `pip` | Développement Python |
| `nodejs`, `npm` | Développement JavaScript |
| `gimp` | Retouche d'images |
| `thunderbird` | Client mail |
| `vlc` | Lecteur multimédia |
| `thunar` | Gestionnaire de fichiers |
| `sudo` | Élévation de privilèges |

### Couche 3 — Firefox (natif, sans snap)

```dockerfile
# Utilise le PPA Mozilla pour obtenir Firefox sans snap
add-apt-repository ppa:mozillateam/ppa
# Priorité 1001 pour forcer l'utilisation du PPA au lieu du snap Ubuntu
echo 'Pin-Priority: 1001' > /etc/apt/preferences.d/mozilla-firefox
```

> **Pourquoi sans snap ?** Les snaps ne fonctionnent pas correctement dans les containers Docker (isolation des namespaces incompatible).

### Couche 4 — Visual Studio Code

```dockerfile
# Dépôt officiel Microsoft
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor
echo "deb [...] https://packages.microsoft.com/repos/code stable main"
apt-get install -y code
```

### Couche 5 — Utilisateur `kasm-user`

```dockerfile
useradd -m -s /bin/bash kasm-user
echo "kasm-user:password123" | chpasswd        # Mot de passe par défaut
usermod -aG sudo kasm-user
echo "kasm-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers  # Sudo sans mot de passe
```

> **Sécurité :** Le mot de passe `password123` est en dur dans le Dockerfile. En production, utiliser une variable d'environnement ou une génération aléatoire.

### Couche 6 — Fichiers de configuration

| Source (build) | Destination (container) | Usage |
|---|---|---|
| `config/xfce4-desktop.xml` | `~/.config/xfce4/.../xfce4-desktop.xml` | Fond d'écran XFCE4 |
| `config/xfce4-screensaver.xml` | `~/.config/xfce4/.../xfce4-screensaver.xml` | Désactive l'économiseur d'écran |
| `scripts/supervisord.conf` | `/etc/supervisor/conf.d/supervisord.conf` | Config supervisord |
| `scripts/startup.sh` | `/startup.sh` | Point d'entrée du container |

### Couche 7 — Raccourcis bureau

Raccourcis `.desktop` créés dans `/home/kasm-user/Desktop/` :
- Firefox, Terminal XFCE, Visual Studio Code, GIMP, Thunderbird, VLC, Thunar

### Port exposé

```dockerfile
EXPOSE 6901   # Port noVNC (interface web VNC)
```

## Configuration supervisord

Fichier : `/home/docker/issat-desktop/scripts/supervisord.conf`

Supervisord est le **chef d'orchestre** du container. Il démarre et surveille tous les processus dans le bon ordre.

| Programme | Priorité | Commande | Description |
|---|---|---|---|
| `Xvfb` | 1 | `Xvfb :1 -screen 0 1920x1080x24` | Écran virtuel 1920×1080, 24 bits |
| `x11vnc` | 2 | `x11vnc -display :1 -nopw -shared -forever` | Serveur VNC sans mot de passe |
| `xfce4` | 2 | `dbus-launch --exit-with-session startxfce4` | Bureau XFCE4 via dbus |
| `novnc` | 3 | `websockify --web=/usr/share/novnc/ 6901 localhost:5900` | Pont WebSocket → VNC |
| `disable-screensaver` | 5 | `xfconf-query` × 3 | Désactive l'économiseur |

**Ordre de démarrage :**
1. Xvfb démarre (crée l'écran virtuel `:1`)
2. x11vnc et XFCE4 **attendent** que Xvfb soit prêt (`xdpyinfo -display :1`)
3. noVNC **attend** que le port VNC 5900 soit ouvert
4. Après 5 secondes, le screensaver est désactivé

## Script de démarrage — `startup.sh`

```bash
#!/bin/bash
rm -f /tmp/.X*-lock /tmp/.X11-unix/X*    # Nettoie les verrous X11 résiduels
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
```

> `exec` remplace le processus shell par supervisord, qui devient le **PID 1** du container.

## Construire et publier l'image

```bash
cd /home/docker/issat-desktop

# Construire l'image localement
docker build -t moubarakyampa/vdi-etudiant:latest .

# Tester localement
docker run -d -p 6901:6901 --name test-bureau moubarakyampa/vdi-etudiant:latest
# Accéder via : http://localhost:6901

# Publier sur Docker Hub
docker push moubarakyampa/vdi-etudiant:latest
```
