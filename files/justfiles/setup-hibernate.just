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

    echo "→ 4/6 Añadiendo resume= al kernel (rpm-ostree, solo una vez)..."
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
    STAGED_NEEDED=0
    if echo "$CUR_KARGS" | tr ' ' '\n' | grep -qxF "$RESUME_KARG"; then
        echo "   ✓ resume ya correcto: $RESUME_KARG (sin staged)"
    elif echo "$CUR_KARGS" | tr ' ' '\n' | grep -q "^resume="; then
        CUR_RESUME="$(echo "$CUR_KARGS" | tr ' ' '\n' | grep "^resume=" | head -n1)"
        CUR_VAL="${CUR_RESUME#resume=}"
        NEW_VAL="${RESUME_KARG#resume=}"
        echo "   Actualizando $CUR_RESUME → $RESUME_KARG"
        # Solo crea staged si realmente cambia; --replace es idempotente
        if ! sudo rpm-ostree kargs --replace="resume=${CUR_VAL}=${NEW_VAL}" 2>/dev/null; then
            sudo rpm-ostree kargs --delete="$CUR_RESUME" --append-if-missing="$RESUME_KARG" 2>/dev/null || \
                sudo rpm-ostree kargs --append-if-missing="$RESUME_KARG"
        fi
        STAGED_NEEDED=1
        CUR_KARGS="$(rpm-ostree kargs 2>/dev/null || echo "")"
    else
        echo "   Añadiendo $RESUME_KARG (único staged, próximos toggles sin reboot)"
        sudo rpm-ostree kargs --append-if-missing="$RESUME_KARG"
        STAGED_NEEDED=1
        CUR_KARGS="$(rpm-ostree kargs 2>/dev/null || echo "")"
    fi
    # resume_offset: solo si lo resolvimos y no está ya — idempotente
    if [[ -n "${SWAP_OFFSET:-}" && "$SWAP_OFFSET" != "0" ]]; then
        if echo "$CUR_KARGS" | tr ' ' '\n' | grep -q "^resume_offset="; then
            CUR_OFF="$(echo "$CUR_KARGS" | tr ' ' '\n' | grep "^resume_offset=" | head -n1)"
            if [[ "$CUR_OFF" == "resume_offset=$SWAP_OFFSET" ]]; then
                echo "   ✓ resume_offset ya correcto: $CUR_OFF"
            else
                echo "   Actualizando $CUR_OFF → resume_offset=$SWAP_OFFSET"
                CUR_OFF_VAL="${CUR_OFF#resume_offset=}"
                sudo rpm-ostree kargs --replace="resume_offset=${CUR_OFF_VAL}=${SWAP_OFFSET}" 2>/dev/null || \
                    sudo rpm-ostree kargs --append-if-missing="resume_offset=$SWAP_OFFSET" || true
                STAGED_NEEDED=1
            fi
        else
            echo "   Añadiendo resume_offset=$SWAP_OFFSET (swapfile)"
            sudo rpm-ostree kargs --append-if-missing="resume_offset=$SWAP_OFFSET" || true
            STAGED_NEEDED=1
        fi
    else
        echo "   ℹ︎  resume_offset no resuelto (systemd ≥254 lo infiere automáticamente al hibernar)."
    fi
    if [[ $STAGED_NEEDED -eq 0 ]]; then
        echo "   ℹ︎  Sin cambios de kargs — toggle futuro sin staged ni reboot."
    fi

    # Aviso LUKS: si el dispositivo es mapper/crypt, el initramfs debe poder descifrarlo
    if [[ "$RESUME_SRC" == /dev/mapper/* ]] || blkid "$RESUME_SRC" 2>/dev/null | grep -qi "crypto_LUKS"; then
        echo "   ℹ︎  Dispositivo cifrado (LUKS) detectado. Asegúrate de que el initramfs pide la clave al reanudar."
        echo "      En Fedora Atomic suele funcionar si el sistema ya pide clave al arrancar."
    fi

    echo "→ 5/6 Configurando logind (suspend-then-hibernate, aplica en vivo)..."
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/lid.conf >/dev/null <<'EOF'
    [Login]
    HandleLidSwitch=suspend-then-hibernate
    HandleLidSwitchExternalPower=suspend-then-hibernate
    HandleLidSwitchDocked=ignore
    HibernateDelaySec=1800
    EOF
    # Aplica sin reboot: HUP recarga lid.conf sin matar sesión (a diferencia de restart)
    if sudo kill -HUP "$(cat /run/systemd/logind.pid 2>/dev/null || pidof systemd-logind 2>/dev/null | awk '{print $1}')" 2>/dev/null; then
        echo "   ✓ logind recargado en vivo (HUP)"
    elif sudo systemctl kill -s HUP systemd-logind 2>/dev/null; then
        echo "   ✓ logind recargado en vivo (systemctl HUP)"
    else
        echo "   ℹ︎  logind leerá lid.conf en próximo reinicio (HUP no disponible)"
    fi

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
        # ¿Necesita reinicio? Solo si kargs staged y aún no en cmdline
        if [[ $STAGED_NEEDED -eq 1 ]] && ! cat /proc/cmdline 2>/dev/null | tr ' ' '\n' | grep -q "^resume="; then
            echo "✅ Hecho. REINICIA una sola vez para que el kernel cargue resume=. (próximos toggles sin reboot)"
            echo "   Tras reiniciar, verifica con: systemctl hibernate"
            echo "   (suspenderá al cerrar la tapa y, si sigue cerrada 30 min, hibernará a 0 consumo)"
            echo "   Toggle futuro: ujust setup-lid-lock ↔ ujust setup-hibernate sin staged ni reboot."
        elif [[ $STAGED_NEEDED -eq 1 ]]; then
            echo "✅ Hecho (staged aplicado pero resume= ya estaba cargado — raro, reinicia si hibernate falla)."
            echo "   Puedes probar ya: systemctl hibernate"
        else
            echo "✅ Hecho (sin staged — toggle en vivo). logind ya en suspend-then-hibernate."
            echo "   Prueba: cierra tapa 5s → debe suspender; o systemctl hibernate"
        fi
    else
        echo "⚠️  Instalado con advertencias. Revisa los mensajes de arriba."
        exit 1
    fi
