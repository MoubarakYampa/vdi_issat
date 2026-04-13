# Scripts d'automatisation

## `lancer_kasm.sh` — Version principale

**Fichier :** `/home/docker/lancer_kasm.sh`  
**Usage :** `./lancer_kasm.sh <nom_utilisateur>`

**Comportement :**

```
Si le container "kasm-<user>" existe déjà
    → Le redémarrer
Sinon
    1. Créer les dossiers de données (/home/docker/kasm-data/<user>/)
    2. Trouver un port libre (7000-8000)
    3. Lancer le container Docker
    4. Générer la config Nginx (/etc/nginx/kasm-locations/kasm-<user>.conf)
    5. Recharger Nginx
```

## `lancer_kasm.sh` — Version améliorée (recommandée)

**Fichier :** `/home/docker/authentik/lancer_kasm.sh`  
**Usage :** `./lancer_kasm.sh <nom_utilisateur>`

**Améliorations par rapport à la version racine :**
- Volumes **séparés** par type (Documents, Downloads, Music, Pictures, Videos, PDF, Uploads)
- Après création, **relit le port** depuis Docker inspect (plus fiable)
- Affiche l'URL finale : `http://labo.issat.local/kasm/<user>/`

> **Note :** Cette version est celle déclenchée par le webhook. Elle remplace la version racine.

## `stopper_kasm.sh`

**Fichier :** `/home/docker/authentik/stopper_kasm.sh`  
**Usage :** `./stopper_kasm.sh <nom_utilisateur>`

```bash
# 1. Arrête le container s'il tourne
docker stop "kasm-$USER_NAME"

# 2. Supprime la config Nginx et recharge
sudo rm /etc/nginx/kasm-locations/kasm-${USER_NAME}.conf
sudo nginx -t && sudo systemctl reload nginx
```

> Quand un étudiant se déconnecte d'Authentik, ce script libère les ressources (RAM, port). Déclenché automatiquement par le webhook Authentik.

## `fix_nginx_configs.sh` — Script de récupération d'urgence

**Fichier :** `/home/docker/authentik/fix_nginx_configs.sh`  
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

> **Cas d'usage :** après un redémarrage du serveur, les configs Nginx ont disparu mais les containers sont peut-être encore présents.

## Sudoers nécessaires

Pour que le webhook Flask puisse exécuter les scripts en tant que `sudo` :

```bash
# Dans /etc/sudoers.d/kasm
www-data ALL=(ALL) NOPASSWD: /home/docker/authentik/lancer_kasm.sh
www-data ALL=(ALL) NOPASSWD: /home/docker/authentik/stopper_kasm.sh
www-data ALL=(ALL) NOPASSWD: /usr/sbin/nginx
www-data ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
www-data ALL=(ALL) NOPASSWD: /bin/rm /etc/nginx/kasm-locations/*
```
