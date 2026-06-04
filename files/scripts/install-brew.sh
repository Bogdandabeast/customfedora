#!/usr/bin/env bash
set -Eeuo pipefail

# Install Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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
