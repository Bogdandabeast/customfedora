# Tasks: docs-hugo-site

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 850–1100 (12 content pages + scaffold + workflow) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 (stacked to main, ~280–380 lines each) |
| Delivery strategy | auto-forecast |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Scaffold + theme + landing + CI | PR 1 | Base `main`; `hugo.yaml`, `go.mod`, `assets/`, `docs.yml`, `.gitignore`, `justfile`; verify build without Node |
| 2 | Concepts (3) + Reference (3) | PR 2 | Base `main` after PR 1; IA slice; verifies shape + counts |
| 3 | Guides (6) + entry points + checks | PR 3 | Base `main` after PR 2; badge/stub, `just docs-serve`, `lychee`, search/dark QA |

## Phase 1: Foundation / Scaffold

- [x] 1.1 Create `site/hugo.yaml` — `baseURL`, `module.imports: [hextra]`, `params.search` + `darkMode` enabled (build-time)
- [x] 1.2 Create `site/go.mod`/`go.sum` pin `hextra v0.9.x`; run `hugo mod tidy` without Node
- [x] 1.3 Create `site/assets/css/custom.css` minimal overrides (Hugo Pipes, no Node)
- [x] 1.4 Update `.gitignore` ignore `site/public/` and `site/resources/`
- [x] 1.5 Verify `hugo --minify --source site` without Node → `site/public/index.html`; invalid config fails non-zero

## Phase 2: Core Content — IA 3+6+3

- [x] 2.1 Create `site/content/_index.md` landing "I want to …" → 6 guides; `title`/`weight` front matter
- [ ] 2.2 Create `site/content/concepts/bluebuild.md`, `atomic-ostree.md`, `repo-structure.md` — shape Quick→Details→Checklist→Next step; only `hint`/`callout`
- [ ] 2.3 Create `site/content/reference/recipe-anatomy.md`, `modules-catalog.md`, `troubleshooting.md` — same shape; no hardcoded SHA/`cosign.pub`
- [ ] 2.4 Create `site/content/guides/add-package.md`, `add-repo-copr.md`, `add-system-file.md`, `add-systemd-service.md`, `kernel-cachyos.md`, `debug-build.md` — same shape; read-only `recipes/*.yml`
- [ ] 2.5 Verify IA counts `concepts/`=3 `guides/`=6 `reference/`=3 `_index.md` exists; headings in order

## Phase 3: Publishing / Wiring

- [x] 3.1 Create `.github/workflows/docs.yml` — `actions-hugo@v3` extended 0.128.x+ + `deploy-pages` OIDC (`pages: write`+`id-token: write`), artifact `site/public`, triggers `site/**` only
- [x] 3.2 Create `justfile` `docs-serve: hugo server --source site` live reload; missing Hugo → actionable error; no root `package.json` deps
- [ ] 3.3 Modify `README.md` add Pages badge + deploy link
- [ ] 3.4 Modify `docs/README.md` stub "archived Omarchy" → `site/`/Pages link; keep `docs/fedora_migrations/` untouched

## Phase 4: Verification / Quality Gates

- [ ] 4.1 Add `lychee`/`htmltest` on `site/public` CI non-blocking; confirm broken link reported
- [ ] 4.2 Verify isolation: `site/**` push → `docs.yml` only; `recipes/**` → `build.yml` only
- [ ] 4.3 Verify offline FlexSearch `COPR`/`scx`/`kernel` <1s, dark mode persists, zero console errors
- [ ] 4.4 Verify idempotency: same SHA rebuild → identical hashes; Book swap `hugo.yaml`/`go.mod` needs no body edits
