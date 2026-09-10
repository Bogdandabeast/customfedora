#!/bin/bash
set -e
# Sin cargador (ADP1=0): ULTRA 6W + extras max vida.
# Enchufado (ADP1=1): ryzen-ac-hook.sh restaura stock — nada que hacer aquí.
/usr/bin/ryzen-profiles battery
# Extra max vida: para dockers (1.5W), BT (0.3W), USB autosuspend
systemctl stop docker.service docker.socket 2>/dev/null || true
podman ps -q 2>/dev/null | xargs -r podman stop 2>/dev/null || true
bluetoothctl power off 2>/dev/null || true
for d in /sys/bus/usb/devices/*/power/control; do echo auto > "$d" 2>/dev/null || true; done
echo 1 > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true
echo 26214 > /sys/class/backlight/amdgpu_bl1/brightness 2>/dev/null || true
for p in /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
  echo 2200000 > "$p" 2>/dev/null || true
done
echo "ULTRA bateria activa: max $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null) PPT $(sensors 2>/dev/null | grep PPT | head -n1)"
