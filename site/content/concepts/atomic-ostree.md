---
title: "Atomic and OSTree"
weight: 20
description: "How Fedora Atomic images work: read-only deployments, rebase, rollback, and signing."
---

Fedora Atomic is an OSTree system: `/usr` is read-only, each image is a deployment you reboot into. You never `dnf upgrade` the host — you rebase.

## Quick path

1. Rebase once: `rpm-ostree rebase ostree-unverified-registry:ghcr.io/bogdandabeast/customfedora:niri`.
2. Reboot — new deployment is active, old one is kept.
3. Rollback if needed: `rpm-ostree rollback` then reboot. Verify with `cosign` and the repo's `cosign.pub`.

## Details

| Concept | Traditional Fedora | Atomic (this repo) |
|---------|-------------------|--------------------|
| Updates | `dnf upgrade` mutates `/usr` | `rpm-ostree upgrade` or rebase to new OCI image |
| Root | Writable | Read-only `/usr`; writable `/etc` and `/var` |
| Rollback | Reinstall / snapshot | `rpm-ostree rollback` — previous deployment boots |
| Verification | RPM GPG | `cosign` with `cosign.pub` (root, not hardcoded in docs) |
| User apps | RPM + Flatpak | RPM for base (image), Flatpak system/user, Brew for CLI, Distrobox |

Deployments are kept on disk. `/etc` overlays per-deployment, so config in `files/system/etc/` becomes the default for new installs and rebase targets.

{{< callout type="warning" >}}
Do not `rpm-ostree install` packages to work around the image — add them to `recipes/*.yml` so every machine gets them. Host layering survives rebase but drifts.
{{< /callout >}}

## Checklist

- [ ] Can rebase to `niri` or `niri-cachyos` and verify with `cosign.pub`.
- [ ] Know `rollback` reverts to the previous deployment, not a full reinstall.
- [ ] Know `/usr` is read-only; custom files go via `files/system/` at build time, not `sudo cp` at runtime.

## Next step

See [Repo structure](/concepts/repo-structure/) for where those deployments are built, then [Recipe anatomy](/reference/recipe-anatomy/) for the YAML that defines them.
