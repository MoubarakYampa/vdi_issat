# Containers Kasm — Postes de travail virtuels

## Concept

Chaque étudiant dispose de son propre container Docker. Ce container est :
- **Isolé** : chaque étudiant a son propre système, ses propres processus
- **Persistant** : les données personnelles sont stockées en dehors du container via des volumes
- **Limité en ressources** : 1 Go de RAM maximum par étudiant

## Données persistantes par étudiant

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

## Paramètres de lancement des containers

```bash
docker run -d \
    --security-opt seccomp=unconfined \  # Désactive les restrictions seccomp (nécessaire pour X11/VNC)
    --shm-size="512m" \                  # 512 Mo de mémoire partagée (rendu graphique)
    --memory="1g" \                      # Limite RAM à 1 Go par étudiant
    --restart=no \                       # Ne redémarre pas automatiquement (géré par webhook)
    -p "$PORT:6901" \                    # Port dynamique hôte → port noVNC 6901 container
    --name "kasm-$USER_NAME" \
    moubarakyampa/vdi-etudiant:latest
```

## Sélection dynamique du port

Le script cherche le premier port libre entre 7000 et 8000 :

```bash
for PORT in $(seq 7000 8000); do
    # Vérifie dans le système (ss) ET dans Docker (docker inspect)
    USED=$(ss -Htan | awk '{print $4}' | grep -oE '[0-9]+$' | grep -xF "$PORT")
    DOCKER_USED=$(docker inspect ... | grep -oE 'HostPort":"[0-9]+' | grep -xF "$PORT")
    if [ -z "$USED" ] && [ -z "$DOCKER_USED" ]; then
        break  # Port libre trouvé
    fi
done
```

## État actuel des containers (au 2026-04-10)

| Utilisateur | Container | Port | Durée d'activité | URL d'accès |
|---|---|---|---|---|
| malek | kasm-malek | 7000 | 41 heures | `http://labo.issat.local/kasm/malek/` |
| testuser | kasm-testuser | 7001 | 41 heures | `http://labo.issat.local/kasm/testuser/` |
| akadmin | kasm-akadmin | 7002 | 40 heures | `http://labo.issat.local/kasm/akadmin/` |

> Les containers ont `--restart=no` : après un reboot du serveur, ils ne redémarrent pas. Les étudiants doivent se déconnecter et se reconnecter via Authentik.
