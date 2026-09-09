# Archive Report — docs-hugo-site

**Change:** `docs-hugo-site` — Hugo + Hextra site at `site/`, IA 3+6+3, offline FlexSearch, Pages deploy
**Archived:** 2026-09-09 → `openspec/changes/archive/2026-09-09-docs-hugo-site/`
**Verdict at archive:** PASS WITH WARNINGS — 13/13 requirements proven, 18/18 tasks done, 0 CRITICAL, 3 WARNING (W1–W3)
**Source of truth now:** `openspec/specs/docs-site/spec.md` + `openspec/specs/docs-publishing/spec.md`

## Quick path — what changed and why it matters

Future maintainer no longer reverse-engineers `recipe.niri.yml` + `files/system/` to answer "how to add a package/repo/systemd unit or debug a build." Docs site at `site/` is source-of-truth with Hextra (Hugo Modules, no Node), 12 content pages in cognitive-doc-design shape, offline search, dark mode; Pages deploy via OIDC is isolated (`site/**` only); `docs/` legacy preserved as appendix stub. Change was high-line-count (850–1100) delivered as 3 stacked slices to keep review under 400 lines each.

**Verify → Archive gate:** `hugo --minify --source site` 24 pages without Node, `just docs-check` (IA + headings + idempotency), `site/public/en.search-data.json` contains COPR/scx/kernel, all gates PASS.

## Details

| Topic | Decision |
|-------|----------|
| **Scope** | New capabilities `docs-site` (site, theme, IA, search) + `docs-publishing` (Pages, isolation, link check). No existing specs modified — `openspec/specs/` was empty. |
| **Architecture** | Hextra primary via Hugo Modules (`site/go.mod` v0.12.3), Hugo Pipes (vendored Tailwind, no Node), Book fallback = `hugo.yaml`/`go.mod` swap. Pages `peaceiris/actions-hugo@v3` extended 0.165 + `deploy-pages@v4` OIDC. Site root `site/` preserves `docs/`. |
| **Delivery** | `stacked-to-main`: PR1 scaffold+CI → PR2 concepts+reference (3+3) → PR3 guides (6)+badge/stub+checks. 18/18 tasks, each slice <400 lines, autonomous rollback (`git revert`). |
| **Verification** | PASS WITH WARNINGS 2026-09-09. Build/idempotency/badget+stub proven at runtime (`hugo --minify`, `just docs-check`, sha256 `f4468b8665f…` identical, invalid YAML exit 1). 2 SHOULD items deferred non-blocking (Lighthouse ≥90, deploy <3min). |
| **Warnings carried** | W1 version drift `v0.12.3/0.165` vs spec `v0.9.x/0.128.x` + `callout` vs `hint` shim needed for Book. W2 trigger scope `build.yml` `**.md` only — `site/hugo.yaml` non-md push triggers both workflows (1-line fix: add `site/**` to `paths-ignore`). W3 E2E search/dark proven via config+JS+index, not Playwright (manual proof). |
| **Conventions** | RFC 2119 MUST/SHOULD, Given/When/Then scenarios, 400-line review budget, `stacked-to-main` chain strategy. |

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| `docs-site` | **Created** | 7 requirements (Hugo root/config, theme Hextra+Book fallback, IA 3+6+3, content shape Quick→Details→Checklist→Next step, offline search+dark, legacy preservation, performance) + 12 scenarios → `openspec/specs/docs-site/spec.md` |
| `docs-publishing` | **Created** | 6 requirements (Pages deploy OIDC, trigger isolation, local `just docs-serve`, badge+stub entry points, link integrity lychee non-blocking, idempotency+rollback) + 11 scenarios → `openspec/specs/docs-publishing/spec.md` |

No existing specs merged — empty baseline, no destructive delta. If future change modifies these, match requirements by `### Requirement: <name>` and preserve unmentioned ones. `rules.archive: Warn before merging destructive deltas` — no warning needed here.

**Filesystem sync:** `openspec/changes/docs-hugo-site/specs/docs-site/spec.md` → `openspec/specs/docs-site/spec.md` (3985 B) and `.../docs-publishing/spec.md` → `.../docs-publishing/spec.md` (3206 B) — direct copy as delta IS full spec when main absent (per `sdd-archive` § Step 2).

## Archive Contents

Active folder moved — audit trail preserved intact:

- [x] `proposal.md` — intent, scope 3+6+3 IA, approach Hextra modules, rollback plan, risks (5)
- [x] `specs/docs-site/spec.md` — 7 req delta (copied to main)
- [x] `specs/docs-publishing/spec.md` — 6 req delta (copied to main)
- [x] `design.md` — 5 arch decisions, data flow, file table (13 rows, phase=build-time, CI rebuild=No), contracts, rollout
- [x] `tasks.md` — 18/18 checked (Phase 1 5/5, Phase 2 5/5, Phase 3 4/4, Phase 4 4/4) + workload forecast High/Yes/stacked-to-main + work units table
- [x] `verify-report.md` — PASS WITH WARNINGS, build/test evidence table, 13-req compliance matrix, design coherence, issues W1-W3/S1-S2
- [x] `apply-progress.md` — PR3 cumulative file list (26 files), deviations (pin drift, budget 394 lines, lychee inline vs job)
- [x] `exploration.md` + `explore.md` — BlueBuild/Atomic context, IaC constraints
- [x] `site/` reality check — `hugo.yaml` (baseURL `bogdandabeast.github.io/customfedora`, min 0.146.0, Hextra), `go.mod` v0.12.3, `content/` IA 3+6+3+`_index.md`, `assets/css/custom.css`, `.github/workflows/docs.yml` (paths `site/**`, OIDC), `justfile` (`docs-serve`/`docs-check`), `README.md` badge, `docs/README.md` archived stub, `docs/fedora_migrations/` intact

Active directory no longer present:

```
openspec/changes/docs-hugo-site/  → (moved)
openspec/changes/archive/2026-09-09-docs-hugo-site/  ✅
```

## Source of Truth Updated

`openspec/specs/` now reflects new behavior — future changes MUST build on these:

- `openspec/specs/docs-site/spec.md` — Hugo root no-Node build, theme boundary, IA counts, shape, search/dark, legacy
- `openspec/specs/docs-publishing/spec.md` — Pages OIDC workflow, trigger isolation, local dev wrapper, badge/stub, lychee, idempotency

Verify sync: `site/content` counts 3/6/3, headings `## Quick path`→`## Details`→`## Checklist`→`## Next step` in all 12 pages, `go.mod` hextra present, `site/public/en.search-data.json` searchable — matches spec.

## SDD Cycle Complete

Planned → designed → tasked (chained PRs) → implemented (3 slices, no Node) → verified (PASS WITH WARNINGS, no CRITICAL) → **archived**. Ready for next change.

**Engram lineage (hybrid audit trail):**

| Artifact | Engram observation | Filesystem |
|----------|--------------------|------------|
| proposal | #228 `sdd/docs-hugo-site/proposal` | `proposal.md` |
| spec (concatenated + deltas) | #229 `sdd/docs-hugo-site/spec` + delta files | `specs/docs-site/spec.md`, `specs/docs-publishing/spec.md` |
| design | #230 `sdd/docs-hugo-site/design` | `design.md` |
| tasks | #231 `sdd/docs-hugo-site/tasks` (snapshot PR2) — superseded by filesystem 18/18 | `tasks.md` (final 18/18) |
| apply-progress | #232 `sdd/docs-hugo-site/apply-progress` (PR2) + filesystem `apply-progress.md` (PR3 final 10957 B) | `apply-progress.md` |
| verify-report | #233 `sdd/docs-hugo-site/verify-report` | `verify-report.md` |
| archive-report | **this report** `sdd/docs-hugo-site/archive-report` | `archive-report.md` (this file) |

> Note: Engram `tasks`/`apply-progress` are PR2 snapshots; filesystem holds PR3-final 18/18 — archive uses filesystem as ground truth, Engram as cross-session trace.

## Checklist — Archive Verification

- [x] Main specs updated correctly (created, not merged — empty baseline)
- [x] Change folder moved to `openspec/changes/archive/2026-09-09-docs-hugo-site/`
- [x] Archive contains all artifacts (proposal, specs, design, tasks 18/18, verify, apply-progress, exploration)
- [x] Active changes directory no longer has `docs-hugo-site`
- [x] `openspec/specs/` updated — future spec reads pick up docs-site/publishing
- [x] `rules.archive` applied — no destructive merge, no warn needed

## Next step

1. **Queue follow-up PR (low priority, ≤10 lines):** add `site/**` to `build.yml` `paths-ignore` (W2) + add `layouts/shortcodes/callout.html` shim aliasing `hint` for Book fallback (W1). Both reduce drift without reopening specs.
2. **Optional maintenance:** add `just docs-e2e` (serve `site/public` + curl `en.search-data.json` for `COPR`) and Lighthouse CI non-blocking (`SHOULD` gates S1/W3) — next iteration.
3. **This change is closed.** Start next SDD change with `openspec/specs/docs-site` and `docs-publishing` as established source of truth — do not recreate; propose deltas against them.

---
*Archive: sdd-archive sub-agent, 2026-09-09, cognitive-doc-design shape (Quick path → Details → Checklist → Next step). Hybrid mode: Engram lineage + filesystem audit trail. Config `testing.strict_tdd: false`, `verify.build_command: "docker build ."` (image) bifurcated from docs gate `hugo --minify --source site` — see verify S2.*
