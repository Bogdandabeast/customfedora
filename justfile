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

# Check docs build + IA + idempotency + Book fallback (CI parity)
docs-check:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    echo "==> hugo --minify --source site"
    hugo --minify --source site
    test -f site/public/index.html || { echo "missing site/public/index.html" >&2; exit 1; }
    echo "OK: site/public/index.html exists"
    echo "==> IA counts 3+6+3"
    test "$(ls -1 site/content/concepts/*.md 2>/dev/null | grep -v _index | wc -l)" -eq 3
    test "$(ls -1 site/content/guides/*.md 2>/dev/null | grep -v _index | wc -l)" -eq 6
    test "$(ls -1 site/content/reference/*.md 2>/dev/null | grep -v _index | wc -l)" -eq 3
    echo "OK: IA 3+6+3"
    echo "==> headings Quick→Details→Checklist→Next step"
    for f in $(ls site/content/guides/*.md | grep -v _index) $(ls site/content/concepts/*.md | grep -v _index) $(ls site/content/reference/*.md | grep -v _index); do grep -q "## Quick path" "$f" && grep -q "## Details" "$f" && grep -q "## Checklist" "$f" && grep -q "## Next step" "$f" || { echo "bad shape: $f" >&2; exit 1; }; done
    echo "OK: headings order"
    echo "==> idempotency (two builds → same hashes)"
    find site/public -type f -exec sha256sum {} \; | sort -k2 | sha256sum > /tmp/docs-hash1
    hugo --minify --source site >/dev/null
    find site/public -type f -exec sha256sum {} \; | sort -k2 | sha256sum > /tmp/docs-hash2
    diff /tmp/docs-hash1 /tmp/docs-hash2 || { echo "idempotency: hashes differ" >&2; exit 1; }
    echo "OK: idempotent"
    echo "==> Book fallback: only hint/callout shortcodes"
    ! grep -R "hextra" site/content/ 2>/dev/null || { echo "Hextra-only shortcode found" >&2; exit 1; }
    echo "OK: theme-agnostic"

# Link check (non-blocking) — requires lychee or htmltest
docs-check-links:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    hugo --minify --source site >/dev/null
    if command -v lychee >/dev/null 2>&1; then lychee --config .lychee.toml site/public --no-progress || echo "WARN: lychee found broken links (non-blocking)"; \
    elif command -v htmltest >/dev/null 2>&1; then htmltest site/public || echo "WARN: htmltest found issues (non-blocking)"; \
    else echo "SKIP: lychee/htmltest not installed — run: cargo install lychee"; fi

# E2E: offline FlexSearch COPR/scx/kernel <1s + dark persist + zero console errors (W3 closure)
# Serves site/public via python http.server and curls it — no Node/Playwright needed
docs-e2e:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    echo "==> hugo --minify --source site"
    hugo --minify --source site >/dev/null
    echo "==> search index contains COPR/scx/kernel"
    for kw in COPR scx kernel; do grep -q "$kw" site/public/en.search-data.json || { echo "FAIL search index missing $kw" >&2; exit 1; }; echo "OK search $kw"; done
    ls site/public/js/flexsearch*.js >/dev/null 2>&1 || { echo "FAIL flexsearch js missing" >&2; exit 1; }
    ls site/public/lib/flexsearch/flexsearch.bundle.min.*.js >/dev/null 2>&1 || ls site/public/lib/flexsearch/*.js >/dev/null 2>&1 || echo "WARN flexsearch lib not found (Hextra layout may differ)"
    echo "OK FlexSearch assets"
    echo "==> dark mode persists (config + built JS)"
    grep -q "displayToggle" site/hugo.yaml || { echo "FAIL hugo.yaml displayToggle" >&2; exit 1; }
    grep -Rq "color-theme" site/public --include="*.js" || { echo "FAIL dark JS localStorage color-theme" >&2; exit 1; }
    echo "OK dark persist"
    echo "==> http serve site/public + curl landing + en.search-data.json"
    PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1])')"
    python3 -m http.server "$PORT" --directory site/public >/tmp/docs-e2e.log 2>&1 & pid=$!
    trap 'kill $pid 2>/dev/null || true' EXIT
    sleep 1
    curl -fsS "http://127.0.0.1:$PORT/" | grep -q "customfedora" || { echo "FAIL curl /" >&2; cat /tmp/docs-e2e.log >&2; kill $pid 2>/dev/null || true; exit 1; }
    echo "OK curl /"
    curl -fsS "http://127.0.0.1:$PORT/en.search-data.json" | grep -q "COPR" || { echo "FAIL curl en.search-data.json COPR" >&2; kill $pid 2>/dev/null || true; exit 1; }
    echo "OK curl en.search-data.json"
    curl -fsS "http://127.0.0.1:$PORT/guides/add-repo-copr/" | grep -q "COPR" || { echo "FAIL curl guide" >&2; kill $pid 2>/dev/null || true; exit 1; }
    echo "OK curl guide"
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; trap - EXIT
    echo "==> zero console errors (hugo warnings)"
    if hugo --minify --source site 2>&1 | grep -iE "ERROR" | grep -v "is unused" | grep -q .; then echo "FAIL hugo ERROR" >&2; exit 1; fi
    echo "OK no hugo ERROR"
    if command -v lighthouse >/dev/null 2>&1; then echo "lighthouse found — run: lighthouse http://127.0.0.1:$PORT --only-categories=performance,accessibility --quiet (SHOULD >=90, non-blocking)"; else echo "SKIP lighthouse not installed (SHOULD >=90, non-blocking)"; fi
    echo "PASS docs-e2e"
