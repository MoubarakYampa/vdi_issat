# Authentik — Serveur d'authentification SSO

## Qu'est-ce qu'Authentik ?

Authentik est un **Identity Provider (IdP)** open-source. Il gère l'authentification des utilisateurs (login/logout), les sessions, et peut déclencher des **webhooks** lors d'événements (connexion, déconnexion).

Dans ce projet, Authentik est le **gardien d'entrée** : aucun étudiant ne peut accéder à son bureau VDI sans s'être authentifié via Authentik.

## Structure du docker-compose.yml — `/home/ubuntu/docker-compose.yml`

```yaml
services:
  postgresql:       # Base de données
  server:           # Serveur Authentik (interface web + API)
  worker:           # Worker Authentik (tâches en arrière-plan)
```

### Service `postgresql`

- **Image :** `postgres:16-alpine` (légère et stable)
- **Base de données :** `authentik` (par défaut)
- **Données persistées dans :** volume Docker `ubuntu_database`
- **Health check :** vérifie que PostgreSQL est prêt toutes les 30 secondes

### Service `server` (Authentik)

- **Image :** `ghcr.io/goauthentik/server:2026.2.1`
- **Commande :** `server` (interface web + API REST)
- **Ports exposés :**
  - `9000` → HTTP (utilisé par Nginx)
  - `9443` → HTTPS
- **Attend que** PostgreSQL soit sain avant de démarrer
- **Données :** montées dans `./data` (dossier `/home/ubuntu/data/`)
- **Templates personnalisés :** `./custom-templates` → `/templates`

### Service `worker` (Authentik Worker)

- **Image :** identique au server
- **Commande :** `worker` (traitement des tâches : emails, webhooks, etc.)
- **Spécificité :** tourne en tant que `root` et monte le socket Docker `/var/run/docker.sock`
  > Cela permet au worker Authentik d'interagir avec Docker si nécessaire.
- **Certificats SSL :** montés depuis `./certs`

## Variables d'environnement (fichier `.env`)

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

## Rôle d'Authentik dans le flux VDI

1. L'étudiant se connecte sur `http://labo.issat.local` → Nginx le redirige vers Authentik
2. Authentik vérifie les identifiants et crée une **session** (cookie `authentik_session`)
3. Authentik envoie un **webhook** à `webhook_receiver.py` (port 9001) avec l'action `login`
4. Le receiver démarre automatiquement le container Kasm de l'étudiant
5. L'étudiant est redirigé vers son bureau via `/bureau`

## Commandes utiles

```bash
# Démarrer la stack Authentik
cd /home/ubuntu && docker compose up -d

# Voir les logs
docker compose logs -f server

# Redémarrer uniquement le worker
docker compose restart worker
```
