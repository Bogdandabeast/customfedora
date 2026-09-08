#!/usr/bin/env bash
# Test en seco (DRY-RUN) para setup-hibernate.just — no toca swap, fstab ni kargs.
# Solo diagnostica si suspend-then-hibernate podrá funcionar.
set -euo pipefail

JUSTFILE="files/justfiles/setup-hibernate.just"
GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; CYAN="\033[0;36m"; NC="\033[0m"
pass(){ echo -e "${GREEN}  ✓ $*${NC}"; }
warn(){ echo -e "${YELLOW}  ⚠ $*${NC}"; }
fail(){ echo -e "${RED}  ✗ $*${NC}"; }
info(){ echo -e "${CYAN}  $*${NC}"; }

FAIL=0
echo "═══ test-hibernate (dry-run) — no modifica el sistema ═══"
echo "Repo: $(pwd)"
echo "Fecha: $(date -Is)"
echo

echo "→ 1/6 Justfile presente y parseable"
if [[ -f "$JUSTFILE" ]]; then pass "$JUSTFILE existe ($(wc -l < "$JUSTFILE") líneas)"; else fail "$JUSTFILE no existe"; FAIL=1; fi
if grep -q "SWAP_SIZE_G=16" "$JUSTFILE" 2>/dev/null; then pass "swap fijo 16G (SWAP_SIZE_G=16)"; else warn "no se encontró SWAP_SIZE_G=16 — ¿cambió el tamaño?"
fi
if just --version >/dev/null 2>&1; then
  tmpdir=$(mktemp -d); jf="$tmpdir/justfile"; echo "import '$(pwd)/$JUSTFILE'" > "$jf"
  if just --justfile "$jf" --list >/dev/null 2>&1; then pass "just --list OK"; else fail "just --list falló"; FAIL=1; fi
  rm -rf "$tmpdir"
fi
python3 <<'PY' 2>&1 | sed 's/^/    /'
import re, pathlib, subprocess, tempfile
txt = pathlib.Path("files/justfiles/setup-hibernate.just").read_text()
m = re.search(r"^setup-[^\n]*:\n(.*)", txt, re.S|re.M)
body = m.group(1)
body = "\n".join(l[4:] if l.startswith("    ") else l for l in body.splitlines())
import tempfile, subprocess
with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f: f.write(body); fn=f.name
r = subprocess.run(["bash","-n", fn], capture_output=True, text=True)
print("bash -n outer: " + ("OK" if r.returncode==0 else "FAIL "+r.stderr))
import os; os.unlink(fn)
PY
echo

echo "→ 2/6 Filesystem y swap actual"
findmnt /var 2>&1 | sed 's/^/    /' || findmnt / 2>&1 | sed 's/^/    /'
fstype=$(findmnt -no FSTYPE /var 2>/dev/null || findmnt -no FSTYPE / 2>/dev/null || echo "?")
if [[ "$fstype" == "btrfs" ]]; then pass "FSTYPE btrfs en /var (btrfs mkswapfile funcionará)"; else warn "FSTYPE=$fstype — btrfs mkswapfile fallará; el justfile abortará con mensaje claro"
fi
echo "    swapon --show:"; swapon --show 2>&1 | sed 's/^/      /' || echo "      (sin swap activo)"
if swapon --show 2>&1 | grep -q "/var/swapfile"; then pass "/var/swapfile ya activo"; else info "/var/swapfile aún no existe/activo (lo creará el justfile, 16G)"
fi
if [[ -f /var/swapfile ]]; then ls -lh /var/swapfile 2>&1 | sed 's/^/    swapfile: /'; du -sh /var/swapfile 2>&1 | sed 's/^/    /'; else info "/var/swapfile no existe aún"
fi
mem_g=$(( ( $(awk '/^MemTotal:/{print $2}' /proc/meminfo) + 1024*1024 -1 ) / (1024*1024) ))
echo "    RAM ~ ${mem_g}G — swap 16G cubre hasta esa RAM (el justfile ya no calcula, es fijo 16G)"
echo "    /etc/fstab (líneas swap):"; grep -i swap /etc/fstab 2>&1 | sed 's/^/      /' || echo "      (sin entradas swap en fstab)"
echo

echo "→ 3/6 Resume (kargs y cmdline)"
src_raw=$(findmnt -no SOURCE /var 2>/dev/null || findmnt -no SOURCE / 2>/dev/null || echo "")
src="${src_raw%%\[*}"  # strip '[/var]' que btrfs subvol añade (si no hay, queda igual)
echo "    findmnt SOURCE /var → ${src_raw:-<no resuelto>}  (normalizado: ${src:-<vacío>})"
if [[ -n "$src" ]]; then
  uuid=$(sudo blkid -s UUID -o value "$src" 2>/dev/null || blkid -s UUID -o value "$src" 2>/dev/null || echo "")
  if [[ "$src" == /dev/mapper/* ]]; then
    pass "LUKS mapper: $src → el justfile usará resume=$src (estable, coincide con rd.luks.uuid)"
    [[ -n "$uuid" ]] && info "      UUID interno btrfs: $uuid (no se usa para resume en LUKS)"
  elif [[ -n "$uuid" ]]; then pass "UUID de $src → $uuid (el justfile usará resume=UUID=$uuid)"; else warn "sin UUID para $src — usará path directo resume=$src (menos robusto)"
  fi
  if blkid "$src" 2>/dev/null | grep -qi crypto_LUKS || [[ "$src" == /dev/mapper/* ]]; then warn "LUKS detectado en $src — el initramfs debe pedir clave al reanudar (en Fedora Atomic suele estar OK)"; else pass "sin LUKS en el dispositivo de /var"
  fi
else fail "no se pudo resolver SOURCE de /var ni /"; FAIL=1; fi
echo "    rpm-ostree kargs (resume*):"
rpm-ostree kargs 2>&1 | tr ' ' '\n' | grep -E "^resume" | sed 's/^/      /' || echo "      (sin resume= en kargs — el justfile lo añadirá)"
echo "    /proc/cmdline resume*:"
tr ' ' '\n' < /proc/cmdline 2>&1 | grep -E "^resume" | sed 's/^/      /' || echo "      (sin resume= en este boot — necesitarás reiniciar tras el justfile)"
# resume_offset preview
if [[ -f /var/swapfile ]]; then
  off=$(btrfs inspect-internal map-swapfile -r /var/swapfile 2>/dev/null | head -n1 | awk '{print $NF}' || echo "")
  [[ -z "$off" ]] && off=$(sudo filefrag -v /var/swapfile 2>/dev/null | awk 'NR==4{print $4}' | tr -d '.' || echo "")
  if [[ -n "$off" && "$off" != "0" ]]; then pass "resume_offset resoluble → $off"; else info "resume_offset no resuelto ahora (systemd ≥254 lo infiere al hibernar, no bloquea)"
  fi
else info "resume_offset no comprobable sin swapfile (el justfile lo intentará tras crearlo)"
fi
echo

echo "→ 4/6 Logind — preview"
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch 2>&1 | sed 's/^/    actual: /' || info "sin bus logind"
if [[ -f /etc/systemd/logind.conf.d/lid.conf ]]; then echo "    lid.conf actual:"; sed 's/^/      /' /etc/systemd/logind.conf.d/lid.conf | head -n 20; else info "lid.conf aún no existe"
fi
echo "    Lo que hará setup-hibernate:"
echo "      HandleLidSwitch=suspend-then-hibernate"
echo "      HandleLidSwitchExternalPower=suspend-then-hibernate"
echo "      HandleLidSwitchDocked=ignore"
echo "      HibernateDelaySec=1800  (30 min → hibernación)"
echo "      + desactiva lid-lock.service"
echo

echo "→ 5/6 Capacidades del sistema (¿puede hibernar?)"
# systemd puede hibernar si hay swap y resume configurado; comprobamos sin hibernar de verdad
if systemctl hibernate --help >/dev/null 2>&1; then pass "systemctl hibernate disponible"; else warn "systemctl hibernate no disponible"
fi
# No hacemos busctl CanHibernate sin privs; solo informativo
can_hib=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>&1 || echo "?")
echo "    CanHibernate: $can_hib"
info "Prueba real (opcional, cierra sesión y guarda a disco): systemctl hibernate"
info "Tras instalar el modo, prueba con tapa abierta: systemctl hibernate debe guardar y apagar."
echo

echo "→ 6/6 Simulación fstab (sin escribir)"
SWAPFILE="/var/swapfile"
if grep -q "^${SWAPFILE}[[:space:]]" /etc/fstab 2>/dev/null; then pass "fstab ya tiene entrada canónica para $SWAPFILE"; else
  if grep -qF "$SWAPFILE" /etc/fstab 2>/dev/null; then warn "fstab menciona $SWAPFILE con flags distintos — el justfile la limpiará y reescribirá"; else info "fstab sin $SWAPFILE — el justfile añadirá: $SWAPFILE none swap defaults 0 0"
  fi
fi
# Estimación espacio libre
avail=$(df -BG /var 2>&1 | awk 'NR==2{print $4}' || echo "?")
echo "    Espacio libre en /var: $avail (necesitas ~16G libres para el swapfile)"
echo

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}═══ RESULTADO: diagnóstico OK — listo para instalar ═══${NC}"
else
  echo -e "${YELLOW}═══ RESULTADO: con avisos — revisa arriba ═══${NC}"
fi
echo "Para instalar de verdad:"
echo "  ujust setup-hibernate     # crea swap 16G + resume + logind suspend-then-hibernate"
echo "  # luego REINICIA y prueba: systemctl hibernate"
echo "Este script no ha tocado nada (solo lectura)."
