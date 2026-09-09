---
title: "Debug a build"
weight: 60
description: "Diagnose BlueBuild failures — validate, containerfile, CI logs, rollback, and local bluebuild validate/build."
---

When `bluebuild` CI fails, triage locally before pushing another commit.

## Quick path

1. Validate schema: `bluebuild validate ./recipes/recipe.niri.yml` (and `recipe.niri-cachyos.yml`) — instant, no OCI.
2. Reproduce container layer: `bluebuild build ./recipes/recipe.niri.yml` (or read `build.yml` → `validate` job logs).
3. Roll back: `rpm-ostree rollback && systemctl reboot` (previous deployment boots; no reinstall).

## Details

| Topic | Decision |
|-------|----------|
| `validate` vs `build` | `validate` checks YAML schema + module types (seconds, CI `validate` job); `build` runs the Containerfile in podman (minutes, needs disk/RAM) |
| Common schema errors | Unknown `type:`, wrong `source: system` path, indented `repos:` under `install:` — `validate` prints the field |
| Containerfile / kernel | `modules.dep is missing. Did you run depmod?` → missing `tsflags=noscripts` + `depmod -a $KVER` (see [CachyOS kernel](/guides/kernel-cachyos/)). Broken `RUN` heredoc → check `snippets:` quoting |
| CI logs | `build.yml` → `Validate recipes` step prints `bluebuild validate ./recipes/*.yml`; `Build Custom Image` step streams the failing `RUN` line — search the log for the last `RUN` before `error` |
| Rollback + pin | After a bad rebase, `rpm-ostree rollback` reboots into the previous `ostree` deployment; `image-version: latest` tracks `base-main:latest` — pin to a SHA only for a short bisect |
| Local build | `bluebuild validate` + `bluebuild build` require the BlueBuild CLI (`curl -fsSL https://raw.githubusercontent.com/blue-build/cli/main/install.sh | bash` — same as CI `Install BlueBuild CLI` step) |

```bash
# local triage — mirrors CI validate job
for r in recipe.niri.yml recipe.niri-cachyos.yml; do
  echo "==> $r"
  bluebuild validate "./recipes/$r"
done
# full local build (slow, optional)
bluebuild build ./recipes/recipe.niri.yml
```

{{< callout type="info" >}}
`*.md` pushes never trigger image builds (`build.yml` has `paths-ignore: ["**.md"]`) so docs edits cannot mask a recipe regression — always push a recipe change separately to see the build result.
{{< /callout >}}

## Checklist

- [ ] `bluebuild validate` passes for the changed recipe before push.
- [ ] Failing `RUN` line identified from CI log (containerfile/kernel vs dnf).
- [ ] Rollback plan known: `rpm-ostree rollback` reverts deployment without data loss.
- [ ] After fix, `bluebuild validate` re-run and CI `validate` job green before `bluebuild` matrix runs.

## Next step

Fix is usually in `recipes/*.yml` → [Add a package](/guides/add-package/) or [CachyOS kernel](/guides/kernel-cachyos/) for ordering. Files issue → [Add a system file](/guides/add-system-file/).
