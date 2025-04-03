#!/bin/bash

source /opt/TBERRYPRINT/fonctions.sh

# Vérification de si le script est utilisé en tant qu'administrateur
require_root


# Installation de Pi-Apps
log_info "Installation de Pi-Apps..."
sudo -u admin bash -c 'wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash'


# Installation de Hangover
log_info "Installation de Hangover..."
sudo -u admin bash -c '/home/admin/pi-apps/manage install Hangover'


# Création du réoertoire commun entre le service wine et le Raspberry
log_info "Création du répertoire commun entre wine et le Raspberry..."
sudo ln -s /opt/TBERRYPRINT/ImpressionInstallation/wine /home/admin/.wine/dosdevices/r:


# Installation de winbind
log_info "Installation de winbind..."
sudo apt install winbind -y


# Création des fichiers qui contiennent les infos du Raspberry
log_info "Création des fichiers d'info du Raspberry..."
cat /proc/cpuinfo | grep Serial | awk '{print $3}' > /opt/TBERRYPRINT/ImpressionInstallation/wine/infos/numeroDeSerie.txt
cat /proc/cpuinfo | grep "Model" | awk -F ': ' '{print $2}' > /opt/TBERRYPRINT/ImpressionInstallation/wine/infos/modeleRaspberry.txt
#sudo sh -c "lpstat -v | grep usb | awk -F: '{print \$1}' | awk '{print \$3}' > /opt/TBERRYPRINT/ImpressionInstallation/wine/infos/nomImprimante.txt"
echo -e "${GREEN}Informations enregistrées${RESET}"


# Création du fichier .service
log_info "Création du service systemd..."
sudo cat > /etc/systemd/system/TBerryPrint.service << EOF
[Unit]
Description=Service d impression
After=network.target

[Service]
User=admin
WorkingDirectory=/opt/TBERRYPRINT/ImpressionInstallation
ExecStart=/usr/bin/wine /opt/TBERRYPRINT/ImpressionInstallation/TBerryPrint.exe
Restart=always

[Install]
WantedBy=multi-user.target
EOF


# Rechargement de systemd et création des liens symboliques appropriés
log_info "Rechargement des fichiers de configuration..."
sudo systemctl daemon-reload
sudo systemctl enable TBerryPrint.service


log_success "Installation du service d'impression terminée ! Un redémarrage est necessaire."
