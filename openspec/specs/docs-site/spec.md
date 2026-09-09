# Delta for docs-site

## ADDED Requirements

### Requirement: Hugo Site Root and Config

The system MUST provide Hugo site at `site/` with `hugo.yaml`, `go.mod`, `content/` that builds via `hugo --minify --source site` using Hugo extended 0.128.x+. The system MUST NOT require Node for production builds.

#### Scenario: Build without Node succeeds

- GIVEN `site/hugo.yaml` and `site/go.mod` present, Node absent
- WHEN `hugo --minify --source site` runs
- THEN build succeeds and emits `site/public/index.html`

#### Scenario: Invalid config fails

- GIVEN `site/hugo.yaml` missing or invalid
- WHEN `hugo --minify --source site` runs
- THEN build exits non-zero

### Requirement: Theme — Hextra Primary, Book Fallback

The system MUST use Hextra as Hugo Module. Content MUST stay theme-agnostic: only `hint`/`callout`-compatible shortcodes; Hextra-only shortcodes MUST NOT appear in bodies. Book fallback MUST require only `hugo.yaml`/`go.mod` swap.

#### Scenario: Hextra builds without Node

- GIVEN `site/go.mod` pins Hextra
- WHEN `hugo --minify --source site` runs without Node
- THEN `site/public` contains Hextra assets, no Node error

#### Scenario: Book swap needs no body edits

- GIVEN Hextra requires Node (regression)
- WHEN module swapped to `hugo-book` in `hugo.yaml`/`go.mod`
- THEN build still succeeds, all `content/**` pages render unchanged

### Requirement: Information Architecture 3+6+3

The system MUST provide IA under `site/content/` with `title`/`weight` front matter:

| Section | Count | Files |
|---------|-------|-------|
| `concepts/` | 3 | `bluebuild.md`, `atomic-ostree.md`, `repo-structure.md` |
| `guides/` | 6 | `add-package.md`, `add-repo-copr.md`, `add-system-file.md`, `add-systemd-service.md`, `kernel-cachyos.md`, `debug-build.md` |
| `reference/` | 3 | `recipe-anatomy.md`, `modules-catalog.md`, `troubleshooting.md` |
| root | 1 | `_index.md` (landing) |

#### Scenario: IA complete

- GIVEN fresh clone
- WHEN listing `site/content/concepts/`, `guides/`, `reference/`
- THEN counts are 3, 6, 3 and `_index.md` exists

### Requirement: Content Shape (Cognitive Doc Design)

Each `concepts/`, `guides/`, `reference/` page MUST follow Quick path → Details (table) → Checklist → Next step in order. Landing `_index.md` MUST provide "I want to …" links to all six guides.

#### Scenario: Guide follows shape

- GIVEN `site/content/guides/add-package.md` opened
- WHEN headings inspected
- THEN `## Quick path`, `## Details`, `## Checklist`, `## Next step` appear in order

#### Scenario: Landing links all guides

- GIVEN `site/content/_index.md` rendered
- WHEN searching "I want to"
- THEN six guide links present and resolve

### Requirement: Offline Search and Dark Mode

The system MUST provide offline FlexSearch (no Algolia) returning results for `COPR`, `scx`, `kernel` in <1s on built site. The system MUST provide dark mode toggle persisted across navigations.

#### Scenario: Offline search <1s

- GIVEN site served from `site/public` offline
- WHEN searching `COPR`
- THEN `guides/add-repo-copr` appears within 1s

#### Scenario: Dark mode persists

- GIVEN site loaded
- WHEN toggling dark mode and navigating
- THEN dark theme remains without flash

### Requirement: Legacy Docs Preservation

The system MUST leave `docs/` untouched (including `docs/fedora_migrations/`). Content MUST NOT hardcode Containerfile SHA/`cosign.pub`; references MUST use derivable markers.

#### Scenario: Legacy docs untouched

- GIVEN `docs/fedora_migrations/mapping.md` exists
- WHEN Hugo site built and committed
- THEN that file remains present and unchanged

### Requirement: Non-Functional — Performance

The built site SHOULD score Lighthouse ≥90 (performance, accessibility) on landing + one guide, and MUST emit valid HTML with zero console errors for search/theme flows.

#### Scenario: No console errors

- GIVEN built site served
- WHEN navigating landing → guide → search → toggle
- THEN console shows zero errors
