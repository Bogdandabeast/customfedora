#!/bin/bash

set -e

# --- Configuration ---
REPO_DIR="$(pwd)/Gentleman.Dots"
OBSIDIAN_PATH="/var/home/bobbie/Documentos/Obsidian Vault"
USER_HOME="$HOME"

echo "🚀 Starting Gentleman installation on Fedora..."

# 1. Base System Dependencies
echo "📦 Base system dependencies already present."


# 2. Homebrew Dependencies
echo "🍺 Installing Homebrew packages..."
# Ensure brew is in PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew install fish carapace zoxide atuin starship fzf \
             nvim node npm fd ripgrep coreutils bat \
             lazygit tree-sitter tmux

# 3. Iosevka Term Nerd Font
echo "🔠 Installing Iosevka Term Nerd Font..."
mkdir -p "$USER_HOME/.local/share/fonts"
wget -O "$USER_HOME/.local/share/fonts/Iosevka.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.zip
unzip -o "$USER_HOME/.local/share/fonts/Iosevka.zip" -d "$USER_HOME/.local/share/fonts/"
fc-cache -fv

# 4. Alacritty Configuration
echo "🖥️ Configuring Alacritty..."
mkdir -p "$USER_HOME/.config/alacritty"
cp "$REPO_DIR/alacritty.toml" "$USER_HOME/.config/alacritty/alacritty.toml"

# 5. Fish Shell Configuration
echo "🐟 Configuring Fish..."
mkdir -p "$USER_HOME/.config/fish"
cp -rf "$REPO_DIR/GentlemanFish/fish/"* "$USER_HOME/.config/fish/"
mkdir -p "$USER_HOME/.config"
cp "$REPO_DIR/starship.toml" "$USER_HOME/.config/starship.toml"

# 6. Tmux Configuration
echo "📟 Configuring Tmux..."
mkdir -p "$USER_HOME/.tmux/plugins"
if [ ! -d "$USER_HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$USER_HOME/.tmux/plugins/tpm"
fi
cp -r "$REPO_DIR/GentlemanTmux/plugins/"* "$USER_HOME/.tmux/plugins/"
cp "$REPO_DIR/GentlemanTmux/tmux.conf" "$USER_HOME/.tmux.conf"

# Install Tmux plugins (non-interactive)
tmux new-session -d -s plugin_install 'tmux source-file ~/.tmux.conf; tmux run-shell ~/.tmux/plugins/tpm/bin/install_plugins'
sleep 5
tmux kill-session -t plugin_install

# 7. Neovim Configuration
echo "Configuring Neovim..."
mkdir -p "$USER_HOME/.config/nvim"
cp -r "$REPO_DIR/GentlemanNvim/nvim/"* "$USER_HOME/.config/nvim/"

# Update Obsidian Path
echo "📓 Setting Obsidian path to $OBSIDIAN_PATH..."
# Replace the default path with the user's vault pathq
sed -i "s|path = os.getenv(\"HOME\") .. \"/.config/obsidian\"|path = \"$OBSIDIAN_PATH\"|" "$USER_HOME/.config/nvim/lua/plugins/obsidian.lua"

# 8. Default Shell
echo "🐚 To set Fish as your default shell, run this command manually:
sudo chsh -s $(which fish) $USER"


echo "✅ Installation complete! Please restart your terminal or log out and back in."
