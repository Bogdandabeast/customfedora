# Ryzen 7730U (Modern 15 B7M) tuning — solo AHORRO DE BATERÍA.
# Un único perfil (ULTRA 6W) que se aplica solo al desconectar el cargador (udev).
# Al enchufar: se restaura stock MSI y PPD/GPU mandan. Sin perfiles perf/silent/stock.
# Reinstalaste? → `just ryzen-setup` lo hace todo (msi-ec no needed, usa ec_sys).

# Setup inicial: compila ryzen_smu si kargs no esta, programa EC 80% + autocambio
ryzen-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Ryzen 7730U setup (MS-15HK B7M, Cezanne)"
    if [ "$(cat /sys/class/dmi/id/product_name 2>&1 | tr -d '\n')" != "Modern 15 B7M" ] ; then
      echo "WARN: esto es para Modern 15 B7M (tienes $(cat /sys/class/dmi/id/product_name 2>&1)), sigo igual..."
    fi
    echo "-> kargs ec_sys.write_support=Y (persistente ostree)"
    kargs_staged=0
    if ! rpm-ostree kargs | grep -q ec_sys.write_support; then
      sudo rpm-ostree kargs --append=ec_sys.write_support=Y
      kargs_staged=1
      echo "   staged, reinicia despues de este just para activar EC 80%"
    else
      echo "   ya staged"
    fi
    echo "-> modprobe.d ec_sys.conf"
    echo "options ec_sys write_support=Y" | sudo tee /etc/modprobe.d/ec_sys.conf >/dev/null
    echo "-> habilitar servicios ryzen (smu_loader, profiles-boot, ac, msi-battery-80, udev)"
    sudo systemctl daemon-reload
    sudo systemctl enable ryzen_smu_loader.service ryzen-profiles-boot.service ryzen-ac.service msi-battery-80.service
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=power_supply
    echo "-> aplicar perfil segun ADP1 actual"
    if [ "$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 1)" = "1" ]; then
      echo "   ADP1=1 enchufado -> restaura stock"
      sudo /usr/bin/ryzen-ac-hook.sh
    else
      echo "   ADP1=0 bateria -> ultra 6W"
      sudo /usr/bin/ryzen-battery-hook.sh
    fi
    echo "-> intentar EC 80% ya (falla si no has reiniciado con ec_sys Y, normal)"
    sudo /usr/bin/msi-battery-80.sh 2>&1 | tail -n 10 || echo "   EC 80% se activara al proximo reboot"
    echo ""
    if [ "$kargs_staged" = "1" ]; then
      echo "OK. Reinicia con \`systemctl reboot\` para EC 80%. Luego: just ryzen-status"
    else
      echo "OK. \`just ryzen-status\` para ver."
    fi
    echo "Uso diario: quitas cargador => ULTRA 6W (auto via udev), pones cargador => stock (PPD manda)."

# Estado rapido: ADP1, SMU PPT, EPP, boost, EC 80%, bateria, GPU
ryzen-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "== ADP1/CPU =="
    echo -n " ADP1 online: "; cat /sys/class/power_supply/ADP1/online 2>&1 | head
    echo -n " scaling_max: "; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>&1 | head
    echo -n " cpuinfo_max: "; cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>&1 | head
    echo -n " boost: "; cat /sys/devices/system/cpu/cpufreq/policy0/boost 2>&1 | head -c 3; echo
    echo -n " EPP: "; cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>&1 | head
    echo -n " gov: "; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>&1 | head
    echo -n " ppd: "; powerprofilesctl get 2>&1 | head
    echo "== sensors =="
    sensors 2>&1 | grep -E "Tctl|edge|PPT" | head -n 5
    echo "== GPU =="
    DRM=$(ls /sys/class/drm/card*/device/pp_power_profile_mode 2>/dev/null | head -n1 | xargs -r dirname 2>/dev/null || echo "")
    if [ -n "$DRM" ]; then
      echo -n " level: "; cat "$DRM/power_dpm_force_performance_level" 2>&1 | head
      echo " sclk:"; cat "$DRM/pp_dpm_sclk" 2>&1 | head -n 5
      echo " profile:"; cat "$DRM/pp_power_profile_mode" 2>&1 | grep -E "^\s*(2 |0 |1 |3 |4 )" | head -n 4 || cat "$DRM/pp_power_profile_mode" 2>&1 | head -n 20
      echo -n " od clk: "; cat "$DRM/pp_od_clk_voltage" 2>&1 | head -n 5 | tr '\n' ' '; echo
    else
      echo " no drm amdgpu"
    fi
    echo "== EC 80% =="
    echo -n " ec_sys write_support: "; cat /sys/module/ec_sys/parameters/write_support 2>&1 | head
    printf " EC[0xEF]: 0x"; sudo dd if=/sys/kernel/debug/ec/ec0/io bs=1 skip=239 count=1 2>/dev/null | od -An -t x1 | tr -d " \n"; echo " (d0=80% OK, 80=100% sin limite)"
    echo -n " BAT capacity/status: "; cat /sys/class/power_supply/BAT1/capacity 2>&1 | head -n1 | tr -d '\n'; echo -n " / "; cat /sys/class/power_supply/BAT1/status 2>&1 | head -n1
    echo "== ryzen_smu =="
    ls /sys/kernel/ryzen_smu_drv/smu_args 2>&1 | head -c 40; echo
    echo -n " services: "; systemctl is-enabled ryzen_smu_loader.service ryzen-profiles-boot.service ryzen-ac.service msi-battery-80.service 2>&1 | tr '\n' ' '; echo
    sensors 2>&1 | grep -E "Tctl" | head -n 2

# Aplica el perfil ULTRA de batería a mano (prueba sin esperar a desconectar)
ryzen-battery:
    sudo /usr/bin/ryzen-battery-hook.sh

# Restaura stock MSI a mano (lo que pasa auto al enchufar el cargador)
ryzen-ac:
    sudo /usr/bin/ryzen-ac-hook.sh

# Fuerza EC 80% o 100% (viaje: just ryzen-charge-limit 100)
ryzen-charge-limit limit="80":
    #!/usr/bin/env bash
    set -euo pipefail
    LIM="{{limit}}"
    if [ "$LIM" != "80" ] && [ "$LIM" != "100" ]; then echo "Uso: just ryzen-charge-limit 80|100"; exit 1; fi
    if [ "$LIM" = "100" ]; then
      echo "-> quitando limite (EC 0x80 = 100%)"
      sudo bash -c 'printf "\x80" | dd of=/sys/kernel/debug/ec/ec0/io bs=1 seek=239 count=1 conv=notrunc 2>/dev/null'
      echo "EC 100% (carga completa) hasta proximo msi-battery-80.service (reboot)"
    else
      echo "-> poniendo 80%"
      sudo /usr/bin/msi-battery-80.sh
    fi
    printf "EC[0xEF]=0x"; sudo dd if=/sys/kernel/debug/ec/ec0/io bs=1 skip=239 count=1 2>/dev/null | od -An -t x1 | tr -d "\n"; echo

# Desactiva el autocambio udev (vuelve a stock MSI y PPD manda siempre)
ryzen-disable:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Desactivando ryzen tuning..."
    sudo systemctl disable --now ryzen-battery.service ryzen-ac.service ryzen-profiles-boot.service msi-battery-80.service 2>&1 | head -n 20 || true
    sudo rm -f /etc/udev/rules.d/99-ryzen-profiles.rules
    sudo udevadm control --reload 2>&1 | head
    sudo /usr/bin/ryzen-profiles restore
    echo "-> quita kargs ec_sys si quieres (opcional): just ryzen-kargs-remove"
    echo "Desactivado. PPD vuelve a mandar siempre."

ryzen-kargs-remove:
    sudo rpm-ostree kargs --delete=ec_sys.write_support=Y 2>&1 | tail -n 5 || true
    sudo rm -f /etc/modprobe.d/ec_sys.conf
    echo "Quita ec_sys Y. Reboot para 100% sin limite EC."

# Log udev + systemd de los cambios auto al enchufar/desenchufar
ryzen-log:
    journalctl -u ryzen-battery.service -u ryzen-ac.service -u ryzen_smu_loader.service -u msi-battery-80.service --since "2 hours ago" 2>&1 | tail -n 80
