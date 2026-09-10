# Configura suspend-to-RAM al cerrar la tapa (comportamiento estándar de Fedora):
# la RAM se mantiene auto-refrescada (~0.5-2W) y despierta en ~2 segundos.
# No crea swap, no toca kargs, no hiberna. Toggle: ujust setup-lid-lock ↔ setup-suspend.
setup-suspend:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "→ 1/3 Comprobando soporte de suspend-to-RAM..."
    if [[ ! -e /sys/power/state ]]; then
        echo "   ❌ /sys/power/state no existe: el kernel no expone estados de sleep."
        exit 1
    fi
    if ! grep -q "mem" /sys/power/state; then
        echo "   ❌ 'mem' no está en /sys/power/state ($(cat /sys/power/state)): suspend-to-RAM no disponible."
        exit 1
    fi
    echo "   ✓ suspend-to-RAM disponible (states: $(cat /sys/power/state | tr '\n' ' '))"

    echo "→ 2/3 Configurando logind (cerrar tapa = suspender, aplica en vivo)..."
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/lid.conf >/dev/null <<'EOF'
    [Login]
    HandleLidSwitch=suspend
    HandleLidSwitchExternalPower=suspend
    HandleLidSwitchDocked=ignore
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

    echo "→ 3/3 Verificando..."
    FAIL=0
    if grep -q "^HandleLidSwitch=suspend" /etc/systemd/logind.conf.d/lid.conf 2>/dev/null; then
        echo "   ✓ logind en suspend (suspend-to-RAM al cerrar tapa)"
    else
        echo "   ❌ lid.conf no configurado"
        FAIL=1
    fi
    CAN="$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspend 2>/dev/null || echo '?')"
    if [[ "$CAN" == *"yes"* ]]; then
        echo "   ✓ CanSuspend: yes"
    else
        echo "   ⚠︎  CanSuspend: $CAN (revisa sleep states en BIOS/journalctl si dice 'no')"
    fi

    # Navbar Noctalia → suspend (tapa suspende)
    /usr/bin/noctalia-lid-mode-sync.sh 2>/dev/null || true

    echo
    if [[ $FAIL -eq 0 ]]; then
        echo "✅ Hecho (en vivo, sin reboot). Cierra la tapa → suspend-to-RAM, despierta en ~2s."
        echo "   Prueba: cierra la tapa 5s → abre → sesión intacta. O: systemctl suspend"
        echo "   Toggle futuro: ujust setup-suspend ↔ ujust setup-lid-lock (HUP live)."
        echo "   Restos de hibernate (swapfile/kargs): ujust setup-suspend-cleanup"
        echo "   Menos drenaje: ujust suspend-deep on | ujust suspend-usbwake on | medir: ujust suspend-drain"
    else
        echo "⚠️  Instalado con advertencias. Revisa los mensajes de arriba."
        exit 1
    fi

# Limpia los restos del hibernate antiguo: swapfile 16G, fstab y kargs resume*.
# El borrado de kargs es staged → requiere UN reboot para salir de /proc/cmdline.
setup-suspend-cleanup:
    #!/usr/bin/env bash
    set -euo pipefail
    SWAPFILE="/var/swapfile"
    REBOOT_NEEDED=0

    echo "→ 1/3 Swapfile y fstab..."
    if swapon --show 2>/dev/null | grep -qF "$SWAPFILE"; then
        echo "   swapoff $SWAPFILE"
        sudo swapoff "$SWAPFILE" || true
    fi
    if [[ -f "$SWAPFILE" ]]; then
        sudo rm -f "$SWAPFILE"
        echo "   ✓ $SWAPFILE borrado (16G liberados)"
    else
        echo "   $SWAPFILE ya no existe"
    fi
    if grep -qF "$SWAPFILE" /etc/fstab 2>/dev/null; then
        sudo sed -i "\\|$SWAPFILE|d" /etc/fstab
        echo "   ✓ entrada de fstab eliminada"
    else
        echo "   fstab sin entrada del swapfile (ok)"
    fi

    echo "→ 2/3 Kargs resume* (staged)..."
    for K in resume resume_offset; do
        FULL="$(rpm-ostree kargs 2>/dev/null | tr ' ' '\n' | grep "^${K}=" | head -n1 || true)"
        if [[ -n "${FULL:-}" ]]; then
            sudo rpm-ostree kargs --delete="$FULL" 2>&1 | tail -n 3 || true
            echo "   ✓ ${FULL} staged para borrado"
            REBOOT_NEEDED=1
        else
            echo "   sin ${K}= en kargs"
        fi
    done

    echo "→ 3/3 Recargando logind (tapa ya en suspend)..."
    sudo kill -HUP "$(cat /run/systemd/logind.pid 2>/dev/null || pidof systemd-logind 2>/dev/null | awk '{print $1}')" 2>/dev/null || true

    echo
    if [[ $REBOOT_NEEDED -eq 1 ]]; then
        echo "✅ Limpieza hecha. REINICIA una vez para que resume= desaparezca del cmdline."
        echo "   Tras el reboot: sin restos de hibernate (swapfile, fstab, kargs)."
    else
        echo "✅ Limpieza hecha (sin kargs que borrar — nada pendiente de reboot)."
    fi
    echo "   Nota: systemctl hibernate ya no funcionará (sin swap) — es lo esperado."

# Opt-in: deep sleep (S3) en vez de s2idle — menos drenaje (~0.3-0.8W menos) si la BIOS lo expone.
# Actívalo solo si la sesión despierta intacta: systemctl suspend → abre tapa → todo en su sitio.
suspend-deep enable="on":
    #!/usr/bin/env bash
    set -euo pipefail
    MODE="{{enable}}"
    if [ "$MODE" != "on" ] && [ "$MODE" != "off" ]; then echo "Uso: just suspend-deep on|off"; exit 1; fi
    if [ "$MODE" = "on" ]; then
      if grep -qw deep /sys/power/mem_sleep 2>/dev/null; then
        sudo mkdir -p /var/lib/ryzen-suspend
        sudo touch /var/lib/ryzen-suspend/suspend-deep
        echo "ON: el próximo suspend usará mem_sleep=deep (S3)."
        echo "   PRUEBA YA: systemctl suspend → abre tapa → sesión intacta = OK. Si cuelga al despertar: just suspend-deep off"
      else
        echo "⚠ /sys/power/mem_sleep no ofrece 'deep' ($(cat /sys/power/mem_sleep 2>/dev/null || echo '?'))."
        echo "  Solo s2idle disponible (el firmware no expone S3). Nada que hacer."
        exit 1
      fi
    else
      sudo rm -f /var/lib/ryzen-suspend/suspend-deep
      echo "OFF: vuelve a s2idle (default del kernel) en el próximo suspend."
    fi

# Opt-in: desactivar despertar por USB (XHC) — ~0.1-0.3W menos. No despertará con ratón/teclado USB.
suspend-usbwake enable="off":
    #!/usr/bin/env bash
    set -euo pipefail
    MODE="{{enable}}"
    if [ "$MODE" != "on" ] && [ "$MODE" != "off" ]; then echo "Uso: just suspend-usbwake on|off"; exit 1; fi
    sudo mkdir -p /var/lib/ryzen-suspend
    if [ "$MODE" = "on" ]; then
      sudo touch /var/lib/ryzen-suspend/suspend-usbwake
      echo "ON: el próximo suspend desactiva wake por USB (solo despertarás con la tapa)."
    else
      sudo rm -f /var/lib/ryzen-suspend/suspend-usbwake
      echo "OFF: wake por USB vuelve al default."
    fi

# Mide el drenaje real en suspend: suspende, despierta cuando quieras, y muestra el consumo medio.
# Sin cargador. Referencia Modern 15 B7M: s2idle optimizado ~0.8-1.5W; deep ~0.5-1.0W.
suspend-drain:
    #!/usr/bin/env bash
    set -euo pipefail
    BAT="/sys/class/power_supply/BAT1"
    if [ "$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 1)" = "1" ]; then
      echo "⚠ Estás ENCHUFADO: la medición no valdrá. Desconecta el cargador y repite."
      exit 1
    fi
    get() { cat "$BAT/$1" 2>/dev/null || echo 0; }
    T1=$(date +%s); C1=$(get charge_now); E1=$(get energy_now)
    echo "Suspendiendo... duerme lo que quieras medir (≥10 min recomendado) y despierta abriendo la tapa."
    sudo systemctl suspend
    T2=$(date +%s); C2=$(get charge_now); E2=$(get energy_now)
    DT=$(( T2 - T1 )); [ "$DT" -gt 60 ] || DT=60
    H=$(awk "BEGIN{printf \"%.2f\", $DT/3600}")
    if [ "$E1" != "0" ] && [ "$E2" != "0" ] && [ "$E1" -gt "$E2" ]; then
      MWH=$(awk "BEGIN{printf \"%.1f\", ($E1-$E2)/1000}")
      PW=$(awk "BEGIN{printf \"%.2f\", ($E1-$E2)/1000/$H}")
      echo "  Dormido ${DT}s (${H}h): $MWH mWh → $PW mW de media"
    elif [ "$C1" != "0" ] && [ "$C1" -gt "$C2" ]; then
      V=$(awk "BEGIN{printf \"%.3f\", $(get voltage_now)/1000000}")
      MAH=$(awk "BEGIN{printf \"%.1f\", ($C1-$C2)/1000}")
      PW=$(awk "BEGIN{printf \"%.2f\", ($C1-$C2)/1000/$H*$V}")
      echo "  Dormido ${DT}s (${H}h): $MAH mAh (${V}V) → ~$PW mW de media"
    else
      echo "  No se pudo medir (¿lecturas de batería iguales o suspend muy corto?)."
    fi
    echo "  Referencia: s2idle ~1.5-2.5W stock, ~0.8-1.5W con hook; deep ~0.5-1.0W."
