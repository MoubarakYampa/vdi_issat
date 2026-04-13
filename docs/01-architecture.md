# Vue d'ensemble de l'architecture

Ce système est une **infrastructure VDI (Virtual Desktop Infrastructure)** conçue pour les étudiants de l'ISSAT. Elle permet à chaque étudiant d'accéder via un navigateur web à un **bureau Linux complet** (XFCE4), isolé dans un container Docker, accessible via le protocole **noVNC** (VNC sur WebSocket).

## Schéma de l'architecture

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

## Composants principaux

| Composant | Rôle | Port |
|---|---|---|
| **pfSense** | Pare-feu, NAT, routage | WAN: 192.168.11.196 |
| **Nginx** | Reverse proxy, authentification des requêtes | 80 |
| **Authentik** | SSO (Single Sign-On), gestion des utilisateurs | 9000, 9443 |
| **redirector.py** | Redirige l'étudiant vers son bureau VDI | 8080 |
| **webhook_receiver.py** | Démarre/arrête les containers selon login/logout | 9001 |
| **Containers Kasm** | Bureau Linux XFCE4 par étudiant via noVNC | 7000–8000 |
| **PostgreSQL** | Base de données d'Authentik | 5432 (interne) |

## Principe de fonctionnement

1. L'étudiant ouvre son navigateur et accède à `http://labo.issat.local`
2. **Nginx** reçoit la requête et la redirige vers **Authentik** pour s'authentifier
3. Après login réussi, Authentik envoie un **webhook** à `webhook_receiver.py`
4. Le webhook déclenche le script `lancer_kasm.sh` qui démarre le container Docker de l'étudiant
5. L'étudiant est redirigé vers `redirector.py` qui le redirige vers son bureau noVNC
6. **Nginx** protège l'accès au bureau via `auth_request` (vérifie que l'étudiant accède bien à SON bureau)
7. Le bureau XFCE4 s'affiche dans le navigateur
