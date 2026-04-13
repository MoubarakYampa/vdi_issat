# Documentation Technique — Infrastructure ISSAT VDI
**Date de rédaction :** 2026-04-10  
**Serveur :** ubuntu (192.168.1.3)  
**Rédigé par :** Claude Code — analyse complète des fichiers de configuration

---

## Table des matières

1. [Vue d'ensemble de l'architecture](#1-vue-densemble-de-larchitecture)
2. [Infrastructure réseau & pfSense](#2-infrastructure-réseau--pfsense)
3. [Serveur Ubuntu — Ressources système](#3-serveur-ubuntu--ressources-système)
4. [Docker — Vue d'ensemble des containers](#4-docker--vue-densemble-des-containers)
5. [Authentik — Serveur d'authentification SSO](#5-authentik--serveur-dauthentification-sso)
6. [Nginx — Reverse Proxy](#6-nginx--reverse-proxy)
7. [Image Docker personnalisée — issat-desktop / vdi-etudiant](#7-image-docker-personnalisée--issat-desktop--vdi-etudiant)
8. [Containers Kasm — Postes de travail virtuels](#8-containers-kasm--postes-de-travail-virtuels)
9. [Scripts d'automatisation](#9-scripts-dautomatisation)
10. [Application Flask — redirector.py](#10-application-flask--redirectorpy)
11. [Application Flask — webhook_receiver.py](#11-application-flask--webhook_receiverpy)
12. [Flux complet d'authentification et de démarrage](#12-flux-complet-dauthentification-et-de-démarrage)
13. [Arborescence complète des fichiers](#13-arborescence-complète-des-fichiers)
14. [Utilisateurs actifs](#14-utilisateurs-actifs)
15. [Points d'attention et recommandations](#15-points-dattention-et-recommandations)

---

## 1. Vue d'ensemble de l'architecture

Ce système est une **infrastructure VDI (Virtual Desktop Infrastructure)** conçue pour les étudiants de l'ISSAT. Elle permet à chaque étudiant d'accéder via un navigateur web à un **bureau Linux complet** (XFCE4), isolé dans un container Docker, accessible via le protocole **noVNC** (VNC sur WebSocket).

### Schéma de l'architecture

```
Internet / Réseau externe
         │
         ▼
  ┌─────────────┐
  │  pfSense    │  WAN : 192.168.11.196
  │  Pare-feu   │  LAN : 192.168.1.1
  └──────┬──────┘
         │ NAT / Port forwarding (ports 7000-8000, 80)
         ▼
  ┌──────────────────────────────────────────────────┐
  │  Serveur Ubuntu — 192.168.1.3                    │
  │                                                  │
  │  ┌──────────┐   ┌────────────┐  ┌─────────────┐ │
  │  │  Nginx   │──▶│ Authentik  │  │  redirector │ │
  │  │ :80      │   │ :9000      │  │  Flask :8080│ │
  │  └────┬─────┘   └────────────┘  └──────┬──────┘ │
  │       │                                │         │
  │       ▼                                ▼         │
  │  ┌──────────────────────────────────────────┐    │
  │  │         Containers Kasm (VDI)            │    │
  │  │  kasm-malek    :7000                     │    │
  │  │  kasm-testuser :7001                     │    │
  │  │  kasm-akadmin  :7002                     │    │
  │  └──────────────────────────────────────────┘    │
  │                                                  │
  │  ┌────────────┐   ┌─────────────┐               │
  │  │ PostgreSQL │   │   webhook   │               │
  │  │    :5432   │   │  Flask:9001 │               │
  │  └────────────┘   └─────────────┘               │
  └──────────────────────────────────────────────────┘
```

### Composants principaux

| Composant | Rôle | Port |
|---|---|---|
| **pfSense** | Pare-feu, NAT, routage | WAN: 192.168.11.196 |
| **Nginx** | Reverse proxy, authentification des requêtes | 80 |
| **Authentik** | SSO (Single Sign-On), gestion des utilisateurs | 9000, 9443 |
| **redirector.py** | Redirige l'étudiant vers son bureau VDI | 8080 |
| **webhook_receiver.py** | Démarre/arrête les containers selon login/logout | 9001 |
| **Containers Kasm** | Bureau Linux XFCE4 par étudiant via noVNC | 7000–8000 |
| **PostgreSQL** | Base de données d'Authentik | 5432 (interne) |

---

## 2. Infrastructure réseau & pfSense

### Topologie réseau

```
WAN (Internet / réseau externe)
    │
    │  IP WAN : 192.168.11.196
    ▼
┌──────────┐
│ pfSense  │
└──────────┘
    │
    │  IP LAN : 192.168.1.1
    │  Réseau LAN : 192.168.1.0/24
    ▼
Serveur Ubuntu : 192.168.1.3
```

### Règles NAT configurées sur pfSense

Les règles de NAT (Port Forwarding) redirigent les connexions entrantes sur le WAN vers le serveur Ubuntu :

| Port(s) WAN | IP destination | Port destination | Usage |
|---|---|---|---|
| **80** | 192.168.1.3 | 80 | Nginx (Authentik + VDI) |
| **7000–8000** | 192.168.1.3 | 7000–8000 | Accès direct aux containers Kasm (à éviter en production) |

> **Note :** Les ports 7000–8000 exposent directement les containers noVNC sans authentification. En production, seul le port 80 (via Nginx qui force l'authentification) devrait être exposé.

### Réseau interne du serveur Ubuntu

| Interface | Adresse | Usage |
|---|---|---|
| `ens18` | 192.168.1.3/24 | Interface physique, réseau LAN |
| `docker0` | 172.17.0.1/16 | Réseau Docker par défaut (containers Kasm) |
| `br-8264da28702a` | 172.18.0.1/16 | Réseau Docker `ubuntu_default` (Authentik stack) |
| `lo` | 127.0.0.1 | Loopback |

### DNS local (noms d'hôtes utilisés)

| Nom | Résolution | Usage |
|---|---|---|
| `issat.local` | 192.168.1.3 | Interface Authentik (réseau interne) |
| `labo.issat.local` | 192.168.1.3 ou 192.168.11.196 | Portail VDI + accès aux bureaux |

> Ces noms doivent être configurés dans pfSense (DNS Resolver) ou dans les fichiers `/etc/hosts` des postes clients.

---

## 3. Serveur Ubuntu — Ressources système

### Informations système

| Paramètre | Valeur |
|---|---|
| **OS** | Ubuntu Linux |
| **Kernel** | 6.8.0-106-generic (x86_64) |
| **Compilé le** | 6 mars 2026 |
| **Architecture** | x86_64 |

### Mémoire RAM

| | Total | Utilisé | Libre | Disponible |
|---|---|---|---|---|
| **RAM** | 21 Go | 3,4 Go | 506 Mo | 17 Go |
| **Swap** | 8 Go | 669 Mo | 7,3 Go | — |

> Le serveur dispose de beaucoup de mémoire disponible (~17 Go). Chaque container Kasm est limité à 1 Go, donc le serveur peut théoriquement accueillir ~15 bureaux simultanés.

### Stockage disque

| Partition | Taille | Utilisé | Disponible | % |
|---|---|---|---|---|
| `/` (LVM ubuntu-vg) | 95 Go | 60 Go | 31 Go | 66% |
| `/boot` | 2 Go | 200 Mo | 1,6 Go | 11% |

> Le disque principal est rempli à 66%. Avec la croissance des données étudiants (dossiers kasm-data), surveiller l'espace disponible.

---

## 4. Docker — Vue d'ensemble des containers

### Containers en cours d'exécution

```
CONTAINER ID   IMAGE                              STATUT        PORTS                    NOM
d1d70f77bb4a   moubarakyampa/vdi-etudiant:latest  Up 40h        0.0.0.0:7002->6901/tcp   kasm-akadmin
65a2b9783753   moubarakyampa/vdi-etudiant:latest  Up 41h        0.0.0.0:7001->6901/tcp   kasm-testuser
15277e1cd3d7   moubarakyampa/vdi-etudiant:latest  Up 40h        0.0.0.0:7000->6901/tcp   kasm-malek
fd5e0c2861b6   goauthentik/server:2026.2.1        Up 2j (sain)  0.0.0.0:9000,9443->...   ubuntu-server-1
19412aa76644   goauthentik/server:2026.2.1        Up 2j (sain)                            ubuntu-worker-1
9c87e159f17c   postgres:16-alpine                 Up 2j (sain)  5432/tcp (interne)        ubuntu-postgresql-1
```

### Réseaux Docker

| Nom | Driver | Sous-réseau | Usage |
|---|---|---|---|
| `bridge` (docker0) | bridge | 172.17.0.0/16 | Containers Kasm (réseau par défaut) |
| `ubuntu_default` | bridge | 172.18.0.0/16 | Stack Authentik (postgresql + server + worker) |
| `host` | host | — | Accès direct à l'hôte |
| `none` | null | — | Isolation totale |

### Volumes Docker

| Nom | Driver | Usage |
|---|---|---|
| `ubuntu_database` | local | Base de données PostgreSQL d'Authentik |

---

## 5. Authentik — Serveur d'authentification SSO

### Qu'est-ce qu'Authentik ?

Authentik est un **Identity Provider (IdP)** open-source. Il gère l'authentification des utilisateurs (login/logout), les sessions, et peut déclencher des **webhooks** lors d'événements (connexion, déconnexion).

Dans ce projet, Authentik est le **gardien d'entrée** : aucun étudiant ne peut accéder à son bureau VDI sans s'être authentifié via Authentik.

### Fichier docker-compose.yml — `/home/ubuntu/docker-compose.yml`

```yaml
services:
  postgresql:       # Base de données
  server:           # Serveur Authentik (interface web + API)
  worker:           # Worker Authentik (tâches en arrière-plan)
```

#### Service `postgresql`
- **Image :** `postgres:16-alpine` (légère et stable)
- **Base de données :** `authentik` (par défaut)
- **Données persistées dans :** volume Docker `ubuntu_database`
- **Health check :** vérifie que PostgreSQL est prêt toutes les 30 secondes

#### Service `server` (Authentik)
- **Image :** `ghcr.io/goauthentik/server:2026.2.1`
- **Commande :** `server` (interface web + API REST)
- **Ports exposés :**
  - `9000` → HTTP (utilisé par Nginx)
  - `9443` → HTTPS
- **Attend que** PostgreSQL soit sain avant de démarrer
- **Données :** montées dans `./data` (dossier `/home/ubuntu/data/`)
- **Templates personnalisés :** `./custom-templates` → `/templates`

#### Service `worker` (Authentik Worker)
- **Image :** identique au server
- **Commande :** `worker` (traitement des tâches : emails, webhooks, etc.)
- **Spécificité :** tourne en tant que `root` et monte le socket Docker `/var/run/docker.sock`
  > Cela permet au worker Authentik d'interagir avec Docker si nécessaire.
- **Certificats SSL :** montés depuis `./certs`

#### Variables d'environnement (fichier `.env`)

Les variables sensibles sont dans `/home/ubuntu/.env` (non partagé) :

| Variable | Description |
|---|---|
| `PG_PASS` | Mot de passe PostgreSQL (obligatoire) |
| `PG_DB` | Nom de la base (défaut : `authentik`) |
| `PG_USER` | Utilisateur PostgreSQL (défaut : `authentik`) |
| `AUTHENTIK_SECRET_KEY` | Clé secrète de chiffrement (obligatoire) |
| `COMPOSE_PORT_HTTP` | Port HTTP (défaut : 9000) |
| `COMPOSE_PORT_HTTPS` | Port HTTPS (défaut : 9443) |
| `AUTHENTIK_TAG` | Version d'Authentik (ici : 2026.2.1) |

### Rôle d'Authentik dans le flux VDI

1. L'étudiant se connecte sur `http://labo.issat.local` → Nginx le redirige vers Authentik
2. Authentik vérifie les identifiants et crée une **session** (cookie `authentik_session`)
3. Authentik envoie un **webhook** à `webhook_receiver.py` (port 9001) avec l'action `login`
4. Le receiver démarre automatiquement le container Kasm de l'étudiant
5. L'étudiant est redirigé vers son bureau via `/bureau`

---

## 6. Nginx — Reverse Proxy

Nginx est le **point d'entrée unique** de toute l'infrastructure. Il joue plusieurs rôles :
- Proxy inverse vers Authentik
- Proxy inverse vers les containers Kasm (noVNC + WebSocket)
- Contrôle d'accès via `auth_request` (vérifie la session avant d'accéder à un bureau)

### Configuration principale — `/etc/nginx/nginx.conf`

```
user www-data;
worker_processes auto;       # Utilise tous les cœurs CPU disponibles
worker_connections 768;      # Connexions max par worker
```

Paramètres activés :
- `sendfile on` → transfert de fichiers optimisé (kernel bypass)
- `tcp_nopush on` → envoi de paquets TCP plus efficace
- `gzip on` → compression des réponses HTTP
- SSL : TLSv1, TLSv1.1, TLSv1.2, TLSv1.3 supportés

> **Recommandation sécurité :** Désactiver TLSv1 et TLSv1.1 (protocoles obsolètes et vulnérables). Garder uniquement TLSv1.2 et TLSv1.3.

### Virtual Host 1 — `issat.local` (dans `/etc/nginx/sites-available/default`)

```
server_name issat.local;
listen 80;
```

| Chemin | Destination | Description |
|---|---|---|
| `/` | `http://192.168.1.3:9000` | Interface de connexion Authentik |
| `/bureau` | `http://192.168.1.3:8080` | Redirecteur Flask vers le bureau VDI |

> Ce virtual host est destiné à un accès **depuis le réseau LAN interne** (résolution DNS de `issat.local` vers 192.168.1.3).

### Virtual Host 2 — `labo.issat.local` (dans `/etc/nginx/sites-available/default`)

```
server_name labo.issat.local 192.168.11.196 127.0.0.1;
listen 80;
```

C'est le virtual host **principal**, accessible depuis l'extérieur via l'IP WAN du pfSense.

| Chemin | Destination | Description |
|---|---|---|
| `/` | `http://192.168.1.3:9000` | Interface Authentik (login) |
| `/bureau` | `http://127.0.0.1:8080` | Redirecteur Flask (avec transmission du cookie) |
| `/auth-kasm` | `http://127.0.0.1:8080/auth-kasm` | Endpoint interne de vérification de session (utilisé par `auth_request`) |
| `/kasm/` | Voir ci-dessous | Accès aux bureaux VDI (protégés) |

#### Protection des bureaux VDI avec `auth_request`

```nginx
location ^~ /kasm/ {
    auth_request /auth-kasm;    # Vérifie la session AVANT de servir le contenu
    error_page 401 = @login;    # Non authentifié → redirige vers login
    error_page 403 = @forbidden;# Mauvais utilisateur → accès refusé
    include /etc/nginx/kasm-locations/*.conf;  # Charge les configs dynamiques
}
```

**Fonctionnement de `auth_request` :**
1. Nginx intercepte toute requête vers `/kasm/...`
2. Il fait une **sous-requête interne** vers `/auth-kasm` (qui appelle `redirector.py`)
3. `redirector.py` vérifie le cookie `authentik_session` et que l'utilisateur accède **à son propre bureau** (pas celui d'un autre)
4. Retourne `200` (OK), `401` (non connecté) ou `403` (accès refusé)

#### Configs dynamiques par utilisateur — `/etc/nginx/kasm-locations/`

Chaque étudiant a son propre fichier de configuration généré automatiquement :

**Exemple pour `malek` — `/etc/nginx/kasm-locations/kasm-malek.conf` :**

```nginx
# Redirection automatique vers l'interface VNC complète avec options de qualité
location = /kasm/malek/ {
    return 302 /kasm/malek/vnc_auto.html?autoconnect=true&reconnect=true
               &reconnect_delay=1000&resize=scale&quality=6
               &path=kasm/malek/websockify;
}

# Tunnel WebSocket pour le flux VNC temps réel
location ^~ /kasm/malek/websockify {
    proxy_pass http://127.0.0.1:7000/websockify;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;     # Upgrade HTTP → WebSocket
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600;    # 1h de timeout (sessions longues)
    proxy_send_timeout 3600;
    proxy_buffering off;        # Désactivé pour le temps réel
}

# Proxy de toutes les ressources statiques noVNC (HTML, JS, images)
location ^~ /kasm/malek/ {
    proxy_pass http://127.0.0.1:7000/;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    ...
}
```

**Containers actifs et leurs ports :**

| Utilisateur | Port hôte | Fichier nginx |
|---|---|---|
| malek | 7000 | kasm-malek.conf |
| testuser | 7001 | kasm-testuser.conf |
| akadmin | 7002 | kasm-akadmin.conf |

### Virtual Host 3 — `laboissat` (fichier séparé `/etc/nginx/sites-available/laboissat`)

Ce fichier est identique au bloc `labo.issat.local` dans `default`. Il s'agit probablement d'une ancienne version ou d'un doublon à nettoyer.

---

## 7. Image Docker personnalisée — issat-desktop / vdi-etudiant

### Dockerfile — `/home/docker/issat-desktop/Dockerfile`

Cette image est la **base du bureau étudiant**. Elle est construite depuis Ubuntu 22.04 et installe un environnement de bureau complet accessible via navigateur.

#### Couche 1 — Système de base + Bureau XFCE4

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

#### Couche 2 — Applications utilisateur

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

#### Couche 3 — Firefox (natif, sans snap)

```dockerfile
# Utilise le PPA Mozilla pour obtenir Firefox sans snap
add-apt-repository ppa:mozillateam/ppa
# Priorité 1001 pour forcer l'utilisation du PPA au lieu du snap Ubuntu
echo 'Pin-Priority: 1001' > /etc/apt/preferences.d/mozilla-firefox
```

> **Pourquoi sans snap ?** Les snaps ne fonctionnent pas correctement dans les containers Docker (isolation des namespaces incompatible).

#### Couche 4 — Visual Studio Code

```dockerfile
# Dépôt officiel Microsoft
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor
echo "deb [...] https://packages.microsoft.com/repos/code stable main"
apt-get install -y code
```

#### Couche 5 — Utilisateur `kasm-user`

```dockerfile
useradd -m -s /bin/bash kasm-user
echo "kasm-user:password123" | chpasswd        # Mot de passe par défaut
usermod -aG sudo kasm-user
echo "kasm-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers  # Sudo sans mot de passe
```

> **Sécurité :** Le mot de passe `password123` est dans le Dockerfile. Dans un environnement de production, utiliser une variable d'environnement ou une génération aléatoire.

#### Couche 6 — Fichiers de configuration copiés

| Source (build) | Destination (container) | Usage |
|---|---|---|
| `config/xfce4-desktop.xml` | `~/.config/xfce4/.../xfce4-desktop.xml` | Fond d'écran XFCE4 |
| `config/xfce4-screensaver.xml` | `~/.config/xfce4/.../xfce4-screensaver.xml` | Désactive l'économiseur d'écran |
| `scripts/supervisord.conf` | `/etc/supervisor/conf.d/supervisord.conf` | Config supervisord |
| `scripts/startup.sh` | `/startup.sh` | Point d'entrée du container |

#### Couche 7 — Raccourcis bureau

Raccourcis `.desktop` créés dans `/home/kasm-user/Desktop/` :
- Firefox, Terminal XFCE, Visual Studio Code, GIMP, Thunderbird, VLC, Thunar (fichiers)

#### Port exposé

```dockerfile
EXPOSE 6901   # Port noVNC (interface web VNC)
```

### Configuration supervisord — `/home/docker/issat-desktop/scripts/supervisord.conf`

Supervisord est le **chef d'orchestre** du container. Il démarre et surveille tous les processus dans le bon ordre.

```
[supervisord]
nodaemon=true    # Reste au premier plan (requis pour Docker)
user=root
```

| Programme | Priorité | Commande | Description |
|---|---|---|---|
| `Xvfb` | 1 | `Xvfb :1 -screen 0 1920x1080x24` | Écran virtuel 1920×1080, 24 bits de couleur, display `:1` |
| `x11vnc` | 2 | `x11vnc -display :1 -nopw -shared -forever` | Serveur VNC sur l'écran `:1`, sans mot de passe, partageable |
| `xfce4` | 2 | `dbus-launch --exit-with-session startxfce4` | Bureau XFCE4 lancé via dbus (nécessaire pour les notifications) |
| `novnc` | 3 | `websockify --web=/usr/share/novnc/ 6901 localhost:5900` | Pont WebSocket → VNC sur le port 6901 |
| `disable-screensaver` | 5 | `xfconf-query` × 3 | Désactive l'économiseur et le verrouillage d'écran |

**Ordre de démarrage :**
1. Xvfb démarre (crée l'écran virtuel `:1`)
2. x11vnc et XFCE4 **attendent** que Xvfb soit prêt (`xdpyinfo -display :1`)
3. noVNC **attend** que le port VNC 5900 soit ouvert
4. Après 5 secondes, le screensaver est désactivé

### Script de démarrage — `/home/docker/issat-desktop/scripts/startup.sh`

```bash
#!/bin/bash
rm -f /tmp/.X*-lock /tmp/.X11-unix/X*    # Nettoie les verrous X11 résiduels (crash précédent)
mkdir -p /tmp/.X11-unix                   # Recrée le répertoire socket X11
chmod 1777 /tmp/.X11-unix                 # Permissions sticky bit (nécessaire pour X11)
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf  # Lance supervisord
```

> `exec` remplace le processus shell par supervisord, qui devient le PID 1 du container.

### Configuration bureau XFCE4

#### Fond d'écran — `xfce4-desktop.xml`

```xml
<property name="last-image" type="string"
    value="/usr/share/backgrounds/xfce/xfce-verticals.png"/>
<property name="image-style" type="int" value="5"/>   <!-- Mode : étiré -->
```

Fond d'écran par défaut XFCE4 (`xfce-verticals.png`), affiché en mode étiré.

#### Économiseur d'écran désactivé — `xfce4-screensaver.xml`

```xml
<property name="enabled" type="bool" value="false"/>        <!-- Pas d'économiseur -->
<property name="lock-enabled" type="bool" value="false"/>   <!-- Pas de verrouillage -->
```

> Essentiel pour un usage VDI : évite que les sessions se verrouillent pendant les cours.

---

## 8. Containers Kasm — Postes de travail virtuels

### Concept

Chaque étudiant dispose de son propre container Docker. Ce container est :
- **Isolé** : chaque étudiant a son propre système, ses propres processus
- **Persistant** : les données personnelles (Documents, Downloads, etc.) sont stockées en dehors du container via des volumes
- **Limité en ressources** : 1 Go de RAM maximum par étudiant

### Données persistantes par étudiant

Structure dans `/home/docker/kasm-data/<username>/` :

```
/home/docker/kasm-data/
├── malek/
│   ├── Documents/
│   ├── Downloads/
│   ├── Music/
│   ├── Pictures/
│   ├── Videos/
│   ├── PDF/
│   └── Uploads/
├── akadmin/
│   └── (mêmes dossiers)
└── testuser/
    └── (mêmes dossiers)
```

Ces dossiers sont montés dans le container comme :
```
/home/docker/kasm-data/malek/Documents → /home/etudiant/Documents (dans le container)
```

> **Propriétaire :** uid/gid 1000:1000 avec permissions 755.

### Paramètres de lancement des containers

```bash
docker run -d \
    --security-opt seccomp=unconfined \  # Désactive les restrictions seccomp (nécessaire pour X11/VNC)
    --shm-size="512m" \                  # 512 Mo de mémoire partagée (pour le rendu graphique)
    --memory="1g" \                      # Limite RAM à 1 Go par étudiant
    --restart=no \                       # Ne redémarre pas automatiquement (géré par webhook)
    -p "$PORT:6901" \                    # Port dynamique hôte → port noVNC 6901 container
    --name "kasm-$USER_NAME" \
    moubarakyampa/vdi-etudiant:latest
```

### Sélection dynamique du port

Le script cherche le premier port libre entre 7000 et 8000 :

```bash
for PORT in $(seq 7000 8000); do
    # Vérifie dans le système (ss) ET dans Docker (docker inspect)
    # pour éviter les conflits
    USED=$(ss -Htan | awk '{print $4}' | grep -oE '[0-9]+$' | grep -xF "$PORT")
    DOCKER_USED=$(docker inspect ... | grep -oE 'HostPort":"[0-9]+' | grep -xF "$PORT")
    if [ -z "$USED" ] && [ -z "$DOCKER_USED" ]; then
        break  # Port libre trouvé
    fi
done
```

---

## 9. Scripts d'automatisation

### 9.1 `lancer_kasm.sh` — Version principale `/home/docker/lancer_kasm.sh`

**Usage :** `./lancer_kasm.sh <nom_utilisateur>`

**Comportement :**

```
Si le container "kasm-<user>" existe déjà
    → Le redémarrer
Sinon
    1. Créer les dossiers de données
    2. Trouver un port libre (7000-8000)
    3. Lancer le container Docker
    4. Générer la config Nginx (/etc/nginx/kasm-locations/)
    5. Recharger Nginx
```

> **Différence avec la version dans `authentik/` :** La version racine crée un seul volume (`/home/etudiant`). La version Authentik crée des sous-dossiers séparés (Documents, Downloads, etc.) pour une meilleure organisation.

### 9.2 `lancer_kasm.sh` — Version améliorée `/home/docker/authentik/lancer_kasm.sh`

**Améliorations par rapport à la version racine :**
- Volumes **séparés** par type (Documents, Downloads, Music, Pictures, Videos, PDF, Uploads)
- Après création, **relit le port** depuis Docker inspect (plus fiable)
- Affiche l'URL finale : `http://labo.issat.local/kasm/<user>/`

### 9.3 `stopper_kasm.sh` — `/home/docker/authentik/stopper_kasm.sh`

**Usage :** `./stopper_kasm.sh <nom_utilisateur>`

```bash
# 1. Arrête le container s'il tourne
docker stop "kasm-$USER_NAME"

# 2. Supprime la config Nginx et recharge
sudo rm /etc/nginx/kasm-locations/kasm-${USER_NAME}.conf
sudo nginx -t && sudo systemctl reload nginx
```

> Quand un étudiant se déconnecte d'Authentik, ce script libère les ressources (RAM, port). C'est déclenché automatiquement par le webhook.

### 9.4 `fix_nginx_configs.sh` — `/home/docker/authentik/fix_nginx_configs.sh`

**Usage :** `./fix_nginx_configs.sh`

Script de **récupération d'urgence**. Il régénère toutes les configs Nginx en scannant les containers `kasm-*` actifs.

```bash
# Pour chaque container dont le nom commence par "kasm-"
for container in $(docker ps -a --format '{{.Names}}' | grep ^kasm-); do
    user=$(echo $container | sed 's/kasm-//')
    docker start $container 2>/dev/null           # Démarre si arrêté
    port=$(docker inspect $container ...)          # Récupère le port
    sudo tee /etc/nginx/kasm-locations/kasm-${user}.conf  # Génère la config
done
sudo nginx -t && sudo systemctl reload nginx
```

> **Cas d'usage :** après un redémarrage du serveur, les configs Nginx ont disparu mais les containers sont peut-être encore là.

---

## 10. Application Flask — `redirector.py`

**Fichier :** `/home/docker/authentik/redirector.py`  
**Port :** 8080  
**Framework :** Flask + docker SDK Python

Ce service est le **cerveau de la redirection**. Il fait le lien entre la session Authentik et le container Docker de l'étudiant.

### Endpoints

#### `GET /auth-kasm` — Vérification d'accès (utilisé par Nginx `auth_request`)

```
Nginx intercepte /kasm/USERNAME/...
    → Appelle en interne /auth-kasm
        → Lit le cookie "authentik_session"
        → Interroge l'API Authentik : GET /api/v3/core/users/me/
        → Extrait le username depuis la réponse JSON
        → Vérifie que le username de l'URL correspond au username connecté
    → Retourne 200 (OK), 401 (non connecté), ou 403 (accès interdit)
```

**Exemple de requête vers l'API Authentik :**
```python
response = requests.get(
    "http://192.168.1.3:9000/api/v3/core/users/me/",
    cookies={"authentik_session": session_cookie},
    timeout=5
)
# Retourne : {"user": {"username": "malek", ...}}
```

**Protection contre l'accès croisé :**
```python
# Si malek essaie d'accéder à /kasm/testuser/...
if kasm_user != username:      # "testuser" != "malek"
    return "", 403             # Accès refusé
```

#### `GET /bureau` (et toute URL) — Redirection vers le bureau

```
1. Lit le cookie "authentik_session"
2. Interroge l'API Authentik pour obtenir le username
3. Interroge Docker pour trouver le port du container "kasm-<username>"
4. Redirige vers : /kasm/<username>/vnc_auto.html?autoconnect=true&...
```

**Paramètres noVNC dans l'URL de redirection :**
- `autoconnect=true` → Connexion automatique sans clic
- `reconnect=true` → Reconnexion automatique si coupure
- `reconnect_delay=1000` → Attendre 1 seconde avant de retenter
- `resize=scale` → Adapte la résolution à la fenêtre du navigateur
- `quality=6` → Qualité d'image VNC (0=min, 9=max)

#### `GET /status` — Monitoring des containers actifs

```json
{
    "redirecteur": "actif",
    "total": 3,
    "containers": [
        {
            "utilisateur": "malek",
            "container": "kasm-malek",
            "port": "7000",
            "url": "http://labo.issat.local/kasm/malek/",
            "statut": "running"
        },
        ...
    ]
}
```

---

## 11. Application Flask — `webhook_receiver.py`

**Fichier :** `/home/docker/authentik/webhook_receiver.py`  
**Port :** 9001  
**Framework :** Flask

Ce service écoute les **webhooks envoyés par Authentik** lors des événements de session.

### Endpoint `POST /webhook`

**Format JSON attendu :**
```json
{
    "user": {"username": "malek"},
    "action": "login"
}
```

**Actions gérées :**

| Action | Script exécuté | Résultat |
|---|---|---|
| `login` | `lancer_kasm.sh malek` | Démarre le container kasm-malek |
| `custom_notification_test` | `lancer_kasm.sh malek` | Identique à login (pour tests) |
| `logout` | `stopper_kasm.sh malek` | Arrête le container kasm-malek |
| Autre | Aucun | Réponse `ignored` |

**Exécution des scripts :**
```python
subprocess.run(
    ["sudo", "-n", "bash", script, user],
    capture_output=True, text=True
)
```

> `-n` signifie "non-interactif" : si sudo demande un mot de passe, il échoue immédiatement plutôt que d'attendre. L'utilisateur `www-data` (ou l'utilisateur Flask) doit avoir le droit d'exécuter ces scripts via sudoers.

**Codes de retour HTTP :**
- `200` : container créé ou redémarré
- `200` : container arrêté
- `200` : action ignorée (inconnue)
- `400` : JSON invalide
- `500` : erreur d'exécution du script

---

## 12. Flux complet d'authentification et de démarrage

Voici le parcours complet d'un étudiant de l'ouverture du navigateur jusqu'à son bureau :

```
Étudiant ouvre http://labo.issat.local
        │
        ▼
    Nginx (labo.issat.local)
        │  location /  → proxy_pass Authentik :9000
        ▼
    Page de login Authentik
        │
        │  [Étudiant entre login + mot de passe]
        ▼
    Authentik vérifie les identifiants
        │
        ├──► Crée un cookie de session "authentik_session"
        │
        └──► Envoie un webhook POST à webhook_receiver.py:9001
                {
                  "user": {"username": "malek"},
                  "action": "login"
                }
                        │
                        ▼
              webhook_receiver.py
                        │
                        └──► sudo bash lancer_kasm.sh malek
                                    │
                                    ├── Trouve port libre (ex: 7000)
                                    ├── docker run kasm-malek -p 7000:6901
                                    ├── Génère /etc/nginx/kasm-locations/kasm-malek.conf
                                    └── sudo nginx -t && systemctl reload nginx

Étudiant est redirigé vers /bureau
        │
        ▼
    Nginx → proxy_pass http://127.0.0.1:8080 (redirector.py)
        │
        ▼
    redirector.py
        │  Lit cookie "authentik_session"
        │  GET http://192.168.1.3:9000/api/v3/core/users/me/
        │  → username = "malek"
        │  docker inspect kasm-malek → port = 7000
        │
        └──► Redirect 302 vers :
             /kasm/malek/vnc_auto.html?autoconnect=true&...

Navigateur charge /kasm/malek/
        │
        ▼
    Nginx : auth_request /auth-kasm
        │
        ▼
    redirector.py /auth-kasm
        │  Vérifie session → username = "malek"
        │  URL = /kasm/malek/ → kasm_user = "malek"
        │  "malek" == "malek" → OK
        └──► Retourne 200
        │
        ▼
    Nginx : include kasm-malek.conf
        │  proxy_pass http://127.0.0.1:7000/
        ▼
    Container kasm-malek (noVNC)
        │
        ▼
    Bureau XFCE4 affiché dans le navigateur ✓
```

### Déconnexion

```
Étudiant se déconnecte d'Authentik
        │
        └──► Webhook POST → webhook_receiver.py
                {
                  "user": {"username": "malek"},
                  "action": "logout"
                }
                        │
                        └──► sudo bash stopper_kasm.sh malek
                                    │
                                    ├── docker stop kasm-malek
                                    ├── rm /etc/nginx/kasm-locations/kasm-malek.conf
                                    └── sudo nginx -t && systemctl reload nginx
```

---

## 13. Arborescence complète des fichiers

```
/home/
├── ubuntu/                          # Utilisateur système principal
│   ├── docker-compose.yml           # Stack Authentik (server + worker + postgresql)
│   ├── .env                         # Variables sensibles (mots de passe, clés secrètes)
│   ├── data/                        # Données Authentik (avatars, médias, config)
│   ├── certs/                       # Certificats TLS pour le worker Authentik
│   └── custom-templates/            # Templates HTML personnalisés pour Authentik
│
└── docker/                          # Dossier principal des ressources Docker
    ├── lancer_kasm.sh               # Script de lancement (version basique)
    │
    ├── authentik/                   # Scripts liés à l'intégration Authentik
    │   ├── lancer_kasm.sh           # Script de lancement (version complète avec sous-volumes)
    │   ├── stopper_kasm.sh          # Arrête le container et supprime la config Nginx
    │   ├── fix_nginx_configs.sh     # Régénère toutes les configs Nginx depuis les containers actifs
    │   ├── redirector.py            # Flask :8080 — redirecteur + auth_request pour Nginx
    │   └── webhook_receiver.py      # Flask :9001 — écoute les webhooks Authentik
    │
    ├── issat-desktop/               # Image Docker personnalisée du bureau étudiant
    │   ├── Dockerfile               # Construction de l'image Ubuntu + XFCE4 + apps
    │   ├── config/
    │   │   ├── xfce4-desktop.xml    # Fond d'écran XFCE4
    │   │   └── xfce4-screensaver.xml # Désactivation de l'économiseur d'écran
    │   ├── scripts/
    │   │   ├── startup.sh           # Point d'entrée du container (lance supervisord)
    │   │   └── supervisord.conf     # Supervision de Xvfb, x11vnc, XFCE4, noVNC
    │   └── desktop/                 # Raccourcis bureau (.desktop)
    │       ├── firefox.desktop
    │       ├── terminal.desktop
    │       └── vscode.desktop
    │
    └── kasm-data/                   # Données persistantes des étudiants
        ├── malek/                   # Données de l'étudiant malek
        │   ├── Documents/
        │   ├── Downloads/
        │   ├── Music/
        │   ├── Pictures/
        │   ├── Videos/
        │   ├── PDF/
        │   └── Uploads/
        ├── akadmin/                 # Données de l'admin akadmin
        └── testuser/                # Données de l'utilisateur test

/etc/nginx/
├── nginx.conf                       # Config principale Nginx
├── sites-available/
│   ├── default                      # VH issat.local + VH par défaut (port 80)
│   ├── issat                        # (probablement ancien/doublon)
│   └── laboissat                    # VH labo.issat.local (avec auth_request)
├── sites-enabled/                   # Liens symboliques vers sites-available
└── kasm-locations/                  # Configs générées dynamiquement (une par étudiant)
    ├── kasm-malek.conf              # Proxy noVNC pour malek (port 7000)
    ├── kasm-testuser.conf           # Proxy noVNC pour testuser (port 7001)
    └── kasm-akadmin.conf            # Proxy noVNC pour akadmin (port 7002)
```

---

## 14. Utilisateurs actifs

Au moment de l'analyse (2026-04-10), 3 containers sont actifs :

| Utilisateur | Container | Port | Durée d'activité | URL d'accès |
|---|---|---|---|---|
| malek | kasm-malek | 7000 | 41 heures | `http://labo.issat.local/kasm/malek/` |
| testuser | kasm-testuser | 7001 | 41 heures | `http://labo.issat.local/kasm/testuser/` |
| akadmin | kasm-akadmin | 7002 | 40 heures | `http://labo.issat.local/kasm/akadmin/` |

> Les containers ont démarré il y a 40–41 heures et tournent en continu. Sans déconnexion Authentik, les containers restent actifs indéfiniment (`--restart=no` signifie qu'ils ne redémarrent pas après un reboot du serveur).

---

## 15. Points d'attention et recommandations

### Sécurité

| Priorité | Problème | Recommandation |
|---|---|---|
| 🔴 HAUTE | Mot de passe `password123` hardcodé dans le Dockerfile | Utiliser `ARG PASSWORD` avec une variable d'environnement, ou désactiver le compte |
| 🔴 HAUTE | Ports 7000–8000 exposés directement via pfSense | Supprimer ces règles NAT. Tout le trafic doit passer par Nginx (port 80/443) |
| 🔴 HAUTE | Pas de HTTPS | Ajouter Let's Encrypt (Certbot) ou un certificat auto-signé. Toutes les sessions et cookies circulent en clair |
| 🟡 MOYENNE | `kasm-user ALL=(ALL) NOPASSWD:ALL` dans sudoers | Un étudiant a sudo sans mot de passe dans son container |
| 🟡 MOYENNE | TLSv1 et TLSv1.1 activés dans nginx.conf | Désactiver ces versions obsolètes : `ssl_protocols TLSv1.2 TLSv1.3;` |
| 🟡 MOYENNE | Le worker Authentik monte `/var/run/docker.sock` | Accès complet au daemon Docker. Limiter si possible |
| 🟠 FAIBLE | `server_tokens` non désactivé dans nginx.conf | Décommenter `server_tokens off;` pour masquer la version Nginx |

### Fonctionnement

| | Observation | Action suggérée |
|---|---|---|
| ⚠️ | Deux versions de `lancer_kasm.sh` coexistent | Utiliser uniquement la version dans `authentik/` (plus complète) et supprimer `/home/docker/lancer_kasm.sh` |
| ⚠️ | `redirector.py` et `webhook_receiver.py` ne sont pas gérés comme services | Les enregistrer comme services systemd (`systemctl enable/start`) ou les ajouter dans docker-compose |
| ⚠️ | Les containers Kasm utilisent `--restart=no` | Après un reboot du serveur, les containers ne redémarrent pas. Les étudiants doivent se déconnecter/reconnecter |
| ℹ️ | `fix_nginx_configs.sh` existe comme outil de récupération | À conserver, mais documenter quand l'utiliser |
| ℹ️ | Disque à 66% d'utilisation | Surveiller la croissance de `/home/docker/kasm-data/` et du volume `ubuntu_database` |

### Améliorations suggérées

1. **HTTPS obligatoire** : Ajouter Certbot pour Let's Encrypt sur `labo.issat.local`
2. **Systemd pour Flask** : Créer des unités systemd pour `redirector.py` et `webhook_receiver.py` afin qu'ils démarrent automatiquement
3. **Limite de sessions** : Ajouter une logique pour limiter le nombre de containers simultanés (éviter les abus)
4. **Monitoring** : Exposer `/status` de `redirector.py` uniquement sur le réseau interne (actuellement accessible sans authentification)
5. **Nettoyage automatique** : Script cron pour arrêter les containers inactifs depuis plus de N heures

---

*Documentation générée automatiquement à partir de l'analyse des fichiers de configuration du serveur Ubuntu ISSAT (192.168.1.3) — 2026-04-10*
