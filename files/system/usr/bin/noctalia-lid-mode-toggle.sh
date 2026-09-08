#!/usr/bin/env bash
# Toggle lid-mode hibernate on/off sin password (usa sudo NOPASSWD de 90-lid-toggle).
# Se llama desde el widget Noctalia lid-mode (left click).
set -euo pipefail

notify() {
    noctalia msg notification-show "Modo tapa" "$1" 2>/dev/null || \
    notify-send "Modo tapa" "$1" 2>/dev/null || echo "[lid-toggle] $1"
}

lid_mode() {
    local f="/etc/systemd/logind.conf.d/lid.conf"
    if [[ -r "$f" && $(grep -c "suspend-then-hibernate" "$f" 2>/dev/null) -gt 0 ]]; then
        echo "hibernate"
    elif systemctl --user is-active --quiet lid-lock.service 2>/dev/null; then
        echo "lock"
    elif [[ -r "$f" && $(grep -c "HandleLidSwitch=ignore" "$f" 2>/dev/null) -gt 0 ]]; then
        echo "lock"
    else
        echo "unknown"
    fi
}

MODE="$(lid_mode)"
case "$MODE" in
    hibernate)
        notify "Cambiando a hibernate off (solo bloquea)..."
        if ujust setup-lid-lock 2>&1 | systemd-cat -t lid-toggle 2>/dev/null; then
            notify "Modo tapa: hibernate off — tapa solo bloquea"
        else
            notify "Error al cambiar a hibernate off — revisa journalctl -t lid-toggle"
            exit 1
        fi
        ;;
    lock|unknown|*)
        notify "Cambiando a hibernate on (suspende → hiberna)..."
        if ujust setup-hibernate 2>&1 | systemd-cat -t lid-toggle 2>/dev/null; then
            # setup-hibernate avisa si necesita reinicio por resume=
            if ! tr ' ' '\n' < /proc/cmdline 2>/dev/null | grep -q "^resume="; then
                if rpm-ostree kargs 2>/dev/null | tr ' ' '\n' | grep -q "^resume="; then
                    notify "Modo tapa: hibernate on — reinicia para activar resume"
                fi
            else
                notify "Modo tapa: hibernate on — tapa suspende → hiberna en 30 min"
            fi
        else
            notify "Error al cambiar a hibernate on — revisa journalctl -t lid-toggle"
            exit 1
        fi
        ;;
esac

# Refresca widget inmediatamente (sync ya hace hot-reload)
 /usr/bin/noctalia-lid-mode-sync.sh 2>/dev/null || true
