# Configura suspend-then-hibernate al cerrar la tapa:
# suspende al instante y, si sigue cerrada 30 min, hiberna (0 consumo).
# Requiere reiniciar una vez para que el kernel cargue resume=.
setup-hibernate:
    #!/usr/bin/env bash
    set -euo pipefail

    SWAPFILE="/var/swapfile"
    SWAP_SIZE_G=16

    echo "→ 1/5 Comprobando swapfile (necesario para hibernar)..."
    if [[ ! -f "$SWAPFILE" ]]; then
        echo "   Creando swapfile de ${SWAP_SIZE_G}G en $SWAPFILE..."
        sudo btrfs filesystem mkswapfile --size "${SWAP_SIZE_G}G" "$SWAPFILE"
    else
        echo "   Ya existe."
    fi

    echo "→ 2/5 Registrando en /etc/fstab..."
    if ! grep -q "^$SWAPFILE " /etc/fstab; then
        echo "$SWAPFILE none swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null
    fi

    echo "→ 3/5 Activando swap..."
    sudo swapon "$SWAPFILE" 2>/dev/null || true
    if swapon --show | grep -q "$SWAPFILE"; then
        echo "   Swap activo."
    else
        echo "   ⚠️  Swap no activo."
    fi

    echo "→ 4/5 Añadiendo resume= al kernel..."
    RESUME_DEV="$(findmnt -no SOURCE /var)"
    if ! rpm-ostree kargs | tr ' ' '\n' | grep -q "^resume="; then
        echo "   Añadiendo resume=$RESUME_DEV"
        sudo rpm-ostree kargs --append="resume=$RESUME_DEV"
    else
        echo "   Ya hay resume=."
    fi

    echo "→ 5/5 Configurando logind (suspend-then-hibernate)..."
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/lid.conf >/dev/null <<'EOF'
    [Login]
    HandleLidSwitch=suspend-then-hibernate
    HandleLidSwitchExternalPower=suspend-then-hibernate
    HibernateDelaySec=1800
    EOF
    sudo systemctl restart systemd-logind

    # El watcher de "solo bloquear" no debe interferir
    systemctl --user disable --now lid-lock.service >/dev/null 2>&1 || true

    echo
    echo "✅ Hecho."
    echo "   Reinicia para que el kernel cargue resume=."
    echo "   Verifica con: systemctl hibernate"
