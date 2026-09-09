#!/bin/bash
set -e
MODE="${1:-on}"
FLAG="/var/lib/ryzen-silent.active"
if [ "$MODE" = "on" ]; then
  ADP1=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 1)
  if [ "$ADP1" != "1" ]; then
    echo "ERROR: silent-gaming solo con cargador (ADP1=0 bateria = no juegas, tareas basicas)."
    echo " Enchufa el cargador y repite: just ryzen-silent-gaming on"
    echo " Te dejo en ULTRA 6W max bateria:"
    /usr/local/bin/ryzen-profiles battery 2>&1 | tail -n 10 || true
    exit 1
  fi
  mkdir -p /var/lib
  date -Iseconds > "$FLAG"
  echo "Flag silent-gaming creado: $FLAG (solo enchufado)"
  /usr/local/bin/ryzen-profiles silent-gaming
  echo ""
  echo "SILENT GAMING ACTIVO: 9/10/12W T70 + 2.9GHz + GPU 1100MHz + EPP balance_power (solo con cargador)"
  echo "- Enchufado: udev NO pisara (sigue en silent hasta que quites cargador o hagas off)"
  echo "- Quitas cargador ADP1=0 -> battery hook BORRA flag y pasa a ULTRA 6W 2.2GHz (+120min, como quieres)"
  echo "- Apaga manual: just ryzen-silent-gaming off -> FRIO 15W"
  echo "- Ventilador: 0rpm reposo / 1200rpm jugando 60-70C"
else
  rm -f "$FLAG"
  echo "Flag silent-gaming borrado"
  ADP1=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 1)
  if [ "$ADP1" = "1" ]; then
    echo "ADP1=1 -> volviendo a FRIO 15W"
    /usr/local/bin/ryzen-perf-hook.sh 2>&1 || /usr/local/bin/ryzen-profiles perf
  else
    echo "ADP1=0 -> volviendo a ULTRA 6W"
    /usr/local/bin/ryzen-battery-hook.sh 2>&1 || /usr/local/bin/ryzen-profiles battery
  fi
  echo "Auto ADP1 restaurado"
fi
