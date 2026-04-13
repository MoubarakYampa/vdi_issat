# Arborescence complète des fichiers

```
/home/
├── ubuntu/                          # Utilisateur système principal
│   ├── docker-compose.yml           # Stack Authentik (server + worker + postgresql)
│   ├── .env                         # Variables sensibles (mots de passe, clés secrètes)
│   ├── data/                        # Données Authentik (avatars, médias, config)
│   ├── certs/                       # Certificats TLS pour le worker Authentik
│   └── custom-templates/            # Templates HTML personnalisés pour Authentik
│
└── docker/                          # Dossier principal des ressources Docker
    ├── lancer_kasm.sh               # Script de lancement (version basique)
    │
    ├── authentik/                   # Scripts liés à l'intégration Authentik
    │   ├── lancer_kasm.sh           # Script de lancement (version complète)
    │   ├── stopper_kasm.sh          # Arrête le container et supprime la config Nginx
    │   ├── fix_nginx_configs.sh     # Régénère toutes les configs Nginx
    │   ├── redirector.py            # Flask :8080 — redirecteur + auth_request
    │   └── webhook_receiver.py      # Flask :9001 — écoute les webhooks Authentik
    │
    ├── issat-desktop/               # Image Docker personnalisée du bureau étudiant
    │   ├── Dockerfile               # Construction de l'image Ubuntu + XFCE4 + apps
    │   ├── config/
    │   │   ├── xfce4-desktop.xml    # Fond d'écran XFCE4
    │   │   └── xfce4-screensaver.xml# Désactivation de l'économiseur d'écran
    │   ├── scripts/
    │   │   ├── startup.sh           # Point d'entrée du container
    │   │   └── supervisord.conf     # Supervision de Xvfb, x11vnc, XFCE4, noVNC
    │   └── desktop/                 # Raccourcis bureau (.desktop)
    │       ├── firefox.desktop
    │       ├── terminal.desktop
    │       └── vscode.desktop
    │
    └── kasm-data/                   # Données persistantes des étudiants
        ├── malek/
        │   ├── Documents/
        │   ├── Downloads/
        │   ├── Music/
        │   ├── Pictures/
        │   ├── Videos/
        │   ├── PDF/
        │   └── Uploads/
        ├── akadmin/
        └── testuser/

/etc/nginx/
├── nginx.conf                       # Config principale Nginx
├── sites-available/
│   ├── default                      # VH issat.local + VH par défaut
│   ├── issat                        # (doublon à nettoyer)
│   └── laboissat                    # VH labo.issat.local (avec auth_request)
├── sites-enabled/                   # Liens symboliques vers sites-available
└── kasm-locations/                  # Configs générées dynamiquement
    ├── kasm-malek.conf              # Proxy noVNC pour malek (port 7000)
    ├── kasm-testuser.conf           # Proxy noVNC pour testuser (port 7001)
    └── kasm-akadmin.conf            # Proxy noVNC pour akadmin (port 7002)
```
