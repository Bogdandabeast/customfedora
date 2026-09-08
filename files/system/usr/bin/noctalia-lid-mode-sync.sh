#!/usr/bin/env bash
# Sincroniza el widget custom_button lid-mode de Noctalia con el modo real de tapa.
# Lee /etc/systemd/logind.conf.d/lid.conf y actualiza el config de Noctalia.
# Se llama desde ujust setup-lid-lock / setup-hibernate y al hacer login.
set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"
DEST="$CONF_DIR/lid-mode.toml"

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
    hibernate) GLYPH="moon-stars"; LABEL="hibernate on"; TIP="Tapa: suspende → hiberna (ahorro)" ;;
    lock)      GLYPH="lock";       LABEL="hibernate off"; TIP="Tapa: solo bloquea, tareas siguen" ;;
    *)         GLYPH="help";       LABEL="lid ?";         TIP="Modo tapa desconocido" ;;
esac

mkdir -p "$CONF_DIR"
# Se usa text + glyph: el widget lid-mode es custom_button con glyph+label.
# Noctalia hot-reload: escribir el toml lo recarga al instante.
cat > "$DEST" <<EOF
# Generado por noctalia-lid-mode-sync.sh — no editar a mano (se regenera en ujust setup-*).
[widget.lid-mode]
type = "custom_button"
glyph = "$GLYPH"
label = "$LABEL"
tooltip = "$TIP"

[widget.lid-mode.actions]
left = "exec sh -c 'noctalia msg notification-show \"Modo tapa\" \"$(printf "%s" "$TIP" | sed "s/\"/\\\\\"/g")\"'"
EOF

# Asegura que bar.default.end contiene lid-mode (GUI overrides en settings.toml pisan config.toml)
for _cfg in "${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/config.toml" "${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"; do
    if [[ -f "$_cfg" ]] && ! grep -q '"lid-mode"' "$_cfg" 2>/dev/null; then
        # Solo parchea el bar.default.end si existe; no crea uno nuevo
        if grep -q 'bar\.default' "$_cfg" 2>/dev/null; then
            sed -i 's/end = \[ "notifications"/end = [ "lid-mode", "notifications"/' "$_cfg" 2>/dev/null || true
        fi
    fi
done

# Validación rápida (no aborta si noctalia no está)
noctalia config validate "$DEST" >/dev/null 2>&1 || true
# Intenta refrescar Noctalia si está corriendo (hot-reload ya lo hace, pero por si)
if pgrep -x noctalia >/dev/null 2>&1; then
    noctalia msg config-reload >/dev/null 2>&1 || true
fi
# Salida útil para el justfile
echo "lid-mode: $LABEL ($MODE, glyph=$GLYPH)"
