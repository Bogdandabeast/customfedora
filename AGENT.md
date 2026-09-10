# AGENT.md — customfedora

Reglas para Buffy/Codebuff y cualquier agente que toque este repo. Violar cualquiera de estas rompe el build o el boot.

## Fedora Atomic es inmutable (OSTree)

- `/usr` es **read-only** en el host. Todo lo que va a `/` en la imagen viene de `files/system/` con `type: files` (`source: system, destination: /`) — nunca `sudo cp` en el host salvo `hotfix` via `ostree admin unlock --hotfix` (`/var/usrlocal`).
- `/etc` y `/var` son writable y **persisten** tras `rpm-ostree upgrade`/`rebase`. `/usr` no — cada update lo regenera desde la imagen.
- `rpm-ostree kargs` (ej. `ec_sys.write_support=Y`, `resume=`) va en `ostree admin` (`/boot/loader/entries`) y **se hereda** en cada upgrade. No reaplicar cada kernel — `just <setup>` una vez tras reinstalar.

## Nunca uses `files/system/usr/local`

**`/usr/local` no es un directorio en Atomic — es un symlink:**

```
/usr/local -> ../var/usrlocal   (en la imagen y en el host)
```

El `files` module de BlueBuild hace `cp -r /tmp/files/system/* /` y falla si intentas sobreescribir el symlink con un directorio:

```
cp: cannot overwrite non-directory '/usr/local' with directory '/tmp/files/system/usr/local'
  -> Failed 'files' Module (todas las imágenes: niri, niri-cachyos, nvidia)
```

Historial: nos ha roto el build **2 veces** (ryzen tuning). Fix siempre igual:

| Qué hacer | Dónde |
|-----------|-------|
| Binarios/scripts | `files/system/usr/bin/<bin>` (o `usr/libexec/`, `usr/lib/systemd/system/`) — **nunca** `usr/local/bin` |
| Fuentes para hotfix fallback | `files/system/usr/local/src/...` está **prohibido** también. Usa `files/system/usr/src/...` o deja que `build-ryzen-smu.sh` cree `/usr/local/src/ryzen_smu` en build (mkdir funciona, `files` copy no). Ver `build-ryzen-smu.sh` usa `mkdir -p /usr/local/src/ryzen_smu` OK, pero no `files/system/usr/local`. |
| Referencias en services/justfiles | `/usr/bin/<bin>` no `/usr/local/bin/<bin>` — aplica a `ryzen-profiles`, `msi-battery-80.sh`, hooks y `ExecStart=` |

Si ves `files/system/usr/local` en un `git diff`, **recházalo** y mueve a `usr/bin` o `usr/libexec`.

## Recipes y docs gating

- `build.yml` tiene `paths-ignore: ["**.md", "site/**"]` — un push que solo toque docs **no dispara** `bluebuild`. Si tu commit mezcla código + docs, el build sí dispara; si es solo `site/content/*.md`, no hay imagen nueva (esperado).
- Flavours: `niri` es genérica (otras máquinas), `niri-cachyos` es la de esta máquina (ryzen tuning + kernel CachyOS + scx). No dupliques ryzen tuning en `niri` genérica.
- `bluebuild validate` corre en CI antes del build. Antes de push: `bun run validate` + `hugo --minify --source site`.

## Ryzen tuning (Modern 15 B7M B9M, 7730U)

- Perfil único: `ULTRA 6W 2.2GHz T80` solo con batería (`ADP1=0`, udev). Al enchufar (`ADP1=1`) `ryzen-ac-hook` restaura stock MSI (25W, sin caps) y PPD manda — sin perfiles `perf`/`silent-gaming`. Ver `site/content/guides/ryzen-tuning.md`.
- `EC 80%` en `0xEF = 0xD0` via `ec_sys.write_support=Y` (kargs + `/etc/modprobe.d/ec_sys.conf` + `msi-battery-80.service`). Persistente, una vez.
- `ryzen_smu.ko` va **baked** en `/usr/lib/modules/<kver>/extra` vía `build-ryzen-smu.sh` (necesita `kernel-cachyos-devel-matched` en imagen). `ryzen_smu_loader` es fallback hotfix recompila.
- Tras suspend (`setup-suspend` suspend-to-RAM al cerrar tapa), `ryzen-resume.service` re-aplica ADP1 (ULTRA/stock) + `EC 80%` (SMU es volátil).
- Drenaje suspend minimizado por hook `system-sleep/ryzen-power-save` (BT off, USB autosuspend, WoWLAN off, kbd off; BT vuelve solo en AC). Opt-ins: `ujust suspend-deep on` (S3, probar despertar), `ujust suspend-usbwake on`; medir con `ujust suspend-drain`.

## Build debugging

- `gh run list --limit 10` + `gh run view <id> --log-failed` — filtra por `cp:`, `Failed 'files' Module`, `modules.dep is missing`.
- `bluebuild validate ./recipes/*.yml` rápido, `bluebuild build` lento (local podman).
- Si `/usr/local` vuelve a aparecer: ver este archivo.
