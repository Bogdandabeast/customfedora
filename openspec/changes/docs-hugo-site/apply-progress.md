# Apply Progress — docs-hugo-site

**Change**: docs-hugo-site
**Mode**: Standard (strict_tdd false)
**Slice**: PR 2 — Concepts+Reference (Phase 2 partial, stacked on PR 1)
**Chain strategy**: stacked-to-main
**Date**: 2026-09-09

## Completed Tasks

- [x] 1.1 Create `site/hugo.yaml` — baseURL, module.imports [hextra], params.search + theme.toggle (dark mode)
- [x] 1.2 Create `site/go.mod`/`go.sum` pin `hextra v0.12.3`; `hugo mod tidy` without Node
- [x] 1.3 Create `site/assets/css/custom.css` minimal overrides (Hugo Pipes, no Node)
- [x] 1.4 Update `.gitignore` ignore `site/public/` and `site/resources/` (+ .hugo_build.lock)
- [x] 1.5 Verify `hugo --minify --source site` without Node → `site/public/index.html`; invalid config fails non-zero
- [x] 2.1 Create `site/content/_index.md` landing "I want to …" → 6 guide placeholders; title/weight front matter
- [x] 2.2 Create `site/content/concepts/bluebuild.md`, `atomic-ostree.md`, `repo-structure.md` — shape Quick→Details→Checklist→Next step; only `hint`/`callout`
- [x] 2.3 Create `site/content/reference/recipe-anatomy.md`, `modules-catalog.md`, `troubleshooting.md` — same shape; no hardcoded SHA/`cosign.pub`
- [x] 3.1 Create `.github/workflows/docs.yml` — actions-hugo@v3 extended 0.165 + deploy-pages OIDC (pages:write id-token:write), artifact site/public, triggers site/** only
- [x] 3.2 Create `justfile` docs-serve/docs-build/docs-check; missing Hugo → actionable error; no root package.json deps

## Files Changed (cumulative)

| File | Action | What |
|------|--------|------|
| `site/hugo.yaml` | Created (PR1) | baseURL `https://bogdandabeast.github.io/customfedora/`, module hextra, search flexsearch forward, theme system toggle |
| `site/go.mod` | Created (PR1) | `module github.com/bogdandabeast/customfedora/site`, require hextra v0.12.3 |
| `site/go.sum` | Created (PR1) | sums for v0.12.3 |
| `site/assets/css/custom.css` | Created (PR1) | minimal overrides, --hextra-max-content-width |
| `site/content/_index.md` | Modified (PR2) | landing live: Concepts/Reference → live, Guides placeholders, callout updated |
| `site/content/docs/_index.md` | Created (PR1) | placeholder section |
| `site/content/concepts/_index.md` | Created (PR1) | placeholder |
| `site/content/guides/_index.md` | Created (PR1) | placeholder |
| `site/content/reference/_index.md` | Created (PR1) | placeholder |
| `site/content/concepts/bluebuild.md` | Created (PR2) | What is BlueBuild: recipe→module→Containerfile, real snippet from recipe.niri.yml, table, Quick→Next step |
| `site/content/concepts/atomic-ostree.md` | Created (PR2) | Atomic OSTree: rebase/rollback, ro /usr, cosign.pub derivable, table vs traditional |
| `site/content/concepts/repo-structure.md` | Created (PR2) | Repo structure + flavours: base-main, niri vs niri-cachyos, files/system shared, image-version latest |
| `site/content/reference/recipe-anatomy.md` | Created (PR2) | Recipe anatomy: header fields, real 30-line snippet, order matters, bluebuild validate |
| `site/content/reference/modules-catalog.md` | Created (PR2) | Modules catalog: files/dnf/script/systemd/brew/flatpak/containerfile/initramfs/justfiles/signing with examples |
| `site/content/reference/troubleshooting.md` | Created (PR2) | Files overlay map files/system→/ + table (niri, sddm, scx) + common failures (modules.dep, Provides: kernel, ConditionPath) |
| `.gitignore` | Modified (PR1) | ignore site/public/, site/resources/, .hugo_build.lock |
| `justfile` | Created (PR1) | docs-serve with hugo missing guard, docs-build, docs-check |
| `.github/workflows/docs.yml` | Created (PR1) | OIDC Pages deploy, paths site/**, publish_dir site/public |

## Verification

- `hugo --minify --source site` → 0, emits `site/public/index.html`, no Node error — PASS (101ms, 18 pages)
- Headings order Quick→Details→Checklist→Next step in all 6 new pages — PASS (grep)
- IA counts: `concepts/`=3, `reference/`=3, `guides/`=0 (expected until PR3), `_index.md` exists — PASS
- No hardcoded cosign SHA/pub in reference pages (derivble marker only) — PASS
- `site/content/_index.md` still builds; callout updated to live — PASS
- `go mod tidy` without Node — PASS (from PR1, unchanged)
- PR2 line budget: 294 lines new content + 2-line landing edit = ~296, under 400 — PASS

## Deviations from Design

- **Hextra pin**: as in PR1 — v0.12.3 + Hugo 0.146 min (0.165 CI) vs spec v0.9.x/0.128.x; compatible, no Node (carried).
- **Spec vs slice naming**: task prompt listed `concepts/what-is-bluebuild.md` / `ostree-atomic.md` / `base-image-and-flavours.md` and `reference/files-overlay.md`; spec requires `bluebuild.md`, `atomic-ostree.md`, `repo-structure.md`, `troubleshooting.md`. Implemented spec filenames (contract) and merged requested topics into them: what-is-bluebuild→bluebuild, ostree-atomic→atomic-ostree, base-image-and-flavours + files-overlay→repo-structure + troubleshooting. Keeps IA 3+6+3 verification green.
- **Files overlay location**: requested `reference/files-overlay.md` content is in `reference/troubleshooting.md` (overlay map + failures) and `concepts/repo-structure.md` (flavour overlay scope). Avoids 4th reference page that would break IA count.
- **languageCode/go version**: as in PR1, unchanged.

## Issues Found

- None blocking. `hugo 0.165 extended` builds 6 new pages without warnings. Guides still placeholders — PR3 will fill 6.

## Remaining Tasks

- [ ] 2.4 Create guides 6 pages (add-package, add-repo-copr, add-system-file, add-systemd-service, kernel-cachyos, debug-build)
- [ ] 2.5 Verify IA counts + headings order (final: 3+6+3)
- [ ] 3.3 Modify README.md badge
- [ ] 3.4 Modify docs/README.md stub
- [ ] 4.1-4.4 Verification / Quality Gates (lychee, isolation E2E, search/dark, idempotency, Book swap)

## Workload / PR Boundary

- Mode: stacked PR slice (PR 2 of 3, stacked-to-main)
- Current work unit: Concepts+Reference (6 pages, cognitive-doc-design shape)
- Boundary: starts from PR1 scaffold (18 pages total) → ends after 6 spec-compliant pages + landing edit, before Guides
- Estimated review budget impact: ~296 lines added (294 content + 2 landing) — under 400, clean rollback `git revert HEAD` for PR2 slice; `docs/` untouched
- Rollback: revert PR2 commit(s), site still builds (PR1 scaffold remains)

## Status

10/18 tasks complete (Phase 1 + 2.1–2.3 + 3.1/3.2). Ready for next batch (PR 3 — Guides+entry points+checks). PR 2 is autonomous, verifiable, rollback-safe.

## Next Recommended

sdd-apply PR 3 (Phase 2 guides 6 + Phase 3 badges/stubs + Phase 4 checks) stacked on PR2, or verify search/dark on `site/public` before continuing.
