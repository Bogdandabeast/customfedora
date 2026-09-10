#!/bin/bash
set -e
# Con cargador (ADP1=1): sin perfil propio — restaura stock MSI (25W, sin caps).
# Así PPD/GPU mandan enchufado y la batería solo se optimiza al desconectar.
/usr/bin/ryzen-profiles restore
echo 52428 > /sys/class/backlight/amdgpu_bl1/brightness 2>/dev/null || true
echo "Stock restaurado (enchufado): max $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null) PPT $(sensors 2>/dev/null | grep PPT | head -n1)"
