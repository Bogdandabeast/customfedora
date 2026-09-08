# Configura suspend-then-hibernate al cerrar la tapa:
# suspende al instante y, si sigue cerrada 30 min, hiberna (0 consumo).
# Ideal para no quedarte sin batería llevando el portátil cerrado.
# Requiere reiniciar una vez para que el kernel cargue resume=.
setup-hibernate:
    #!/usr/bin/env bash
    set -euo pipefail

    SWAPFILE="/var/swapfile"
    SWAP_SIZE_G=16

    echo "→ 1/6 Comprobando swapfile (necesario para hibernar)..."
    if [[ ! -f "$SWAPFILE" ]]; then
        echo "   Creando swapfile de ${SWAP_SIZE_G}G en $SWAPFILE..."
        if ! sudo btrfs filesystem mkswapfile --size "${SWAP_SIZE_G}G" "$SWAPFILE" 2>&1; then
            echo "   ❌ No se pudo crear el swapfile con btrfs. ¿El filesystem de /var es btrfs?"
            echo "   Comprueba con: findmnt /var  (debe mostrar FSTYPE=btrfs)"
            echo "   Si usas ext4/xfs, crea el swapfile manualmente con fallocate+mkswap."
            exit 1
        fi
    else
        echo "   Ya existe."
    fi

    echo "→ 2/6 Registrando en /etc/fstab (sin duplicados)..."
    # Limpieza previa de entradas viejas del mismo swapfile (evita duplicados por flags distintos)
    if grep -q "^${SWAPFILE}[[:space:]]" /etc/fstab 2>/dev/null; then
        echo "   Ya registrado en fstab."
    else
        # Elimina cualquier línea previa que mencione el mismo path (por si había flags distintos)
        # y añade la canónica. Usamos edita-atómica con tmp.
        if grep -qF "$SWAPFILE" /etc/fstab 2>/dev/null; then
            sudo sed -i "\|$SWAPFILE|d" /etc/fstab
        fi
        echo "$SWAPFILE none swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null
        echo "   Añadido a fstab."
    fi

    echo "→ 3/6 Activando swap..."
    sudo swapon "$SWAPFILE" 2>/dev/null || true
    if swapon --show 2>/dev/null | grep -qF "$SWAPFILE"; then
        echo "   ✓ Swap activo."
        swapon --show 2>/dev/null | sed 's/^/     /' || true
    else
        echo "   ❌ Swap NO activo tras swapon. Abortando: hibernar sin swap fallará seguro."
        echo "   Revisa: sudo swapon --show ; dmesg | tail -n 50"
        exit 1
    fi

    echo "→ 4/6 Añadiendo resume= al kernel (rpm-ostree)..."
    # findmnt en btrfs subvol devuelve /dev/mapper/luks-xxx[/var] — quitamos el sufijo [subvol]
    RESUME_SRC="$(findmnt -no SOURCE /var 2>/dev/null || findmnt -no SOURCE / 2>/dev/null || true)"
    RESUME_SRC="${RESUME_SRC%%\[*}"  # strip '[/var]' si existe
    if [[ -z "${RESUME_SRC:-}" ]]; then
        echo "   ❌ No se pudo resolver el dispositivo de /var ni de /. abortando."
        exit 1
    fi
    # LUKS: resume debe apuntar al mapper descifrado, no al UUID del FS.
    # Intentamos UUID persistente; necesita sudo para leer LUKS/btrfs.
    RESUME_UUID="$(sudo blkid -s UUID -o value "$RESUME_SRC" 2>/dev/null || blkid -s UUID -o value "$RESUME_SRC" 2>/dev/null || true)"
    if [[ "$RESUME_SRC" == /dev/mapper/* ]]; then
        # En LUKS+btrfs el UUID es del btrfs interno (mismo que root=UUID), pero
        # resume= con UUID puede no resolver antes de descifrar. Usamos el mapper directo,
        # que ya es estable (nombre incluye UUID de LUKS y coincide con rd.luks.uuid).
        RESUME_KARG="resume=$RESUME_SRC"
        echo "   Dispositivo LUKS: $RESUME_SRC → $RESUME_KARG (mapper estable, rd.luks.uuid ya en kargs)"
    elif [[ -n "${RESUME_UUID:-}" ]]; then
        RESUME_KARG="resume=UUID=$RESUME_UUID"
        echo "   Dispositivo: $RESUME_SRC → $RESUME_KARG (persistente)"
    else
        RESUME_KARG="resume=$RESUME_SRC"
        echo "   ⚠️  No se pudo obtener UUID de $RESUME_SRC, usando path directo: $RESUME_KARG"
        echo "      (menos robusto si cambia el nombre del dispositivo)"
    fi
    # También intenta fijar resume_offset si es posible (necesario para swapfile en kernels
    # donde systemd no lo infiere). No falla si no se puede.
    SWAP_OFFSET="$(btrfs inspect-internal map-swapfile -r "$SWAPFILE" 2>/dev/null | head -n1 | awk '{print $NF}' || true)"
    if [[ -z "${SWAP_OFFSET:-}" ]]; then
        # Fallback genérico (filefrag) — funciona en btrfs/ext4/xfs
        SWAP_OFFSET="$(sudo filefrag -v "$SWAPFILE" 2>/dev/null | awk 'NR==4{print $4}' | tr -d '.' || true)"
    fi

    CUR_KARGS="$(rpm-ostree kargs 2>/dev/null || echo "")"
    if echo "$CUR_KARGS" | tr ' ' '\n' | grep -q "^resume="; then
        CUR_RESUME="$(echo "$CUR_KARGS" | tr ' ' '\n' | grep "^resume=" | head -n1)"
        if [[ "$CUR_RESUME" == "$RESUME_KARG" ]]; then
            echo "   Ya está correcto: $CUR_RESUME"
        else
            # rpm-ostree --replace necesita forma KEY=VALUE=NEWVALUE (sin el prefijo 'resume=' duplicado)
            CUR_VAL="${CUR_RESUME#resume=}"
            NEW_VAL="${RESUME_KARG#resume=}"
            echo "   Actualizando $CUR_RESUME → $RESUME_KARG"
            sudo rpm-ostree kargs --replace="resume=${CUR_VAL}=${NEW_VAL}" 2>/dev/null || \
                sudo rpm-ostree kargs --delete="$CUR_RESUME" --append="$RESUME_KARG"
        fi
    else
        echo "   Añadiendo $RESUME_KARG"
        sudo rpm-ostree kargs --append="$RESUME_KARG"
    fi
    # resume_offset: solo si lo resolvimos y no está ya
    if [[ -n "${SWAP_OFFSET:-}" && "$SWAP_OFFSET" != "0" ]]; then
        if echo "$CUR_KARGS" | tr ' ' '\n' | grep -q "^resume_offset="; then
            echo "   resume_offset ya presente ($(echo "$CUR_KARGS" | tr ' ' '\n' | grep "^resume_offset=" | head -n1))"
        else
            echo "   Añadiendo resume_offset=$SWAP_OFFSET (swapfile)"
            sudo rpm-ostree kargs --append="resume_offset=$SWAP_OFFSET" || true
        fi
    else
        echo "   ℹ︎  resume_offset no resuelto (systemd ≥254 lo infiere automáticamente al hibernar)."
    fi

    # Aviso LUKS: si el dispositivo es mapper/crypt, el initramfs debe poder descifrarlo
    if [[ "$RESUME_SRC" == /dev/mapper/* ]] || blkid "$RESUME_SRC" 2>/dev/null | grep -qi "crypto_LUKS"; then
        echo "   ℹ︎  Dispositivo cifrado (LUKS) detectado. Asegúrate de que el initramfs pide la clave al reanudar."
        echo "      En Fedora Atomic suele funcionar si el sistema ya pide clave al arrancar."
    fi

    echo "→ 5/6 Configurando logind (suspend-then-hibernate)..."
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/lid.conf >/dev/null <<'EOF'
    [Login]
    HandleLidSwitch=suspend-then-hibernate
    HandleLidSwitchExternalPower=suspend-then-hibernate
    HandleLidSwitchDocked=ignore
    HibernateDelaySec=1800
    EOF
    echo "   (logind leerá esto tras reiniciar; no se reinicia logind aquí para no sacarte de sesión)"

    # El watcher de "solo bloquear" no debe interferir
    systemctl --user disable --now lid-lock.service >/dev/null 2>&1 || true
    sudo systemctl disable --now lid-lock.service >/dev/null 2>&1 || true

    echo "→ 6/6 Verificando..."
    FAIL=0
    if swapon --show 2>/dev/null | grep -qF "$SWAPFILE"; then
        echo "   ✓ swap activo"
    else
        echo "   ❌ swap no activo"
        FAIL=1
    fi
    if rpm-ostree kargs 2>/dev/null | tr ' ' '\n' | grep -q "^resume="; then
        echo "   ✓ kargs: $(rpm-ostree kargs 2>/dev/null | tr ' ' '\n' | grep "^resume" | tr '\n' ' ')"
    else
        echo "   ❌ falta resume= en kargs"
        FAIL=1
    fi
    if grep -q "suspend-then-hibernate" /etc/systemd/logind.conf.d/lid.conf 2>/dev/null; then
        echo "   ✓ logind en suspend-then-hibernate (30 min → hibernación)"
    else
        echo "   ❌ lid.conf no configurado"
        FAIL=1
    fi

    # Navbar Noctalia → hibernate on
    /usr/bin/noctalia-lid-mode-sync.sh 2>/dev/null || true

    echo
    if [[ $FAIL -eq 0 ]]; then
        # ¿Necesita reinicio?
        if ! cat /proc/cmdline 2>/dev/null | tr ' ' '\n' | grep -q "^resume="; then
            echo "✅ Hecho. REINICIA para que el kernel cargue resume=. (navbar ya dice hibernate on)"
            echo "   Tras reiniciar, verifica con: systemctl hibernate"
            echo "   (suspenderá al cerrar la tapa y, si sigue cerrada 30 min, hibernará a 0 consumo)"
        else
            echo "✅ Hecho (resume= ya cargado en este boot)."
            echo "   Puedes probar ya: systemctl hibernate  (guardará la sesión y apagará)"
        fi
    else
        echo "⚠️  Instalado con advertencias. Revisa los mensajes de arriba."
        exit 1
    fi
