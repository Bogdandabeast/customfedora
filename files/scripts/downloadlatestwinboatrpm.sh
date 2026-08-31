#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -euo pipefail

# Get the latest RPM download URL from the current WinBoat repository.
RELEASE_JSON=$(curl -fsSL --retry 3 https://api.github.com/repos/winboat-org/winboat/releases/latest)
RPM_URL=$(jq -r 'first(.assets[] | select(.name | endswith(".rpm")) | .browser_download_url) // empty' <<< "$RELEASE_JSON")

if [[ -z "$RPM_URL" ]]; then
  echo "Error: no RPM asset found in the latest WinBoat release" >&2
  exit 1
fi

# Print the URL being used for download
echo "Downloading RPM from: $RPM_URL"

# Download the RPM file to /tmp directory
curl -fL --retry 3 -o /tmp/winboat.rpm "$RPM_URL"

echo "Installing RPM with dnf..."
dnf install -y /tmp/winboat.rpm
