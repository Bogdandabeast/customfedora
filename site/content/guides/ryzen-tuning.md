---
title: "Ryzen 7730U tuning (Modern 15 B7M)"
weight: 55
description: "Perfiles PPT 6W/15W/9W + GPU + LAVD + límite 80% — Modern 15 B7M Cezanne (7730U + Vega 8). Udev auto, silent-gaming, y orden de reboot tras update."
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
# quitas cargador -> ULTRA 6W 2.2GHz auto (+120min)
# pones cargador  -> FRIO 15W 4.5GHz auto (fresco, 95% perf)
# enchufado + juego noche -> silent 9W 2.9GHz GPU 1100MHz (0-1200rpm silencioso)

just ryzen-silent-gaming on   # solo con cargador, bloquea auto hasta quitar cargador
just ryzen-silent-gaming off  # -> FRIO 15W (o si quitas cargador -> ULTRA 6W auto)
just ryzen-status             # verifica
```

## Details

### 1. Qué perfiles hay y cuál usar

| Perfil | Cuándo | SMU PPT STAPM/SLOW/FAST | Tctl | CPU `scaling_max` + EPP | GPU | Brillo | Ruido / Autonomía |
|--------|--------|-------------------------|------|--------------------------|-----|--------|-------------------|
| **`ULTRA battery` `ADP1=0`** `ryzen-battery` | Sin cargador — tareas básicas (navegar/VSCode/LibreOffice) | `6W / 8W / 12W` | `80°C` | `2.2GHz cap` `EPP power` `powersave` `boost 1` + `USB autosuspend + BT off + docker stop` | `auto` `POWER_SAVING` | `40% 26214` | `0rpm` reposo — `27Wh real 72% salud -> 7.5h` vs `5.5h stock` |
| **`FRIO enchufado` `ADP1=1`** `ryzen-perf` | Enchufado día a día (no compilas) — silencioso y fresco | `15W / 15W / 18W` | `85°C` | `4.5GHz` `EPP balance_performance` `powersave` `boost 1` | `auto 2000MHz` `BOOTUP_DEFAULT` | `80% 52428` | `~1500rpm` `82°C` vs `3200rpm 92°C stock` — `0-3% perf` |
| **`SILENT-GAMING` `ADP1=1 only`** `ryzen-silent-gaming on` | Solo enchufado + juego noche — no enciende turbina | `9W / 10W / 12W` | `70°C` | `2.9GHz cap` `EPP balance_power` `powersave` `boost 1` | `manual 1100MHz cap` `POWER_SAVING` | `70% 45874` | `0rpm` reposo `2D 45fps` / `1200rpm` `3D light 28-32fps ~75% stock 60-70°C` |
| **`STOCK MSI`** `ryzen-profiles stock` | Revertir todo | `25W / 25W / 30W` | `100°C` | `4.5GHz` | `auto 2000MHz` | `100% 65535` | `3200rpm 92°C` |

TDP real: `P = C·V²·f`. Pasar de `2.2GHz 0.9V 6W` a `4.5GHz 1.35V 30W` es `3.4×` potencia por `2×` frecuencia — por eso `2.2GHz` da `75% perf` con `60% menos consumo`.

`SILENT` a `1100MHz` es el codo de eficiencia Vega 8: `75% FPS` con `40% consumo GPU`. Subir a `1600MHz` da solo `+3fps` por `+3W` y `+8°C` y rompe el `9W T70` silencioso.

{{< callout type="warning" >}}
`0rpm jugando 3D AAA es imposible` en `Modern 15` (`18W en 143mm² sin aire = 100°C PROCHOT en 45s -> throttling a 400MHz = 5fps`). `SILENT 9W T70` es lo más silencioso jugable sin throttling.
{{< /callout >}}

### 2. Autocambio y `silent-gaming` (solo enchufado)

```text
ADP1=0 sin cargador  -> udev 99-ryzen-profiles.rules -> ryzen-battery.service -> ryzen-battery-hook.sh -> ULTRA 6W
  (si estabas en silent -> borra /var/lib/ryzen-silent.active y pasa a ULTRA: no juegas sin cargador)
ADP1=1 con cargador  -> ryzen-perf.service -> ryzen-perf-hook.sh -> FRIO 15W
  (si estabas en silent -> respeta flag, no pisa: sigues en 9W hasta quitar cargador o hacer off)
Arrancada            -> ryzen-profiles-boot.service (After ryzen_smu_loader) mira ADP1 y silent flag
  - ADP1=1 + flag -> silent, ADP1=0 + flag -> borra flag -> ULTRA, sino FRIO/ULTRA según ADP1
Silent manual        -> /usr/bin/ryzen-silent-gaming-hook.sh on|off
  - on: solo si ADP1=1, crea /var/lib/ryzen-silent.active (date -Iseconds) y aplica silent-gaming
  - off: borra flag y restaura el que toca por ADP1
  - battery hook siempre gana en ADP1=0 aunque haya flag
```

Wifi `power_save` se deja siempre `off` (no se toca) para evitar cortes en `mt7921` + `InternetCMBiblio`.

| Fichero en `files/system` | En imagen `destination: /` |
|---|---|
| `usr/bin/ryzen-profiles` | `ryzen-profiles perf|battery|silent-gaming|stock|status` — kernel + SMU + GPU |
| `usr/bin/ryzen-battery-hook.sh` | `ULTRA 6W 2.2GHz` + `bluetooth off + docker stop + USB autosuspend + brillo 40%` |
| `usr/bin/ryzen-perf-hook.sh` | `FRIO 15W` + `brillo 80%` |
| `usr/bin/ryzen-silent-gaming-hook.sh` | `on/off` con guarda `ADP1` |
| `usr/local/bin/msi-battery-80.sh` | `EC[0xEF]=0xD0 (80% | BIT7)` + `charge_control_end_threshold` |
| `usr/libexec/ryzen_smu_loader.sh` | hotfix recompila `ryzen_smu.ko` si cambia `KVER` |
| `etc/modprobe.d/ec_sys.conf` | `options ec_sys write_support=Y` |
| `etc/udev/rules.d/99-ryzen-profiles.rules` | `ADP1 0->battery 1->perf` |
| `usr/lib/systemd/system/ryzen_*.service` + `msi-battery-80.service` | enabled |
| `files/justfiles/ryzen-tuning.just` | `just` de imagen (importado en `justfile` raíz) |
| `files/scripts/build-ryzen-smu.sh` | build-time `ryzen_smu` `0.1.7` + `kernel-cachyos-devel-matched` |

Enabled solo en `recipes/recipe.niri-cachyos.yml` (esta máquina):
`ryzen_smu_loader.service` + `ryzen-profiles-boot.service` + `ryzen-resume.service` + `msi-battery-80.service` (`battery/perf/silent` son `Type=oneshot` triggered, no enabled). `recipe.niri.yml` no lleva tuning — imagen genérica para otras máquinas.

SMU=`/sys/kernel/ryzen_smu_drv/smu_args` es **volátil** (se pierde al `suspend`/`hibernate` según `logind lid`). Además de `boot` y `udev ADP1`, `ryzen-resume.service` (`WantedBy suspend/hibernate/hybrid-sleep/suspend-then-hibernate`) re-aplica `ADP1` + `EC 80%` al despertar, así `just setup-hibernate`/`setup-lid-lock` no pierden `PPT 6W`/`FRIO`/`SILENT` ni el límite 80%.

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
* `FRIO 15W` + `LAVD balanced`: ~igual.
* `SILENT 9W` + `LAVD powersave`: `+0.5W`, ventilador arranca 2min más tarde.

Si LAVD falla (`scx_lavd: BTF malformed scx kfunc... pahole < 1.26` en `journalctl -u scx`), todos los `scx_*` fallan igual — es el `kernel-cachyos 7.2.3` compilado con `pahole <1.26` (commit `9edd04c4189e`). Solo CPUs scheduling, no PPT. Se arregla solo con `kernel 7.2.4+` (`pahole >=1.26`). No rompe los perfiles Ryzen — el `90%` es `PPT+Tctl+GPU`.

```bash
systemctl status scx.service   # failed exit 1 BTF -> restart loop -> no afecta ryzen
cat /sys/kernel/sched_ext/state  # disabled hoy -> EEVDF default (cuando LAVD vuelva: enabled)
journalctl -u scx.service --no-pager -n 30  # ver error BTF
# opcional silenciar loop: sudo systemctl disable --now scx.service
```

`PPD` `power-saver` clampa `scaling_max` a `2.0GHz`. Tus hooks ya usan `EPP` `power|balance_power|balance_performance` + `powersave` y pisan `max` a `2.2/2.9/4.5GHz` — `PPD` no puede con `PPT`.

## Checklist

- [ ] `just ryzen-setup` + `systemctl reboot` + `just ryzen-status` muestra `d0 + Y + ryzen_smu OK`.
- [ ] `ADP1=0` -> `max 2200000 EPP power GPU auto` (`just ryzen-battery` o quitar cargador); `ADP1=1` -> `max 4547946 EPP balance_performance GPU auto 2000MHz`.
- [ ] `just ryzen-silent-gaming on` solo con cargador (`ADP1=1`); `ADP1=0` lo rechaza y deja `ULTRA`; quitar cargador borra flag auto.
- [ ] `systemctl is-enabled ryzen_smu_loader ryzen-profiles-boot msi-battery-80` -> `enabled`.
- [ ] Si `scx.service` falla `BTF pahole <1.26`, es kernel 7.2.3 — ignóralo, no toca PPT. Vuelve a `systemctl enable --now scx.service` tras `kernel 7.2.4`.
- [ ] Tras `rpm-ostree upgrade` que cambie `KVER`, verifica `ls /sys/kernel/ryzen_smu_drv/smu_args` (loader recompiló).

## Next step

Perfiles finos en [Add a systemd service](/guides/add-systemd-service/), `scx` en [CachyOS kernel](/guides/kernel-cachyos/), si algo falla → [Debug a build](/guides/debug-build/) + `just ryzen-log`.
