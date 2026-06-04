#!/bin/bash

# Definir opciones con iconos
entries="󰌾 Bloquear\n󰗼 Cerrar Sesión\n󰐥 Apagar\n󰑐 Reiniciar"

# Lanzar wofi y capturar la selección
selected=$(echo -e "$entries" | wofi --dmenu --prompt "Energía" --width 300 --height 250 --cache-file /dev/null)

# Ejecutar acción basándose en el texto seleccionado
if [[ "$selected" == *"Bloquear"* ]]; then
    # Configuración basada estrictamente en el manual de swaylock estándar
    /usr/bin/swaylock \
        -c 1e1e2e \
        --ring-color 89b4fa \
        --key-hl-color 89b4fa \
        --ring-ver-color 89b4fa \
        --ring-wrong-color f38ba8
elif [[ "$selected" == *"Cerrar Sesión"* ]]; then
    /usr/bin/swaymsg exit
elif [[ "$selected" == *"Apagar"* ]]; then
    /usr/bin/systemctl poweroff
elif [[ "$selected" == *"Reiniciar"* ]]; then
    /usr/bin/systemctl reboot
fi
