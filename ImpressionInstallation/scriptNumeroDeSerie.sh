#!/bin/bash

# Ce script enregistre le numero de serie du processeur du Raspberry
cat /proc/cpuinfo | grep Serial | awk '{print $3}' > /opt/TBERRYPRINT/ImpressionInstallation/numeroDeSerie.txt
