#!/bin/bash
set -e
# Fedora Atomic + CachyOS : /lib/modules se borra en cada ostree update
# Este loader asegura ryzen_smu.ko exista, si no lo recompila en el host (hotfix)
# En la imagen BlueBuild ya viene compilado en /usr/lib/modules/... pero por hotfix se mantiene aqui tambien
KVER=$(uname -r)
KO="/lib/modules/${KVER}/extra/ryzen_smu.ko"
if [ -f /sys/kernel/ryzen_smu_drv/smu_args ]; then
  echo "ryzen_smu ya cargado"
  exit 0
fi
if [ -f "$KO" ]; then
  echo "Cargando ryzen_smu desde $KO"
  modprobe ryzen_smu 2>/dev/null || insmod "$KO" 2>/dev/null || true
  sleep 1
  [ -f /sys/kernel/ryzen_smu_drv/smu_args ] && echo "ryzen_smu OK" && exit 0
fi
# Fallback: compila en hotfix (requiere kernel-cachyos-devel-matched en imagen)
if [ -d "/usr/src/kernels/${KVER}" ] && [ -d /usr/local/src/ryzen_smu ]; then
  echo "Recompilando ryzen_smu para ${KVER}"
  cd /usr/local/src/ryzen_smu
  make -C /usr/src/kernels/${KVER} M=$(pwd) modules >/dev/null 2>&1
  mkdir -p /lib/modules/${KVER}/extra
  cp -f ryzen_smu.ko /lib/modules/${KVER}/extra/
  depmod -a "${KVER}"
  modprobe ryzen_smu 2>/dev/null || insmod ryzen_smu.ko 2>/dev/null || true
  sleep 1
  [ -f /sys/kernel/ryzen_smu_drv/smu_args ] && echo "ryzen_smu recompilado OK" && exit 0
  echo "ryzen_smu FAIL recompilado"
else
  echo "ryzen_smu KO no encontrado y sin fuentes (instala kernel-cachyos-devel-matched)"
fi
modprobe msr 2>/dev/null || true
ls /sys/kernel/ryzen_smu_drv/smu_args >/dev/null 2>&1 && echo "ryzen_smu OK" || echo "ryzen_smu FAIL - PPT seguirá stock 25W pero kernel EPP seguirá funcionando"
exit 0
