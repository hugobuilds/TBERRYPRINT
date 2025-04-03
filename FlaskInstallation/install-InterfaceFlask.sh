#!/bin/bash

source /opt/TBERRYPRINT/fonctions.sh

# Vérification de si le script est utilisé en tant qu'administrateur
require_root


# Changement du hostname
# Partie à décommenter dans le cas où le hostname n'a pas été configuré sur Pi Imager
# log_info "Changement du hostname pour tberryprint..."
# sudo /opt/TBERRYPRINT/fonctions.sh set_hostname tberryprint


# Installation des dépendances
log_info "Installation des dépendances..."
apt-get install -y python3-pip python3-cups


# Installation des bibliothèques Python requises via apt
log_info "Installation des bibliothèques Python..."
apt install -y python3-flask python3-psutil python3-dotenv


# Attribution des permissions
log_info "Configuration des permissions..."
chown -R admin:admin /opt/TBERRYPRINT/FlaskInstallation/InterfaceFlask
chmod -R 755 /opt/TBERRYPRINT/FlaskInstallation/InterfaceFlask


# Création du fichier .service
log_info "Création du service systemd..."
sudo cat > /etc/systemd/system/InterfaceFlask.service << EOF
[Unit]
Description=Interface web du Raspberry
After=network.target

[Service]
User=admin
WorkingDirectory=/opt/TBERRYPRINT/FlaskInstallation/InterfaceFlask
ExecStart=/usr/bin/python3 /opt/TBERRYPRINT/FlaskInstallation/InterfaceFlask/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF


# Rechargement de systemd et création des liens symboliques appropriés
log_info "Rechargement des fichiers de configuration..."
sudo systemctl daemon-reload
sudo systemctl enable InterfaceFlask


log_success "Installation de l'interface web terminée ! Un redémarrage est necessaire."
