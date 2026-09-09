---
title: "Repo structure and flavours"
weight: 30
description: "Where recipes, modules, and the files overlay live — and how niri, niri-cachyos, and nvidia flavours relate."
---

Three active recipes share one `files/system/` overlay. Flavour is chosen at rebase time.

## Quick path

1. `recipes/recipe.niri.yml` — default Niri + Noctalia on `base-main:latest`.
2. `recipes/recipe.niri-cachyos.yml` — same stack plus CachyOS kernel + `scx_lavd`.
3. `recipes/recipe.nvidia.yml` — same as niri plus `akmods` `nvidia-open` (Turing+).
4. `files/system/` → `/` in the image.

## Details

| Path | Role | Flavour scope |
|------|------|---------------|
| `recipes/recipe.niri.yml` | Canonical desktop (niri, noctalia, sddm, nautilus, flatpaks) | `niri` |
| `recipes/recipe.niri-cachyos.yml` | Niri plus kernel swap (`containerfile` + `tsflags=noscripts` + `depmod`), `scx-scheds`, `scx.service` | `niri-cachyos` |
| `recipes/recipe.nvidia.yml` | Same as niri plus `akmods` `base: main` `nvidia-open` | `nvidia` |
| `files/system/etc/niri/config.kdl` | Niri keybindings, spawns Noctalia + alacritty/Brave | All Niri |
| `files/system/usr/lib/systemd/` | `scx.service`, `brew-install-*.service`, `noctalia-lid-mode-sync.service`, `ryzen_*.service` + `msi-battery-80.service` | Conditional |
| `files/justfiles/ryzen-tuning.just` | `just ryzen-setup/status/perf/battery/silent-gaming/charge-limit/disable/log` | Ryzen 7730U |
| `files/system/etc/default/scx` | `SCX_SCHEDULER=scx_lavd` + `SCX_FLAGS=--autopower` | CachyOS only |
| `files/system/usr/local/bin/ryzen-profiles` | `ryzen-profiles perf\|battery\|silent-gaming\|stock\|status` (`PPT`/`Tctl`/`GPU`) + hooks + `EC 80%` | CachyOS + stock (ryzen tuning) |
| `cosign.pub` | Public key — derivable marker, never paste SHA in docs | All |

```yaml
# flavour distinction in one glance
# recipe.niri.yml:          base-image: ghcr.io/ublue-os/base-main  image-version: latest
# recipe.niri-cachyos.yml:  same base + containerfile kernel swap + copr bieszczaders/kernel-cachyos
```

Base is `ghcr.io/ublue-os/base-main` (minimal Atomic, no DE). SDDM, Nautilus/`gvfs`, `power-profiles-daemon`, `xdg-user-dirs` are installed explicitly because base has no desktop. `image-version: latest` tracks Fedora latest; pin only if you need a stable gate.

## Checklist

- [ ] Can name which recipe builds `ghcr.io/...:niri` vs `:niri-cachyos` vs `:nvidia`.
- [ ] Know `files/system/` is shared — changes affect all flavours unless guarded by a module.
- [ ] Know `image-version` is `latest` today; pinning requires a conscious commit.

Ryzen tuning (perfiles `6W`/`15W`/`9W` + `GPU 1100MHz` + `80%` + `LAVD`) lives in [Ryzen 7730U tuning](/guides/ryzen-tuning/).

## Next step

Deep dive into [Recipe anatomy](/reference/recipe-anatomy/), then [Modules catalog](/reference/modules-catalog/) for per-module options.
