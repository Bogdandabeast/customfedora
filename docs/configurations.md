# Omarchy Configuration System

Omarchy uses a template-based configuration system that allows for easy deployment and dynamic theming.

## Configuration Structure

Configurations are organized into two main directories:

- **`default/`**: Contains the default settings and templates. These are used as the baseline for all installations.
- **`config/`**: Contains static configurations that do not change based on themes.

## Theming Mechanism

One of the most powerful features of Omarchy is its dynamic theming system:

1. **Templates**: Many configuration files in `default/themed/` use the `.tpl` extension.
2. **Placeholders**: These files contain placeholders like `{{ accent }}` or `{{ background }}`.
3. **Color Definitions**: Each theme (located in `themes/*/colors.toml`) defines the actual values for these placeholders.
4. **Processing**: The `install/config/theme.sh` script reads the selected theme's `colors.toml`, replaces the placeholders in the `.tpl` files, and writes the final configuration to `~/.config/`.

## Application Process

Configurations are deployed during the installation process via scripts in `install/config/`:

1. **`config.sh`**: Handles the basic copying of files from `default/` and `config/` to the user's home directory.
2. **`theme.sh`**: Processes the themed templates as described above.
3. **System Scripts**: Specialized scripts (e.g., `timezones.sh`, `xcompose.sh`) handle root-level configurations in `/etc/`.
4. **Hardware Scripts**: `install/config/hardware/` applies specific tweaks based on the detected hardware.
