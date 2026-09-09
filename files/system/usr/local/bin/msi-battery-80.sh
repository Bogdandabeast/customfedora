#!/bin/bash
# MSI Modern 15 B7M 7730U - limite 80% via EC 0xEF
# EC: escribe (threshold | 0x80) en 0xEF, lee es (val & 0x7F)
# Requiere ec_sys write_support=Y y /sys/kernel/debug/ec/ec0/io
set -e
EC_IO="/sys/kernel/debug/ec/ec0/io"
if [ ! -w "$EC_IO" ]; then echo "EC no escribible (reboot needed con ec_sys Y)"; exit 1; fi
THRESH=80
VAL=$(( THRESH | 0x80 ))  # 0xD0
echo "Escribiendo EC[0xEF]=0x$(printf "%02X" $VAL) (threshold $THRESH% + BIT7)"
printf "\\x$(printf "%02x" $VAL)" | dd of="$EC_IO" bs=1 seek=239 count=1 conv=notrunc 2>/dev/null
sleep 1
CUR=$(dd if="$EC_IO" bs=1 skip=239 count=1 2>/dev/null | od -An -t u1 | tr -d " ")
CUR_VAL=$(( CUR & 0x7F ))
echo "Verificacion: EC[0xEF]=0x$(printf "%02X" $CUR) -> threshold $CUR_VAL% (esperado $THRESH%)"
if [ "$CUR_VAL" = "$THRESH" ]; then echo "OK: limite 80% activo"; else echo "FALLO: lee $CUR_VAL"; exit 1; fi
if [ -f /sys/class/power_supply/BAT1/charge_control_end_threshold ]; then
  echo 80 > /sys/class/power_supply/BAT1/charge_control_end_threshold 2>/dev/null && echo "msi-ec sync OK"
fi
