"""
TBerryPrint - Application de gestion d'imprimantes pour Raspberry Pi

Cette application Flask permet de:
- Gérer les imprimantes USB connectées via CUPS
- Surveiller les ressources système (CPU, RAM, température)
- Configurer la connexion Wi-Fi
- Gérer des fonctions système (redémarrage, mise à jour, changement de hostname)
"""

import cups
import json
import os
import psutil
import re
import socket
import subprocess
from dotenv import load_dotenv
from flask import Flask, render_template, request, redirect, url_for, session, jsonify
from typing import Dict, List, Tuple, Optional, Any, Union

# Configuration de l'application
app = Flask(__name__)
app.secret_key = "supersecretkey"  # Clé secrète pour les sessions

# Chargement des variables d'environnement depuis un fichier .env
load_dotenv()

# Récupération des identifiants depuis les variables d'environnement avec des valeurs par défaut en cas d'absence
ADMIN_USERNAME = os.environ.get("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "default_password")
CLIENT_USERNAME = os.environ.get("CLIENT_USERNAME", "client")
CLIENT_PASSWORD = os.environ.get("CLIENT_PASSWORD", "client_password")


# ===== FONCTIONS UTILITAIRES =====

def get_ip() -> str:
    """
    Récupère l'adresse IP locale du Raspberry Pi.
    
    Returns:
        str: L'adresse IP locale ou 127.0.0.1 en cas d'échec
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(0)
    try:
        # Cette adresse n'a pas besoin d'être accessible, c'est juste pour obtenir l'interface
        s.connect(('10.254.254.254', 1))
        ip_address = s.getsockname()[0]
    except Exception:
        ip_address = '127.0.0.1'
    finally:
        s.close()
    return ip_address

def get_hostname() -> str:
    """
    Récupère le nom d'hôte du système.
    
    Returns:
        str: Le nom d'hôte
    """
    return socket.gethostname()

def get_temperature() -> str:
    """
    Récupère la température du processeur du Raspberry Pi.
    
    Returns:
        str: La température formatée (ex: "45.6°C") ou "Indisponible" en cas d'échec
    """
    try:
        temp = os.popen("vcgencmd measure_temp").readline()
        return temp.replace("temp=", "").strip()
    except Exception:
        return "Indisponible"

def format_memory(bytes_value: int) -> str:
    """
    Formate une valeur de mémoire en Go ou Mo selon la taille.
    
    Args:
        bytes_value: Valeur en octets à formater
        
    Returns:
        str: Valeur formatée avec unité (Go ou Mo)
    """
    gb_value = bytes_value / (1024.0 ** 3)
    if gb_value < 1:
        mb_value = bytes_value / (1024.0 ** 2)
        return f"{round(mb_value)} Mo"
    return f"{round(gb_value, 2)} Go"

def format_percent(value: float) -> str:
    """
    Formate un pourcentage avec précision adaptée.
    
    Args:
        value: Valeur en pourcentage à formater
        
    Returns:
        str: Pourcentage formaté (2 décimales si <1%, sinon 1 décimale)
    """
    if value < 1:
        return f"{round(value, 2)}%"
    return f"{round(value, 1)}%"


# ===== FONCTIONS POUR LES IMPRIMANTES =====

def get_usb_printers() -> List[Tuple[str, int]]:
    """
    Récupère la liste des imprimantes USB via CUPS.
    
    Returns:
        List[Tuple[str, int]]: Liste de tuples (nom_imprimante, statut)
    """
    printers = []
    try:
        conn = cups.Connection()
        printers_list = conn.getPrinters()
        for printer, attributes in printers_list.items():
            device_uri = attributes.get("device-uri", "").lower()
            if device_uri.startswith("usb:"):
                status = attributes.get("printer-state", 0)
                printers.append((printer, status))
    except Exception as e:
        print(f"Erreur CUPS : {e}")
    return printers

def get_printer_status_text(status: int) -> str:
    """
    Renvoie un texte descriptif pour un code de statut d'imprimante.
    
    Args:
        status: Code de statut CUPS
        
    Returns:
        str: Description du statut
    """
    status_texts = {
        1: "L'imprimante a des tâches en attente, mais n'imprime pas encore.",
        2: "Les tâches sont mises en pause et ne seront pas imprimées tant qu'elles ne seront pas relancées manuellement.",
        3: "L'imprimante est prête.",
        4: "L'imprimante est en train d'imprimer.",
        5: "L'imprimante est arrêtée ou en erreur."
    }
    return status_texts.get(status, "Statut: Inconnu")

def get_printer_status_icon(status: int) -> Dict[str, str]:
    """
    Renvoie les informations d'icône pour un code de statut d'imprimante.
    
    Args:
        status: Code de statut CUPS
        
    Returns:
        Dict[str, str]: Dictionnaire avec classe d'icône et couleur
    """
    status_icons = {
        1: {"class": "fas fa-clock", "color": "#f39c12"},
        2: {"class": "fas fa-pause-circle", "color": "#f39c12"},
        3: {"class": "fas fa-check-circle", "color": "#2ecc71"},
        4: {"class": "fas fa-print", "color": "#3498db"},
        5: {"class": "fas fa-exclamation-circle", "color": "#e74c3c"}
    }
    default_icon = {"class": "fas fa-question-circle", "color": "#95a5a6"}
    return status_icons.get(status, default_icon)

# ===== FONCTIONS POUR LE WI-FI =====

def has_connected_to_wifi(ssid: str) -> bool:
    """
    Vérifie si un réseau Wi-Fi identifié par son SSID a déjà été connecté,
    en vérifiant l'existence du fichier de configuration correspondant dans
    /etc/NetworkManager/system-connections/<SSID>.nmconnection.

    Args:
        ssid (str): Le SSID du réseau Wi-Fi. Peut contenir des espaces (ex: "iPhone Hugo").

    Returns:
        bool: True si le fichier existe (le réseau a déjà été connecté), False sinon.
    """
    # Construit le chemin du fichier, en tenant compte des espaces dans le nom
    file_path = os.path.join("/etc/NetworkManager/system-connections", f"{ssid}.nmconnection")
    return os.path.isfile(file_path)

def get_wifi_status() -> Dict[str, Any]:
    """
    Récupère le statut de la connexion Wi-Fi actuelle.
    
    Returns:
        Dict: Informations sur la connexion Wi-Fi (connected, ssid, ip_address)
    """
    try:
        # Vérifier si le Wi-Fi est connecté
        iwconfig_output = subprocess.run(
            ["sudo", "/opt/TBERRYPRINT/fonctions.sh", "wifi_iwconfig"], 
            capture_output=True, 
            text=True
        ).stdout
        
        # Chercher le SSID si connecté
        ssid_match = re.search(r'ESSID:"([^"]*)"', iwconfig_output)
        ssid = ssid_match.group(1) if ssid_match else None
        
        # Vérifier si on est connecté (SSID non vide)
        is_connected = ssid is not None and ssid != "off/any"
        
        # Obtenir l'adresse IP si connecté
        ip_address = None
        if is_connected:
            ip_output = subprocess.run(
                ["sudo", "/opt/TBERRYPRINT/fonctions.sh", "ip_info"],
                capture_output=True,
                text=True
            ).stdout
            ip_match = re.search(r'inet (\d+\.\d+\.\d+\.\d+)', ip_output)
            ip_address = ip_match.group(1) if ip_match else None
        
        return {
            "connected": is_connected,
            "ssid": ssid if is_connected else None,
            "ip_address": ip_address
        }
    except Exception as e:
        print(f"Erreur lors de la récupération du statut Wi-Fi: {e}")
        return {"connected": False, "ssid": None, "ip_address": None}

def get_available_wifi_networks() -> List[Dict[str, Any]]:
    """
    Récupère la liste des réseaux Wi-Fi disponibles.
    
    Returns:
        List[Dict]: Liste des réseaux Wi-Fi avec leurs informations
    """
    try:
        # Lancer un scan avec iwlist
        scan_output = subprocess.run(
            ["sudo", "/opt/TBERRYPRINT/fonctions.sh", "wifi_scan_iwlist"],
            capture_output=True,
            text=True
        ).stdout
        
        # Extraire les SSID et le niveau de signal
        networks = []
        cells = scan_output.split("Cell ")
        
        for cell in cells[1:]:  # Ignorer la première partie qui ne contient pas de réseau
            ssid_match = re.search(r'ESSID:"([^"]*)"', cell)
            signal_match = re.search(r'Signal level=(-\d+) dBm', cell)
            encryption_match = re.search(r'Encryption key:(\w+)', cell)
            
            if ssid_match and signal_match:
                ssid = ssid_match.group(1)
                signal_level = int(signal_match.group(1))
                encrypted = encryption_match.group(1) == "on" if encryption_match else True
                hasConnected = has_connected_to_wifi(ssid)
                
                # Convertir le niveau de signal en pourcentage (approximatif)
                # -30 dBm est excellent (100%), -90 dBm est faible (0%)
                signal_percent = max(0, min(100, 2 * (signal_level + 100)))
                
                networks.append({
                    "ssid": ssid,
                    "signal_level": signal_level,
                    "signal_percent": signal_percent,
                    "encrypted": encrypted,
                    "hasConnected": hasConnected
                })
        
        # Trier par niveau de signal (du plus fort au plus faible)
        return sorted(networks, key=lambda x: x["signal_level"], reverse=True)
    except Exception as e:
        print(f"Erreur lors de la récupération des réseaux Wi-Fi: {e}")
        return []


# ===== FONCTIONS D'AUTHENTIFICATION =====

def check_auth() -> bool:
    """
    Vérifie si l'utilisateur est authentifié.
    
    Returns:
        bool: True si l'utilisateur est authentifié, False sinon
    """
    return session.get("logged_in", False)

def is_admin() -> bool:
    """
    Vérifie si l'utilisateur connecté est l'administrateur.
    
    Returns:
        bool: True si l'utilisateur est admin, False sinon
    """
    return session.get("user_type", "") == "admin"


# ===== ROUTES DE L'APPLICATION =====

@app.route("/")
def dashboard():
    """Page principale du tableau de bord."""
    if not check_auth():
        return redirect(url_for("login"))
    
    # Récupération des informations système
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    
    # Formatage des informations de RAM
    ram_total = format_memory(memory.total)
    ram_used = format_memory(memory.used)
    ram_percent = format_percent(memory.percent)
    
    # Récupération des autres informations
    ip_address = get_ip()
    hostname = get_hostname()
    usb_printers = get_usb_printers()
    temperature = get_temperature()
    
    return render_template(
        "index.html",
        cpu_percent=format_percent(cpu_percent),
        ip_address=ip_address,
        hostname=hostname,
        usb_printers=usb_printers,
        temperature=temperature,
        ram_total=ram_total,
        ram_used=ram_used,
        ram_percent=ram_percent,
        session=session
    )

@app.route("/login", methods=["GET", "POST"])
def login():
    """Page de connexion."""
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]
        
        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            session["logged_in"] = True
            session["user_type"] = "admin"
            return redirect(url_for("dashboard"))
        elif username == CLIENT_USERNAME and password == CLIENT_PASSWORD:
            session["logged_in"] = True
            session["user_type"] = "client"
            return redirect(url_for("dashboard"))
        else:
            return render_template("login.html", error="Identifiants incorrects")
    return render_template("login.html")

@app.route("/logout")
def logout():
    """Déconnexion de l'utilisateur."""
    session.pop("logged_in", None)
    return redirect(url_for("login"))

@app.route("/wifi_setup")
def wifi_setup():
    """Page de configuration Wi-Fi."""
    if not check_auth():
        return redirect(url_for("login"))
    
    current_status = get_wifi_status()
    return render_template(
        "wifi_setup.html", 
        current_status=current_status,
        hostname=get_hostname(),
        ip_address=get_ip()
    )


# ===== ROUTES DE L'API =====

@app.route("/stats")
def get_stats():
    """API pour récupérer les statistiques système en temps réel."""
    if not check_auth():
        return jsonify({"error": "Unauthorized"}), 401
    
    # Récupération des informations système
    memory = psutil.virtual_memory()
    cpu_percent_value = psutil.cpu_percent(interval=1)
    
    # Récupération des imprimantes
    usb_printers = get_usb_printers()
    printers_data = []
    for printer_name, status_code in usb_printers:
        printers_data.append({
            "name": printer_name,
            "status": status_code,
            "status_text": get_printer_status_text(status_code),
            "status_icon": get_printer_status_icon(status_code)
        })
    
    # Construction de la réponse
    data = {
        "cpu_percent": format_percent(cpu_percent_value),
        "raw_cpu_percent": cpu_percent_value,
        "temperature": get_temperature(),
        "ram_used": format_memory(memory.used),
        "ram_percent": format_percent(memory.percent),
        "raw_ram_percent": memory.percent,
        "printers": printers_data
    }
    
    return jsonify(data)

@app.route("/api/wifi_networks")
def get_wifi_networks():
    """API pour récupérer la liste des réseaux Wi-Fi disponibles."""
    if not check_auth():
        return jsonify({"error": "Unauthorized"}), 401
    
    networks = get_available_wifi_networks()
    return jsonify({
        "networks": networks,
        "current_status": get_wifi_status()
    })

@app.route("/delete_printer/<printer_name>", methods=["POST"])
def delete_printer(printer_name):
    """API pour supprimer une imprimante."""
    if not check_auth():
        return jsonify({"error": "Unauthorized"}), 401
    
    try:
        subprocess.run(
            ["sudo", "/opt/TBERRYPRINT/fonctions.sh", "printer_remove", printer_name],
            check=True
        )
        return jsonify({"success": True, "message": "Imprimante supprimée avec succès"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route("/test_print/<printer_name>", methods=["POST"])
def test_print(printer_name):
    """API pour lancer un test d'impression."""
    if not check_auth():
        return jsonify({"error": "Unauthorized"}), 401
    
    try:
        subprocess.run([
            "sudo",
            "/opt/TBERRYPRINT/fonctions.sh",
            "impression_test",
            "/opt/TBERRYPRINT/FlaskInstallation/testImpressionInterface.pdf", 
            printer_name
        ], check=True)
        return jsonify({"success": True, "message": "Test d'impression lancé avec succès"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route("/setup_wifi", methods=["POST"])
def setup_wifi():
    """API pour configurer la connexion Wi-Fi avec vérification de la connexion. Dans le cas où le Wi-Fi n'est pas connu par le Raspberry."""
    if not check_auth():
        return jsonify({"error": "Unauthorized"}), 401
    
    ssid = request.form.get("ssid")
    password = request.form.get("password")
    
    if not ssid or not password:
        return jsonify({"success": False, "message": "SSID et mot de passe requis"}), 400
    
    try:
        # Vérifier si le fichier de configuration existe déjà
        connection_file = f"/etc/NetworkManager/system-connections/{ssid}.nmconnection"
        if os.path.isfile(connection_file):
            return redirect(url_for('wifi_setup'))

        # Exécuter le script et capturer le code de retour
        result = subprocess.run(
            ["sudo", "/opt/TBERRYPRINT/fonctions.sh", "wifi_connect", ssid, password], 
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode == 0:
            subprocess.run(
                ["sudo", "/opt/TBERRYPRINT/fonctions.sh", "TBerryPrint_restart"], 
                capture_output=True,
                text=True,
                check=False
            )

            return jsonify({
                "success": True, 
                "message": "Connexion Wi-Fi configurée avec succès",
                "requires_reboot": True
            })
        elif result.returncode == 1:
            return jsonify({
                "success": False, 
                "message": "Échec de connexion: le mot de passe semble incorrect"
            }), 400
        else:
            return jsonify({
                "success": False, 
                "message": f"Erreur lors de la configuration Wi-Fi: {result.stderr}"
            }), 500
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route("/setup_wifi_connected", methods=["POST"])
def setup_wifi_connected():
    """API pour configurer la connexion Wi-Fi avec vérification de la connexion. Dans le cas où le réseaux est déjà connu par le raspberry"""
    if not check_auth():
        return jsonify({"error": "Unauthorized"}), 401
    
    ssid = request.form.get("ssid")
    
    if not ssid:
        return jsonify({"success": False, "message": "SSID et mot de passe requis"}), 400
    
    try:
        # Vérifier si le fichier de configuration existe déjà
        connection_file = f"/etc/NetworkManager/system-connections/{ssid}.nmconnection"
        if os.path.isfile(connection_file):
            return redirect(url_for('wifi_setup'))
        
        # Exécuter le script et capturer le code de retour
        result = subprocess.run(
            ["sudo", "/opt/TBERRYPRINT/fonctions.sh", "wifi_up", ssid], 
            capture_output=True,
            text=True,
            check=False  # Ne pas lever d'exception en cas d'échec
        )
        
        # Vérifier le code de retour
        if result.returncode == 0:
            # Connexion réussie

            # Redéarrage du service d'impression après le changement de connexion
            subprocess.run(
                ["sudo", "/opt/TBERRYPRINT/fonctions.sh", "TBerryPrint_restart"], 
                capture_output=True,
                text=True,
                check=False  # Ne pas lever d'exception en cas d'échec
            )

            return jsonify({
                "success": True, 
                "message": "Connexion Wi-Fi configurée avec succès",
                "requires_reboot": True
            })
        elif result.returncode == 1:
            # Erreur d'authentification (mot de passe incorrect)
            return jsonify({
                "success": False, 
                "message": "Échec de connexion: le mot de passe semble incorrect"
            }), 400
        else:
            # Autre erreur
            return jsonify({
                "success": False, 
                "message": f"Erreur lors de la configuration Wi-Fi: {result.stderr}"
            }), 500
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route("/reboot", methods=["POST"])
def reboot():
    """Route pour redémarrer le Raspberry Pi."""
    if check_auth():
        # Utiliser check=False pour éviter l'erreur si le redémarrage est réussi
        subprocess.run(["sudo", "/opt/TBERRYPRINT/fonctions.sh", "reboot_system"], check=False)
    return redirect(url_for("dashboard"))

@app.route("/update", methods=["POST"])
def update():
    """Route pour mettre à jour le système."""
    if check_auth():
        subprocess.run(["sudo", "/opt/TBERRYPRINT/fonctions.sh", "apt_update"], capture_output=True, text=True)
        subprocess.run(["sudo", "/opt/TBERRYPRINT/fonctions.sh", "apt_upgrade"], capture_output=True, text=True)
        subprocess.run(["sudo", "/opt/TBERRYPRINT/fonctions.sh", "reboot_system"], check=False)
    return redirect(url_for("dashboard"))

@app.route("/change_hostname", methods=["POST"])
def change_hostname():
    """Route pour changer le nom d'hôte."""
    if check_auth():
        if not is_admin():
            return redirect(url_for("dashboard"))
        new_hostname = request.form.get("hostname")
        if new_hostname and new_hostname.isalnum():
            subprocess.run(["sudo", "/opt/TBERRYPRINT/fonctions.sh", "set_hostname", new_hostname], capture_output=True, text=True)
            subprocess.run(["sudo", "/opt/TBERRYPRINT/fonctions.sh", "reboot_system"], check=False)
    return redirect(url_for("dashboard"))


# ===== POINT D'ENTRÉE DE L'APPLICATION =====

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)