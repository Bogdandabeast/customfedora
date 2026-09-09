#!/bin/bash
set -e
# Enchufado: si estabas en silent, lo respeta (no pisa) -> sigues jugando silencioso
# Si no estabas en silent, aplica FRIO 15W
if [ -f /var/lib/ryzen-silent.active ]; then
  echo "silent-gaming ACTIVO ($(cat /var/lib/ryzen-silent.active 2>/dev/null)) -> perf hook NO pisa (jugando silencioso 9W)"
  echo " desactiva con: just ryzen-silent-gaming off -> FRIO 15W"
  exit 0
fi
/usr/bin/ryzen-profiles perf
# Enchufado frio: no restaura docker/BT dock (ahorro ruido), brillo 80%
echo 52428 > /sys/class/backlight/amdgpu_bl1/brightness 2>/dev/null || true
echo "EQUILIBRADO FRIO activo: max $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null) PPT $(sensors 2>/dev/null | grep PPT | head -n1)"
