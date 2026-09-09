# Apply Progress — docs-hugo-site

**Change**: docs-hugo-site
**Mode**: Standard (strict_tdd false)
**Slice**: PR 1 — Scaffold+CI (Phase 1 + parts of Phase 3)
**Chain strategy**: stacked-to-main
**Date**: 2026-09-09

## Completed Tasks

- [x] 1.1 Create `site/hugo.yaml` — baseURL, module.imports [hextra], params.search + theme.toggle (dark mode)
- [x] 1.2 Create `site/go.mod`/`go.sum` pin `hextra v0.12.3`; `hugo mod tidy` without Node
- [x] 1.3 Create `site/assets/css/custom.css` minimal overrides (Hugo Pipes, no Node)
- [x] 1.4 Update `.gitignore` ignore `site/public/` and `site/resources/` (+ .hugo_build.lock)
- [x] 1.5 Verify `hugo --minify --source site` without Node → `site/public/index.html`; invalid config fails non-zero
- [x] 2.1 Create `site/content/_index.md` landing "I want to …" → 6 guide placeholders; title/weight front matter
- [x] 3.1 Create `.github/workflows/docs.yml` — actions-hugo@v3 extended 0.165 + deploy-pages OIDC (pages:write id-token:write), artifact site/public, triggers site/** only
- [x] 3.2 Create `justfile` docs-serve/docs-build/docs-check; missing Hugo → actionable error; no root package.json deps

## Files Changed

| File | Action | What |
|------|--------|------|
| `site/hugo.yaml` | Created | baseURL `https://bogdandabeast.github.io/customfedora/`, module hextra, search flexsearch forward, theme system toggle, menu Concepts/Guides/Reference |
| `site/go.mod` | Created | `module github.com/bogdandabeast/customfedora/site`, require hextra v0.12.3 |
| `site/go.sum` | Created | sums for v0.12.3 |
| `site/assets/css/custom.css` | Created | minimal overrides, --hextra-max-content-width |
| `site/content/_index.md` | Created | landing with I want to → 6 placeholders, Quick path/Details/Checklist table, callout |
| `site/content/docs/_index.md` | Created | placeholder section |
| `site/content/concepts/_index.md` | Created | placeholder |
| `site/content/guides/_index.md` | Created | placeholder |
| `site/content/reference/_index.md` | Created | placeholder |
| `.gitignore` | Modified | ignore site/public/, site/resources/, .hugo_build.lock |
| `justfile` | Created | docs-serve with hugo missing guard, docs-build, docs-check |
| `.github/workflows/docs.yml` | Created | OIDC Pages deploy, paths site/**, publish_dir site/public |

## Verification

- `hugo --minify --source site` (pwd site) → 0, emits `site/public/index.html` (35K), no Node error — PASS
- Invalid YAML append `invalid: [:` → `hugo --minify` exit 1 — PASS
- `just docs-serve` with PATH stripped → actionable "hugo not found, brew/dnf" — PASS
- `docs.yml` triggers: `on.push.paths: ["site/**", ".github/workflows/docs.yml"]` and `pull_request` same; `build.yml` has `paths-ignore: "**.md"` → site/** push docs only, recipes/** skips docs — PASS (static check)
- `go mod tidy` without Node — PASS

## Deviations from Design

- **Hextra pin**: spec says v0.9.x + Hugo 0.128.x min. Implemented v0.12.3 + Hugo 0.146 min (0.165 in CI) because Hugo 0.165 (current brew) breaks v0.9.7 RSS template (`.Site.Author.email`). v0.12.3 is maintained, still vendored Tailwind via Hugo Pipes (no Node), and min version still satisfies "0.128.x+" (0.146 > 0.128, 0.165 used). Book fallback still one-line swap.
- **languageCode**: removed deprecated top-level `languageCode: en-us` (Hugo 0.158 deprecated) → use `defaultContentLanguage: en` only; no functional change.
- **go version**: go.mod is 1.27 (installed) vs Hextra's 1.21 — compatible, no impact.
- **Section placeholders**: added `site/content/docs/_index.md` plus concepts/guides/reference placeholders to let Hextra render cleanly in PR1. Not in original Phase 1 but required for valid build and navigation; will be superseded by full 3+6+3 in PR2/3.

## Issues Found

- None blocking. Brew `hugo` 0.165 + `go` 1.27 installed during apply (Fedora had no go/hugo). Future CI must use setup-go 1.22 per workflow (pinned) — local uses 1.27, compatible.

## Remaining Tasks

- [ ] 2.2 Create concepts 3 pages (bluebuild, atomic-ostree, repo-structure)
- [ ] 2.3 Create reference 3 pages (recipe-anatomy, modules-catalog, troubleshooting)
- [ ] 2.4 Create guides 6 pages (add-package, add-repo-copr, add-system-file, add-systemd-service, kernel-cachyos, debug-build)
- [ ] 2.5 Verify IA counts + headings order
- [ ] 3.3 Modify README.md badge
- [ ] 3.4 Modify docs/README.md stub
- [ ] 4.1-4.4 Verification / Quality Gates (lychee, isolation E2E, search/dark, idempotency, Book swap)

## Workload / PR Boundary

- Mode: stacked PR slice (PR 1 of 3, stacked-to-main)
- Current work unit: Scaffold+CI
- Boundary: starts from empty site/ → ends after hugo builds + workflow + justfile, before core content
- Estimated review budget impact: 269 lines staged (177 scaffold + 92 CI) — under 400, clean rollback `git revert 2737210 1783cab`
- Rollback: revert two commits, disable Pages; `docs/` untouched

## Status

8/18 tasks complete (Phase 1 + 2.1 + 3.1/3.2). Ready for next batch (PR 2 — Concepts+Reference). PR 1 is autonomous, verifiable, rollback-safe.

## Next Recommended

sdd-apply PR 2 (Phase 2 concepts+reference) stacked on PR 1, or manual review of scaffold before continuing.
