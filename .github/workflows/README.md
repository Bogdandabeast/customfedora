# GitHub Actions (Bun-based CI)

The workflows in this directory are powered by `bun` via the official
`oven-sh/setup-bun` action (v2, bun 1.3.4). The `package.json` declares
`packageManager: bun@1.3.4`, and the lockfile (`bun.lock`) is the source of
truth for reproducible installs.

## Workflows

- `bluebuild` (`build.yml`) — daily/weekly image builds (GHCR + signing).
- `bluebuild-iso` (`iso.yml`) — weekly ISO generation (Sunday 07:00 UTC).
