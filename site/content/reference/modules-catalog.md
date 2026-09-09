---
title: "Modules catalog"
weight: 20
description: "Every BlueBuild module type used in this repo — files, dnf, script, systemd, brew, flatpak, containerfile and more — with real examples."
---

Modules are the only way the recipe changes the image. This catalog lists each type as used in `recipe.niri.yml` / `recipe.niri-cachyos.yml`.

## Quick path

1. Need a config or service? → `files` or `systemd`.
2. Need an RPM or repo? → `dnf`.
3. Need arbitrary setup? → `script` or `containerfile` (kernel swap only).

## Details

| Module `type:` | Purpose | Real example in this repo |
|---------------|---------|---------------------------|
| `files` | Copy `files/system/` → `/` | `source: system, destination: /` — Niri config, SDDM, `scx` default, systemd units |
| `dnf` | Add repos + install/remove RPMs | `repos: {files, copr}`, `install: {skip-broken, packages: [niri, noctalia, sddm ...]}` |
| `script` | Run a build-time shell script | `scripts: [downloadlatestwinboatrpm.sh]` — fetches WinBoat RPM from GitHub |
| `systemd` | Enable units at build time | `system.enabled: [warp-svc, brew-install-*.service, docker.socket, scx.service]` |
| `brew` | Install Linuxbrew (first-boot `brew-setup.service`) | `brew-analytics: false` — fish/lazygit/bun then via brew services |
| `default-flatpaks` | Declare Flatpaks (system + user) | `boot-install: true` list: Brave, Librewolf, Steam, VLC, KeePassXC… |
| `containerfile` | Raw `RUN` snippet when dnf order matters | CachyOS kernel swap: remove stock kernel, `dnf5 install --setopt=tsflags=noscripts kernel-cachyos*`, `depmod -a` |
| `initramfs` | Regenerate initramfs after kernel swap | Last module in `recipe.niri-cachyos.yml` |
| `justfiles` | Expose `just` recipes from image | `type: justfiles` (no args) |
| `signing` | Configure image signing policy | Legacy `recipe.yml` (bluefin-dx); Niri recipes inherit via Action `cosign_private_key` |

Minimal examples (copy-pasteable, trimmed):

```yaml
- type: dnf
  repos: { copr: [bieszczaders/kernel-cachyos] }
  install: { packages: [sbsigntools, mokutil] }

- type: systemd
  system: { enabled: [docker.socket, podman.socket, scx.service] }
  user: { enabled: [noctalia-lid-mode-sync.service] }

- type: containerfile
  snippets: ["RUN dnf5 -y remove --no-autoremove $(rpm -qa kernel*) && dnf5 -y install --setopt=tsflags=noscripts kernel-cachyos ... && depmod -a $(ls /usr/lib/modules)"]
```

## Checklist

- [ ] Know which type to reach for (table above) without grepping CI.
- [ ] Know `containerfile` is reserved for the kernel swap — not for general packages.
- [ ] Know `brew` and `default-flatpaks` install at first boot, keeping the OCI layers small.

## Next step

See [Files overlay](/reference/troubleshooting/) for the `files/system/` → `/` map, or jump to a guide in [Guides](/guides/).
