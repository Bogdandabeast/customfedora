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

- **Add a package** → [Add package](/guides/add-package/)
- **Add a COPR / external repo** → [Add COPR repo](/guides/add-repo-copr/)
- **Add a system file** → [Add system file](/guides/add-system-file/)
- **Add a systemd service** → [Add systemd service](/guides/add-systemd-service/)
- **Swap the CachyOS kernel** → [CachyOS kernel](/guides/kernel-cachyos/)
- **Debug a failing build** → [Debug build](/guides/debug-build/)

## Where to go next

| Section | What it covers | Status |
|---------|---------------|--------|
| [Concepts](/concepts/) | BlueBuild, Atomic/OStree, repo-structure | 3 pages — live |
| [Guides](/guides/) | 6 task guides above | 6 pages — live |
| [Reference](/reference/) | Recipe anatomy, modules catalog, troubleshooting | 3 pages — live |
| [Legacy `docs/`](../../docs/) | Archived Omarchy mappings (preserved) | Kept as appendix source |

## How this site is built

- **Hugo extended 0.128.x+** — `hugo --minify --source site` with **no Node** (Tailwind via Hugo Pipes).
- **Hextra via Hugo Modules** — pinned in `site/go.mod`. Swap to Hugo Book needs only `hugo.yaml`/`go.mod` change.
- **Offline FlexSearch** + dark mode toggle.

{{< callout type="info" >}}
All 12 content pages are live (3 Concepts + 6 Guides + 3 Reference) — search `COPR` / `scx` / `kernel` to try offline FlexSearch.
{{< /callout >}}

## Quick path

1. `just docs-serve` → http://localhost:1313
2. Edit `site/content/_index.md` or future guides
3. `hugo --minify --source site` must emit `site/public/index.html` without Node
