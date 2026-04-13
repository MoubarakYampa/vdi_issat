# Applications Flask

## redirector.py

**Fichier :** `/home/docker/authentik/redirector.py`  
**Port :** 8080  
**Framework :** Flask + docker SDK Python

Ce service est le **cerveau de la redirection**. Il fait le lien entre la session Authentik et le container Docker de l'étudiant.

### Endpoints

#### `GET /auth-kasm` — Vérification d'accès (Nginx `auth_request`)

```
Nginx intercepte /kasm/USERNAME/...
    → Appelle en interne /auth-kasm
        → Lit le cookie "authentik_session"
        → Interroge l'API Authentik : GET /api/v3/core/users/me/
        → Extrait le username depuis la réponse JSON
        → Vérifie que le username de l'URL correspond au username connecté
    → Retourne 200 (OK), 401 (non connecté), ou 403 (accès interdit)
```

**Exemple de requête vers l'API Authentik :**
```python
response = requests.get(
    "http://192.168.1.3:9000/api/v3/core/users/me/",
    cookies={"authentik_session": session_cookie},
    timeout=5
)
# Retourne : {"user": {"username": "malek", ...}}
```

**Protection contre l'accès croisé :**
```python
# Si malek essaie d'accéder à /kasm/testuser/...
if kasm_user != username:      # "testuser" != "malek"
    return "", 403             # Accès refusé
```

#### `GET /bureau` — Redirection vers le bureau

```
1. Lit le cookie "authentik_session"
2. Interroge l'API Authentik pour obtenir le username
3. Interroge Docker pour trouver le port du container "kasm-<username>"
4. Redirige vers : /kasm/<username>/vnc_auto.html?autoconnect=true&...
```

**Paramètres noVNC dans l'URL de redirection :**
- `autoconnect=true` → Connexion automatique sans clic
- `reconnect=true` → Reconnexion automatique si coupure
- `reconnect_delay=1000` → Attendre 1 seconde avant de retenter
- `resize=scale` → Adapte la résolution à la fenêtre du navigateur
- `quality=6` → Qualité d'image VNC (0=min, 9=max)

#### `GET /status` — Monitoring des containers actifs

```json
{
    "redirecteur": "actif",
    "total": 3,
    "containers": [
        {
            "utilisateur": "malek",
            "container": "kasm-malek",
            "port": "7000",
            "url": "http://labo.issat.local/kasm/malek/",
            "statut": "running"
        }
    ]
}
```

---

## webhook_receiver.py

**Fichier :** `/home/docker/authentik/webhook_receiver.py`  
**Port :** 9001  
**Framework :** Flask

Ce service écoute les **webhooks envoyés par Authentik** lors des événements de session.

### Endpoint `POST /webhook`

**Format JSON attendu :**
```json
{
    "user": {"username": "malek"},
    "action": "login"
}
```

**Actions gérées :**

| Action | Script exécuté | Résultat |
|---|---|---|
| `login` | `lancer_kasm.sh malek` | Démarre le container kasm-malek |
| `custom_notification_test` | `lancer_kasm.sh malek` | Identique à login (pour tests) |
| `logout` | `stopper_kasm.sh malek` | Arrête le container kasm-malek |
| Autre | Aucun | Réponse `ignored` |

**Exécution des scripts :**
```python
subprocess.run(
    ["sudo", "-n", "bash", script, user],
    capture_output=True, text=True
)
```

> `-n` signifie "non-interactif" : si sudo demande un mot de passe, il échoue immédiatement. L'utilisateur Flask doit avoir les droits sudoers appropriés.

**Codes de retour HTTP :**
- `200` : container créé, redémarré ou arrêté
- `200` : action ignorée (inconnue)
- `400` : JSON invalide
- `500` : erreur d'exécution du script

## Démarrage automatique (recommandé)

Pour que ces services démarrent automatiquement au reboot, créer des unités systemd :

```ini
# /etc/systemd/system/redirector.service
[Unit]
Description=Redirector Flask VDI
After=network.target docker.service

[Service]
User=www-data
WorkingDirectory=/home/docker/authentik
ExecStart=/usr/bin/python3 redirector.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable redirector webhook-receiver
sudo systemctl start redirector webhook-receiver
```
