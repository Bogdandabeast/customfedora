---
title: "Add a COPR or external repo"
weight: 20
description: "Add a COPR or .repo file to recipe.niri.yml — copr vs files repos, priority, and verification."
---

Add packages from outside Fedora — COPR or a third-party `.repo` file — without hand-editing the Containerfile.

## Quick path

1. Choose repo type: **COPR** (`bieszczaders/kernel-cachyos`) for Fedora COPRs, **files** (`zed.repo`) for vendor `.repo` files.
2. In `recipes/recipe.niri.yml` `type: dnf` add the repo and the package that needs it in the same module.
3. `bluebuild validate ./recipes/recipe.niri.yml` then push — `validate` checks schema, build will fail fast if the repo URL is wrong.

## Details

| Topic | Decision |
|-------|----------|
| COPR repo | `repos: { copr: [bieszczaders/kernel-cachyos] }` — BlueBuild enables the COPR at build time; no `copr enable` script needed |
| File repo | `repos: { files: [zed.repo, vstudio.repo] }` where `zed.repo` is a file shipped via `files/system/etc/yum.repos.d/` or a remote URL (e.g. `https://pkg.cloudflareclient.com/...repo`) |
| `priority` / ordering | Keep vendor repos in the same `dnf` block as the packages that need them; BlueBuild writes repo files before `dnf5 install` — no separate `priority` field needed |
| Same package in two repos | DNF picks highest version; pin with `install.packages: [pkg-1.2.3]` if you need a specific NVR |
| Real examples | `copr: [bieszczaders/kernel-cachyos, bieszczaders/kernel-cachyos-addons]` → `scx-scheds`; `files: [docker-ce.repo, https://pkg.cloudflareclient.com/...]` → `docker-ce`, `cloudflare-warp` |

```yaml
# COPR — kernel and schedulers
- type: dnf
  repos: { copr: [bieszczaders/kernel-cachyos-addons] }
  install: { packages: [scx-scheds] }

# File / URL repo — vendor RPMs
- type: dnf
  repos:
    files: [zed.repo, "https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo"]
  install: { packages: [zed, cloudflare-warp] }
```

{{< callout type="info" >}}
`files` repos that reference a local `*.repo` expect that file under `files/system/etc/yum.repos.d/` (copied by the `type: files` module). Remote URLs are fetched at build time — no local file needed.
{{< /callout >}}

## Checklist

- [ ] Repo type is `copr:` for COPR, `files:` for `.repo` / URL — not swapped.
- [ ] Repo and its packages are in the **same** `dnf` module.
- [ ] `.repo` file exists in `files/system/etc/yum.repos.d/` if using a local name.
- [ ] `bluebuild validate ./recipes/recipe.niri.yml` passes; search `COPR` finds this page offline.

## Next step

Now install an RPM from it → [Add a package](/guides/add-package/). Shipping a config? → [Add a system file](/guides/add-system-file/).
