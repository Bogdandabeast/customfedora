#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

# Get the latest RPM download URL from GitHub API
RPM_URL=$(curl -s https://api.github.com/repos/TibixDev/winboat/releases/latest \
  | grep "browser_download_url" \
  | grep ".rpm" \
  | cut -d '"' -f 4)

# Print the URL being used for download
echo "Downloading RPM from: $RPM_URL"

# Download the RPM file to /tmp directory
curl -L -o /tmp/winboat.rpm "$RPM_URL"

echo "Installing RPM with dnf..."
sudo dnf install -y /tmp/winboat.rpm
