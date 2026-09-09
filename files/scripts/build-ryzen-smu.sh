#!/usr/bin/env bash
# BlueBuild script: compila ryzen_smu para el kernel de la imagen (CachyOS o stock Fedora)
# Se ejecuta dentro del build del container, no en el host.
# Resultado: /usr/lib/modules/<kver>/extra/ryzen_smu.ko + fuentes en /usr/local/src/ryzen_smu para hotfix recompila
set -Eeuo pipefail
echo "==> build-ryzen-smu.sh: ryzen_smu para $(uname -r)"

KVER=$(ls -1 /usr/lib/modules | head -n1)
echo "KVER en imagen: ${KVER}"
if [ ! -d "/usr/src/kernels/${KVER}" ] && [ ! -d "/usr/lib/modules/${KVER}/build" ]; then
  echo "WARN: sin kernel headers para ${KVER}, intenta instalar kernel-cachyos-devel-matched o kernel-devel"
fi
BUILD_DIR=$(realpath /usr/lib/modules/${KVER}/build 2>/dev/null || echo "/usr/src/kernels/${KVER}")

dnf_opt=""
if rpm -q dnf5 >/dev/null 2>&1; then dnf_opt="dnf5"; else dnf_opt="dnf"; fi
# En build ya viene git/make/gcc, si no los pone system
if ! command -v git >/dev/null 2>&1; then ${dnf_opt} -y install git 2>&1 | tail -n 5; fi
if ! command -v make >/dev/null 2>&1; then ${dnf_opt} -y install make 2>&1 | tail -n 5; fi
if ! command -v gcc >/dev/null 2>&1; then ${dnf_opt} -y install gcc 2>&1 | tail -n 5; fi

TMP=/tmp/ryzen_smu_build
rm -rf "${TMP}"
git clone --depth 1 https://github.com/amkillam/ryzen_smu "${TMP}" 2>&1 | tail -n 5
echo "Clonado ryzen_smu 0.1.7 en ${TMP}"

make -C "${BUILD_DIR}" M="${TMP}" modules -j"$(nproc)" 2>&1 | tail -n 20
echo "Compilado OK"

# Instala ko en extra para que no pise kernel stock
mkdir -p /usr/lib/modules/${KVER}/extra
cp -v "${TMP}/ryzen_smu.ko" /usr/lib/modules/${KVER}/extra/
# Fuentes para loader hotfix si el OSTree hace unlock y cambia kver
mkdir -p /usr/local/src/ryzen_smu
cp -v "${TMP}/Makefile" "${TMP}/dkms.conf" "${TMP}"/*.c "${TMP}"/*.h /usr/local/src/ryzen_smu/ 2>&1 | head -n 20
cp -rv "${TMP}/lib" /usr/local/src/ryzen_smu/ 2>&1 | head -n 20 || true

depmod -a "${KVER}" 2>&1 | head -n 20
echo "depmod OK"
modinfo /usr/lib/modules/${KVER}/extra/ryzen_smu.ko 2>&1 | head -n 10

# udev extra para ryzen_smu permisos (PPD corre como root, pero just lo usa user)
cat > /usr/lib/udev/rules.d/90-ryzen-smu.rules << 'RULE'
KERNEL=="ryzen_smu*", MODE="0660", GROUP="wheel"
SUBSYSTEM=="power_supply", KERNEL=="ADP1", TAG+="systemd"
RULE
echo "udev 90-ryzen-smu.rules creada"

echo "==> ryzen_smu listo: /usr/lib/modules/${KVER}/extra/ryzen_smu.ko"
ls -lh /usr/lib/modules/${KVER}/extra/ryzen_smu.ko
