---
title: "What is BlueBuild"
weight: 10
description: "How recipe YAML becomes a bootable Fedora Atomic image — modules, files overlay, and generated Containerfile."
---

BlueBuild turns a `recipes/*.yml` file into a Containerfile, runs it, and publishes a signed OCI image you rebase onto. You edit YAML, not Dockerfiles.

{{< callout type="info" >}}
Future self: if you know `recipe.niri.yml` you know the whole pipeline. Everything else is a module.
{{< /callout >}}

## Quick path

1. Open `recipes/recipe.niri.yml` — `base-image`, `image-version`, `modules:` in order.
2. Trace one module: `type: files` copies `files/system/` → `/`; `type: dnf` installs RPMs.
3. Push → `bluebuild` GitHub Action validates, builds Containerfile, pushes to `ghcr.io`.

## Details

| Stage | What happens | Where in this repo |
|-------|--------------|--------------------|
| Recipe | Declares base + ordered modules | `recipes/recipe.niri.yml`, `recipe.niri-cachyos.yml` |
| Modules | Each `type:` maps to a BlueBuild action | `dnf`, `files`, `script`, `brew`, `systemd`, `containerfile`, `justfiles`, `default-flatpaks` |
| Files overlay | `files/system/` mirrored to `/` | `files/system/etc/niri/config.kdl`, `files/system/usr/lib/systemd/` |
| Containerfile | Generated, not hand-edited | Derived from modules; do not commit |
| Signing | `type: signing` + `cosign.pub` at repo root | Verify after rebase, never hardcode SHA |

BlueBuild modules run top-to-bottom. Order matters — the CachyOS flavour removes the Fedora kernel *before* installing `kernel-cachyos` (see [CachyOS kernel guide](/guides/kernel-cachyos/) in PR 3, and the `containerfile` snippet in `recipe.niri-cachyos.yml`).

```yaml
# excerpt — recipes/recipe.niri.yml (real file, trimmed)
base-image: ghcr.io/ublue-os/base-main
image-version: latest
modules:
  - type: files
    files: [{ source: system, destination: / }]
  - type: dnf
    repos: { files: [zed.repo, vstudio.repo, docker-ce.repo] }
    install: { packages: [niri, noctalia, sddm, nautilus] }
```

## Checklist

- [ ] Can point from a recipe field to the file it touches (`source: system` → `files/system/`).
- [ ] Know Containerfile is generated — never edited by hand.
- [ ] Know `base-main` is minimal; desktop pieces are added explicitly.

## Next step

Continue to [Atomic and OSTree](/concepts/atomic-ostree/) for rebase/rollback, then [Repo structure](/concepts/repo-structure/) for flavour map.
