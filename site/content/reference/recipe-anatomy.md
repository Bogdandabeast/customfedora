---
title: "Recipe anatomy"
weight: 10
description: "Line-by-line walkthrough of recipe.niri.yml — base-image, image-version, and the ordered modules list."
---

A recipe is the build manifest. BlueBuild reads it top-to-bottom and generates the Containerfile. This page walks the real `recipe.niri.yml`.

## Quick path

1. Copy `recipes/recipe.niri.yml` header: `name`, `description`, `base-image`, `image-version`.
2. Read `modules:` — each entry is a typed step. Order is the build order.
3. Find the `files` → `dnf` → `script` → `brew` → `systemd` → `default-flatpaks` sequence and match each to its file.

## Details

| Field | What it does | Example from recipe.niri.yml |
|-------|--------------|------------------------------|
| `name` | Image name / tag suffix | `name: niri` → `ghcr.io/...:niri` |
| `base-image` | `FROM` for the build | `ghcr.io/ublue-os/base-main` |
| `image-version` | Tag of base to track | `latest` (tracks Fedora) |
| `modules[]` | Ordered build steps | 8 entries (see below) |

Real snippet — first 30 lines of `recipes/recipe.niri.yml`:

```yaml
---
# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json
name: niri
description: Fedora Atomic with Niri compositor and Noctalia Shell
base-image: ghcr.io/ublue-os/base-main
image-version: latest
modules:
  - type: files
    files:
      - source: system
        destination: /
  - type: dnf
    repos:
      files: [zed.repo, vstudio.repo, docker-ce.repo,
              https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo]
    install:
      skip-broken: true
      packages: [niri, noctalia, alacritty, sddm, nautilus, gvfs, ...]
```

CachyOS flavour inserts two extra modules before the main `dnf` block: a `dnf` for `sbsigntools`/`mokutil` and a `containerfile` kernel swap. See `recipe.niri-cachyos.yml` for that exact `tsflags=noscripts` + `depmod -a` pattern.

{{< callout type="info" >}}
Validation: `bluebuild validate ./recipes/recipe.niri.yml` runs in CI (`validate` job) before any image build. A schema error fails fast.
{{< /callout >}}

## Checklist

- [ ] Can name the 4 header fields and what each controls.
- [ ] Can explain why `modules` order matters (kernel swap must precede the big `dnf` install in CachyOS).
- [ ] Know to look at `recipes/recipe.niri-cachyos.yml` for the `containerfile` snippet — not duplicated here.

## Next step

Browse [Modules catalog](/reference/modules-catalog/) for per-type options, then [Files overlay](/reference/troubleshooting/) for where `files/system/` lands.
