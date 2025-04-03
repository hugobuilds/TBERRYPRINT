#!/bin/bash

# Ce script récupère le modèle du Raspberry
cat /proc/cpuinfo | grep "Model" | awk -F ': ' '{print $2}' > /opt/TBERRYPRINT/ImpressionInstallation/modeleRaspberry.txt
