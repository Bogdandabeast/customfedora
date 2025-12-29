#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

# Carpeta donde tienes los fondos
WALLPAPERS="/usr/share/backgrounds/"

# Elige un archivo aleatorio
RANDOM_WALL=$(find "$WALLPAPERS" -type f | shuf -n 1)

# Lanza swaybg con ese fondo
swaybg -i "$RANDOM_WALL" -m fill
