#!/bin/bash

# Définition des couleurs et du style bold
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'  # Réinitialisation des couleurs

# Constantes
DEFAULT_COUNTRY="FR"

# Affiche un message d'information
log_info() {
    echo -e "${BOLD}${BLUE}[INFO] $1 ${NC}"
}

# Affiche un message de succès
log_success() {
    echo -e "${BOLD}${GREEN}[SUCCESS] $1 ${NC}"
}

# Affiche un message d'avertissement
log_warning() {
    echo -e "${BOLD}${YELLOW}[WARNING] $1 ${NC}"
}

# Affiche un message d'erreur
log_error() {
    echo -e "${BOLD}${RED}[ERROR] $1 ${NC}"
}

# Vérifie si le script est exécuté en tant que root
require_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
}

# Fonction pour modifier le hostname (configuration manuelle)
set_hostname() {
    require_root
    
    if [ "$#" -ne 1 ]; then
        log_error "Usage : set_hostname <HOSTNAME>"
        return 1
    fi
    
    local HOSTNAME="$1"
    
    log_info "Configuration du hostname: $HOSTNAME"
    
    # Modifier d'abord les fichiers
    echo "$HOSTNAME" > /etc/hostname
    
    # Modifier /etc/hosts proprement
    if grep -q "127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*/127.0.1.1 $HOSTNAME/" /etc/hosts
    else
        echo "127.0.1.1 $HOSTNAME" >> /etc/hosts
    fi
    
    # Changer le hostname en dernier
    hostnamectl set-hostname "$HOSTNAME"
    
    log_success "Hostname configuré avec succès: $HOSTNAME"
}

# Fonction pour configurer le wifi avec NetworkManager
wifi_show() {
    log_info "Affichage des connexions wifi enregistrées"
    sudo nmcli connection show
}

wifi_connect() {
    require_root
    
    if [ "$#" -lt 2 ]; then
        log_error "Usage: wifi_connect <SSID> <PASSWORD> [INTERFACE]"
        return 1
    fi
    
    local SSID="$1"
    local PASSWORD="$2"
    local INTERFACE="${3:-wlan0}"
    
    log_info "Connexion au réseau WiFi: $SSID sur l'interface $INTERFACE"
    
    if nmcli device wifi connect "$SSID" password "$PASSWORD" ifname $INTERFACE; then
        log_success "Connexion réussie au réseau: $SSID"
    else
        log_error "Échec de la connexion au réseau: $SSID"
        return 1
    fi
}

wifi_delete() {
    require_root
    
    if [ "$#" -ne 1 ]; then
        log_error "Usage: wifi_delete <SSID>"
        return 1
    fi
    
    local SSID="$1"
    
    log_info "Suppression de la connexion WiFi: $SSID"
    
    if nmcli connection delete "$SSID"; then
        log_success "Connexion supprimée: $SSID"
    else
        log_error "Échec de la suppression de la connexion: $SSID"
        return 1
    fi
}

wifi_up() {
    require_root
    
    if [ "$#" -ne 1 ]; then
        log_error "Usage: wifi_up <SSID>"
        return 1
    fi
    
    local SSID="$1"
    
    log_info "Activation de la connexion WiFi: $SSID"
    
    if nmcli connection up "$SSID"; then
        log_success "Connexion activée: $SSID"
    else
        log_error "Échec de l'activation de la connexion: $SSID"
        return 1
    fi
}

wifi_down() {
    require_root
    
    if [ "$#" -ne 1 ]; then
        log_error "Usage: wifi_down <SSID>"
        return 1
    fi
    
    local SSID="$1"
    
    log_info "Désactivation de la connexion WiFi: $SSID"
    
    if nmcli connection down "$SSID"; then
        log_success "Connexion désactivée: $SSID"
    else
        log_error "Échec de la désactivation de la connexion: $SSID"
        return 1
    fi
}

wifi_scan() {
    log_info "Recherche des réseaux WiFi disponibles (nmcli)"
    nmcli device wifi list
}


# -------------------------------------------------------------------
# Fonctions complémentaires intégrant les commandes supplémentaires
# -------------------------------------------------------------------

# Mesurer la température du CPU
measure_temp() {
    log_info "Mesure de la température du CPU"
    vcgencmd measure_temp
}

# Obtenir des informations sur la configuration Wi-Fi via iwconfig
wifi_iwconfig() {
    log_info "Affichage de la configuration WiFi via iwconfig"
    iwconfig wlan0
}

# Obtenir l'adresse IP de l'interface Wi-Fi
ip_info() {
    log_info "Affichage de l'adresse IP de l'interface wlan0"
    ip addr show wlan0
}

# Scanner les réseaux Wi-Fi disponibles avec iwlist
wifi_scan_iwlist() {
    require_root
    log_info "Scan des réseaux WiFi disponibles (iwlist)"
    iwlist wlan0 scan
}

# Supprimer une imprimante
printer_remove() {
    require_root
    if [ "$#" -ne 1 ]; then
        log_error "Usage: printer_remove <printer_name>"
        return 1
    fi
    local PRINTER="$1"
    log_info "Suppression de l'imprimante: $PRINTER"
    lpadmin -x "$PRINTER"
    log_success "Imprimante supprimée: $PRINTER"
}

# Lancer un test d'impression
impression_test() {
    require_root
    if [ "$#" -ne 2 ]; then
        log_error "Usage: impression_test <file> <printer_name>"
        return 1
    fi
    local FILE="$1"
    local PRINTER="$2"
    log_info "Lancement d'un test d'impression sur l'imprimante: $PRINTER avec le fichier: $FILE"
    /opt/TBERRYPRINT/ImpressionInstallation/scriptImpression.sh "$FILE" "$PRINTER"
}

# Redémarrer le service TBerryPrint
TBerryPrint_restart() {
    require_root
    log_info "Redémarrage du service TBerryPrint"
    systemctl restart TBerryPrint.service
    log_success "Service TBerryPrint redémarré"
}

# Redémarrer le Raspberry Pi
reboot_system() {
    require_root
    log_info "Redémarrage du Raspberry Pi"
    reboot
}

# Mettre à jour la liste des paquets
apt_update() {
    require_root
    log_info "Mise à jour de la liste des paquets"
    apt update
}

# Installer les mises à jour du système
apt_upgrade() {
    require_root
    log_info "Installation des mises à jour du système"
    apt upgrade -y
}


# -------------------------------------------------------------------
# Afficher l'aide générale
show_help() {
    echo -e "${BOLD}Fonctions disponibles:${NC}"
    echo "  set_hostname <HOSTNAME>                 - Configurer le hostname (manuel)"
    echo "  wifi_show                               - Afficher les connexions WiFi enregistrées"
    echo "  wifi_connect <SSID> <PWD> [IFACE]       - Se connecter à un réseau WiFi"
    echo "  wifi_delete <SSID>                      - Supprimer une connexion WiFi"
    echo "  wifi_up <SSID>                          - Activer une connexion WiFi"
    echo "  wifi_down <SSID>                        - Désactiver une connexion WiFi"
    echo "  wifi_scan                               - Scanner les réseaux WiFi disponibles (nmcli)"
    echo "  wifi_iwconfig                           - Afficher la configuration WiFi via iwconfig"
    echo "  ip_info                                 - Afficher l'adresse IP de l'interface wlan0"
    echo "  wifi_scan_iwlist                        - Scanner les réseaux WiFi disponibles (iwlist)"
    echo "  measure_temp                            - Mesurer la température du CPU"
    echo "  printer_remove <printer_name>           - Supprimer une imprimante"
    echo "  impression_test <file> <printer_name>   - Lancer un test d'impression"
    echo "  TBerryPrint_restart                     - Redémarrer le service TBerryPrint"
    echo "  reboot_system                           - Redémarrer le Raspberry Pi"
    echo "  apt_update                              - Mettre à jour la liste des paquets"
    echo "  apt_upgrade                             - Installer les mises à jour du système"
    echo -e "${BOLD}Utilisation des logs:${NC}"
    echo "  log_info, log_success, log_warning, log_error"
}

# -------------------------------------------------------------------
# Bloc case pour gérer l'exécution directe vs. le sourcing
# -------------------------------------------------------------------
case "${BASH_SOURCE[0]}" in
    "$0")
        # Le script est exécuté directement
        if [ "$#" -eq 0 ]; then
            # Aucun argument, afficher l'aide
            show_help
        else
            # Traitement des arguments de ligne de commande
            case "$1" in
                set_hostname)
                    shift
                    set_hostname "$@"
                    ;;
                wifi_show)
                    wifi_show
                    ;;
                wifi_connect)
                    shift
                    wifi_connect "$@"
                    ;;
                wifi_delete)
                    shift
                    wifi_delete "$@"
                    ;;
                wifi_up)
                    shift
                    wifi_up "$@"
                    ;;
                wifi_down)
                    shift
                    wifi_down "$@"
                    ;;
                wifi_scan)
                    wifi_scan
                    ;;
                wifi_iwconfig)
                    wifi_iwconfig
                    ;;
                ip_info)
                    ip_info
                    ;;
                wifi_scan_iwlist)
                    wifi_scan_iwlist
                    ;;
                measure_temp)
                    measure_temp
                    ;;
                printer_remove)
                    shift
                    printer_remove "$@"
                    ;;
                impression_test)
                    shift
                    impression_test "$@"
                    ;;
                TBerryPrint_restart)
                    TBerryPrint_restart
                    ;;
                reboot_system)
                    reboot_system
                    ;;
                apt_update)
                    apt_update
                    ;;
                apt_upgrade)
                    apt_upgrade
                    ;;
                help|--help|-h)
                    show_help
                    ;;
                *)
                    log_error "Commande inconnue: $1"
                    show_help
                    exit 1
                    ;;
            esac
        fi
        ;;
    *)
        # Le script est sourcé, ne rien faire
        log_info "Fonctions chargées et prêtes à être utilisées"
        ;;
esac
