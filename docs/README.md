# docs/ — archived Omarchy mapping

> **Archived.** This `docs/` folder is the legacy Omarchy migration material (pre-BlueBuild) kept for reference. It is **not** the web docs.

**Canonical web docs:** [`site/`](../site/) — Hugo + Hextra site deployed to **[bogdandabeast.github.io/customfedora](https://bogdandabeast.github.io/customfedora/)** via `.github/workflows/docs.yml` (`hugo --minify --source site`, no Node). Edit `site/content/**` and run `just docs-serve`.

**Legacy contents preserved (read-only):**

- `mapping.md`, `configurations.md`, `packages.md`, `fedora-migration-plan.md`
- `fedora_migrations/` — Omarchy configs grouped by `config/`, `install/`, `themes/`, etc.

Do not delete this folder — rollback keeps `docs/` lossless. New documentation belongs in `site/content/` (IA 3+6+3: `concepts/`, `guides/`, `reference/`).
