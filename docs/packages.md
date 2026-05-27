# Omarchy Package Management

Omarchy employs a layered approach to software installation to ensure consistency across different hardware and user needs.

## Installation Mechanisms

### 1. System Package Lists
The primary method for bulk installation is via `.packages` files, which are processed by `pacman` or `yay`.

- **Core Packages (`install/omarchy-base.packages`)**:
  Contains the essential desktop environment and core utilities. This includes:
  - Window Manager: `hyprland`, `hyprlock`, `hypridle`.
  - UI Components: `waybar`, `omarchy-walker`, `mako`, `swayosd`.
  - Core CLI Tools: `bat`, `fzf`, `ripgrep`, `zoxide`, `eza`, `fd`, `dust`, `btop`.
  - Applications: `chromium`, `obsidian`, `kdenlive`, `libreoffice-fresh`, `spotify`.

- **Other/Optional Packages (`install/omarchy-other.packages`)**:
  Contains base system components and hardware-specific drivers.
  - Base: `base`, `base-devel`, `linux-headers`.
  - Hardware: Drivers for NVIDIA, Intel, Apple T2, and Surface devices.

### 2. Specialized Installation Scripts
Located in `install/packaging/`, these scripts handle complex installations that go beyond simple package management.

- **NPM Packages (`npm.sh`)**: Installs AI-related CLI tools and utilities via `npm`/`pnpm` (e.g., `@openai/codex`, `@google/gemini-cli`).
- **Neovim (`nvim.sh`)**: Executes `omarchy-nvim-setup` to install LazyVim and the Omarchy-specific Neovim configuration.
- **Web Apps (`webapps.sh`)**: Creates custom wrappers for web services like ChatGPT and GitHub to make them behave like native applications.
- **Fonts (`fonts.sh`)**: Installs custom typography, including the `omarchy.ttf` font.
- **TUI Shortcuts (`tuis.sh`)**: Sets up specific shortcuts and configurations for TUIs like `lazydocker`.
