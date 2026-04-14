#!/usr/bin/env python3
"""
webhook_receiver.py — Récepteur de webhooks Authentik
Port : 9001

Rôle :
  Écoute les événements envoyés par Authentik (login / logout)
  et déclenche les scripts de gestion des containers VDI.

Format JSON attendu :
  {
    "user": {"username": "malek"},
    "action": "login"
  }

Dépendances :
  pip install flask
"""

from flask import Flask, request, jsonify
import subprocess
import logging
import os

# ─── Configuration ────────────────────────────────────────────────────────────
WEBHOOK_PORT = 9001
SCRIPTS_DIR = "/home/docker/authentik"
LANCER_SCRIPT = os.path.join(SCRIPTS_DIR, "lancer_kasm.sh")
STOPPER_SCRIPT = os.path.join(SCRIPTS_DIR, "stopper_kasm.sh")

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

app = Flask(__name__)

# ─── Fonctions utilitaires ────────────────────────────────────────────────────

def run_script(script: str, username: str) -> tuple[bool, str]:
    """Exécute un script bash avec sudo et retourne (succès, sortie)."""
    try:
        result = subprocess.run(
            ["sudo", "-n", "bash", script, username],
            capture_output=True,
            text=True,
            timeout=60
        )
        output = result.stdout + result.stderr
        if result.returncode == 0:
            log.info(f"Script {os.path.basename(script)} OK pour {username}\n{output}")
            return True, output
        else:
            log.error(f"Script {os.path.basename(script)} ÉCHEC pour {username}\n{output}")
            return False, output
    except subprocess.TimeoutExpired:
        log.error(f"Script {os.path.basename(script)} TIMEOUT pour {username}")
        return False, "Timeout dépassé"
    except Exception as e:
        log.error(f"Erreur d'exécution du script : {e}")
        return False, str(e)

# ─── Endpoint ─────────────────────────────────────────────────────────────────

@app.route("/webhook", methods=["POST"])
def webhook():
    """
    Reçoit les webhooks d'Authentik et déclenche les scripts correspondants.

    Actions gérées :
      - login                    → lancer_kasm.sh <username>
      - logout                   → stopper_kasm.sh <username>
      - custom_notification_test → lancer_kasm.sh <username> (pour tests)
    """
    # Vérifier le Content-Type
    if not request.is_json:
        log.warning("Webhook reçu sans Content-Type application/json")
        return jsonify({"error": "Content-Type must be application/json"}), 400

    data = request.get_json(silent=True)
    if not data:
        log.warning("Webhook reçu avec un JSON invalide")
        return jsonify({"error": "JSON invalide ou vide"}), 400

    # Extraire les champs
    user_info = data.get("user", {})
    username = user_info.get("username", "").strip()
    action = data.get("action", "").strip()

    if not username:
        log.warning(f"Webhook reçu sans username : {data}")
        return jsonify({"error": "username manquant"}), 400

    log.info(f"Webhook reçu — action: '{action}', utilisateur: '{username}'")

    # ─── Dispatch selon l'action ──────────────────────────────────────────────
    if action in ("login", "custom_notification_test"):
        success, output = run_script(LANCER_SCRIPT, username)
        if success:
            return jsonify({
                "status": "started",
                "user": username,
                "action": action
            }), 200
        else:
            return jsonify({
                "status": "error",
                "user": username,
                "action": action,
                "detail": output
            }), 500

    elif action == "logout":
        success, output = run_script(STOPPER_SCRIPT, username)
        if success:
            return jsonify({
                "status": "stopped",
                "user": username,
                "action": action
            }), 200
        else:
            return jsonify({
                "status": "error",
                "user": username,
                "action": action,
                "detail": output
            }), 500

    else:
        log.info(f"Action '{action}' ignorée pour {username}")
        return jsonify({
            "status": "ignored",
            "user": username,
            "action": action
        }), 200


@app.route("/health")
def health():
    """Endpoint de contrôle de santé."""
    return jsonify({"status": "ok", "service": "webhook-receiver"}), 200


# ─── Point d'entrée ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info(f"Démarrage du webhook receiver sur le port {WEBHOOK_PORT}")
    app.run(host="0.0.0.0", port=WEBHOOK_PORT, debug=False)
