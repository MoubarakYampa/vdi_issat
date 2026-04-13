# Nginx — Reverse Proxy

Nginx est le **point d'entrée unique** de toute l'infrastructure. Il joue plusieurs rôles :
- Proxy inverse vers Authentik
- Proxy inverse vers les containers Kasm (noVNC + WebSocket)
- Contrôle d'accès via `auth_request` (vérifie la session avant d'accéder à un bureau)

## Configuration principale — `/etc/nginx/nginx.conf`

Paramètres activés :
- `sendfile on` → transfert de fichiers optimisé (kernel bypass)
- `tcp_nopush on` → envoi de paquets TCP plus efficace
- `gzip on` → compression des réponses HTTP
- SSL : TLSv1, TLSv1.1, TLSv1.2, TLSv1.3 supportés

> **Recommandation sécurité :** Désactiver TLSv1 et TLSv1.1 (protocoles obsolètes et vulnérables). Garder uniquement TLSv1.2 et TLSv1.3.

## Virtual Host 1 — `issat.local`

Fichier : `/etc/nginx/sites-available/default`

```nginx
server_name issat.local;
listen 80;
```

| Chemin | Destination | Description |
|---|---|---|
| `/` | `http://192.168.1.3:9000` | Interface de connexion Authentik |
| `/bureau` | `http://192.168.1.3:8080` | Redirecteur Flask vers le bureau VDI |

> Ce virtual host est destiné à un accès **depuis le réseau LAN interne**.

## Virtual Host 2 — `labo.issat.local` (principal)

Fichier : `/etc/nginx/sites-available/default`

```nginx
server_name labo.issat.local 192.168.11.196 127.0.0.1;
listen 80;
```

| Chemin | Destination | Description |
|---|---|---|
| `/` | `http://192.168.1.3:9000` | Interface Authentik (login) |
| `/bureau` | `http://127.0.0.1:8080` | Redirecteur Flask (avec transmission du cookie) |
| `/auth-kasm` | `http://127.0.0.1:8080/auth-kasm` | Endpoint interne de vérification de session |
| `/kasm/` | Voir ci-dessous | Accès aux bureaux VDI (protégés) |

## Protection des bureaux VDI avec `auth_request`

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
3. `redirector.py` vérifie le cookie `authentik_session` et que l'utilisateur accède **à son propre bureau**
4. Retourne `200` (OK), `401` (non connecté) ou `403` (accès refusé)

## Configs dynamiques par utilisateur — `/etc/nginx/kasm-locations/`

Chaque étudiant a son propre fichier de configuration généré automatiquement.

**Exemple pour `malek` — `/etc/nginx/kasm-locations/kasm-malek.conf` :**

```nginx
# Redirection automatique vers l'interface VNC complète
location = /kasm/malek/ {
    return 302 /kasm/malek/vnc_auto.html?autoconnect=true&reconnect=true
               &reconnect_delay=1000&resize=scale&quality=6
               &path=kasm/malek/websockify;
}

# Tunnel WebSocket pour le flux VNC temps réel
location ^~ /kasm/malek/websockify {
    proxy_pass http://127.0.0.1:7000/websockify;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    proxy_buffering off;
}

# Proxy de toutes les ressources statiques noVNC
location ^~ /kasm/malek/ {
    proxy_pass http://127.0.0.1:7000/;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

## Containers actifs et leurs ports

| Utilisateur | Port hôte | Fichier nginx |
|---|---|---|
| malek | 7000 | kasm-malek.conf |
| testuser | 7001 | kasm-testuser.conf |
| akadmin | 7002 | kasm-akadmin.conf |

## Commandes utiles

```bash
# Vérifier la configuration nginx
sudo nginx -t

# Recharger nginx sans interruption
sudo systemctl reload nginx

# Voir les logs d'accès
sudo tail -f /var/log/nginx/access.log

# Voir les logs d'erreur
sudo tail -f /var/log/nginx/error.log
```
