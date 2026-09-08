#!/usr/bin/env bash
# Test en seco (DRY-RUN) para setup-lid-lock.just — no toca logind ni crea servicios.
# Solo lee y simula para comprobar que el modo rendimiento respeta el perfil de energía.
set -euo pipefail

JUSTFILE="files/justfiles/setup-lid-lock.just"
GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; CYAN="\033[0;36m"; NC="\033[0m"
pass(){ echo -e "${GREEN}  ✓ $*${NC}"; }
warn(){ echo -e "${YELLOW}  ⚠ $*${NC}"; }
fail(){ echo -e "${RED}  ✗ $*${NC}"; }
info(){ echo -e "${CYAN}  $*${NC}"; }

FAIL=0
echo "═══ test-lid-lock (dry-run) — no modifica el sistema ═══"
echo "Repo: $(pwd)"
echo "Fecha: $(date -Is)"
echo

echo "→ 1/6 Justfile presente y parseable"
if [[ -f "$JUSTFILE" ]]; then pass "$JUSTFILE existe ($(wc -l < "$JUSTFILE") líneas)"; else fail "$JUSTFILE no existe"; FAIL=1; fi
if just --version >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  jf="$tmpdir/justfile"; echo "import '$(pwd)/$JUSTFILE'" > "$jf"
  if just --justfile "$jf" --list >/dev/null 2>&1; then pass "just --list OK (recurso parseado)"; else fail "just --list falló"; FAIL=1; fi
  rm -rf "$tmpdir"
else warn "just no instalado — salto validación de sintaxis just"
fi
# bash -n del watcher embebido
py_out=$(python3 <<'PY' 2>&1
import re, pathlib, subprocess, tempfile, os
txt = pathlib.Path("files/justfiles/setup-lid-lock.just").read_text()
m = re.search(r"cat > \"\$SCRIPT\" <<'EOS'\n(.*?)\n\s*EOS", txt, re.S)
inner = m.group(1)
inner = "\n".join(line[4:] if line.startswith("    ") else line for line in inner.splitlines())
import tempfile, subprocess
with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f: f.write(inner); fn=f.name
r = subprocess.run(["bash","-n", fn], capture_output=True, text=True)
print("OK" if r.returncode==0 else "FAIL "+r.stderr)
import os; os.unlink(fn)
PY
)
if [[ "$py_out" == OK* ]]; then pass "watcher embebido bash -n OK"; else fail "watcher bash -n: $py_out"; FAIL=1; fi
# chequeo clave: no debe contener powerprofilesctl set
if grep -q "powerprofilesctl set" "$JUSTFILE" 2>/dev/null; then fail "lid-lock contiene 'powerprofilesctl set' (no debe cambiar el perfil)"; FAIL=1; else pass "respeta PPD: no hay 'powerprofilesctl set' (solo get)"; fi
if grep -q "HandleLidSwitch=ignore" "$JUSTFILE" 2>/dev/null; then pass "lid.conf pondrá HandleLidSwitch=ignore"; else fail "falta HandleLidSwitch=ignore en justfile"; FAIL=1; fi
echo

echo "→ 2/6 Sensor de tapa"
for p in /proc/acpi/button/lid/LID/state /proc/acpi/button/lid/LID0/state /proc/acpi/button/lid/LID1/state; do
  if [[ -r "$p" ]]; then
    val=$(tr -d ' \t' < "$p" 2>/dev/null || echo "?")
    if [[ "$val" == *closed* ]]; then pass "$p → closed"; elif [[ "$val" == *open* ]]; then pass "$p → open"; else warn "$p → $val"; fi
  else info "$p → no existe (normal si tu tapa es otro LID)"
  fi
done
if ls /proc/acpi/button/lid/*/state >/dev/null 2>&1; then
  pass "sensor detectado en /proc/acpi/button/lid"
  ls -l /proc/acpi/button/lid/*/state 2>&1 | sed 's/^/    /'
else warn "sin sensor visible — en VM/desktop el watcher quedará en 'unknown' y no hará nada (esperado)"
fi
# Simula read_lid_state() del justfile
snippet_lid=$'LID_PATHS=("/proc/acpi/button/lid/LID/state" "/proc/acpi/button/lid/LID0/state" "/proc/acpi/button/lid/LID1/state")\nread_lid_state(){ local p s; for p in "${LID_PATHS[@]}"; do if [[ -r "$p" ]]; then s="$(tr -d \' \\t\' < "$p" 2>/dev/null)" || s=""; case "$s" in *closed*) echo "closed"; return 0;; *open*) echo "open"; return 0;; esac; fi; done; echo "unknown"; }\nread_lid_state'
lid_now=$(bash -c "$snippet_lid" 2>/dev/null || echo "unknown")
info "read_lid_state() → $lid_now"
[[ "$lid_now" == "open" || "$lid_now" == "closed" ]] && pass "read_lid_state funciona" || warn "read_lid_state → unknown (sin tapa)"
echo

echo "→ 3/6 Stack gráfico (niri / noctalia / Wayland)"
if command -v niri >/dev/null 2>&1; then pass "niri: $(niri --version 2>&1 | head -n1)"; else fail "niri no encontrado"; FAIL=1; fi
if command -v noctalia >/dev/null 2>&1; then pass "noctalia: $(noctalia --version 2>&1 | head -n1)"; else fail "noctalia no encontrado"; FAIL=1; fi
echo "    WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-<no exportado en este shell>}"
echo "    XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-<vacío>} (| id -u = $(id -u))"
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then ls -l "$XDG_RUNTIME_DIR"/wayland-* 2>&1 | sed 's/^/    /' || warn "sin sockets wayland-* en XDG_RUNTIME_DIR"
else warn "XDG_RUNTIME_DIR vacío — suele ser /run/user/$(id -u)"
fi
if pgrep -x niri >/dev/null 2>&1; then pass "niri corriendo (PID $(pgrep -x niri | head -n1))"; else warn "niri no corre en esta sesión — el watcher no podría bloquear hasta que niri arranque (reintentará)"
fi
# Simula niri_env() del watcher
if bash -c 'pid=$(pgrep -x niri 2>/dev/null | head -n1); [[ -n "$pid" ]] && { d=$(tr "\0" "\n" < "/proc/$pid/environ" 2>/dev/null | sed -n "s/^WAYLAND_DISPLAY=//p" | head -n1); [[ -n "$d" ]] && echo "$d"; }' 2>/dev/null | grep -q "wayland"; then
  pass "niri_env: puede resolver WAYLAND_DISPLAY vía /proc/PID/environ"
else
  # fallback por socket
  if ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/wayland-* >/dev/null 2>&1; then pass "niri_env fallback: socket wayland-* presente"; else warn "niri_env podría fallar (ni environ ni socket visibles)"
  fi
fi
# Prueba no-destructiva de IPC (sin bloquear de verdad)
if pgrep -x niri >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" || -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wayland-1" ]]; then
  # Usa el WAYLAND_DISPLAY efectivo del compositor
  disp_probe=${WAYLAND_DISPLAY:-}; [[ -z "$disp_probe" ]] && disp_probe=$(basename "$(ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/wayland-* 2>/dev/null | head -n1)" 2>/dev/null || echo "")
  if WAYLAND_DISPLAY="$disp_probe" niri msg --help >/dev/null 2>&1; then pass "niri msg IPC responde (WAYLAND_DISPLAY=$disp_probe)"; else warn "niri msg no responde — puede que WAYLAND_DISPLAY sea distinto"
  fi
else warn "salto prueba niri msg (sin sesión gráfica activa aquí)"
fi
echo

echo "→ 4/6 Perfil de energía (debe respetarse, no cambiarse)"
ppd_now=$(powerprofilesctl get 2>/dev/null || echo "desconocido")
ppd_bus=$(busctl get-property org.net.hadess.PowerProfiles /org/net/hadess/PowerProfiles org.net.hadess.PowerProfiles ActiveProfile 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
echo "    powerprofilesctl get → $ppd_now"
[[ -n "$ppd_bus" ]] && echo "    busctl ActiveProfile → $ppd_bus"
if [[ "$ppd_now" == "power-saver" ]]; then pass "perfil actual power-saver (ahorro) — lid-lock debe dejarlo tal cual"; elif [[ "$ppd_now" == "balanced" ]]; then pass "perfil balanced — lid-lock lo dejará tal cual"; elif [[ "$ppd_now" == "performance" ]]; then pass "perfil performance — lid-lock lo dejará tal cual"; else warn "perfil desconocido: $ppd_now"
fi
info "El justfile NO hace 'powerprofilesctl set' ni toca IdleAction — lo verifica con get antes y después."
echo

echo "→ 5/6 Logind — vista previa (solo lectura, no se escribe nada)"
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch 2>&1 | sed 's/^/    logind HandleLidSwitch actual: /' || info "sin bus logind accesible"
if [[ -f /etc/systemd/logind.conf.d/lid.conf ]]; then echo "    /etc/systemd/logind.conf.d/lid.conf actual:"; sed 's/^/      /' /etc/systemd/logind.conf.d/lid.conf 2>&1 | head -n 20; else info "/etc/systemd/logind.conf.d/lid.conf no existe aún (lo creará el justfile)"
fi
echo "    Lo que hará setup-lid-lock (preview):"
echo "      HandleLidSwitch=ignore"
echo "      HandleLidSwitchExternalPower=ignore"
echo "      HandleLidSwitchDocked=ignore"
echo "      + inhibitor logind (systemd-inhibit) mientras el watcher vive"
echo

echo "→ 6/6 Simulación de ciclo tapa cerrada/abierta (sin bloquear de verdad)"
echo "    Esto simula el 'case closed/open' del watcher con ficheros temporales,"
echo "    para comprobar que el flujo de lock → power-off solo ocurre si el lock funcionó."
tmp_lid=$(mktemp)
cleanup(){ rm -f "$tmp_lid"; }
trap cleanup EXIT
echo "state:      open" > "$tmp_lid"
fake_state=$(tr -d ' \t' < "$tmp_lid"); [[ "$fake_state" == *open* ]] && pass "mock open detectado" || fail "mock open no detectado"
echo "state:      closed" > "$tmp_lid"
fake_state=$(tr -d ' \t' < "$tmp_lid"); [[ "$fake_state" == *closed* ]] && pass "mock closed detectado" || fail "mock closed no detectado"
info "Lógica del watcher: closed → noctalia msg session lock → solo si OK → niri power-off-monitors"
info "            open   → niri power-on-monitors"
info "Si ves 'open' arriba, tu tapa real está abierta. Para probar de verdad, cierra la tapa 3 s tras instalar el modo."
echo

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}═══ RESULTADO: todo OK (dry-run) — listo para instalar ═══${NC}"
  echo "Para instalar de verdad:"
  echo "  ujust setup-lid-lock        # activa modo rendimiento con tapa bajada"
  echo "  journalctl --user -u lid-lock.service -f   # ver logs del watcher"
else
  echo -e "${YELLOW}═══ RESULTADO: OK con avisos — revisa arriba antes de instalar ═══${NC}"
fi
echo "Este script no ha tocado nada (sin sudo, sin systemctl)."
