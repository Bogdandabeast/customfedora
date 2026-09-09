---
title: "Add a systemd service"
weight: 40
description: "Enable system vs user units in recipe.niri.yml — enabled list, ConditionPath, and preset gotchas."
---

Enable a `systemd` unit at build time so it starts on every boot without `systemctl enable` after rebase.

## Quick path

1. Ship the unit file via `files/system/` — `usr/lib/systemd/system/foo.service` (system) or `usr/lib/systemd/user/foo.service` (user).
2. In `recipes/recipe.niri.yml` add its name to `type: systemd` → `system.enabled` or `user.enabled`.
3. Validate and rebase — `systemctl is-enabled foo.service` should report `enabled` after reboot.

## Details

| Topic | Decision |
|-------|----------|
| System vs user | `system.enabled: [foo.service, docker.socket]` starts at boot for all users; `user.enabled: [noctalia-lid-mode-sync.service]` starts per-user session |
| Unit location | System: `files/system/usr/lib/systemd/system/*.service`; User: `files/system/usr/lib/systemd/user/*.service` |
| `ConditionPath` | Guard optional hardware — `ConditionPathIsDirectory=/sys/kernel/sched_ext` in `scx.service` makes it correctly skip on non-CachyOS kernels (check `journalctl -u scx`) |
| Preset vs explicit | `systemd` module writes explicit enablement; Fedora presets still apply but your `enabled` list wins — keep list minimal and ordered |
| Real list | `system.enabled: [warp-svc.service, brew-install-fish.service, docker.socket, podman.socket, libvirtd.service, power-profiles-daemon.service, scx.service]` + `user.enabled: [noctalia-lid-mode-sync.service]` |

```yaml
# recipes/recipe.niri.yml — excerpt
- type: systemd
  system:
    enabled:
      - foo.service          # system-wide daemon
      - docker.socket
  user:
    enabled:
      - bar-user.service     # per-user session unit
```
Unit example with guard (see `files/system/usr/lib/systemd/system/scx.service`):

```ini
[Unit]
ConditionPathIsDirectory=/sys/kernel/sched_ext
[Service]
EnvironmentFile=/etc/default/scx
ExecStart=/bin/bash -c 'exec ${SCX_SCHEDULER} ${SCX_FLAGS}'
[Install]
WantedBy=multi-user.target
```

{{< callout type="warning" >}}
Ship then enable — adding a name to `enabled` without the file in `files/system/` makes the image build succeed but the service fail at boot with `not-found`.
{{< /callout >}}

## Checklist

- [ ] Unit file is in `files/system/usr/lib/systemd/system/` or `.../user/` matching the `system` vs `user` block.
- [ ] Name in `system.enabled` or `user.enabled` exactly matches filename (including `.service`/`.socket`).
- [ ] If hardware-gated, `ConditionPathIsDirectory` is set and documented.
- [ ] After rebase: `systemctl is-enabled <unit>` is `enabled`; logs clean.

## Next step

`scx` scheduling details → [CachyOS kernel](/guides/kernel-cachyos/). Something broke? → [Debug a build](/guides/debug-build/).
