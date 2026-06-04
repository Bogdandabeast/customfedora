#!/usr/bin/env bash
set -euo pipefail

# Fix permissions on custom scripts in the image overlay
SCRIPTS_DIR="/usr/bin"

for script in "$SCRIPTS_DIR"/*; do
    if [[ -f "$script" && -x "$script" ]]; then
        echo "Permissions OK: $script"
    elif [[ -f "$script" ]]; then
        chmod 755 "$script"
        echo "Fixed permissions: $script"
    fi
done
