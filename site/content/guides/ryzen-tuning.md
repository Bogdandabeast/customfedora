---
title: "Ryzen 7730U tuning (Modern 15 B7M)"
weight: 55
description: "Perfil único de batería PPT 6W + GPU powersaving + LAVD + límite 80% — Modern 15 B7M Cezanne (7730U + Vega 8). Udev auto al desconectar, stock al enchufar, y orden de reboot tras update."
---

`Modern 15 B7M` (`MS-15HK`) con `7730U` (Cezanne + Vega 8) lleva tuning qua via `ryzen_smu` (PPT), `amdgpu` (GPU) y `EC 0xEF` (límite 80%). Todo viene en la imagen `niri-cachyos` y se activa con `just`.

## Quick path

```bash
# 1. Rebase ya incluye ryzen_smu.ko + scripts + justfile
rpm-ostree rebase ostree-unverified-registry:ghcr.io/bogdandabeast/niri-cachyos:latest
systemctl reboot

# 2. Activa 80% + autocambio (1 vez tras reinstalar)
just ryzen-setup
systemctl reboot

# 3. Verifica
just ryzen-status
# Esperado: ec_sys Y / EC[0xEF]=0xd0 (d0=80% OK) / ADP1 online / max 2200000 batería o 4547946 enchufado / ryzen_smu OK

# Día a día (auto vía udev ADP1):
# quitas cargador -> ULTRA 6W 2.2GHz auto (+120min, max ahorro)
# pones cargador  -> stock MSI restaurado (PPD/GPU mandan, sin caps)

just ryzen-status             # verifica
just ryzen-battery            # aplica ULTRA a mano (opcional)
just ryzen-ac                 # restaura stock a mano (lo que hace udev al enchufar)
```

## Details

### 1. Qué perfiles hay y cuál usar

| Perfil | Cuándo | SMU PPT STAPM/SLOW/FAST | Tctl | CPU `scaling_max` + EPP | GPU | Brillo | Ruido / Autonomía |
|--------|--------|-------------------------|------|--------------------------|-----|--------|-------------------|
| **`ULTRA battery` `ADP1=0`** `ryzen-battery` | Sin cargador — tareas básicas (navegar/VSCode/LibreOffice) | `6W / 8W / 12W` | `80°C` | `2.2GHz cap` `EPP power` `powersave` `boost 1` + `USB autosuspend + BT off + docker stop` | `auto` `POWER_SAVING` | `40% 26214` | `0rpm` reposo — `27Wh real 72% salud -> 7.5h` vs `5.5h stock` |
| **`stock MSI` `ADP1=1`** `ryzen-ac` (auto al enchufar) | Con cargador — sin caps propios, PPD manda | `25W / 25W / 30W` | `100°C` | `4.5GHz` (sin cap propio) | `auto 2000MHz` `BOOTUP_DEFAULT` | `80% 52428` | comportamiento de fábrica |

TDP real: `P = C·V²·f`. Pasar de `2.2GHz 0.9V 6W` a `4.5GHz 1.35V 30W` es `3.4×` potencia por `2×` frecuencia — por eso `2.2GHz` da `75% perf` con `60% menos consumo`.

### 2. Autocambio (udev ADP1)

```text
ADP1=0 sin cargador  -> udev 99-ryzen-profiles.rules -> ryzen-battery.service -> ryzen-battery-hook.sh -> ULTRA 6W
ADP1=1 con cargador  -> ryzen-ac.service -> ryzen-ac-hook.sh -> stock MSI restaurado (PPD manda)
Arrancada            -> ryzen-profiles-boot.service (After ryzen_smu_loader) mira ADP1: ULTRA o stock
Resume               -> ryzen-resume.service re-aplica lo mismo + EC 80% (SMU es volátil)
```

Wifi `power_save` se deja siempre `off` (no se toca) para evitar cortes en `mt7921` + `InternetCMBiblio`.

| Fichero en `files/system` | En imagen `destination: /` |
|---|---|
| `usr/bin/ryzen-profiles` | `ryzen-profiles battery|restore|status` — kernel + SMU + GPU |
| `usr/bin/ryzen-battery-hook.sh` | `ULTRA 6W 2.2GHz` + `bluetooth off + docker stop + USB autosuspend + brillo 40%` |
| `usr/bin/ryzen-ac-hook.sh` | restaura stock MSI (sin caps) al enchufar |
| `usr/local/bin/msi-battery-80.sh` | `EC[0xEF]=0xD0 (80% | BIT7)` + `charge_control_end_threshold` |
| `usr/libexec/ryzen_smu_loader.sh` | hotfix recompila `ryzen_smu.ko` si cambia `KVER` |
| `etc/modprobe.d/ec_sys.conf` | `options ec_sys write_support=Y` |
| `etc/udev/rules.d/99-ryzen-profiles.rules` | `ADP1 0->battery 1->ac` |
| `usr/lib/systemd/system/ryzen_*.service` + `msi-battery-80.service` | enabled |
| `files/justfiles/ryzen-tuning.just` | `just` de imagen (importado en `justfile` raíz) |
| `files/scripts/build-ryzen-smu.sh` | build-time `ryzen_smu` `0.1.7` + `kernel-cachyos-devel-matched` |

Enabled solo en `recipes/recipe.niri-cachyos.yml` (esta máquina):
`ryzen_smu_loader.service` + `ryzen-profiles-boot.service` + `ryzen-resume.service` + `msi-battery-80.service` (`battery/ac` son `Type=oneshot` triggered por udev, no enabled). `recipe.niri.yml` no lleva tuning — imagen genérica para otras máquinas.

SMU=`/sys/kernel/ryzen_smu_drv/smu_args` es **volátil** (se pierde al `suspend`/`hibernate` según `logind lid`). Además de `boot` y `udev ADP1`, `ryzen-resume.service` (`WantedBy suspend/hibernate/hybrid-sleep/suspend-then-hibernate`) re-aplica `ADP1` + `EC 80%` al despertar, así `just setup-suspend` (suspend-to-RAM al cerrar tapa)/`setup-lid-lock` no pierden `PPT 6W` ni el límite 80%.

### 3. Límite 80% — cómo verificar y qué pasa tras `upgrade`

EC `0xEF` en `MS-15HK`: `0x80 = 100% sin límite`, `0xD0 = 80% (80 | 0x80)`. Requiere `ec_sys.write_support=Y`.

```bash
just ryzen-status
# ec_sys write_support: Y
# EC[0xEF]: 0xd0 (d0=80% OK, 80=100% sin limite)
# msi-battery-80.service enabled
```

Persistencia (`Fedora Atomic`) — **una sola vez**, no cada kernel:

* `rpm-ostree kargs --append=ec_sys.write_support=Y` -> `Staging` -> **persiste tras `upgrade`/`update` y tras cada cambio de `KVER`** (`ostree admin kargs` heredados, en `/proc/cmdline` y `/boot/loader/entries`). No toques hasta `just ryzen-kargs-remove`.
* `/etc/modprobe.d/ec_sys.conf` + `msi-battery-80.service` + `ryzen_*.service` + `99-ryzen-profiles.rules` -> `/etc` es writable, **sobrevive** a `ostree` (no en `/usr`).
* `/usr/local -> /var/usrlocal` + `build-ryzen-smu.sh` en imagen `niri-cachyos` -> `ryzen_smu.ko` va **baked** en `/usr/lib/modules/<kver>/extra` para ese `kver` (no hace falta `hotfix`). Si un `upgrade` trae `KVER` nuevo, la **nueva imagen** ya lleva el `.ko` para ese `kver`; `ryzen_smu_loader` solo es fallback recompila `hotfix` si `ostree admin unlock` o imagen sin `ko`.

En corto: `just ryzen-setup` **una vez** tras reinstalar; los sucesivos `rpm-ostree upgrade` + `reboot` heredan todo solo (kargs + /etc + .ko baked). Ver [Debug](/guides/debug-build/) si `ryzen_smu` faltó tras `KVER` raro.

**Orden correcto tras reinstalar o si nunca reiniciaste desde `just ryzen-setup`:**

```bash
# 1. Programa
just ryzen-setup          # stage kargs + enable services + trigger udev
systemctl reboot          # BOOT 1: ec_sys=Y -> msi-battery-80 escribe 0xD0 -> 80% activo

# 2. Verifica 80% antes de upgradear
just ryzen-status         # EC 0xd0

# 3. Luego upgrade
rpm-ostree upgrade        # o AutomaticUpdates: stage
systemctl reboot          # BOOT 2: hereda kargs + re-escribe 0xD0 + recompila ryzen_smu si KVER cambió
```

Si haces `upgrade + reboot` sin ese 1er `reboot`, el `EC` sigue `0x80` (100%) hasta el siguiente `BOOT 1` — pierdes ciclos. Ver sección [Debug a build](/guides/debug-build/) si `ryzen_smu` falló tras cambio de kernel.

Para viaje largo (100% la noche antes):
```bash
just ryzen-charge-limit 100  # EC 0x80
# al volver
just ryzen-charge-limit 80   # o deja que msi-battery-80 lo ponga al reboot
```

### 4. `scx_lavd` vs EPP — influencia

`files/system/etc/default/scx`: `SCX_SCHEDULER=scx_lavd` `SCX_FLAGS=--autopower` (sigue a `PPD`: `power-saver -> powersave`, `balanced -> balanced`, `performance -> performance`). `scx.service` tiene `ConditionPathIsDirectory=/sys/kernel/sched_ext`.

LAVD solo cambia **compactación de cores** (no PPT):

* `ULTRA 6W` + `LAVD powersave`: `+0.3-0.8W` ahorro extra vs `EEVDF` (~15min más).
* Enchufado (stock) + `LAVD balanced`: ~igual.

Si LAVD falla (`scx_lavd: BTF malformed scx kfunc... pahole < 1.26` en `journalctl -u scx`), todos los `scx_*` fallan igual — es el `kernel-cachyos 7.2.3` compilado con `pahole <1.26` (commit `9edd04c4189e`). Solo CPUs scheduling, no PPT. Se arregla solo con `kernel 7.2.4+` (`pahole >=1.26`). No rompe los perfiles Ryzen — el `90%` es `PPT+Tctl+GPU`.

```bash
systemctl status scx.service   # failed exit 1 BTF -> restart loop -> no afecta ryzen
cat /sys/kernel/sched_ext/state  # disabled hoy -> EEVDF default (cuando LAVD vuelva: enabled)
journalctl -u scx.service --no-pager -n 30  # ver error BTF
# opcional silenciar loop: sudo systemctl disable --now scx.service
```

`PPD` `power-saver` clampa `scaling_max` a `2.0GHz`. El hook de batería ya usa `EPP` `power` + `powersave` y pisa `max` a `2.2GHz` — `PPD` no puede con `PPT`.

### 5. Drenaje en suspend-to-RAM (hook `ryzen-power-save`)

`/usr/lib/systemd/system-sleep/ryzen-power-save` (en imagen `niri-cachyos`) corta consumidores en cada `pre` de `systemd-sleep`:

* BT off (vuelve solo si estaba on **y hay cargador**; en batería sigue off — ahorro).
* USB autosuspend forzado + WoWLAN off (`mt7921`) + backlight teclado off (restaura al despertar).
* Opt-ins: `ujust suspend-deep on` (`mem_sleep=deep`/S3, `~0.3-0.8W` menos, **probar despertar**; `off` vuelve a `s2idle`), `ujust suspend-usbwake on` (sin wake por USB, `~0.1-0.3W`).
* Mide el drenaje real sin cargador: `ujust suspend-drain` (referencia: `s2idle` stock `1.5-2.5W` → con hook `0.8-1.5W`; `deep` `0.5-1.0W`).

## Checklist

- [ ] `just ryzen-setup` + `systemctl reboot` + `just ryzen-status` muestra `d0 + Y + ryzen_smu OK`.
- [ ] `ADP1=0` -> `max 2200000 EPP power GPU POWER_SAVING` (`just ryzen-battery` o quitar cargador); `ADP1=1` -> stock restaurado, `max 4547946`, sin caps propios (`just ryzen-ac` o enchufar).
- [ ] `systemctl is-enabled ryzen_smu_loader ryzen-profiles-boot msi-battery-80` -> `enabled`.
- [ ] Si `scx.service` falla `BTF pahole <1.26`, es kernel 7.2.3 — ignóralo, no toca PPT. Vuelve a `systemctl enable --now scx.service` tras `kernel 7.2.4`.
- [ ] Tras `rpm-ostree upgrade` que cambie `KVER`, verifica `ls /sys/kernel/ryzen_smu_drv/smu_args` (loader recompiló).

## Next step

Perfiles finos en [Add a systemd service](/guides/add-systemd-service/), `scx` en [CachyOS kernel](/guides/kernel-cachyos/), si algo falla → [Debug a build](/guides/debug-build/) + `just ryzen-log`.
