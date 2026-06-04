#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -euo pipefail

# Get the latest RPM download URL from GitHub API
RPM_URL=$(curl -fsSL https://api.github.com/repos/TibixDev/winboat/releases/latest \
  | grep "browser_download_url" \
  | grep ".rpm" \
  | cut -d '"' -f 4)

if [[ -z "$RPM_URL" ]]; then
    echo "ERROR: Could not find RPM download URL for winboat" >&2
    exit 1
fi

# Print the URL being used for download
echo "Downloading RPM from: $RPM_URL"

# Download the RPM file to /tmp directory
curl -fsSL -o /tmp/winboat.rpm "$RPM_URL"

echo "Installing RPM with dnf..."
dnf install -y /tmp/winboat.rpm
