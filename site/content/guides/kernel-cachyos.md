---
title: "CachyOS kernel"
weight: 50
description: "Swap the Fedora kernel for CachyOS — tsflags=noscripts, depmod, scx schedulers, Secure Boot, and rollback."
---

`niri-cachyos` replaces the Fedora kernel with `kernel-cachyos` from the `bieszczaders/kernel-cachyos` COPR. The ordering and flags are load-bearing.

## Quick path

1. Read `recipes/recipe.niri-cachyos.yml` — `dnf` COPR `bieszczaders/kernel-cachyos` for `sbsigntools`/`mokutil` + `containerfile` kernel swap + `dnf` `bieszczaders/kernel-cachyos-addons` for `scx-scheds`.
2. Rebase: `rpm-ostree rebase ostree-image-signed:docker://ghcr.io/bogdandabeast/customfedora:niri-cachyos` then `systemctl reboot`.
3. Verify: `uname -r` contains `cachyos`, `ls /usr/lib/modules` has one entry, `systemctl status scx.service` (CachyOS only).

## Details

| Topic | Decision |
|-------|----------|
| Why `containerfile` | `kernel-cachyos-core` declares `Provides: kernel` — a plain `dnf install: [kernel-cachyos]` followed by `remove: [kernel]` would immediately remove the new kernel. The `containerfile` RUN removes first, then installs |
| `tsflags=noscripts` | Required, not optional: CachyOS RPMs ship no `modules.dep`; their `%posttrans` runs `kernel-install → dracut` which aborts with `modules.dep is missing`. `--setopt=tsflags=noscripts` skips scriptlets; you `depmod` manually |
| `depmod` + assert | After install: `KVER=$(ls /usr/lib/modules)`; `depmod -a "$KVER"`; `test -f /usr/lib/modules/$KVER/vmlinuz` + `modules.dep` — build fails if swap is half-done |
| `scx` schedulers | `dnf` COPR `bieszczaders/kernel-cachyos-addons` → `scx-scheds` (`scx_lavd`) + `files/system/etc/default/scx` (`SCX_SCHEDULER=scx_lavd`, `SCX_FLAGS=--autopower`) + `scx.service` with `ConditionPathIsDirectory=/sys/kernel/sched_ext` |
| Secure Boot | CachyOS kernel has no PE signature — sign with `sbsign` + enroll with `mokutil` if Secure Boot is ON; repo ships `sbsigntools`/`mokutil` for copy-paste |

Real `containerfile` snippet from `recipes/recipe.niri-cachyos.yml` (trimmed):

```bash
RUN set -eu \
 && STOCK="$(rpm -qa --queryformat '%{NAME}\n' | grep -E '^(kernel|kernel-core|kernel-modules.*)$' || true)" \
 && if [ -n "$STOCK" ]; then dnf5 -y remove --no-autoremove $STOCK; fi \
 && rm -rf /usr/lib/modules/* \
 && dnf5 -y install --setopt=tsflags=noscripts kernel-cachyos kernel-cachyos-core kernel-cachyos-modules kernel-cachyos-devel-matched \
 && dnf5 clean all \
 && test "$(ls -1 /usr/lib/modules | wc -l)" -eq 1 \
 && KVER="$(ls -1 /usr/lib/modules)" \
 && depmod -a "$KVER" \
 && test -f "/usr/lib/modules/$KVER/modules.dep"
```

{{< callout type="warning" >}}
Do not swap remove/install order — `Provides: kernel` will pull the new kernel back out. When adding packages to `niri-cachyos`, keep kernel-COPR repos in their own `dnf` block before the `containerfile` swap.
{{< /callout >}}

## Checklist

- [ ] Understand remove-before-install ordering and why it exists.
- [ ] `tsflags=noscripts` + manual `depmod -a $KVER` pattern copied if modifying kernel modules.
- [ ] After rebase on `niri-cachyos`: `uname -r` shows `cachyos`, one `/usr/lib/modules/<kver>` with `vmlinuz` + `modules.dep`, `scx.service` is active (or correctly skipped on `niri`).
- [ ] Secure Boot note read if applicable.

## Next step

`scx` tuning in `/etc/default/scx` — try `--powersave` vs `--autopower`. Build broke? → [Debug a build](/guides/debug-build/).
