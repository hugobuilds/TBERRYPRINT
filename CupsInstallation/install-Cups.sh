#!/bin/bash

source /opt/TBERRYPRINT/fonctions.sh

# Vérification de si le script est utilisé en tant qu'administrateur
require_root


# Installation des dépendances
log_info "Installation des dépendances..."
sudo apt-get install libssl-dev libcups2-dev libcupsimage2-dev build-essential -y


# Décompression de cups-2.4.11-source.tar.gz
log_info "Décompression de cups-2.4.11-source.tar.gz..."
tar -xzvf /opt/TBERRYPRINT/CupsInstallation/cups-2.4.11-source.tar.gz -C /tmp
log_info "Entré dans le dossier cups-2.4.11-source.tar.gz"
cd /tmp/cups-2.4.11/


# Configuration de cups
log_info "Configuration de CUPS..."
sudo ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc


# Compilation de CUPS
log_info "Compilation de CUPS..."
sudo make


# Installation de CUPS
log_info "Installation de CUPS..."
sudo make install


# Filtres de cups
log_info "Installation des filtres CUPS..."
sudo apt-get install cups-filters -y


# Sauvegarde de la config de CUPS
log_info "Sauvegarde de la config de CUPS..."
sudo cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.backup


# Modification de la config CUPS
log_info "Modification de la config CUPS..."
sudo tee /etc/cups/cupsd.conf <<'EOF'
#
# Configuration file for the CUPS scheduler.  See "man cupsd.conf" for a
# complete description of this file.
#

# Log general information in error_log - change "warn" to "debug"
# for troubleshooting...
LogLevel warn
PageLogFormat

# Specifies the maximum size of the log files before they are rotated.  The value "0" disables log rotation.
MaxLogSize 1m

# Default error policy for printers
ErrorPolicy stop-printer

# Only listen for connections from the local machine.
Port 631
Listen 0.0.0.0:631
Listen /var/run/cups/cups.sock

# Show shared printers on the local network.
Browsing Yes
BrowseLocalProtocols

# Default authentication type, when authentication is required...
DefaultAuthType Basic

# Web interface setting...
WebInterface Yes

# Timeout after cupsd exits if idle (applied only if cupsd runs on-demand - with -l)
IdleExitTimeout 60

# Restrict access to the server...
<Location />
  Order allow,deny
  Allow all
</Location>

# Restrict access to the admin pages...
<Location /admin>
  Order allow,deny
  Allow all
</Location>

# Restrict access to configuration files...
<Location /admin/conf>
  Order allow,deny
  Allow all
</Location>

# Restrict access to log files...
<Location /admin/log>
  Order allow,deny
  Allow all
</Location>

# Set the default printer/job policies...
<Policy default>
  # Job/subscription privacy...
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default

  # Job-related operations must be done by the owner or an administrator...
  <Limit Create-Job Print-Job Print-URI Validate-Job>
    Order deny,allow
  </Limit>

  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Move-Job>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit CUPS-Get-Document>
    AuthType Default
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  # All administration operations require an administrator to authenticate...
  <Limit CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default CUPS-Get-Devices>
    Order deny,allow
    Allow all
  </Limit>

  # All printer operations require a printer operator to authenticate...
  <Limit Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs Deactivate-Printer Activate-Printer Restart-Printer Shutdown-Printer Startup-Printer Promote-Job Schedule-Job-After Cancel-Jobs CUPS-Accept-Jobs CUPS-Reject-Jobs>
    Order deny,allow
    Allow all
  </Limit>

  # Only the owner or an administrator can cancel or authenticate a job...
  <Limit Cancel-Job>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit CUPS-Authenticate-Job>
    AuthType Default
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit All>
    Order deny,allow
  </Limit>
</Policy>

# Set the authenticated printer/job policies...
<Policy authenticated>
  # Job/subscription privacy...
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default

  # Job-related operations must be done by the owner or an administrator...
  <Limit Create-Job Print-Job Print-URI Validate-Job>
    AuthType Default
    Order deny,allow
  </Limit>

  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Move-Job CUPS-Get-Document>
    AuthType Default
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  # All administration operations require an administrator to authenticate...
  <Limit CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>

  # All printer operations require a printer operator to authenticate...
  <Limit Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs Deactivate-Printer Activate-Printer Restart-Printer Shutdown-Printer Startup-Printer Promote-Job Schedule-Job-After Cancel-Jobs CUPS-Accept-Jobs CUPS-Reject-Jobs>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>

  # Only the owner or an administrator can cancel or authenticate a job...
  <Limit Cancel-Job CUPS-Authenticate-Job>
    AuthType Default
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit All>
    Order deny,allow
  </Limit>
</Policy>

# Set the kerberized printer/job policies...
<Policy kerberos>
  # Job/subscription privacy...
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default

  # Job-related operations must be done by the owner or an administrator...
  <Limit Create-Job Print-Job Print-URI Validate-Job>
    AuthType Negotiate
    Order deny,allow
  </Limit>

  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Move-Job CUPS-Get-Document>
    AuthType Negotiate
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  # All administration operations require an administrator to authenticate...
  <Limit CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>

  # All printer operations require a printer operator to authenticate...
  <Limit Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs Deactivate-Printer Activate-Printer Restart-Printer Shutdown-Printer Startup-Printer Promote-Job Schedule-Job-After Cancel-Jobs CUPS-Accept-Jobs CUPS-Reject-Jobs>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>

  # Only the owner or an administrator can cancel or authenticate a job...
  <Limit Cancel-Job CUPS-Authenticate-Job>
    AuthType Negotiate
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
EOF


# Compilation de rastertostar
log_info "Compilation et déplacement de rastertostar..."
sudo gcc -Wall -fPIC -O2 -Wno-deprecated-declarations -o /usr/lib/cups/filter/rastertostar /opt/TBERRYPRINT/CupsInstallation/rastertostar/rastertostar.c -lcupsimage -lcups


# Attribution des permissions
log_info "Configuration des permissions..."
sudo chown root:root /usr/lib/cups/filter/rastertostar
sudo chmod 755 /usr/lib/cups/filter/rastertostar


# Driver de la Star TSP700II
log_info "Déplacement du driver de la Star TSP700II..."
sudo cp /opt/TBERRYPRINT/CupsInstallation/tsp700II.ppd /usr/share/cups/model


# Ajout d'une imprimante Star TSP700II
#log_info "Ajout de la Star TSP700II."
#log_warning "Par défaut dite 'prête', même si elle n'est pas branchée."
#sudo lpadmin -p Star_TSP743II_ -E -v "usb://Star/TSP743II%20(STR_T-001)?serial=12345678" -P /usr/share/cups/model/tsp700II.ppd
#sudo lpadmin -p Star_TSP743II_ -D "Imprimante Tickboss Star_TSP743II_"
#sudo lpadmin -p Star_TSP743II_ -o PageCutType=2FullCutPage -o DocCutType=2FullCutDoc


log_success "Installation de CUPS terminée ! Un redémarrage est necessaire."
