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
- Synced Memory Bank (product, architecture, tech, context) with current state.

## Next Steps

- Stabilize current setup and evolve configs incrementally as needed.
- Keep Memory Bank updated when new tools/scripts are added.
