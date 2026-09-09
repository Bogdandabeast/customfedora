# Design: docs-hugo-site

## Technical Approach

Isolated Hugo site at `site/` — Hextra via Hugo Modules, theme-agnostic content (`hint`/`callout` only) so Book fallback is one `hugo.yaml`/`go.mod` swap. CI: `peaceiris/actions-hugo@v3` extended 0.128+ + `deploy-pages` OIDC → `site/public`, no Node, no image rebuild.

Covers `docs-site` (site, theme, IA, search) + `docs-publishing` (Pages, isolation, link check).

## Architecture Decisions

| Decision | Option | Tradeoff | Choice |
|----------|--------|----------|--------|
| **Theme** | Hextra | Tailwind via Pipes, FlexSearch offline, polished, active 2024-26 | **Primary** |
|  | Hugo Book | Lightest, zero-JS, file-tree nav | **Fallback** — pin swap |
|  | Docsy/Lotus | Versioning but npm+SCSS, 2× CI, churn | Rejected |
|  | Hand-rolled | Full control, rebuild TOC/search | Rejected |
| **Vendoring** | Hugo Modules (`go.mod`) | Pinned, `hugo mod tidy`, no Node | **Chosen** |
|  | git submodule / npm | Drift or 200 MB Node | Rejected |
| **Pages deploy** | `actions/deploy-pages` OIDC | Official, artifact `site/public` | **Chosen** |
|  | `peaceiris/actions-gh-pages` | Branch push, simpler | Alt if OIDC disabled |
| **Site root** | `site/` | `hugo new site` convention, preserves `docs/` | **Chosen** |
| **Asset pipeline** | Hugo Pipes (vendored Tailwind) | `hugo --minify --source site` no Node | **Chosen** |

Solo maintainer needs `hugo --minify` without `npm ci`. Hextra = Docsy polish at Book cost; modules pin version.

## Data Flow

```
site/content/**/*.md ──→ hugo --minify --source site (extended + Go modules)
                              ├─→ site/public/ (HTML + FlexSearch + CSS)
                              ▼
                    docs.yml (paths: site/**) → upload-pages-artifact → deploy-pages (OIDC) → Pages
recipes/*.yml ──(read-only)──→ guides/reference (no codegen coupling)
```

## File Changes

| File | Action | Description | Phase | CI rebuild |
|------|--------|-------------|-------|------------|
| `site/hugo.yaml` | Create | `baseURL`, `module.imports: [hextra]`, search/darkMode params | build | No |
| `site/go.mod`+`go.sum` | Create | Pin Hextra `github.com/imfing/hextra v0.9.x` | build | No |
| `site/content/_index.md` | Create | Landing: "I want to …" → 6 guides | build | No |
| `site/content/concepts/*.md` | Create | 3 pages: bluebuild, atomic-ostree, repo-structure | build | No |
| `site/content/guides/*.md` | Create | 6 pages: add-package/repo-copr/system-file/systemd-service, kernel-cachyos, debug-build | build | No |
| `site/content/reference/*.md` | Create | 3 pages: recipe-anatomy, modules-catalog, troubleshooting | build | No |
| `site/assets/css/custom.css` | Create | Minimal overrides | build | No |
| `.github/workflows/docs.yml` | Create | hugo extended + deploy OIDC, triggers `site/**` only | build | No |
| `README.md` | Modify | Pages badge + link | build | No (`**.md` ignored) |
| `docs/README.md` | Modify | Stub: archived Omarchy → site/Pages link | build | No |
| `justfile` | Create | `just docs-serve` → `hugo server --source site` | build | No |
| `.gitignore` | Modify | Ignore `site/public/`, `site/resources/` | build | No |
| `docs/**` legacy | Untouched | Preserved; no deletions | — | No |
| `recipes/*.yml` etc. | Read-only | Source only, no mutation | runtime | Only if changed |

**Phase:** All `site/`+`docs.yml` = **build-time docs only** (`build.yml` ignores `**.md`; `docs.yml` ignores `recipes/**`). Zero runtime effect. Image rebuild **not required**.

## Interfaces / Contracts

- **Build:** `hugo --minify --source site` → `site/public/index.html` without Node; invalid YAML → non-zero, no deploy.
- **Content:** Front matter `title`/`weight`; headings `## Quick path` → `## Details` → `## Checklist` → `## Next step`; shortcodes `hint`/`callout` only.
- **Workflow:** `docs.yml` perms `pages: write`/`id-token: write`; artifact `site/public`; triggers `site/**`.

```yaml
# site/hugo.yaml — module import (non-obvious)
module:
  imports: [{ path: github.com/imfing/hextra }]
params: { search: { enable: true }, darkMode: { enable: true } }
```

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Build without Node → `site/public/index.html` | Local + CI |
| Integration | `site/**` triggers docs only; `recipes/**` skips it; rebuild idempotent | Trigger check + `sha256sum` compare |
| E2E | Search `COPR`/`scx`/`kernel` <1s offline; dark persists; 0 console errors | Serve `site/public` + `htmltest`/`lychee` non-blocking |

Lighthouse ≥90 SHOULD, not gate.

## Migration / Rollout

No migration. Rollout: 1) merge `site/`+`docs.yml`, enable Pages (Actions source), 2) verify CI without Node, 3) badges/stubs.

**Rollback:** Revert commit, disable Pages; `docs/` lossless; delete `gh-pages` if created. No image rebuild.

**Verification:**

- [ ] `hugo --minify --source site` without Node emits `site/public/index.html`
- [ ] `just docs-serve` → `:1313` live reload
- [ ] `site/**` push → `docs.yml` only; `recipes/**` push → `build.yml` only
- [ ] Same SHA rebuild → identical hashes; deploy <3 min
- [ ] Offline search <1s; dark toggle persists; `lychee` 0 broken links

## Open Questions

- [ ] Confirm OIDC `pages: write` allowed vs branch deploy fallback
- [ ] `justfile` vs `bun run docs:serve` — no `justfile` exists today
