#!/usr/bin/env bash
# Test en seco (DRY-RUN) para setup-suspend.just — no modifica el sistema.
# Diagnostica si suspend-to-RAM funcionará y detecta restos del hibernate antiguo.
set -euo pipefail

JUSTFILE="files/justfiles/setup-suspend.just"
GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; CYAN="\033[0;36m"; NC="\033[0m"
pass(){ echo -e "${GREEN}  ✓ $*${NC}"; }
warn(){ echo -e "${YELLOW}  ⚠ $*${NC}"; }
fail(){ echo -e "${RED}  ✗ $*${NC}"; }
info(){ echo -e "${CYAN}  $*${NC}"; }

FAIL=0
echo "═══ test-suspend (dry-run) — no modifica el sistema ═══"
echo "Repo: $(pwd)"
echo "Fecha: $(date -Is)"
echo

echo "→ 1/5 Justfile presente y parseable"
if [[ -f "$JUSTFILE" ]]; then pass "$JUSTFILE existe ($(wc -l < "$JUSTFILE") líneas)"; else fail "$JUSTFILE no existe"; FAIL=1; fi
if just --version >/dev/null 2>&1; then
  if just --justfile "$JUSTFILE" --list >/dev/null 2>&1; then pass "just --list OK (setup-suspend, setup-suspend-cleanup)"; else fail "just --list falló"; FAIL=1; fi
else
  fail "just no disponible — no se pudo validar el justfile"; FAIL=1
fi
if [[ -f "$JUSTFILE" ]]; then
python3 <<'PY' 2>&1 | sed 's/^/    /'
import re, pathlib, subprocess, tempfile, os
txt = pathlib.Path("files/justfiles/setup-suspend.just").read_text()
ok = True
for m in re.finditer(r"^(setup-suspend[\w-]*):\n((?:    .*\n?)+)", txt, re.M):
    name, body = m.group(1), m.group(2)
    body = "\n".join(l[4:] if l.startswith("    ") else l for l in body.splitlines())
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
        f.write(body); fn = f.name
    r = subprocess.run(["bash","-n", fn], capture_output=True, text=True)
    print(f"bash -n {name}: " + ("OK" if r.returncode==0 else "FAIL "+r.stderr))
    if r.returncode != 0: ok = False
    os.unlink(fn)
raise SystemExit(0 if ok else 1)
PY
fi

echo
echo "→ 2/5 Suspend-to-RAM (sleep states)"
if [[ -e /sys/power/state ]]; then
  states=$(cat /sys/power/state | tr '\n' ' ')
  if grep -q "mem" /sys/power/state; then pass "/sys/power/state: $states — 'mem' disponible"; else fail "'mem' ausente en /sys/power/state ($states)"; FAIL=1; fi
else
  fail "/sys/power/state no existe"; FAIL=1
fi
if [[ -r /sys/power/mem_sleep ]]; then
  ms=$(cat /sys/power/mem_sleep)
  cur="$(grep -oE '\[[^]]+\]' /sys/power/mem_sleep 2>/dev/null | head -n1 | tr -d '[]' || true)"
  cur="${cur:-?}"
  info "mem_sleep: $ms (activo: $cur — s2idle=moderno/rápido, deep=clásico)"
else
  info "/sys/power/mem_sleep no expuesto (kernel usará default)"
fi
can="$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspend 2>&1 || echo '?')"
echo "    CanSuspend: $can"
info "Prueba real opcional: systemctl suspend (despierta en ~2s)"

echo
echo "→ 3/5 Logind — preview"
cur_lid="$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch 2>&1 || echo '?')"
echo "    actual: $cur_lid"
if [[ -f /etc/systemd/logind.conf.d/lid.conf ]]; then
  echo "    lid.conf actual:"; sed 's/^/      /' /etc/systemd/logind.conf.d/lid.conf | head -n 20
else
  info "lid.conf aún no existe"
fi
echo "    Lo que hará setup-suspend:"
echo "      HandleLidSwitch=suspend"
echo "      HandleLidSwitchExternalPower=suspend"
echo "      HandleLidSwitchDocked=ignore"
echo "      + desactiva lid-lock.service (HUP live, sin reboot)"

echo
echo "→ 4/5 Restos del hibernate antiguo (si setup-hibernate se aplicó antes)"
SWAPFILE="/var/swapfile"
LEFT=0
if swapon --show 2>&1 | grep -qF "$SWAPFILE"; then warn "$SWAPFILE activo como swap"; LEFT=1
elif [[ -f "$SWAPFILE" ]]; then warn "$SWAPFILE existe (inactivo) — 16G ocupados"; LEFT=1
fi
if grep -qF "$SWAPFILE" /etc/fstab 2>/dev/null; then warn "fstab aún tiene entrada para $SWAPFILE"; LEFT=1; fi
kres="$(rpm-ostree kargs 2>/dev/null | tr ' ' '\n' | grep -E '^resume' | tr '\n' ' ' || true)"
if [[ -n "${kres// /}" ]]; then warn "kargs con restos: $kres"; LEFT=1; fi
if [[ $LEFT -eq 1 ]]; then
  info "Limpieza disponible: ujust setup-suspend-cleanup (swapoff+rm swapfile+fstab+kargs staged, 1 reboot)"
else
  pass "sin restos de hibernate (swapfile/fstab/kargs limpios)"
fi
echo

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}═══ RESULTADO: diagnóstico OK — listo para instalar ═══${NC}"
else
  echo -e "${YELLOW}═══ RESULTADO: con avisos — revisa arriba ═══${NC}"
fi
echo
echo "→ 5/5 Optimizaciones de drenaje (hook ryzen-power-save)"
if [[ -x /usr/lib/systemd/system-sleep/ryzen-power-save ]]; then pass "hook ryzen-power-save instalado (BT/USB/WoWLAN/kbd pre-sleep)"; else info "hook aún no en este sistema (viene baked en la imagen niri-cachyos)"; fi
if [[ -f /var/lib/ryzen-suspend/suspend-deep ]]; then info "suspend-deep: ON (S3)"; else info "suspend-deep: off — activar: ujust suspend-deep on (probar despertar)"; fi
if [[ -f /var/lib/ryzen-suspend/suspend-usbwake ]]; then info "suspend-usbwake: ON (sin wake por USB)"; else info "suspend-usbwake: off — activar: ujust suspend-usbwake on"; fi
if [[ -d /sys/module/amd_pmc ]]; then info "amd_pmc cargado (gestión sleep del SoC Zen activa)"; else info "amd_pmc no cargado (raro en 7730U)"; fi
echo
echo "Para instalar de verdad:"
echo "  ujust setup-suspend          # logind suspend-to-RAM (en vivo, sin reboot)"
echo "  ujust setup-suspend-cleanup  # solo si tuviste hibernate antes (staged kargs → 1 reboot)"
echo "  ujust suspend-deep on | suspend-usbwake on   # menos drenaje (opt-in, probar despertar)"
echo "  ujust suspend-drain          # medir drenaje real en mW (sin cargador)"
echo "Este script no ha tocado nada (solo lectura)."
