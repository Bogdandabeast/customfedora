#!/usr/bin/env bash
set -Eeuo pipefail

# Install Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add brew to PATH for this script
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Prevent auto-update during formula installs
export HOMEBREW_NO_AUTO_UPDATE=1

# Install formulae
brew install node npm bun
