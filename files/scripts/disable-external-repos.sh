#!/usr/bin/env bash
set -Eeuo pipefail

# List of external repo files to disable
REPOS=(
    "docker-ce.repo"
    "vstudio.repo"
    "zed.repo"
    "cloudflare-warp.repo"
)

for repo in "${REPOS[@]}"; do
    repo_path="/etc/yum.repos.d/${repo}"
    if [[ -f "$repo_path" ]]; then
        sed -i 's/^enabled=.*/enabled=0/g' "$repo_path"
        echo "Disabled repo: $repo"
    fi
done
