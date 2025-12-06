# Context

## Current Work Focus

- Repo is stable with single-profile terminal setup, no backup pipeline, and VS Code not restoring settings.

## Recent Changes

- Simplified VS Code setup:
  - [`scripts/vscode_setup.sh`](../../scripts/vscode_setup.sh:1) only installs VS Code and extensions.
  - Removed VS Code settings/globalStorage restore to avoid storing secrets.
- Unified terminal setup into single profile:
  - [`scripts/terminal_setup.sh`](../../scripts/terminal_setup.sh:1) installs all packages + power tools in one pass.
  - Removed separate `core_setup.sh` and `enhance_terminal.sh` scripts.
  - Removed `--core`, `--minimal`, `--enhance` flags.
- Removed backup pipeline:
  - `copy_file()` in [`scripts/common.sh`](../../scripts/common.sh:1) overwrites without backup.
  - Removed `scripts/update_assets.sh` (no longer used).
  - Repo `assets/` is the single source of truth.
- Tmux plugins via TPM:
  - TPM cloned from GitHub into `~/.tmux/plugins/tpm`.
  - Removed `assets/.config/tmux/plugins` vendor directory.
  - Plugins installed by user pressing `prefix + I`.
- Fonts simplified:
  - Only CaskaydiaCove Nerd Font in [`assets/fonts/`](../../assets/fonts:1).
- Added Calibre to desktop apps installed by [`scripts/apps_setup.sh`](../../scripts/apps_setup.sh:1).
- Fixed `ibus-bamboo` repository URL in [`scripts/input_setup.sh`](../../scripts/input_setup.sh:1) (changed `home:lamlng` to `home:/lamlng`).
- Improved `ibus-bamboo` repo resolution in [`scripts/input_setup.sh`](../../scripts/input_setup.sh:1) to support Fedora 42 and Rawhide with fallback logic.
- Enhanced `ibus-bamboo` setup to automatically configure GNOME input sources and set Bamboo as default using `gsettings` and `dconf`.
- Added DNS setup script (`scripts/dns_setup.sh`) to configure Cloudflare Block Malware DNS (1.1.1.2/1.0.0.2) via `nmcli`.
- Synced Memory Bank (product, architecture, tech, context) with current state.

## Next Steps

- Stabilize current setup and evolve configs incrementally as needed.
- Keep Memory Bank updated when new tools/scripts are added.
