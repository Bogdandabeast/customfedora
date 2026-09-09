# Delta for docs-publishing

## ADDED Requirements

### Requirement: Pages Deploy Workflow

The system MUST provide `.github/workflows/docs.yml` using `peaceiris/actions-hugo@v3` (extended 0.128.x+) and `actions/deploy-pages` OIDC (`pages: write`, `id-token: write`) that runs `hugo --minify --source site` and deploys `site/public` without Node.

#### Scenario: Push deploys without Node

- GIVEN push to `main` touching `site/**`
- WHEN `docs.yml` runs without Node
- THEN Hugo installs, build succeeds, `deploy-pages` publishes `site/public`

#### Scenario: Broken config fails deploy

- GIVEN `site/hugo.yaml` has invalid YAML
- WHEN `docs.yml` runs
- THEN Hugo step fails, no Pages deployment

### Requirement: Trigger and Build Isolation

The system MUST trigger `docs.yml` only on `site/**` and `.github/workflows/docs.yml`. Push touching only `site/**` MUST NOT trigger `build.yml`; push touching only `recipes/**` MUST NOT trigger `docs.yml`.

#### Scenario: Site-only push triggers docs only

- GIVEN push changes only `site/content/guides/add-package.md`
- WHEN triggers evaluated
- THEN `docs.yml` runs, `build.yml` does not

#### Scenario: Recipe-only push skips docs

- GIVEN push changes only `recipes/recipe.niri.yml`
- WHEN triggers evaluated
- THEN `docs.yml` does not run

### Requirement: Local Development Wrapper

The system MUST provide `just docs-serve` (wrapping `hugo server --source site` with live reload) and document Hugo extended installs (`brew`/`dnf`, warn Fedora package may be stale). Root `package.json` MUST NOT gain Hugo deps.

#### Scenario: Local serve starts

- GIVEN Hugo extended installed
- WHEN `just docs-serve` runs
- THEN server serves `http://localhost:1313` with live reload

#### Scenario: Missing Hugo is actionable

- GIVEN Hugo not installed
- WHEN `just docs-serve` runs
- THEN error points to install docs

### Requirement: Entry Points — Badge and Stub

`README.md` MUST link to Pages site and show Pages badge. `docs/README.md` MUST be stub stating `docs/` is archived Omarchy mapping and linking to `site/`/Pages.

#### Scenario: README links Pages

- GIVEN `README.md` on GitHub
- WHEN badge/link clicked
- THEN navigates to deployed Hugo site

#### Scenario: Stub redirects

- GIVEN reader opens `docs/README.md`
- WHEN reading first paragraph
- THEN it says "archived" and links to `site/`/Pages URL

### Requirement: Link Integrity

The system SHOULD run `htmltest`/`lychee` on `site/public` in CI (non-blocking initially) and SHOULD include PR checklist item for docs impact when `recipes/recipe.niri.yml` or `files/system/` changes.

#### Scenario: Broken link reported

- GIVEN guide links to `../reference/nonexistent.md`
- WHEN checker runs on `site/public`
- THEN broken link is reported

### Requirement: Non-Functional — Idempotency and Rollback

Deploy MUST be idempotent (same `site/**` SHA → identical `site/public` hashes) and SHOULD complete within 3 min. Rollback MUST be revert of `site/`+`docs.yml` commit + Pages disable, with `docs/` lossless.

#### Scenario: Rebuild hashes identical

- GIVEN same `site/**` commit built twice
- WHEN `hugo --minify --source site` runs each time
- THEN `site/public` file hashes match
