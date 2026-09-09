---
title: customfedora docs
type: docs
weight: 1
---

# customfedora

BlueBuild recipes for **Fedora Atomic (Niri + Noctalia)**. This site explains the recipe → module → `files/system/` → Containerfile (generated) pipeline and the CachyOS kernel path (`tsflags=noscripts` + `depmod`).

> [!TIP]
> New here? Start with the **Concepts** then jump to the guide you need. All guides follow Quick path → Details → Checklist → Next step.

## I want to …

- **Add a package** → [Add package guide](/guides/add-package/) *(coming in PR 2 — placeholder)*
- **Add a COPR / external repo** → [Add COPR repo](/guides/add-repo-copr/) *(placeholder)*
- **Add a system file** → [Add system file](/guides/add-system-file/) *(placeholder)*
- **Add a systemd service** → [Add systemd service](/guides/add-systemd-service/) *(placeholder)*
- **Tweak the CachyOS kernel** → [Kernel — CachyOS](/guides/kernel-cachyos/) *(placeholder)*
- **Debug a failing build** → [Debug build](/guides/debug-build/) *(placeholder)*

## Where to go next

| Section | What it covers | Status |
|---------|---------------|--------|
| [Concepts](/concepts/) | BlueBuild, Atomic/OStree, repo-structure | 3 pages — PR 2 |
| [Guides](/guides/) | 6 task guides above | 6 pages — PR 3 |
| [Reference](/reference/) | Recipe anatomy, modules catalog, troubleshooting | 3 pages — PR 2 |
| [Legacy `docs/`](../../docs/) | Archived Omarchy mappings (preserved) | Kept as appendix source |

## How this site is built

- **Hugo extended 0.128.x+** — `hugo --minify --source site` with **no Node** (Tailwind via Hugo Pipes).
- **Hextra via Hugo Modules** — pinned in `site/go.mod`. Swap to Hugo Book needs only `hugo.yaml`/`go.mod` change.
- **Offline FlexSearch** + dark mode toggle.

{{< callout type="info" >}}
Future IA (3+6+3) is scaffolded. Placeholder links above will resolve once PR 2/3 land; the site still builds today.
{{< /callout >}}

## Quick path

1. `just docs-serve` → http://localhost:1313
2. Edit `site/content/_index.md` or future guides
3. `hugo --minify --source site` must emit `site/public/index.html` without Node
