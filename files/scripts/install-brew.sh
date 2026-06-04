#!/usr/bin/env bash
set -Eeuo pipefail

# Install Homebrew (pinned commit + checksum verification)
BREW_COMMIT="280cbc9adffcbdef15dd1c9d991ef2d1dd7cfc9c"
EXPECTED_CHECKSUM="f3e91784ffeda32bc397de7acc1154724cc47522a459c9ac656cca176eeba457"
BREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/${BREW_COMMIT}/install.sh"
TMP_INSTALL="$(mktemp)"

curl -fsSL "$BREW_INSTALL_URL" -o "$TMP_INSTALL"
ACTUAL_CHECKSUM="$(sha256sum "$TMP_INSTALL" | cut -d' ' -f1)"
if [[ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]]; then
    echo "ERROR: Homebrew install script checksum mismatch!" >&2
    echo "Expected: $EXPECTED_CHECKSUM" >&2
    echo "Got:      $ACTUAL_CHECKSUM" >&2
    rm -f "$TMP_INSTALL"
    exit 1
fi

NONINTERACTIVE=1 /bin/bash "$TMP_INSTALL"
rm -f "$TMP_INSTALL"

# Add brew to PATH for this script
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Prevent auto-update during formula installs
export HOMEBREW_NO_AUTO_UPDATE=1

# Create profile.d entry so brew is in PATH for all users at runtime
cat > /etc/profile.d/brew.sh <<'PROFILE'
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
PROFILE

# Install formulae
brew install node npm bun
