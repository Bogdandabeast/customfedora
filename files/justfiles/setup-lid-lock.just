# Al cerrar la tapa SOLO bloquea la pantalla (lockscreen de Noctalia) y apaga
# el backlight (DPMS). El sistema sigue corriendo y respeta el perfil de
# energía que tengas puesto (ahorro / equilibrado / rendimiento) — no lo
# cambia. Ideal para tareas largas con tapa bajada (descargas, renders, builds)
# sin forzar consumo extra si estás en ahorro de batería.
# No suspende, no hiberna. Para el modo que sí ahorra batería: ujust setup-hibernate
setup-lid-lock:
    #!/usr/bin/env bash
    set -euo pipefail

    SCRIPT="$HOME/.local/bin/lid-lock.sh"
    UNIT="$HOME/.config/systemd/user/lid-lock.service"

    echo "→ 1/4 Instalando el watcher de la tapa..."
    mkdir -p "$(dirname "$SCRIPT")" "$(dirname "$UNIT")"

    # -- Watcher robusto: detecta estado de tapa por múltiples fuentes,
    #    inhibe logind, y evita apagar pantallas si el lock falló.
    cat > "$SCRIPT" <<'EOS'
    #!/usr/bin/env bash
    # Bloquea la pantalla al cerrar la tapa sin suspender el sistema.
    # Diseñado para modo rendimiento: todo sigue corriendo.
    set -uo pipefail

    # Ruta principal y fallback: algunos equipos exponen /proc/acpi/button/lid/LID/state
    # otros /proc/acpi/button/lid/LID0/state. También usamos loginctl como respaldo.
    LID_PATHS=(
        "/proc/acpi/button/lid/LID/state"
        "/proc/acpi/button/lid/LID0/state"
        "/proc/acpi/button/lid/LID1/state"
    )
    PREV=""

    # Inhibidor de logind: bloquea HandleLidSwitch mientras este watcher vive.
    # Así, aunque lid.conf tarde en aplicarse, nunca se suspende por error.
    # El proceso hijo muere con el script (trap).
    INHIBIT_PID=""
    acquire_inhibit() {
        systemd-inhibit --what=handle-lid-switch --who="lid-lock.sh" --why="Bloqueo por tapa sin suspender" --mode=block sleep infinity 2>/dev/null &
        INHIBIT_PID=$!
        trap 'kill "$INHIBIT_PID" 2>/dev/null || true' EXIT
    }
    acquire_inhibit

    read_lid_state() {
        local p s
        for p in "${LID_PATHS[@]}"; do
            if [[ -r "$p" ]]; then
                s="$(tr -d ' \t' < "$p" 2>/dev/null)" || s=""
                case "$s" in
                    *closed*) echo "closed"; return 0 ;;
                    *open*)   echo "open";   return 0 ;;
                esac
            fi
        done
        # Fallback: loginctl/show puede reflejar el estado; no es fiable en VM sin lid, así que
        # solo lo usamos si /proc no existe.
        # Si nada funciona, devolvemos unknown para no accionar nada.
        echo "unknown"
    }

    # Busca WAYLAND_DISPLAY del compositor niri sin depender de que /proc/PID/environ
    # sea legible (hidepid/SELinux). Prueba varios métodos y devuelve 0 si pudo exportar.
    niri_env() {
        local pid disp
        pid="$(pgrep -x niri 2>/dev/null | head -n1 || true)"
        [[ -z "$pid" ]] && return 1

        # 1) environ del pid (más preciso)
        disp="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^WAYLAND_DISPLAY=//p' | head -n1)"

        # 2) fallback: escanea runtimedirs del usuario por wayland-*
        if [[ -z "${disp:-}" ]]; then
            for d in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/wayland-*; do
                [[ -S "$d" ]] || continue
                disp="$(basename "$d")"
                break
            done
        fi
        [[ -z "${disp:-}" ]] && return 1
        WAYLAND_DISPLAY="$disp"
        export WAYLAND_DISPLAY
        return 0
    }

    # Log mínimo a journal (útil para debug, sin spamear)
    log() { echo "[lid-lock] $*" | systemd-cat -t lid-lock 2>/dev/null || echo "[lid-lock] $*"; }

    while true; do
        state="$(read_lid_state)" || state="unknown"
        if [[ "$state" != "$PREV" ]]; then
            case "$state" in
                closed)
                    if niri_env; then
                        # Bloqueo primero; solo si el lock tuvo éxito apagamos monitores.
                        # Así nunca quedas con pantalla apagada y sesión desbloqueada.
                        if noctalia msg session lock >/dev/null 2>&1; then
                            niri msg action power-off-monitors >/dev/null 2>&1 || true
                            log "tapa cerrada → bloqueada y monitores apagados (WAYLAND_DISPLAY=$WAYLAND_DISPLAY)"
                        else
                            # Retry corto: noctalia puede estar arrancando
                            sleep 1
                            if noctalia msg session lock >/dev/null 2>&1; then
                                niri msg action power-off-monitors >/dev/null 2>&1 || true
                                log "tapa cerrada → bloqueada en 2º intento"
                            else
                                log "tapa cerrada → fallo al bloquear (no se apagan monitores por seguridad)"
                            fi
                        fi
                    else
                        log "tapa cerrada → sin WAYLAND_DISPLAY/niri, no se pudo bloquear"
                    fi
                    ;;
                open)
                    if niri_env; then
                        niri msg action power-on-monitors >/dev/null 2>&1 || true
                        log "tapa abierta → monitores encendidos"
                    fi
                    ;;
                unknown)
                    # Sin sensor de tapa (desktop/VM): no hacer nada, pero no romper el loop
                    ;;
            esac
            PREV="$state"
        fi
        sleep 1
    done
    EOS
    chmod +x "$SCRIPT"

    cat > "$UNIT" <<'EOU'
    [Unit]
    Description=Lock screen when the laptop lid closes (system keeps running)
    After=graphical-session.target
    PartOf=graphical-session.target

    [Service]
    Type=simple
    ExecStart=%h/.local/bin/lid-lock.sh
    Restart=always
    RestartSec=3

    [Install]
    WantedBy=graphical-session.target
    EOU

    echo "→ 2/4 Configurando logind (ignorar la tapa = nada suspende)..."
    echo "   Nota: no se toca power-profiles-daemon; se respeta el perfil actual."
    PPD_NOW="$(powerprofilesctl get 2>/dev/null || busctl get-property org.net.hadess.PowerProfiles /org/net/hadess/PowerProfiles org.net.hadess.PowerProfiles ActiveProfile 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo "desconocido")"
    echo "   Perfil de energía actual: $PPD_NOW (se dejará tal cual)"
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/lid.conf >/dev/null <<'EOF'
    [Login]
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    HandleLidSwitchDocked=ignore
    # Intencionadamente NO se toca IdleAction / IdleActionSec ni PPD:
    # así el ahorro de batería / equilibrado / rendimiento que tengas
    # puesto (Noctalia / powerprofilesctl) sigue mandando.
    EOF
    # Aplica en vivo sin reboot: HUP recarga lid.conf; el inhibitor ya cubre el gap
    if sudo kill -HUP "$(cat /run/systemd/logind.pid 2>/dev/null || pidof systemd-logind 2>/dev/null | awk '{print $1}')" 2>/dev/null; then
        echo "   ✓ logind recargado en vivo (HUP)"
    elif sudo systemctl kill -s HUP systemd-logind 2>/dev/null; then
        echo "   ✓ logind recargado en vivo (systemctl HUP)"
    else
        echo "   (logind leerá esto en el próximo arranque; el inhibitor del watcher ya"
        echo "    bloquea la tapa sin necesidad de reiniciar logind — evitamos sacarte de sesión)"
    fi

    echo "→ 3/4 Activando el watcher..."
    systemctl --user daemon-reload
    systemctl --user enable --now lid-lock.service

    echo "→ 4/4 Verificando..."
    sleep 2
    FAIL=0
    if ! systemctl --user is-active --quiet lid-lock.service; then
        echo "   ⚠️  lid-lock.service no está activo. Logs:"
        systemctl --user status lid-lock.service --no-pager -l 2>/dev/null | tail -n 25 || true
        echo "   Solución: journalctl --user -u lid-lock.service -n 50"
        FAIL=1
    else
        echo "   ✓ watcher activo"
    fi
    # Comprueba que logind realmente ignora la tapa
    if busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch 2>/dev/null | grep -q "ignore"; then
        echo "   ✓ logind: HandleLidSwitch=ignore"
    else
        # busctl puede fallar sin permisos, comprobamos el archivo
        if grep -q "^HandleLidSwitch=ignore" /etc/systemd/logind.conf.d/lid.conf 2>/dev/null; then
            echo "   ✓ lid.conf escrito (ignora tapa)"
        else
            echo "   ⚠️  No se pudo confirmar logind. Reinicia sesión si no bloquea al cerrar."
        fi
    fi
    # Verifica que no hemos tocado el perfil de energía
    PPD_AFTER="$(powerprofilesctl get 2>/dev/null || echo "desconocido")"
    if [[ -n "${PPD_NOW:-}" && "$PPD_NOW" != "desconocido" ]]; then
        if [[ "$PPD_AFTER" == "$PPD_NOW" ]]; then
            echo "   ✓ perfil de energía respetado: $PPD_AFTER"
        else
            echo "   ⚠️  perfil cambió de $PPD_NOW → $PPD_AFTER (no debería pasar)"
        fi
    fi
    # Aviso si no hay sensor de tapa (desktop/VM)
    if [[ ! -e /proc/acpi/button/lid/LID/state && ! -e /proc/acpi/button/lid/LID0/state && ! -e /proc/acpi/button/lid/LID1/state ]]; then
        echo "   ℹ︎  No se detectó sensor de tapa en /proc/acpi/button/lid (normal en desktop/VM)."
    fi
    # Navbar Noctalia → hibernate off
    /usr/bin/noctalia-lid-mode-sync.sh 2>/dev/null || true

    if [[ $FAIL -eq 0 ]]; then
        echo
        echo "✅ Hecho. Al cerrar la tapa: pantalla bloqueada, tareas siguen corriendo (en vivo, sin reboot)."
        echo "   Navbar: hibernate off (tapa solo bloquea). Perfil respetado ($PPD_AFTER)."
        echo "   Toggle futuro sin staged: ujust setup-hibernate ↔ ujust setup-lid-lock (HUP live)"
    else
        echo
        echo "⚠️  Instalado con advertencias. Revisa los mensajes de arriba."
        exit 1
    fi
