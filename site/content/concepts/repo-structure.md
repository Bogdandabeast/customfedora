---
title: "Repo structure and flavours"
weight: 30
description: "Where recipes, modules, and the files overlay live — and how niri, niri-cachyos, and nvidia flavours relate."
---

Two active recipes share one `files/system/` overlay. Flavour is chosen at rebase time.

## Quick path

1. `recipes/recipe.niri.yml` — default Niri + Noctalia on `base-main:latest`.
2. `recipes/recipe.niri-cachyos.yml` — same stack plus CachyOS kernel + `scx_lavd`.
3. `files/system/` → `/` in the image; `recipes/common/` holds extractable `dnf`/`files` fragments.

## Details

| Path | Role | Flavour scope |
|------|------|---------------|
| `recipes/recipe.niri.yml` | Canonical desktop (niri, noctalia, sddm, nautilus, flatpaks) | `niri` |
| `recipes/recipe.niri-cachyos.yml` | Niri plus kernel swap (`containerfile` + `tsflags=noscripts` + `depmod`), `scx-scheds`, `scx.service` | `niri-cachyos` |
| `recipes/recipe.yml`, `recipe.sway*.yml` | Legacy Sway / bluefin-dx base — kept for reference | Sway |
| `recipes/common/*.yml` | Reusable fragments (`from-file: common/...`) — not auto-included in Niri recipes | Shared |
| `files/system/etc/niri/config.kdl` | Niri keybindings, spawns Noctalia + alacritty/Brave | All Niri |
| `files/system/usr/lib/systemd/` | `scx.service`, `brew-install-*.service`, `noctalia-lid-mode-sync.service` | Conditional |
| `files/system/etc/default/scx` | `SCX_SCHEDULER=scx_lavd` + `SCX_FLAGS=--autopower` | CachyOS only |
| `cosign.pub` | Public key — derivable marker, never paste SHA in docs | All |

```yaml
# flavour distinction in one glance
# recipe.niri.yml:          base-image: ghcr.io/ublue-os/base-main  image-version: latest
# recipe.niri-cachyos.yml:  same base + containerfile kernel swap + copr bieszczaders/kernel-cachyos
```

Base is `ghcr.io/ublue-os/base-main` (minimal Atomic, no DE). SDDM, Nautilus/`gvfs`, `power-profiles-daemon`, `xdg-user-dirs` are installed explicitly because base has no desktop. `image-version: latest` tracks Fedora latest; pin only if you need a stable gate.

## Checklist

- [ ] Can name which recipe builds `ghcr.io/...:niri` vs `:niri-cachyos`.
- [ ] Know `files/system/` is shared — changes affect both flavours unless guarded by a module.
- [ ] Know `image-version` is `latest` today; pinning requires a conscious commit.

## Next step

Deep dive into [Recipe anatomy](/reference/recipe-anatomy/), then [Modules catalog](/reference/modules-catalog/) for per-module options.
