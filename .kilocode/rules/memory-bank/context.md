# Context

## Current Work Focus

- Maintaining the Memory Bank in sync with the evolving terminal setup scripts, including new integrations like OneDrive multi-account support.

## Recent Changes

- Initialized the Memory Bank (brief, product, architecture, tech).
- Added Vietnamese input support via [`scripts/input_setup.sh`](../../scripts/input_setup.sh:1).
- Added EasyEffects integration:
  - [`scripts/easyeffects_setup.sh`](../../scripts/easyeffects_setup.sh:1)
  - [`assets/.config/easyeffects`](../../assets/.config/easyeffects:1) with G560 and G435 audio presets
  - `--skip-easyeffects` flag in [`setup.sh`](../../setup.sh:1)
- Added OneDrive integration:
  - [`scripts/onedrive_setup.sh`](../../scripts/onedrive_setup.sh:1) for multi-account setup
  - `--onedrive` flag in [`setup.sh`](../../setup.sh:1)
- Refactored Terminal Setup:
  - Merged `core_setup.sh` and `enhance_terminal.sh` into [`scripts/terminal_setup.sh`](../../scripts/terminal_setup.sh:1).
  - Updated [`setup.sh`](../../setup.sh:1) to support "Exclusive Mode" and new flags (`--full`, `--core`).

## Next Steps

- Keep Memory Bank updated when new tools/scripts are added.
- Optionally document repetitive workflows (e.g., "add new tool integration") in a future [`tasks.md`](./tasks.md:1) if/when needed.