#!/usr/bin/env bash
set -Eeuo pipefail

# Remove external repo files entirely after packages are installed
REPOS=(
    "/etc/yum.repos.d/docker-ce.repo"
    "/etc/yum.repos.d/vstudio.repo"
    "/etc/yum.repos.d/zed.repo"
    "/etc/yum.repos.d/_copr"*.repo
)

for repo in "${REPOS[@]}"; do
    # Expand globs and remove matching files
    for f in $repo; do
        if [[ -f "$f" ]]; then
            rm -f "$f"
            echo "Removed repo: $f"
        fi
    done
done

# Verify no external repos remain enabled
echo "Verifying no external repos are enabled..."
if ! dnf repolist --enabled >/dev/null 2>&1; then
    echo "ERROR: dnf repolist --enabled failed" >&2
    exit 1
fi
if dnf repolist --enabled | grep -qE '(docker-ce|vscode|zed|copr)'; then
    echo "ERROR: Some external repos are still enabled!" >&2
    dnf repolist --enabled | grep -E '(docker-ce|vscode|zed|copr)' >&2
    exit 1
fi
echo "All external repos successfully removed."
