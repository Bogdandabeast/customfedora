# Proposal: docs-hugo-site

## Intent

Future maintainer answers "add package/repo/systemd unit or debug build" without reverse-engineering `recipe.niri.yml` + `files/system/`. `docs/` is Omarchy dump; `README.md` is template — no BlueBuild recipe→module→files→Containerfile (generated) or CachyOS kernel (`tsflags=noscripts`+`depmod`) docs.

## Scope

### In Scope
- Hugo site at `site/` — **Hextra primary + Hugo Book fallback**, offline FlexSearch, dark mode
- GH Pages: `peaceiris/actions-hugo@v3` (extended 0.128.x+) + `actions/deploy-pages` OIDC (`site/public`), trigger `site/**`
- IA (`cognitive-doc-design`): `concepts/` x3 (bluebuild, atomic, repo-structure), `guides/` x6 (add-package/repo-copr/system-file/systemd-service, kernel-cachyos, debug-build), `reference/` x3 (recipe-anatomy, modules-catalog, troubleshooting)
- Port `docs/fedora_migrations/` → appendix stub; `docs/README.md` stub; `README.md` Pages badge; `just docs-serve` wrapper

### Out of Scope
- Docsy/Lotus, versioned docs, i18n/Algolia, deleting `docs/`, `recipes/common/` reconnection

## Capabilities

### New Capabilities
- `docs-site`: Hugo site, theme, IA, content conventions, search
- `docs-publishing`: Pages workflow, build isolation, link check

### Modified Capabilities
- None — `openspec/specs/` empty

## Approach

Hextra as Hugo Module (`hugo.yaml`, `hugo --minify --source site`, Tailwind via Hugo Pipes — no Node, verify in design). Content theme-agnostic (`hint`/`callout` compatible) → Book fallback = one-line module swap (pinned `go.mod`, CI tests without Node). `site/` preserves `docs/`; `docs.yml` `on.push.paths: [site/**]` avoids `build.yml` `**.md` ignore. If Hextra regresses → Book.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `site/` | New | `hugo.yaml`, `go.mod`, `content/`, `assets/` |
| `.github/workflows/docs.yml` | New | Hugo extended + Pages deploy |
| `README.md` | Modified | Pages badge/link |
| `docs/README.md` | Modified | Archived → `site/` stub |
| `docs/` | Untouched | Kept as appendix source |
| `recipes/*.yml`, `files/system/` | Read-only | Source material |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Hextra re-requires Node | Med | Pin `go.mod`; CI without Node; Book fallback |
| `docs/` vs `site/` confusion | Med | Stub + `README.md` link |
| Content rot (recipes drift) | High | PR checklist; optional `check-docs.sh` |
| Hugo not installed | Low | `just docs-serve`; install docs |
| `**.md` ignore shadows Pages | Low | `docs.yml` scoped to `site/**` |

## Rollback Plan

Revert `site/` + `docs.yml` commit; disable Pages in Settings. `README.md` revert needs no image rebuild (`**.md` ignored). No `docs/` loss — never overwritten. If `gh-pages` branch, delete it.

## Dependencies

- `peaceiris/actions-hugo@v3` (extended), `actions/deploy-pages` + `upload-pages-artifact`
- Hugo extended 0.128.x+, Go modules

## Success Criteria

- [ ] `hugo --minify --source site` builds locally + CI without Node
- [ ] Push `site/**` deploys to Pages; does NOT trigger `bluebuild` job
- [ ] IA exists with Quick path/Details/Checklist shape (3+6+3 pages)
- [ ] Offline search for `COPR`/`scx`/`kernel` <1s
- [ ] `README.md` links Pages; `docs/README.md` redirects
