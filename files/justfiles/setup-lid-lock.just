# Al cerrar la tapa SOLO bloquea la pantalla (lockscreen de Noctalia) y apaga
# el backlight (DPMS). El sistema sigue corriendo al 100 %: ideal para tareas
# largas en segundo plano (descargas, renders, builds).
# Para volver al modo ahorro máximo: ujust setup-hibernate
setup-lid-lock:
    #!/usr/bin/env bash
    set -euo pipefail

    SCRIPT="$HOME/.local/bin/lid-lock.sh"
    UNIT="$HOME/.config/systemd/user/lid-lock.service"

    echo "→ 1/3 Instalando el watcher de la tapa..."
    mkdir -p "$(dirname "$SCRIPT")" "$(dirname "$UNIT")"
    cat > "$SCRIPT" <<'EOS'
    #!/usr/bin/env bash
    # Bloquea la pantalla al cerrar la tapa sin suspender el sistema.
    set -uo pipefail

    LID_STATE="/proc/acpi/button/lid/LID0/state"
    PREV=""

    niri_env() {
        local pid
        pid="$(pgrep -x niri | head -n1 || true)"
        [[ -z "$pid" ]] && return 1
        WAYLAND_DISPLAY="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^WAYLAND_DISPLAY=//p' | head -n1)"
        [[ -n "${WAYLAND_DISPLAY:-}" ]]
    }

    while true; do
        state="$(cat "$LID_STATE" 2>/dev/null | tr -d ' \t')" || state="unknown"
        if [[ "$state" != "$PREV" ]]; then
            case "$state" in
                *closed*)
                    if niri_env; then
                        export WAYLAND_DISPLAY
                        noctalia msg session lock >/dev/null 2>&1 || true
                        niri msg action power-off-monitors >/dev/null 2>&1 || true
                    fi
                    ;;
                *open*)
                    if niri_env; then
                        export WAYLAND_DISPLAY
                        niri msg action power-on-monitors >/dev/null 2>&1 || true
                    fi
                    ;;
            esac
            PREV="$state"
        fi
        sleep 2
    done
    EOS
    chmod +x "$SCRIPT"

    cat > "$UNIT" <<'EOU'
    [Unit]
    Description=Lock screen when the laptop lid closes (system keeps running)
    After=graphical-session.target

    [Service]
    Type=simple
    ExecStart=%h/.local/bin/lid-lock.sh
    Restart=on-failure
    RestartSec=3

    [Install]
    WantedBy=default.target
    EOU

    echo "→ 2/3 Configurando logind (ignorar la tapa = nada suspende)..."
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/lid.conf >/dev/null <<'EOF'
    [Login]
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    EOF
    sudo systemctl restart systemd-logind

    echo "→ 3/3 Activando el watcher..."
    systemctl --user daemon-reload
    systemctl --user enable --now lid-lock.service

    echo
    echo "✅ Hecho. Al cerrar la tapa: pantalla bloqueada, sistema al 100 %."
    echo "   Para volver al modo ahorro máximo: ujust setup-hibernate"
