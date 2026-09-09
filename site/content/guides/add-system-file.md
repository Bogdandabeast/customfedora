---
title: "Add a system file"
weight: 30
description: "Ship a config via files/system overlay — source to destination mapping and verification."
---

Ship any file into the image — Niri config, SDDM theme, portal rules — via `files/system/` → `/`.

## Quick path

1. Create the file under `files/system/` mirroring its final absolute path (e.g. `files/system/etc/niri/config.kdl` → `/etc/niri/config.kdl`).
2. No new module needed — `recipes/recipe.niri.yml` already has `type: files` with `source: system, destination: /`.
3. Build or rebase and verify the file exists in the booted image (`ls /etc/niri/config.kdl`).

## Details

| Topic | Decision |
|-------|----------|
| Overlay rule | `files/system/<path>` → `/<path>` at build time via `type: files` (`source: system, destination: /`) |
| Common targets | `etc/niri/config.kdl` (Niri), `etc/sddm.conf.d/theme.conf` (SDDM), `etc/default/scx` (scx flags), `usr/lib/systemd/system/*.service` (units) |
| Overwrite semantics | Later `files` entries overwrite earlier ones; `destination: /` means `files/system/etc` → `/etc` exactly |
| Permissions | File mode is copied as-is — `chmod 644` tracked by git; no post-install `chmod` needed |
| Verification | After rebase: `ls /<path>` + `journalctl -u <service>` if it's a unit; CI `validate` does not check file presence — manual check |

```yaml
# already in recipes/recipe.niri.yml — no change needed for new files
- type: files
  files:
    - source: system
      destination: /
```

Example — add `etc/foo/bar.conf`:

```bash
mkdir -p files/system/etc/foo
echo "value=1" > files/system/etc/foo/bar.conf
# next build copies it to /etc/foo/bar.conf in the image
```

{{< callout type="info" >}}
Misplaced path is the #1 failure — `files/system/usr/etc/foo` would land at `/usr/etc/foo`, not `/etc/foo`. Match the final `/` path exactly.
{{< /callout >}}

## Checklist

- [ ] Path under `files/system/` equals the final `/` path minus the prefix.
- [ ] File is committed (not gitignored) and has correct mode.
- [ ] `bluebuild validate ./recipes/recipe.niri.yml` still passes.
- [ ] After rebase, file exists and service (if any) starts — check `systemctl status`.

## Next step

File is a unit? → [Add a systemd service](/guides/add-systemd-service/). User config? See `files/system/etc/skel/` pattern in [Files overlay](/reference/troubleshooting/).
