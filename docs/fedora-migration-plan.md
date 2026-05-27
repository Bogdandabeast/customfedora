# 🚀 Fedora $\rightarrow$ Omarchy Migration Guide

This guide provides a manual process to replicate the Omarchy experience on a minimal Fedora Linux installation. Since Omarchy is natively built for Arch Linux, several manual adaptations are required.

## 🛠️ Prerequisites

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/anomalyco/omarchy.git ~/omarchy
   ```

2. **Install Base Build Tools**:
   ```bash
   sudo dnf groupinstall "Development Tools" "C Development Tools and Libraries"
   sudo dnf install git curl wget nodejs npm pnpm python3-pip
   ```

---

## 📦 Step 1: Software Installation (DNF Mapping)

Since Fedora uses `dnf`, you must map Arch packages to Fedora counterparts.

### Core Interface
- **Hyprland**: `sudo dnf copr enable solopasha/hyprland && sudo dnf install hyprland`
- **Waybar**: `sudo dnf install waybar`
- **Mako**: `sudo dnf install mako`
- **Terminals**: `sudo dnf install foot kitty` (Ghostty must be compiled from source).

### Essential Utilities
Run the following to install the "Omarchy core" toolset:
```bash
sudo dnf install bat fzf ripgrep zoxide eza btop starship fd dust
```

### Applications
It is recommended to use **Flatpak** for these to maintain consistency with the Omarchy experience:
- `chromium`, `obsidian`, `kdenlive`, `libreoffice`, `spotify`

---

## ⚙️ Step 2: Omarchy-Specific Components

### 1. Omarchy Walker
The launcher is a custom binary. You must:
- Navigate to the walker source in `~/omarchy/` (if available as source) and compile it.
- Otherwise, identify the binary in the distribution and place it in `~/.local/bin/`.

### 2. Neovim Setup
- Install Neovim: `sudo dnf install neovim`
- Apply Omarchy config:
  - Copy `~/omarchy/config/nvim/` to `~/.config/nvim/`
  - Execute the installation logic found in `~/omarchy/install/packaging/nvim.sh`.

### 3. NPM AI Tools
Install the AI CLI wrappers defined in `~/omarchy/install/packaging/npm.sh`:
```bash
npm install -g @openai/codex @google/gemini-cli playwright-cli
```

---

## 📂 Step 3: Configuration Deployment

You will need to manually move the "DNA" of Omarchy to your home directory.

### Static Configurations
```bash
cp -r ~/omarchy/config/* ~/.config/
```

### Base/Default Configurations
```bash
cp -r ~/omarchy/default/* ~/.config/
```

### Shell Environment
- **Bashrc**: `cp ~/omarchy/default/bashrc ~/.bashrc`
- **Bash Functions**: Copy all files from `~/omarchy/default/bash/` to `~/.local/share/omarchy/bash/`.

---

## 🎨 Step 4: Manual Theming (The TPL Process)

Omarchy uses `.tpl` files that must be processed.

1. **Choose a Theme**: Pick a `colors.toml` from `~/omarchy/themes/`.
2. **Process Templates**:
   For every file in `~/omarchy/default/themed/*.tpl`, replace the placeholders (e.g., `{{ accent }}`) with the hex codes from your chosen `colors.toml` and save them as standard config files.
   - **Example**: `waybar.css.tpl` $\rightarrow$ `~/.config/waybar/style.css`
   - **Example**: `foot.ini.tpl` $\rightarrow$ `~/.config/foot/foot.ini`

---

## 🖥️ Step 5: System Integration

### SDDM (Login Manager)
1. Install SDDM: `sudo dnf install sddm`
2. Deploy Theme: Copy `~/omarchy/default/sddm/` to `/usr/share/sddm/themes/`.
3. Configure: Edit `/etc/sddm.conf` to point to the Omarchy theme.

### Plymouth (Boot Splash)
1. Install Plymouth: `sudo dnf install plymouth`
2. Deploy Theme: Copy `~/omarchy/default/plymouth/` to `/usr/share/plymouth/themes/`.

---

## 🗺️ Repository Ingredient Map

Use this table to know exactly which files from the `omarchy` folder are used in each step.

| Migration Step | Repository Source Path | Target Destination |
| :--- | :--- | :--- |
| **Core Tools** | `install/omarchy-base.packages` | (Reference for `dnf install`) |
| **NPM Tools** | `install/packaging/npm.sh` | (Reference for `npm install`) |
| **NVIM Setup** | `install/packaging/nvim.sh` & `config/nvim/` | `~/.config/nvim/` |
| **Static Configs** | `config/` | `~/.config/` |
| **Base Configs** | `default/` | `~/.config/` |
| **Shell Config** | `default/bashrc` & `default/bash/` | `~/.bashrc` & `~/.local/share/omarchy/bash/` |
| **Theming** | `themes/*/colors.toml` & `default/themed/*.tpl` | `~/.config/` (processed) |
| **Login/Boot** | `default/sddm/` & `default/plymouth/` | `/usr/share/sddm/` & `/usr/share/plymouth/` |
