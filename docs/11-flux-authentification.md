# Flux complet d'authentification et de démarrage

## Connexion — Du navigateur au bureau

```
Étudiant ouvre http://labo.issat.local
        │
        ▼
    Nginx (labo.issat.local)
        │  location /  → proxy_pass Authentik :9000
        ▼
    Page de login Authentik
        │
        │  [Étudiant entre login + mot de passe]
        ▼
    Authentik vérifie les identifiants
        │
        ├──► Crée un cookie de session "authentik_session"
        │
        └──► Envoie un webhook POST à webhook_receiver.py:9001
                {
                  "user": {"username": "malek"},
                  "action": "login"
                }
                        │
                        ▼
              webhook_receiver.py
                        │
                        └──► sudo bash lancer_kasm.sh malek
                                    │
                                    ├── Trouve port libre (ex: 7000)
                                    ├── docker run kasm-malek -p 7000:6901
                                    ├── Génère /etc/nginx/kasm-locations/kasm-malek.conf
                                    └── sudo nginx -t && systemctl reload nginx

Étudiant est redirigé vers /bureau
        │
        ▼
    Nginx → proxy_pass http://127.0.0.1:8080 (redirector.py)
        │
        ▼
    redirector.py
        │  Lit cookie "authentik_session"
        │  GET http://192.168.1.3:9000/api/v3/core/users/me/
        │  → username = "malek"
        │  docker inspect kasm-malek → port = 7000
        │
        └──► Redirect 302 vers :
             /kasm/malek/vnc_auto.html?autoconnect=true&...

Navigateur charge /kasm/malek/
        │
        ▼
    Nginx : auth_request /auth-kasm
        │
        ▼
    redirector.py /auth-kasm
        │  Vérifie session → username = "malek"
        │  URL = /kasm/malek/ → kasm_user = "malek"
        │  "malek" == "malek" → OK
        └──► Retourne 200
        │
        ▼
    Nginx : include kasm-malek.conf
        │  proxy_pass http://127.0.0.1:7000/
        ▼
    Container kasm-malek (noVNC)
        │
        ▼
    Bureau XFCE4 affiché dans le navigateur ✓
```

## Déconnexion — Libération des ressources

```
Étudiant se déconnecte d'Authentik
        │
        └──► Webhook POST → webhook_receiver.py
                {
                  "user": {"username": "malek"},
                  "action": "logout"
                }
                        │
                        └──► sudo bash stopper_kasm.sh malek
                                    │
                                    ├── docker stop kasm-malek
                                    ├── rm /etc/nginx/kasm-locations/kasm-malek.conf
                                    └── sudo nginx -t && systemctl reload nginx
```

## Résumé des échanges entre composants

| De | Vers | Protocole | Description |
|---|---|---|---|
| Navigateur | Nginx :80 | HTTP | Toutes les requêtes entrent par Nginx |
| Nginx | Authentik :9000 | HTTP (proxy) | Proxy vers la page de login |
| Nginx | redirector.py :8080 | HTTP (proxy) | Proxy vers `/bureau` et `auth_request` |
| Nginx | Container Kasm :700X | HTTP + WebSocket | Proxy vers le bureau noVNC |
| Authentik | webhook_receiver.py :9001 | HTTP POST | Webhook login/logout |
| webhook_receiver.py | lancer/stopper_kasm.sh | subprocess | Gestion des containers |
| redirector.py | API Authentik :9000 | HTTP | Vérification de session |
| redirector.py | Docker socket | Docker SDK | Inspection des containers |
