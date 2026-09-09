# customfedora — justfile
# Requires: just, hugo extended >=0.128.x, go
# See: https://gohugo.io/installation/ (brew install hugo / dnf install hugo)
#      Fedora package may be stale — prefer brew or binary release

# Serve docs with live reload (http://localhost:1313)
docs-serve:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    if ! command -v hugo >/dev/null 2>&1; then
        echo "ERROR: hugo not found." >&2
        echo "Install Hugo extended >=0.128:" >&2
        echo "  brew install hugo          # macOS/Linux brew" >&2
        echo "  dnf install hugo           # Fedora (may be stale)" >&2
        echo "  https://gohugo.io/installation/" >&2
        exit 1
    fi
    hugo server --source site --buildDrafts --disableFastRender

# Build docs (offline, no Node) — mirrors CI
docs-build:
    hugo --minify --source site

# Check docs build without Node (CI parity)
docs-check:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    echo "==> hugo --minify --source site"
    hugo --minify --source site
    test -f site/public/index.html || { echo "missing site/public/index.html" >&2; exit 1; }
    echo "OK: site/public/index.html exists"
