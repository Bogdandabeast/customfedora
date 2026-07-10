#!/usr/bin/env bash
set -Eeuo pipefail

# List of external repo files to disable
REPOS=(
    "docker-ce.repo"
    "vstudio.repo"
    "zed.repo"
    "cloudflare-warp.repo"
    "niri.repo"
    "noctalia.repo"
)

for repo in "${REPOS[@]}"; do
    repo_path="/etc/yum.repos.d/${repo}"
    if [[ -f "$repo_path" ]]; then
        rm -f "$repo_path"
        echo "Removed repo file: $repo"
    fi
done

# Disable Copr repos explicitly (backup)
echo "Disabling Copr repositories..."
dnf copr disable -y yalter/niri || true
dnf copr disable -y lionheartp/Hyprland || true


# Verify no external repos remain enabled
echo "Verifying no external repos are enabled..."
if dnf repolist --enabled 2>/dev/null | grep -qE '(docker-ce|vscode|zed|cloudflare|niri|noctalia)'; then
    echo "ERROR: Some external repos are still enabled!" >&2
    dnf repolist --enabled | grep -E '(docker-ce|vscode|zed|cloudflare|niri|noctalia)' >&2
    exit 1
fi
echo "All external repos successfully disabled."
