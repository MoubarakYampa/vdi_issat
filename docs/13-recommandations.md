# Points d'attention et recommandations

## Problèmes de sécurité

| Priorité | Problème | Recommandation |
|---|---|---|
| 🔴 HAUTE | Mot de passe `password123` hardcodé dans le Dockerfile | Utiliser `ARG PASSWORD` avec une variable d'environnement, ou désactiver le compte |
| 🔴 HAUTE | Ports 7000–8000 exposés directement via pfSense | Supprimer ces règles NAT. Tout le trafic doit passer par Nginx (port 80/443) |
| 🔴 HAUTE | Pas de HTTPS | Ajouter Let's Encrypt (Certbot) ou un certificat auto-signé. Toutes les sessions et cookies circulent en clair |
| 🟡 MOYENNE | `kasm-user ALL=(ALL) NOPASSWD:ALL` dans sudoers | Un étudiant a sudo sans mot de passe dans son container |
| 🟡 MOYENNE | TLSv1 et TLSv1.1 activés dans nginx.conf | Désactiver ces versions obsolètes : `ssl_protocols TLSv1.2 TLSv1.3;` |
| 🟡 MOYENNE | Le worker Authentik monte `/var/run/docker.sock` | Accès complet au daemon Docker. Limiter si possible |
| 🟠 FAIBLE | `server_tokens` non désactivé dans nginx.conf | Décommenter `server_tokens off;` pour masquer la version Nginx |

## Problèmes de fonctionnement

| Observation | Action suggérée |
|---|---|
| Deux versions de `lancer_kasm.sh` coexistent | Utiliser uniquement la version dans `authentik/` et supprimer `/home/docker/lancer_kasm.sh` |
| `redirector.py` et `webhook_receiver.py` ne sont pas gérés comme services | Les enregistrer comme services systemd (`systemctl enable/start`) |
| Les containers Kasm utilisent `--restart=no` | Après un reboot du serveur, les containers ne redémarrent pas — les étudiants doivent se reconnecter |
| Disque à 66% d'utilisation | Surveiller la croissance de `/home/docker/kasm-data/` et du volume `ubuntu_database` |

## Améliorations suggérées

### 1. HTTPS obligatoire

```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d labo.issat.local
```

### 2. Systemd pour les services Flask

```bash
# Créer /etc/systemd/system/redirector.service
# Créer /etc/systemd/system/webhook-receiver.service
sudo systemctl enable redirector webhook-receiver
sudo systemctl start redirector webhook-receiver
```

### 3. Limite de sessions simultanées

Ajouter une logique dans `lancer_kasm.sh` pour refuser le démarrage d'un nouveau container si le nombre maximum est atteint (ex: 15 containers = 15 Go RAM).

### 4. Sécuriser l'endpoint `/status`

`redirector.py /status` est actuellement accessible sans authentification. Le restreindre au réseau interne dans la config Nginx :

```nginx
location /status {
    allow 192.168.1.0/24;
    deny all;
    proxy_pass http://127.0.0.1:8080/status;
}
```

### 5. Nettoyage automatique des sessions inactives

Script cron pour arrêter les containers inactifs depuis plus de N heures :

```bash
# /etc/cron.d/kasm-cleanup
0 2 * * * root /home/docker/authentik/cleanup_inactive.sh 8
```

### 6. Désactiver TLS obsolètes dans Nginx

```nginx
# Dans /etc/nginx/nginx.conf
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...;
server_tokens off;
```
