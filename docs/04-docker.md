# Docker — Vue d'ensemble des containers

## Containers en cours d'exécution

```
CONTAINER ID   IMAGE                              STATUT        PORTS                    NOM
d1d70f77bb4a   moubarakyampa/vdi-etudiant:latest  Up 40h        0.0.0.0:7002->6901/tcp   kasm-akadmin
65a2b9783753   moubarakyampa/vdi-etudiant:latest  Up 41h        0.0.0.0:7001->6901/tcp   kasm-testuser
15277e1cd3d7   moubarakyampa/vdi-etudiant:latest  Up 40h        0.0.0.0:7000->6901/tcp   kasm-malek
fd5e0c2861b6   goauthentik/server:2026.2.1        Up 2j (sain)  0.0.0.0:9000,9443->...   ubuntu-server-1
19412aa76644   goauthentik/server:2026.2.1        Up 2j (sain)                            ubuntu-worker-1
9c87e159f17c   postgres:16-alpine                 Up 2j (sain)  5432/tcp (interne)        ubuntu-postgresql-1
```

## Réseaux Docker

| Nom | Driver | Sous-réseau | Usage |
|---|---|---|---|
| `bridge` (docker0) | bridge | 172.17.0.0/16 | Containers Kasm (réseau par défaut) |
| `ubuntu_default` | bridge | 172.18.0.0/16 | Stack Authentik (postgresql + server + worker) |
| `host` | host | — | Accès direct à l'hôte |
| `none` | null | — | Isolation totale |

## Volumes Docker

| Nom | Driver | Usage |
|---|---|---|
| `ubuntu_database` | local | Base de données PostgreSQL d'Authentik |

## Commandes utiles

```bash
# Lister tous les containers (actifs + arrêtés)
docker ps -a

# Voir les logs d'un container
docker logs kasm-malek

# Inspecter les ports d'un container
docker inspect kasm-malek | grep HostPort

# Voir l'utilisation des ressources en temps réel
docker stats

# Lister les réseaux
docker network ls

# Lister les volumes
docker volume ls
```
