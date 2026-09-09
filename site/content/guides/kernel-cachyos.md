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

## LAVD y `pahole < 1.26` — qué hacer si `scx.service` falla

En `kernel-cachyos 7.2.3` el `BTF` se generó con `pahole < 1.26` y todos los `scx` (`scx_lavd/bpfland/rusty`) fallan igual:

```
libbpf: extern (func ksym) 'scx_bpf_error_bstr': func_proto [393] incompatible with vmlinux [60790]
Error: BTF has malformed scx kfunc prototype(s): __scx_bpf_dsq_insert_vtime...
These kfuncs are KF_IMPLICIT_ARGS but still carries 'struct bpf_prog_aux *'
Fix: boot a kernel whose BTF was generated with pahole >= 1.26. See kernel commit 9edd04c4189e
```

`scx.service` entra en restart-loop (`failed exit 1`). `sched_ext` queda `state: disabled` y el scheduler vuelve a `EEVDF`. No rompe los perfiles `ryzen_smu` (`PPT`/`Tctl`/`GPU` siguen mandando) — LAVD solo añade compactación de cores (`power-saver -> powersave` `+0.3-0.8W` vs `EEVDF`). Ver [Ryzen tuning (LAVD vs EPP)](/guides/ryzen-tuning/) para tabla completa.

```bash
systemctl status scx.service   # failed BTF pahole <1.26
cat /sys/kernel/sched_ext/state  # disabled hoy -> enabled cuando llegue 7.2.4
journalctl -u scx.service --no-pager -n 30
# opcional silenciar loop hasta 7.2.4:
sudo systemctl disable --now scx.service
# tras kernel 7.2.4: sudo systemctl enable --now scx.service
```

## Checklist

- [ ] Understand remove-before-install ordering and why it exists.
- [ ] `tsflags=noscripts` + manual `depmod -a $KVER` pattern copied if modifying kernel modules.
- [ ] After rebase on `niri-cachyos`: `uname -r` shows `cachyos`, one `/usr/lib/modules/<kver>` with `vmlinuz` + `modules.dep`, `scx.service` is active (or correctly skipped on `niri`).
- [ ] `scx.service` `failed BTF pahole <1.26` on 7.2.3 is expected — not your config; fix is next `kernel-cachyos` with `pahole >=1.26`.
- [ ] Secure Boot note read if applicable.

## Next step

Ryzen `PPT`/`Tctl`/`GPU` + `autocambio ADP1` → [Ryzen 7730U tuning](/guides/ryzen-tuning/). `scx` tuning in `/etc/default/scx` — try `--powersave` vs `--autopower`. Build broke? → [Debug a build](/guides/debug-build/).
