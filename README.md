# Infrastructure VDI — ISSAT

Documentation technique complète de l'infrastructure **Virtual Desktop Infrastructure (VDI)** déployée à l'ISSAT. Ce système permet à chaque étudiant d'accéder depuis un navigateur à un **bureau Linux complet** (XFCE4), isolé dans un container Docker, via le protocole noVNC.

> **Date de rédaction :** 2026-04-10 | **Serveur :** Ubuntu 192.168.1.3

---

## Aperçu rapide de l'architecture

```
Étudiant (navigateur)
    │
    ▼
pfSense (pare-feu) ── NAT ──► Nginx :80
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
               Authentik     redirector.py   Containers Kasm
               (SSO :9000)   (Flask :8080)   (bureaux :7000-8000)
                    │
                    └──► webhook_receiver.py (Flask :9001)
                                  │
                                  └──► lancer/stopper_kasm.sh
```

| Composant | Rôle | Port |
|---|---|---|
| **pfSense** | Pare-feu, NAT, routage | WAN: 192.168.11.196 |
| **Nginx** | Reverse proxy + contrôle d'accès | 80 |
| **Authentik** | SSO (Single Sign-On) | 9000 / 9443 |
| **redirector.py** | Redirige l'étudiant vers son bureau VDI | 8080 |
| **webhook_receiver.py** | Démarre/arrête les containers au login/logout | 9001 |
| **Containers Kasm** | Bureau Linux XFCE4 par étudiant via noVNC | 7000–8000 |
| **PostgreSQL** | Base de données d'Authentik | 5432 (interne) |

---

## Documentation

| # | Section | Description |
|---|---|---|
| 01 | [Architecture](./docs/01-architecture.md) | Vue d'ensemble, schéma, composants et principe de fonctionnement |
| 02 | [Réseau & pfSense](./docs/02-reseau-pfsense.md) | Topologie réseau, règles NAT, interfaces, DNS |
| 03 | [Serveur Ubuntu](./docs/03-serveur-ubuntu.md) | Ressources système, RAM, stockage disque |
| 04 | [Docker](./docs/04-docker.md) | Containers actifs, réseaux Docker, volumes, commandes utiles |
| 05 | [Authentik SSO](./docs/05-authentik.md) | Configuration docker-compose, variables d'environnement, rôle dans le flux VDI |
| 06 | [Nginx](./docs/06-nginx.md) | Virtual hosts, `auth_request`, configs dynamiques par étudiant |
| 07 | [Image Docker](./docs/07-image-docker.md) | Dockerfile, supervisord, startup.sh, construction de l'image |
| 08 | [Containers Kasm](./docs/08-containers-kasm.md) | Postes de travail virtuels, volumes persistants, paramètres de lancement |
| 09 | [Scripts](./docs/09-scripts.md) | `lancer_kasm.sh`, `stopper_kasm.sh`, `fix_nginx_configs.sh` |
| 10 | [Applications Flask](./docs/10-flask-apps.md) | `redirector.py` et `webhook_receiver.py` — endpoints, logique, démarrage automatique |
| 11 | [Flux d'authentification](./docs/11-flux-authentification.md) | Parcours complet du login au bureau, séquence de déconnexion |
| 12 | [Arborescence](./docs/12-arborescence.md) | Tous les fichiers et dossiers du système |
| 13 | [Recommandations](./docs/13-recommandations.md) | Problèmes de sécurité, améliorations suggérées |

La documentation complète en un seul fichier est aussi disponible : [rapport_infrastructure_issat.md](./rapport_infrastructure_issat.md)

---

## Technologies utilisées

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-Reverse_Proxy-009639?logo=nginx&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-Python-000000?logo=flask&logoColor=white)
![pfSense](https://img.shields.io/badge/pfSense-Firewall-212121)

- **Docker** — conteneurisation de tous les services
- **Authentik** — authentification SSO (OpenID Connect)
- **Nginx** — reverse proxy avec `auth_request`
- **Kasm / noVNC** — bureau Linux dans le navigateur via WebSocket
- **Flask (Python)** — microservices de redirection et gestion des containers
- **PostgreSQL** — base de données Authentik
- **pfSense** — pare-feu et routage réseau

---

## Démarrage rapide

```bash
# 1. Démarrer la stack Authentik (depuis /home/ubuntu)
docker compose up -d

# 2. Lancer un bureau étudiant manuellement
sudo bash /home/docker/authentik/lancer_kasm.sh <nom_etudiant>

# 3. Arrêter un bureau étudiant
sudo bash /home/docker/authentik/stopper_kasm.sh <nom_etudiant>

# 4. Vérifier l'état des bureaux actifs
curl http://localhost:8080/status
```

---

## Auteur

<<<<<<< HEAD
Documentation rédigée le **2026-04-10** — Projet Infrastructure ISSAT VDI.
>>>>>>> Initial commit — Documentation technique infrastructure ISSAT VDI
=======
Projet Infrastructure VDI — ISSAT | Documentation rédigée le 2026-04-10
>>>>>>> Restructuration complète : découpage en 13 fichiers docs/
# vdi_issat
