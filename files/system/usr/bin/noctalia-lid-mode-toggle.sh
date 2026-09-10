#!/usr/bin/env bash
# Toggle lid-mode suspend on/off sin password (usa sudo NOPASSWD de 90-lid-toggle).
# Se llama desde el widget Noctalia lid-mode (left click).
set -euo pipefail

notify() {
    noctalia msg notification-show "Modo tapa" "$1" 2>/dev/null || \
    notify-send "Modo tapa" "$1" 2>/dev/null || echo "[lid-toggle] $1"
}

lid_mode() {
    local f="/etc/systemd/logind.conf.d/lid.conf"
    if [[ -r "$f" && $(grep -c "^HandleLidSwitch=suspend$" "$f" 2>/dev/null) -gt 0 ]]; then
        echo "suspend"
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
    suspend)
        notify "Cambiando a suspend off (solo bloquea)..."
        if ujust setup-lid-lock 2>&1 | systemd-cat -t lid-toggle 2>/dev/null; then
            notify "Modo tapa: suspend off — tapa solo bloquea"
        else
            notify "Error al cambiar a suspend off — revisa journalctl -t lid-toggle"
            exit 1
        fi
        ;;
    lock|unknown|*)
        notify "Cambiando a suspend on (suspend-to-RAM)..."
        if ujust setup-suspend 2>&1 | systemd-cat -t lid-toggle 2>/dev/null; then
            notify "Modo tapa: suspend on — la tapa suspende en RAM (despierta en ~2s)"
        else
            notify "Error al cambiar a suspend on — revisa journalctl -t lid-toggle"
            exit 1
        fi
        ;;
esac

# Refresca widget inmediatamente (sync ya hace hot-reload)
 /usr/bin/noctalia-lid-mode-sync.sh 2>/dev/null || true
