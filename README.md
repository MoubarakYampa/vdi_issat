# Infrastructure VDI — ISSAT

<div align="center">

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-Reverse_Proxy-009639?style=for-the-badge&logo=nginx&logoColor=white)
![Authentik](https://img.shields.io/badge/Authentik-SSO-FD4B2D?style=for-the-badge&logo=auth0&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-Python_3-000000?style=for-the-badge&logo=flask&logoColor=white)
![noVNC](https://img.shields.io/badge/noVNC-Bureau_Web-6E9CF7?style=for-the-badge&logo=vnc&logoColor=white)

**Infrastructure VDI (Virtual Desktop Infrastructure) permettant à chaque étudiant d'accéder depuis son navigateur à un bureau Linux complet, isolé et sécurisé.**

</div>

---

## Architecture générale

```mermaid
graph TB
    subgraph INTERNET["🌐 Réseau externe"]
        ETU["💻 Étudiant\n(Navigateur Web)"]
    end

    subgraph PFSENSE["🔥 pfSense — Pare-feu"]
        PF["pfSense\nWAN: 192.168.11.196\nLAN: 192.168.1.1\nNAT → port 80"]
    end

    subgraph SERVEUR["🖥️ Serveur Ubuntu — 192.168.1.3"]
        NGINX["⚙️ Nginx :80\nReverse Proxy\n+ auth_request"]
        AUTH["🔐 Authentik :9000\nSSO / Identity Provider"]
        REDIR["🔀 redirector.py :8080\nFlask — Redirection VDI"]
        HOOK["📡 webhook_receiver.py :9001\nFlask — Gestion containers"]
        DB["🗄️ PostgreSQL :5432\nBase Authentik"]

        subgraph VDI["🖥️ Containers VDI (noVNC)"]
            K1["kasm-malek :7000"]
            K2["kasm-testuser :7001"]
            K3["kasm-akadmin :7002"]
        end
    end

    ETU -->|"HTTPS/HTTP"| PF
    PF -->|"NAT :80"| NGINX
    NGINX -->|"proxy_pass"| AUTH
    NGINX -->|"proxy_pass /bureau"| REDIR
    NGINX -->|"auth_request"| REDIR
    NGINX -->|"proxy WebSocket /kasm/*"| VDI
    AUTH -->|"webhook login/logout"| HOOK
    HOOK -->|"lancer/stopper_kasm.sh"| VDI
    REDIR -->|"API /users/me/"| AUTH
    REDIR -->|"Docker inspect"| VDI
    AUTH --- DB

    style INTERNET fill:#1a1a2e,color:#fff,stroke:#4a4a8a
    style PFSENSE fill:#2d1b00,color:#fff,stroke:#ff8c00
    style SERVEUR fill:#0d2137,color:#fff,stroke:#1e6eb5
    style VDI fill:#0a2a0a,color:#fff,stroke:#2d8a2d
    style ETU fill:#1e3a5f,color:#fff,stroke:#4a90d9
    style PF fill:#7a3800,color:#fff,stroke:#ff8c00
    style NGINX fill:#006400,color:#fff,stroke:#00aa00
    style AUTH fill:#8b0000,color:#fff,stroke:#ff4444
    style REDIR fill:#00008b,color:#fff,stroke:#4444ff
    style HOOK fill:#4a0080,color:#fff,stroke:#9900ff
    style DB fill:#003366,color:#fff,stroke:#0066cc
    style K1 fill:#1a4a1a,color:#fff,stroke:#2d8a2d
    style K2 fill:#1a4a1a,color:#fff,stroke:#2d8a2d
    style K3 fill:#1a4a1a,color:#fff,stroke:#2d8a2d
```

---

## Flux d'authentification et de démarrage

```mermaid
sequenceDiagram
    actor E as 💻 Étudiant
    participant N as ⚙️ Nginx
    participant A as 🔐 Authentik
    participant W as 📡 webhook_receiver
    participant S as 📜 lancer_kasm.sh
    participant R as 🔀 redirector.py
    participant K as 🖥️ Container Kasm

    E->>N: GET http://labo.issat.local/
    N->>A: proxy_pass :9000
    A-->>E: Page de login

    E->>A: POST login + mot de passe
    A-->>E: ✅ Cookie authentik_session
    A->>W: POST /webhook {"action":"login","user":"malek"}
    W->>S: sudo bash lancer_kasm.sh malek
    S->>K: docker run kasm-malek -p 7000:6901
    S->>N: Génère kasm-malek.conf + reload

    A-->>E: Redirect → /bureau

    E->>N: GET /bureau (cookie joint)
    N->>R: proxy_pass :8080
    R->>A: GET /api/v3/core/users/me/ (cookie)
    A-->>R: {"username": "malek"}
    R->>K: docker inspect kasm-malek → port 7000
    R-->>E: Redirect → /kasm/malek/vnc_auto.html

    E->>N: GET /kasm/malek/ (accès bureau)
    N->>R: auth_request /auth-kasm
    R-->>N: 200 OK
    N->>K: proxy_pass :7000 (WebSocket noVNC)
    K-->>E: 🖥️ Bureau XFCE4 dans le navigateur
```

---

## Stack technique

| Composant | Rôle | Adresse |
|---|---|---|
| **pfSense** | Pare-feu, NAT, routage réseau | WAN `192.168.11.196` / LAN `192.168.1.1` |
| **Nginx** | Reverse proxy + contrôle d'accès (`auth_request`) | `:80` |
| **Authentik** | SSO, gestion des sessions, webhooks | `:9000` / `:9443` |
| **redirector.py** | Redirection vers le bureau + vérification d'accès | `:8080` |
| **webhook_receiver.py** | Démarrage/arrêt automatique des containers | `:9001` |
| **Containers Kasm** | Bureau Linux XFCE4 par étudiant via noVNC | `:7000–8000` |
| **PostgreSQL** | Base de données Authentik | `:5432` (interne) |

---

## Structure du dépôt

```
issat-vdi-infrastructure/
│
├── README.md                          ← Ce fichier
│
├── docker/                            ← Image Docker du bureau étudiant
│   ├── Dockerfile                     ← Construction Ubuntu 22.04 + XFCE4
│   ├── docker-compose.yml             ← Déploiement local
│   ├── scripts/
│   │   ├── startup.sh                 ← Point d'entrée du container
│   │   ├── supervisord.conf           ← Supervision Xvfb, XFCE4, x11vnc, noVNC
│   │   └── entrypoint.sh             ← Entrypoint alternatif (LXDE)
│   ├── config/
│   │   └── set-wallpaper.sh          ← Application du fond d'écran XFCE4
│   └── src/install/
│       ├── tools/install_tools.sh    ← Paquets système (XFCE4, VNC, outils)
│       ├── firefox/install_firefox.sh ← Firefox natif (sans snap)
│       ├── vscode/install_vscode.sh  ← Visual Studio Code
│       ├── desktop/setup_desktop.sh  ← Raccourcis + thème Arc-Dark
│       └── cleanup/cleanup.sh        ← Nettoyage post-installation
│
├── authentik/
│   └── docker-compose.yml            ← Stack Authentik (server + worker + postgres + redis)
│
├── scripts/
│   ├── lancer_kasm.sh                ← Démarre un bureau VDI pour un étudiant
│   ├── stopper_kasm.sh               ← Arrête un bureau VDI et libère les ressources
│   ├── fix_nginx_configs.sh          ← Récupération d'urgence des configs Nginx
│   └── build-push.sh                 ← Build et push de l'image sur Docker Hub
│
├── flask/
│   ├── redirector.py                 ← Redirecteur Flask :8080 + auth_request
│   └── webhook_receiver.py           ← Récepteur webhooks Authentik :9001
│
└── rapport_infrastructure_issat.md   ← Documentation technique complète
```

---

## Image Docker — Bureau étudiant

L'image `moubarakyampa/vdi-etudiant` est construite depuis Ubuntu 22.04 avec :

```mermaid
graph LR
    A["ubuntu:22.04"] --> B["XFCE4 + VNC\n+ noVNC"]
    B --> C["Outils\ngit, python3\nnodejs, vim..."]
    C --> D["Firefox\n(natif, sans snap)"]
    D --> E["VS Code\n(Microsoft repo)"]
    E --> F["Thème\nArc-Dark\nPapirus-Dark"]
    F --> G["🖼️ moubarakyampa/\nvdi-etudiant:latest"]

    style A fill:#333,color:#fff,stroke:#666
    style B fill:#1a4a1a,color:#fff,stroke:#2d8a2d
    style C fill:#1a3a5f,color:#fff,stroke:#4a90d9
    style D fill:#8b4500,color:#fff,stroke:#ff8c00
    style E fill:#00008b,color:#fff,stroke:#4444ff
    style F fill:#4a0080,color:#fff,stroke:#9900ff
    style G fill:#8b0000,color:#fff,stroke:#ff4444
```

**Applications disponibles dans le bureau :**
- Firefox, Visual Studio Code, Terminal XFCE4
- GIMP, VLC, Thunderbird
- Gestionnaire de fichiers Thunar
- `git`, `python3`, `nodejs`, `npm`, `vim`, `nano`, `htop`, `curl`

**Ordre de démarrage supervisord :**

```
Xvfb :1 (1920×1080)
    └─► XFCE4 + x11vnc (attendent Xvfb)
            └─► noVNC :6901 (attend le port VNC 5900)
                    └─► disable-screensaver (après 20s)
```

### Construire et déployer l'image

```bash
cd docker/

# Construire l'image localement
docker build -t moubarakyampa/vdi-etudiant:latest .

# Tester en local (accès : http://localhost:6901)
docker run -d -p 6901:6901 --shm-size=512m moubarakyampa/vdi-etudiant:latest

# Publier sur Docker Hub
./build-push.sh <ton-username-dockerhub>
```

---

## Déploiement de l'infrastructure

### 1. Démarrer Authentik

```bash
cd authentik/
cp .env.example .env          # Remplir PG_PASS et AUTHENTIK_SECRET_KEY
docker compose up -d
# Interface disponible : http://192.168.1.3:9000/
```

### 2. Configurer Nginx

```bash
# Copier les virtual hosts
sudo cp nginx/sites-available/* /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/laboissat /etc/nginx/sites-enabled/

# Créer le dossier des configs dynamiques
sudo mkdir -p /etc/nginx/kasm-locations

sudo nginx -t && sudo systemctl reload nginx
```

### 3. Démarrer les services Flask

```bash
# Installer les dépendances
pip install flask requests docker

# Démarrage manuel
python3 flask/redirector.py &          # Port 8080
python3 flask/webhook_receiver.py &    # Port 9001

# Démarrage automatique via systemd (recommandé)
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl enable --now redirector webhook-receiver
```

### 4. Gérer les bureaux étudiants

```bash
# Démarrer un bureau
sudo bash scripts/lancer_kasm.sh <nom_etudiant>

# Arrêter un bureau
sudo bash scripts/stopper_kasm.sh <nom_etudiant>

# Après un reboot : régénérer toutes les configs Nginx
sudo bash scripts/fix_nginx_configs.sh

# Vérifier l'état des bureaux actifs
curl http://localhost:8080/status
```

---

## Sudoers nécessaires

Pour que les services Flask puissent exécuter les scripts :

```bash
# /etc/sudoers.d/kasm-vdi
www-data ALL=(ALL) NOPASSWD: /home/docker/authentik/lancer_kasm.sh
www-data ALL=(ALL) NOPASSWD: /home/docker/authentik/stopper_kasm.sh
www-data ALL=(ALL) NOPASSWD: /home/docker/authentik/fix_nginx_configs.sh
www-data ALL=(ALL) NOPASSWD: /usr/sbin/nginx
www-data ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
www-data ALL=(ALL) NOPASSWD: /bin/rm /etc/nginx/kasm-locations/*
```

---

## Points d'attention sécurité

| Priorité | Problème | Recommandation |
|---|---|---|
| 🔴 **HAUTE** | Pas de HTTPS | Configurer Certbot / Let's Encrypt sur `labo.issat.local` |
| 🔴 **HAUTE** | Ports 7000–8000 exposés via pfSense | Supprimer ces règles NAT — tout doit passer par Nginx :80 |
| 🟡 **MOYENNE** | TLSv1 / TLSv1.1 activés dans Nginx | Désactiver : `ssl_protocols TLSv1.2 TLSv1.3;` |
| 🟡 **MOYENNE** | Worker Authentik monte `/var/run/docker.sock` | Accès total au daemon Docker — limiter si possible |
| 🟠 **FAIBLE** | `server_tokens` actif dans Nginx | Ajouter `server_tokens off;` dans `nginx.conf` |

---

## Informations serveur

| | |
|---|---|
| **OS** | Ubuntu Linux — kernel 6.8.0-106-generic |
| **RAM** | 21 Go total / ~17 Go disponibles |
| **Disque** | 95 Go (utilisé à 66%) |
| **Capacité** | ~15 bureaux simultanés (1 Go RAM/étudiant) |
| **Réseau LAN** | 192.168.1.3/24 (ens18) |
| **Docker** | 172.17.0.0/16 (Kasm) / 172.18.0.0/16 (Authentik) |

---

<div align="center">

Projet Infrastructure VDI — ISSAT | 2026

</div>
