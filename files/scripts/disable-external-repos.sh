#!/usr/bin/env bash
set -Eeuo pipefail

# List of external repo files to disable
REPOS=(
    "docker-ce.repo"
    "vstudio.repo"
    "zed.repo"
)

for repo in "${REPOS[@]}"; do
    repo_path="/etc/yum.repos.d/${repo}"
    if [[ -f "$repo_path" ]]; then
        sed -i 's/^enabled=.*/enabled=0/g' "$repo_path"
        echo "Disabled repo: $repo"
    fi
done

# Verify no external repos remain enabled
echo "Verifying no external repos are enabled..."
if ! dnf repolist --enabled >/dev/null 2>&1; then
    echo "ERROR: dnf repolist --enabled failed" >&2
    exit 1
fi
if dnf repolist --enabled | grep -qE '(docker-ce|vscode|zed)'; then
    echo "ERROR: Some external repos are still enabled!" >&2
    dnf repolist --enabled | grep -E '(docker-ce|vscode|zed)' >&2
    exit 1
fi
echo "All external repos successfully disabled."
