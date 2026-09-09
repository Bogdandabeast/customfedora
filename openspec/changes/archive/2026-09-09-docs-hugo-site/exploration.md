# Exploration: docs-hugo-site — Hugo docs site for future maintenance

## Current State

**Answer first:** `customfedora` is a BlueBuild IaC repo for Fedora Atomic (ostree) that builds a declarative Niri + Noctalia desktop image. Its documentation today does NOT serve future-maintainer needs — `docs/` is a legacy Omarchy migration dump and `README.md` is still the BlueBuild template.

**How the system works today (relevant to docs):**
- **Build pipeline:** `recipes/recipe.niri.yml` (base-main + explicit DE packages) and `recipes/recipe.niri-cachyos.yml` (same + kernel swap via `containerfile` snippet) are the only active recipes validated/built by `.github/workflows/build.yml` matrix (`validate` → `bluebuild` with `blue-build/github-action@v1.12.0`). Weekly netinst ISO via `iso.yml`.
- **Recipe anatomy:** YAML recipe → BlueBuild modules (`files`, `dnf`, `script`, `brew`, `systemd`, `justfiles`, `default-flatpaks`, `containerfile`, `signing`, `initramfs`). Common modules in `recipes/common/*.yml` (currently disconnected from active recipes). `modules/` empty — custom logic lives in `files/system/`.
- **Files overlay:** `files/system/` maps to `/` in the image (`etc/niri/config.kdl`, `etc/sddm.conf.d/theme.conf`, `usr/lib/systemd/system/{scx,brew-install*}.service`, `usr/bin/noctalia-lid-*.sh`). `config.kdl` defines Noctalia startup + keybinds; SDDM is the display manager (conflicts with `getty@tty1`). `scx.service` is disabled (placeholder until CachyOS recipe ships it — bug fixed in `c27c587`).
- **Toolchain:** `bun@1.3.4` + `husky` pre-commit (`bun run validate` → `bluebuild validate`). `Containerfile` is generated (`bluebuild generate`) not hand-edited. No test/lint infra (`openspec/config.yaml` → `testing.strict_tdd: false`, no coverage/linter). `openspec/` is initialized (schema spec-driven, empty `specs/`).
- **Docs debt:** `docs/fedora_migrations/{default,config,themes}` + `mapping.md` describe Omarchy→Fedora mapping, not BlueBuild concepts. No page explains "how to add a COPR/repo/package", "recipe execution order", "files vs modules", "how to debug a failed `dnf`/`script` module", or "kernel swap pitfalls (`tsflags=noscripts` + `depmod`)". A future self must reverse-engineer recipes and Containerfile.

> Progressive disclosure: details above are the happy-path for the *site builder*; edge cases (CachyOS `depmod` dance, Secure Boot `sbsign`, netinst ISO 2 GiB limit) will be documented in deep-dive pages, not the landing.

---

## Affected Areas

- `docs/` — **legacy migration dump**. MUST NOT be overwritten in-place; archive or move to `docs/archive/omarchy-migration/` before new site. Contains `configurations.md`, `packages.md`, `fedora_migrations/` (do not lose — useful as source for "legacy mapping" appendix).
- `README.md` — **template still**. Affected as the docs entrypoint: should gain a one-liner + badge linking to the Hugo site (once on GitHub Pages), and stop being the "real docs".
- `recipes/recipe.niri.yml` + `recipes/recipe.niri-cachyos.yml` — **primary source material** for docs (recipe anatomy, module order, dnf repo examples, kernel swap `containerfile` snippet). Not mutated by this change, but must be *explained* accurately.
- `recipes/common/` + `modules/` — **explains decoupling**; docs must clarify why they are currently unused/incorrect vs active recipes (prevents future confusion).
- `files/system/` + `.bluebuild-scripts_*/` + `files/scripts/` — **overlay semantics** (`files` module `source: system → destination: /`, `files/usr/etc/` vs `files/system/etc/` historical confusion). Docs must map this.
- `.github/workflows/build.yml` (paths-ignore `**.md`) + `iso.yml` — **GH Pages integration point**. New `docs.yml` workflow needed; must not trigger image builds (already ignored). Pages deploy needs `ghcr.io`/`cosign` perms untouched.
- `Containerfile` + `cosign.pub` — **derived artifact**. Docs must stress "do not hand-edit; `bluebuild generate` regenerates".
- `package.json` (bun scripts) + `.husky/pre-commit` — **integration risk**: if Hugo adds `npm`/`bun` deps, decide `docs-site/package.json` vs root. Avoid polluting root.
- `openspec/config.yaml` + `openspec/specs/` — **SDD convention source**; docs site structure should mirror `cognitive-doc-design` shape (Quick path / Details / Checklist) so specs stay scannable.
- New path `site/` (or `docs-site/` or `website/`) — **new Hugo site root**. Must not collide with legacy `docs/`; GitHub Pages `publish_dir: site/public` or `docs-site/public`.

---

## Approaches

### Approach evaluation lens (Recognition over Recall)

| Criterion | Why it matters for "future self at 2am fixing a build" |
|-----------|--------------------------------------------------------|
| **Maintenance** | Solo maintainer; prefers `hugo --minify` over `npm ci` |
| **Search** | Fast offline FlexSearch/Lunr for "COPR / package / scx" |
| **Versioning** | Nice-to-have later (image date tag), not MVP |
| **GH Pages deploy** | Must be a 30-line workflow, not a second CI project |
| **Build complexity** | `build.yml` already ignores `**.md`; docs build must stay isolated |
| **Hugo prerequisite** | `hugo: command not found` today — pin `hugo extended` in CI and document local install |

### 1. Hugo Book (alex-shpak/hugo-book)

Lightweight, zero-JS-docs theme. Content in `content/docs/`, menu from file tree, FlexSearch offline search, dark mode, no Node required.

- **Pros:** Minimum cognitive load — file tree IS navigation. Zero Node/npm; `hugo extended` alone. Fastest to maintain (1 contributor = best fit). Search works offline with zero config. Clean printable pages. Battle-tested (~2k stars, stable).
- **Cons:** Fewest bells/whistles — no built-in version switcher, limited landing-page components (need shortcodes). Less "corporate" visual polish vs Docsy/Hextra.
- **Effort:** Low — theme as Hugo Module (`hugo mod get`), 1 workflow file, `hugo new site site` + copy content.
- **Template footprint:** `site/config.toml` + `site/content/_index.md` + `site/assets/_custom.scss` (optional).

### 2. Hextra (imfing/hextra)

Modern Tailwind docs theme (Hugo + Tailwind via Hugo Pipes). Lauded for speed, built-in search, code-copy, collapsible sidebar, excellent mobile + SEO. No `npm install` on recent versions (Tailwind via `hugo --minify` with PostCSS vendored).

- **Pros:** Best aesthetics/UX per line of config. Excellent DX: callouts, tabs, math, mermaid built-in. Offline FlexSearch. Verbose docs on theming. Active maintenance (2024-2026).
- **Cons:** Heavier than Book (Tailwind pipeline still needs Hugo extended >=0.122 and sometimes Node 18 for PostCSS depending on version — verify). Newer (less long-term stability data). Requires Go modules + vendored theme; slightly steeper first setup.
- **Effort:** Low/Medium — `hugo mod init` + `hextra` module, config is `hugo.yaml` with `params` map. CI is still `hugo --minify` (no extra npm if using vendored build).
- **Template footprint:** `hugo.yaml` + `content/` + `assets/css/custom.css` (Tailwind overrides).

### 3. Docsy (google/docsy)

Enterprise docs theme (Bootstrap + SCSS). Used by Kubernetes, Knative. Supports versioning, multi-language, Algolia, Swagger.

- **Pros:** Most feature-complete: version dropdown, `docsy` landing blocks, mature i18n, strong search options. Good if roadmap includes versioned image docs (`42`/`43`/`44`).
- **Cons:** Highest maintenance: requires `npm install`, SCSS compilation, `postcss`, frequent break on Hugo upgrades. Repo size + build time ↑ (npm 200MB). Overkill for single-maintainer project. Style overrides are fragile (`assets/scss/_variables_project.scss`). CI needs `actions/setup-node` + `npm ci`.
- **Effort:** Medium/High — `npm` + `hugo mod get github.com/google/docsy` + 3 config files. Ongoing upgrade churn.
- **Template footprint:** `config.toml` + `package.json` (npm) + `assets/` + `content/en/`.

### 4. Lotus Docs (colinwilson/lotusdocs)

Bootstrap 5 docs template, clean, with search and code tabs. Lighter than Docsy, more components than Book.

- **Pros:** Good balance: nicer landing than Book without Docsy's weight. Offline search, dark mode. Simpler npm than Docsy (smaller bundle).
- **Cons:** Smaller community (fewer StackOverflow answers, slower issue triage). Bootstrap means jQuery-free but still CSS heavy. Versioning less mature than Docsy.
- **Effort:** Low/Medium — similar to Hextra but with a small `package.json`.
- **Template footprint:** `config.yaml` + `content/` + `assets/scss`.

### 5. Plain Hugo + hand-rolled docs layout

Init `hugo new site` and build a minimal docs layout (list + single + search partial) without external theme.

- **Pros:** Total control, zero theme debt. Teaches Hugo fundamentals (good for SDD "concepts > code").
- **Cons:** You rebuild what Book/Hextra already solved (TOC, breadcrumbs, search, mobile nav). Search requires wiring FlexSearch manually. Highest upfront content-structuring cost. No upstream bug fixes.
- **Effort:** Medium — you write `layouts/_default/{baseof,list,single}.html` + `layouts/partials/search.html`.
- **Template footprint:** Full `layouts/` ownership.

> Chunking note: Options 1/2/4 are variants of "theme as Hugo Module" — the real fork is **lightweight Book/Hextra vs heavyweight Docsy vs bespoke**.

---

## Recommendation

**Recommended: Hextra as primary, Hugo Book as fallback — do NOT choose Docsy for MVP.**

**Why Hextra wins for `customfedora`:**
1. **Future-self ergonomics (cognitive load):** Hextra's content model (one file = one page, weight-ordered, callouts like `{{< callout type="warning" >}}`) maps perfectly to the required guides: "BlueBuild concepts", "Recipe anatomy", "Add a package/repo/COPR", "Kernel swap deep-dive", "Debug a failed build", "Systemd/files overlay". A contributor adds a `.md` and it appears — no `weight` gymnastics or `_index.md` inheritance to learn.
2. **Maintenance vs polish tradeoff:** Docsy's polish costs npm + SCSS + upgrade churn — unacceptable for a solo OS image repo where image CI is already the bottleneck. Hextra gives 90% of Docsy's polish with Book-like maintenance. Its Tailwind build is now vendored in Hugo Pipes (verify in `design.md` — pin `peaceiris/actions-hugo@v3` with `extended: true` and test `hugo --minify` without Node).
3. **GH Pages deploy:** Both Book and Hextra deploy with the same 25-line workflow (`actions/checkout` → `peaceiris/actions-hugo` → `hugo --minify --source site` → `peaceiris/actions-gh-pages`). Docsy needs `setup-node` + `npm ci` before Hugo (2× CI time, more cache keys).
4. **Search/versioning/offline:** Offline FlexSearch built-in covers the "where is scx_lavd documented?" case instantly. Versioning can be added later by branching `content/` + a param — not worth paying Docsy's versioning tax now.
5. **Integration:** Place Hugo site at `site/` (preferred) — keeps legacy `docs/` intact for archival reference, avoids the `**/*.md` `paths-ignore` ambiguity (GH Pages workflow triggers only on `site/**`). Alternative `docs-site/` also valid; `site/` is shortest and matches `hugo new site site` convention.

**If Hextra's PostCSS/Node requirement regresses:** fallback to **Hugo Book** — same content structure ports with trivial front-matter changes (`title`/`weight` identical). Keep `content/` theme-agnostic (no Hextra shortcodes in mvp bodies except callouts — abstract via `{{< hint warning >}}` which Book also supports via `hints`).

**Site IA proposal (progressive disclosure):**

```
site/content/
  _index.md                         # Quick path: install/rebase + "I want to…"
  concepts/
    bluebuild.md                    # recipes → modules → files → Containerfile (generated)
    atomic-ostree.md                # rpm-ostree, layering vs flatpak/brew
    repo-structure.md               # map: recipes/, files/system/, .bluebuild-scripts_/
  guides/
    add-package.md                  # dnf install + skip-broken + verification
    add-repo-copr.md                # repos.files vs repos.copr, key pitfalls
    add-system-file.md              # files module + overlay paths
    add-systemd-service.md          # systemd module + /usr/lib/systemd conventions
    kernel-cachyos.md               # deep-dive: tsflags=noscripts, depmod, Secure Boot
    debug-build.md                  # validate → generate → build locally, read logs
  reference/
    recipe-anatomy.md               # annotated recipe.niri.yml (chunked table)
    modules-catalog.md              # table: module | purpose | example in repo
    troubleshooting.md              # checklist from scripts/test-*.sh
```

Each guide follows `cognitive-doc-design` shape: **Quick path** (3 steps) → **Details** (table) → **Checklist** → **Next step** link.

**Tooling pinning:**
- Hugo `extended` `0.128.x`+ (last verified with Hextra/Book) via `peaceiris/actions-hugo@v3`.
- GH Pages via `peaceiris/actions-gh-pages@v4` with `publish_dir: ./site/public` (or deploy via `actions/deploy-pages` + artifact if repo prefers OIDC).
- Local dev: document `bun` stays for image validation; `hugo` installed via `brew install hugo` (Fedora `sudo dnf install hugo` is often stale — warn).

---

## Risks

- **Theme Node drift (Medium):** Hextra's Tailwind pipeline may re-introduce a Node requirement on upgrade. *Mitigation:* pin Hextra version in `go.mod`, test `hugo --minify` without Node in CI, document fallback to Book. Add `design.md` decision record.
- **Legacy `docs/` confusion (Medium):** Newcomers find two doc roots (`docs/` vs `site/`). *Mitigation:* add `docs/README.md` stub ("archived Omarchy mapping → see site/") and link from root `README.md`. Do not delete `docs/fedora_migrations` until site appendix ports it.
- **Content rot (High):** Recipe-annotated pages (`add-package`, `kernel-cachyos`) drift when `recipe.niri.yml` changes (dnf list, COPR). *Mitigation:* proposal must require a "docs impact" checklist on recipe PRs; consider a `scripts/check-docs.sh` that diffs `recipe.niri.yml` `install.packages` vs `reference/recipe-anatomy.md` code block (lightweight, not blocking).
- **Hugo not installed locally (Low):** Contributors run `bun` but not `hugo`. *Mitigation:* document one-liner installs (Fedora, macOS) and provide `just docs-serve` / `bun run docs:serve` wrapper; do not add Hugo to root `package.json` unless via `site/package.json`.
- **Build.yml `**.md` paths-ignore shadows docs workflow (Low):** `push` to `site/**.md` currently would NOT trigger image build (desired), but also must trigger docs deploy. *Mitigation:* docs workflow `on.push.paths: ["site/**", ".github/workflows/docs.yml"]` scoped independently — image build ignore does not affect it.
- **No tests to gate docs (Low):** `openspec/config.yaml` has no linter. Broken internal links go unnoticed. *Mitigation:* spec `design.md` adds `htmltest` or `lychee` link checker as optional CI step (non-blocking first iteration).
- **Cosign/Base image pinning docs staleness (Low):** `Containerfile` `ARG BASE_IMAGE` SHA and `cosign.pub` change; docs referencing them go stale. *Mitigation:* reference with `<!-- replace with: grep BASE_IMAGE Containerfile -->` marker, not hardcoded SHA in prose.

---

## Ready for Proposal

**Yes — ready.** Scope is bounded, no external dependencies beyond Hugo extended, and the preferred approach (Hextra → Book fallback) avoids the heavy Docsy path.

**What the orchestrator should tell the user:**
- Confirm **Hextra as MVP target** (with Book as fallback) and **`site/` as Hugo root** (preserves legacy `docs/`). Ask: does the user want `site/` or `docs-site/` naming, and does the GH Pages source need to be `gh-pages` branch or `actions/deploy-pages` artifact?
- Flag **two open questions for `proposal.md`:** (1) GH Pages deployment style (classic `peaceiris/actions-gh-pages` vs official `actions/deploy-pages`) and (2) whether to archive legacy `docs/` immediately or keep as appendix source for one iteration.
- No blocking ambiguity — proposal can draft requirements (`sdd-spec`) using the IA above and the `cognitive-doc-design` template.

