---
title: "Add a package"
weight: 10
description: "Add or remove an RPM in recipe.niri.yml — dnf module, skip-broken, and remove ordering."
---

Install one more RPM without breaking the image. All packages live in `recipes/recipe.niri.yml` under `type: dnf`.

## Quick path

1. Open `recipes/recipe.niri.yml` → find the `type: dnf` block (the large `install: packages:` list).
2. Append the package name to `install.packages` (alphabetical keeps diffs clean).
3. Validate: `bluebuild validate ./recipes/recipe.niri.yml`.
4. Push — CI `validate` job fails fast if the package is missing or typos.

## Details

| Topic | Decision |
|-------|----------|
| Where to edit | `recipes/recipe.niri.yml` `modules: - type: dnf` → `install.packages` (and `install.skip-broken: true` is already set) |
| Remove a package | Add to `remove.packages` in the same `dnf` module, or delete from `install.packages` if you added it — `remove` runs after `install` |
| `skip-broken: true` | Keeps build green if a repo is temporarily missing a package; prefer fixing the package name over relying on it |
| Ordering | `files` module first, then `dnf` repos+install; a later `dnf` block can add packages without touching the main list |
| Verify locally | `bluebuild validate ./recipes/recipe.niri.yml` (seconds) — full `bluebuild build` only if you need a local OCI |

```yaml
# recipes/recipe.niri.yml — excerpt
- type: dnf
  repos:
    files: [zed.repo, vstudio.repo, docker-ce.repo]
  install:
    skip-broken: true
    packages:
      - niri
      - noctalia
      - sddm
      - htop        # ← added
  remove:
    packages: [gnome-tour]  # example: prune after install
```

{{< callout type="info" >}}
System-wide RPMs update with the image. For user CLI tools that already ship as Fedora RPMs (see `gh`, `fzf`, `ripgrep` in the same list), prefer RPM over `brew` so updates are atomic.
{{< /callout >}}

## Checklist

- [ ] Package name is an exact Fedora/COPR RPM name (check `dnf search`).
- [ ] Added to `install.packages` (or `remove.packages`) — not hand-edited Containerfile.
- [ ] `bluebuild validate ./recipes/recipe.niri.yml` passes.
- [ ] If removing a `Provides: kernel` package, see [CachyOS kernel](/guides/kernel-cachyos/) for ordering.

## Next step

Need an external repo? → [Add a COPR / external repo](/guides/add-repo-copr/). Need a config file? → [Add a system file](/guides/add-system-file/).
