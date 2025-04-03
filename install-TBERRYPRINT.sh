#!/bin/bash

source /opt/TBERRYPRINT/fonctions.sh

# Vérification de si le script est utilisé en tant qu'administrateur
require_root
apt_update


# Activation du Wi-Fi à chaque redémarrage
# Partie à décommenter dans le cas où le Wi-Fi n'a pas été configuré sur Pi Imager
# sudo cat > /etc/rc.local << 'EOF'
# #!/bin/sh -e
# rfkill unblock wifi
# ifconfig wlan0 up
# exit 0
# EOF

# sudo chmod +x /etc/rc.local


# Installation de l'interface web
log_info "Installation de l'interface web"
/opt/TBERRYPRINT/FlaskInstallation/install-InterfaceFlask.sh || log_error "Problème avec l'exécutable install-InterfaceFlask.sh"


# Installation de CUPS
log_info "Installation de CUPS"
/opt/TBERRYPRINT/CupsInstallation/install-Cups.sh || log_error "Problème avec l'exécutable install-Cups.sh"


# Installation du service d'impression
log_info "Installation du service d'impression"
/opt/TBERRYPRINT/ImpressionInstallation/install-ServiceImpression.sh || log_error "Problème avec l'exécutable install-ServiceImpression.sh "


# Configuration du Hotspot
log_info "Configuration du Hotspot"
sudo nmcli device wifi hotspot ssid tberryprint password "Tickboss1234" ifname wlan0
UUID=$(nmcli -g connection.uuid connection show Hotspot)
sudo nmcli connection modify "$UUID" connection.autoconnect yes connection.autoconnect-priority -10


# Redémarrage du Raspberry
log_success "Fin de l'installation du module d'impression"
log_warning "Le module va redémarrer dans 5 secondes"
sleep 5
reboot_system
