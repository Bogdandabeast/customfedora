#!/usr/bin/env bash
set -euo pipefail

# Fix permissions on overlay-managed scripts only
OVERLAY_DIR="${OVERLAY_DIR:-/tmp/files}"
SCRIPTS_DIR="$OVERLAY_DIR/usr/bin"

if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo "Skipping permissions: $SCRIPTS_DIR not found"
    exit 0
fi

for script in "$SCRIPTS_DIR"/*; do
    [[ -f "$script" ]] || continue
    if [[ -x "$script" ]]; then
        echo "Permissions OK: $script"
    else
        chmod 755 "$script"
        echo "Fixed permissions: $script"
    fi
done
