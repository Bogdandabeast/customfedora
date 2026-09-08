# Cambia entre las imágenes del sistema (niri, NVIDIA open, kernel CachyOS)
# usando `bootc switch`. Tras el rebase hay que reiniciar.
switch-image:
    #!/usr/bin/env bash
    set -euo pipefail

    IMAGES=(
        "niri|ghcr.io/bogdandabeast/niri:latest|Estándar — kernel de Fedora"
        "nvidia|ghcr.io/bogdandabeast/nvidia:latest|NVIDIA Open — drivers NVIDIA open"
        "niri-cachyos|ghcr.io/bogdandabeast/niri-cachyos:latest|Kernel CachyOS"
    )

    echo "→ Imagen actual:"
    bootc status 2>/dev/null | grep -E "Spec|booted" | head -2 || true
    echo

    echo "Elige la imagen a la que quieres cambiar:"
    for i in "${!IMAGES[@]}"; do
        IFS='|' read -r name ref desc <<< "${IMAGES[$i]}"
        echo "  $((i+1))) $name — $desc"
    done
    echo "  q) Salir sin cambios"
    echo
    read -rp "Opción: " choice

    case "$choice" in
        q|Q|0|"")
            echo "Sin cambios."
            exit 0
            ;;
    esac

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#IMAGES[@]} )); then
        echo "❌ Opción inválida: $choice" >&2
        exit 1
    fi

    IFS='|' read -r name ref desc <<< "${IMAGES[$((choice-1))]}"
    echo
    echo "→ Cambiando a: $name"
    echo "  $desc"
    echo "  Ref: $ref"
    echo
    read -rp "¿Continuar? [s/N] " confirm
    case "$confirm" in
        s|S|y|Y) ;;
        *)
            echo "Cancelado."
            exit 0
            ;;
    esac

    sudo bootc switch "$ref"

    echo
    echo "✅ Rebase completado. Reinicia para arrancar con la nueva imagen:"
    echo "   sudo systemctl reboot"
