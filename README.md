# Infrastructure VDI — ISSAT

Documentation technique complète de l'infrastructure **Virtual Desktop Infrastructure (VDI)** déployée à l'ISSAT, permettant à chaque étudiant d'accéder depuis un navigateur à un bureau Linux complet et isolé.

---

## Aperçu de l'architecture

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

---

## Composants

| Composant | Rôle | Port |
|---|---|---|
| **pfSense** | Pare-feu, NAT, routage | WAN: 192.168.11.196 |
| **Nginx** | Reverse proxy + vérification authentification | 80 |
| **Authentik** | SSO (Single Sign-On), gestion des utilisateurs | 9000 / 9443 |
| **redirector.py** | Redirige l'étudiant vers son bureau VDI | 8080 |
| **webhook_receiver.py** | Démarre/arrête les containers au login/logout | 9001 |
| **Containers Kasm** | Bureau Linux XFCE4 par étudiant via noVNC | 7000–8000 |
| **PostgreSQL** | Base de données d'Authentik | 5432 (interne) |

---

## Flux d'authentification

```
Étudiant (navigateur)
    │
    │  GET http://labo.issat.local/
    ▼
  Nginx
    │  auth_request → Authentik
    │  → non authentifié : redirection vers /outpost.goauthentik.io/
    ▼
  Authentik (login)
    │  → authentification réussie
    ▼
  redirector.py (:8080)
    │  → identifie l'étudiant
    │  → démarre le container Kasm si besoin (via Docker)
    │  → redirige vers le port noVNC de l'étudiant
    ▼
  Container Kasm (:700X)
    │  Bureau XFCE4 dans le navigateur (noVNC / WebSocket)
```

---

## Contenu de ce dépôt

| Fichier | Description |
|---|---|
| [`rapport_infrastructure_issat.md`](./rapport_infrastructure_issat.md) | Documentation technique complète de l'infrastructure |

La documentation couvre :
- Vue d'ensemble de l'architecture
- Infrastructure réseau et configuration pfSense
- Ressources système du serveur Ubuntu
- Vue d'ensemble des containers Docker
- Configuration Authentik (SSO)
- Configuration Nginx (reverse proxy)
- Image Docker personnalisée `issat-desktop` / `vdi-etudiant`
- Containers Kasm (postes de travail virtuels)
- Scripts d'automatisation
- Application Flask `redirector.py`
- Application Flask `webhook_receiver.py`
- Flux complet d'authentification et de démarrage
- Arborescence des fichiers
- Utilisateurs actifs
- Points d'attention et recommandations

---

## Prérequis

- Serveur Ubuntu avec Docker installé
- pfSense configuré avec les règles NAT décrites dans la documentation
- Résolution DNS locale pour `issat.local` et `labo.issat.local`

---

## Technologies utilisées

- **Docker** — conteneurisation des services
- **Authentik** — authentification SSO (OpenID Connect / LDAP)
- **Nginx** — reverse proxy avec `auth_request`
- **Kasm Workspaces** — bureau Linux dans le navigateur via noVNC
- **Flask (Python)** — microservices de redirection et de gestion des containers
- **PostgreSQL** — base de données Authentik
- **pfSense** — pare-feu et routage réseau

---

## Auteur

Documentation rédigée le **2026-04-10** — Projet Infrastructure ISSAT VDI.
>>>>>>> Initial commit — Documentation technique infrastructure ISSAT VDI
