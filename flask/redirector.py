#!/usr/bin/env python3
"""
redirector.py — Service Flask de redirection VDI
Port : 8080

Rôle :
  - /bureau    : redirige l'étudiant authentifié vers son container noVNC
  - /auth-kasm : endpoint de vérification pour le auth_request de Nginx
  - /status    : monitoring des containers actifs

Dépendances :
  pip install flask requests docker
"""

from flask import Flask, request, redirect, jsonify, abort
import requests
import docker
import logging

# ─── Configuration ────────────────────────────────────────────────────────────
AUTHENTIK_URL = "http://192.168.1.3:9000"
BASE_URL = "http://labo.issat.local"
VDI_PORT = 8080

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

app = Flask(__name__)
docker_client = docker.from_env()

# ─── Fonctions utilitaires ────────────────────────────────────────────────────

def get_username_from_session(session_cookie: str) -> str | None:
    """Interroge l'API Authentik pour obtenir le username depuis le cookie de session."""
    try:
        response = requests.get(
            f"{AUTHENTIK_URL}/api/v3/core/users/me/",
            cookies={"authentik_session": session_cookie},
            timeout=5
        )
        if response.status_code == 200:
            data = response.json()
            return data.get("user", {}).get("username")
    except requests.RequestException as e:
        log.error(f"Erreur API Authentik : {e}")
    return None


def get_container_port(username: str) -> str | None:
    """Récupère le port hôte du container kasm-<username> via le SDK Docker."""
    try:
        container = docker_client.containers.get(f"kasm-{username}")
        ports = container.ports.get("6901/tcp")
        if ports:
            return ports[0]["HostPort"]
    except docker.errors.NotFound:
        log.warning(f"Container kasm-{username} introuvable")
    except Exception as e:
        log.error(f"Erreur Docker : {e}")
    return None

# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.route("/auth-kasm")
def auth_kasm():
    """
    Endpoint de vérification pour Nginx auth_request.
    Vérifie que l'utilisateur connecté est bien le propriétaire du bureau demandé.

    Retours :
        200  → accès autorisé
        401  → non authentifié (pas de cookie de session valide)
        403  → accès refusé (mauvais utilisateur)
    """
    session_cookie = request.cookies.get("authentik_session")
    if not session_cookie:
        log.info("auth-kasm : pas de cookie de session → 401")
        return "", 401

    username = get_username_from_session(session_cookie)
    if not username:
        log.info("auth-kasm : session invalide → 401")
        return "", 401

    # Extraire le username cible depuis l'URL originale (/kasm/<user>/...)
    original_uri = request.headers.get("X-Original-URI", "")
    parts = original_uri.strip("/").split("/")
    # Format attendu : /kasm/<username>/...
    if len(parts) >= 2 and parts[0] == "kasm":
        kasm_user = parts[1]
        if kasm_user != username:
            log.warning(f"auth-kasm : {username} tente d'accéder au bureau de {kasm_user} → 403")
            return "", 403

    log.info(f"auth-kasm : accès autorisé pour {username}")
    return "", 200


@app.route("/bureau")
@app.route("/")
def bureau():
    """
    Redirige l'étudiant authentifié vers son bureau noVNC.
    Si le container est introuvable, retourne une erreur 503.
    """
    session_cookie = request.cookies.get("authentik_session")
    if not session_cookie:
        log.info("bureau : pas de cookie → redirection vers login")
        return redirect(f"{AUTHENTIK_URL}/")

    username = get_username_from_session(session_cookie)
    if not username:
        log.info("bureau : session invalide → redirection vers login")
        return redirect(f"{AUTHENTIK_URL}/")

    port = get_container_port(username)
    if not port:
        log.error(f"bureau : container de {username} introuvable ou non démarré")
        return f"""
        <html><body style="font-family:sans-serif;text-align:center;padding:50px">
        <h2>Bureau non disponible</h2>
        <p>Votre bureau VDI n'est pas encore prêt. Veuillez patienter quelques secondes et rafraîchir.</p>
        <p><a href="/bureau">Réessayer</a></p>
        </body></html>
        """, 503

    novnc_url = (
        f"/kasm/{username}/vnc_auto.html"
        f"?autoconnect=true"
        f"&reconnect=true"
        f"&reconnect_delay=1000"
        f"&resize=scale"
        f"&quality=6"
        f"&path=kasm/{username}/websockify"
    )

    log.info(f"bureau : redirection de {username} → port {port}")
    return redirect(novnc_url)


@app.route("/status")
def status():
    """
    Retourne l'état de tous les containers kasm-* actifs.
    À restreindre au réseau interne via Nginx en production.
    """
    containers = []
    try:
        for container in docker_client.containers.list():
            if container.name.startswith("kasm-"):
                username = container.name[len("kasm-"):]
                ports = container.ports.get("6901/tcp")
                port = ports[0]["HostPort"] if ports else None
                containers.append({
                    "utilisateur": username,
                    "container": container.name,
                    "port": port,
                    "url": f"{BASE_URL}/kasm/{username}/",
                    "statut": container.status
                })
    except Exception as e:
        log.error(f"status : erreur Docker : {e}")

    return jsonify({
        "redirecteur": "actif",
        "total": len(containers),
        "containers": containers
    })


# ─── Point d'entrée ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info(f"Démarrage du redirecteur VDI sur le port {VDI_PORT}")
    app.run(host="0.0.0.0", port=VDI_PORT, debug=False)
