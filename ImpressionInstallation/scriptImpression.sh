#!/bin/bash

# Ce script imprime le PDF

fichier_pdf=$1
imprimante=$2

# Impression du PDF
lp -d "$imprimante" -o media=Custom.80x120mm -o Density=5 "$fichier_pdf"
