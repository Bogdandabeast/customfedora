---
title: "Files overlay and troubleshooting"
weight: 30
description: "How files/system maps to / in the image, plus common build and boot failures and how to diagnose them."
---

`files/system/` is an overlay: everything under it is copied to `/` at build time via `type: files`. Misplaced files silently do nothing.

## Quick path

1. Add a file under `files/system/` mirroring its final path (e.g. `files/system/etc/niri/config.kdl` → `/etc/niri/config.kdl`).
2. Mention it in the `files` module (`source: system, destination: /`) — already present, no new module needed.
3. Build and verify: `bluebuild build ./recipes/recipe.niri.yml` or wait for CI; check `journalctl -u <service>` after rebase.

## Details

| Host path `files/system/...` | In-image path `/...` | What it configures |
|------------------------------|----------------------|--------------------|
| `etc/niri/config.kdl` | `/etc/niri/config.kdl` | Niri compositor — spawns `noctalia`, keybinds, window rules |
| `etc/sddm.conf.d/theme.conf` | `/etc/sddm.conf.d/theme.conf` | SDDM theme (`Current=maldives`) |
| `etc/default/scx` | `/etc/default/scx` | `SCX_SCHEDULER=scx_lavd` + `SCX_FLAGS=--autopower` (CachyOS only) |
| `etc/xdg-desktop-portal/niri-portals.conf` | `/etc/xdg-desktop-portal/...` | Portal routing for Niri |
| `usr/lib/systemd/system/scx.service` | `/usr/lib/systemd/system/scx.service` | `sched_ext` scheduler, `ConditionPathIsDirectory=/sys/kernel/sched_ext` |
| `usr/lib/systemd/system/brew-install-*.service` | `/usr/lib/systemd/system/...` | First-boot Brew setup (fish, cli) |
| `usr/lib/systemd/user/noctalia-lid-mode-sync.service` | `/usr/lib/systemd/user/...` | Noctalia lid-mode sync |
| `usr/bin/noctalia-lid-mode-*.sh` | `/usr/bin/...` | Lid toggle helpers |

Common failures:

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| File not present after rebase | Path under `files/system` wrong (e.g. `etc/niri` vs `usr/etc/niri`) | Match final `/` path exactly; `destination: /` means `files/system/etc` → `/etc` |
| `modules.dep is missing. Did you run depmod?` | Kernel installed without `tsflags=noscripts` + manual `depmod` | See `recipe.niri-cachyos.yml` `containerfile` snippet — `depmod -a $KVER` required |
| `kernel-cachyos` removed after install | `remove: [kernel]` after `install: [kernel-cachyos]` (Provides: kernel) | Remove stock kernel *before* installing CachyOS; order matters |
| `scx.service` always fails (`BTF malformed ... pahole < 1.26`) | `kernel-cachyos 7.2.3` built with `pahole < 1.26` — all `scx_*` fail | Expected until `kernel-cachyos 7.2.4` with `pahole >=1.26`; does not affect Ryzen `PPT` — `EEVDF` runs (`sched_ext state: disabled`). `sudo systemctl disable --now scx.service` to silence loop |
| `ryzen-profiles` `max 2000000` after `power-saver` | `PPD power-saver` clamps `scaling_max` to `2.0GHz` | Re-apply profile: `just ryzen-perf` / `just ryzen-silent-gaming on` / `just ryzen-battery` — they set `2900000`/`2200000`/`4547946` |
| `silent-gaming` stays `9W` on battery | Old `ryzen-battery-hook` respected flag | Fixed: battery hook now deletes flag and goes `ULTRA 6W` on `ADP1=0`; `silent on` refuses without AC |
| `EC[0xEF]=0x80` after `upgrade` | `hotfix` not rebooted with `ec_sys=Y` before upgrade | `just ryzen-setup` + `systemctl reboot` first (writes `0xD0`), then `rpm-ostree upgrade` + `reboot` — see [Ryzen tuning](/guides/ryzen-tuning/) |
| `scx.service` fails only on `niri` | `ConditionPathIsDirectory` not met (non-CachyOS kernel) | Expected on `niri` flavour — `scx` only on `niri-cachyos` |
| `cosign` verify fails | Wrong `cosign.pub` or tag SHA drift | Use `cosign.pub` at repo root; references use derivable markers, no hardcoded SHA |

## Checklist

- [ ] Can predict `/` path from `files/system/` path and vice versa.
- [ ] Know SDDM, Niri, and `scx` defaults live in `files/system/etc/`, units in `usr/lib/systemd/`.
- [ ] Can diagnose `modules.dep` and kernel `Provides:` ordering from this table.

## Next step

Pick a task in [Guides](/guides/) — [Add system file](/guides/add-system-file/) (PR 3) expands this overlay with step-by-step edits.
