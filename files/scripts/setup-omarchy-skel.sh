#!/bin/bash
set -e

echo "Setting up Omarchy skeleton..."

# Create config directory
mkdir -p /etc/skel/.config

# Copy all from config/ to .config/
cp -r /omarchy/config/* /etc/skel/.config/

# Copy directories from default/ to .config/ (skipping special ones)
for item in /omarchy/default/*; do
    name=$(basename "$item")
    if [ -d "$item" ] && [ "$name" != "bash" ] && [ "$name" != "sddm" ] && [ "$name" != "plymouth" ]; then
        cp -r "$item" /etc/skel/.config/
    fi
done

# Copy bashrc to .bashrc
cp /omarchy/default/bashrc /etc/skel/.bashrc

# Copy bash functions
mkdir -p /etc/skel/.local/share/omarchy/bash
cp -r /omarchy/default/bash/* /etc/skel/.local/share/omarchy/bash/

echo "Omarchy skeleton setup complete."
