# Product: Terminal Custom Setup

## Why This Project Exists

Setting up a full development terminal environment on a fresh Nobara 42 / Fedora-based system is:

- Time-consuming: Many packages, fonts, themes, dotfiles, and GUI configs must be installed and wired together.
- Error-prone: Manual steps are easy to forget or perform inconsistently between machines or fresh installs.
- Hard to reproduce: Without a single source of truth, different systems drift apart in configuration and tooling.

This repository provides a **single, version-controlled source of truth** for the user’s terminal and development environment, plus scripts to restore it with minimal manual effort.

## Problems It Solves

1. **Manual configuration drift**

   - Problem: After months of tweaking shell settings, fonts, themes, and editor configs, it becomes difficult to recreate the same environment on a new machine.
   - Solution: Store all important dotfiles, fonts, and application configs in [`assets/`](../../assets:1) and restore them via scripted installation.

2. **Repetitive setup on new systems**

   - Problem: Each fresh install of Nobara/Fedora requires the same sequence of installing packages, configuring shells, terminals, and tools.
   - Solution: Provide a master orchestrator [`setup.sh`](../../setup.sh:1) that runs the necessary scripts in [`scripts/`](../../scripts:1) to perform core setup, enhancements, and app installations.

3. **Inconsistent tooling across machines**

   - Problem: Workflows depend on a specific combination of tools (Zsh, Starship, Atuin, Kitty, tmux, power tools, VS Code, Qdrant, Godot, etc.), which may not be installed or configured identically.
   - Solution: Centralize installation and configuration for all key tools so each machine can be brought to a consistent state.

4. **Loss of editor and GUI app preferences**

   - Problem: Editor settings (VS Code), Godot editor configuration, and other GUI preferences are easy to lose and hard to reconstruct from memory.
   - Solution: Capture those settings under [`assets/vscode/`](../../assets/vscode:1) and [`assets/godot/`](../../assets/godot:1), then restore them via dedicated setup scripts.

## How It Should Work

### Typical Flow

1. User performs a **fresh install** of Nobara 42 or another Fedora-based distro.
2. User clones this repo and runs:

   ```bash
   ./setup.sh
   ```

3. [`setup.sh`](../../setup.sh:1) orchestrates:
   - **Terminal setup** via [`scripts/terminal_setup.sh`](../../scripts/terminal_setup.sh:1) (handles both core setup and optional enhancements)
   - **VS Code** via [`scripts/vscode_setup.sh`](../../scripts/vscode_setup.sh:1)
   - **Qdrant** via [`scripts/qdrant_setup.sh`](../../scripts/qdrant_setup.sh:1)
   - **Godot** via [`scripts/godot_setup.sh`](../../scripts/godot_setup.sh:1)
   - **Apps** (Chrome, Dropbox, Discord, Obsidian, Anki, Calibre, Super Productivity) via [`scripts/apps_setup.sh`](../../scripts/apps_setup.sh:1)
   - **OneDrive** via [`scripts/onedrive_setup.sh`](../../scripts/onedrive_setup.sh:1) (multi-account support)
   - **EasyEffects** via [`scripts/easyeffects_setup.sh`](../../scripts/easyeffects_setup.sh:1) (audio presets)
   - **Packet Tracer** via [`scripts/packettracer_setup.sh`](../../scripts/packettracer_setup.sh:1) when the .deb is available
   - **Antigravity Rules** via [`scripts/antigravity_setup.sh`](../../scripts/antigravity_setup.sh:1) (AI Agent Rules)
   - Optional **Vietnamese input** via [`scripts/input_setup.sh`](../../scripts/input_setup.sh:1)

4. Scripts:
   - Install required packages with `dnf` (and other mechanisms where needed).
   - Copy dotfiles, fonts, and configuration directories from [`assets/`](../../assets:1) (overwrites without backup).
   - Set Zsh as default shell, configure Kitty, tmux, Starship, Atuin, and power tools.
   - Install VS Code and extensions (settings are NOT restored to avoid storing secrets).
   - Restore Godot editor configuration.
   - Install and configure supporting tools like Qdrant and selected desktop apps.
   - Restore audio processing presets via EasyEffects for reproducible speaker/headphone tuning.

5. After scripts complete, the user:
   - Logs out/in (for shell change).
   - Uses post-setup instructions from [`README.md`](../../README.md:1) (e.g., tmux plugins, optional Catppuccin Starship theme).

### Modes and Options

- **Default (Full)**: `./setup.sh` (runs all standard components).
- **Explicit Full**: `./setup.sh --full` (same as default, useful for clarity).
- **Exclusive Mode**: Run specific components only by passing their flags.
  - Example: `./setup.sh --vscode` (installs ONLY VS Code).
  - Example: `./setup.sh --terminal` (runs ONLY terminal setup).
- **OneDrive setup**: `./setup.sh --onedrive` (interactive setup for one or more OneDrive accounts).
- **Vietnamese support**: `./setup.sh --vietnamese` (installs ibus-bamboo input method).
- **Selective skipping**: In default mode, skip specific parts via `--skip-vscode`, `--skip-qdrant`, `--skip-godot`, `--skip-apps`, `--skip-easyeffects`, `--skip-packettracer`, `--skip-antigravity`.


## User Experience Goals

1. **One-command bootstrap**

   - Primary UX goal: A single command should bring a fresh Nobara/Fedora install to a familiar, productive terminal environment.
   - The user should not need to remember all individual packages or configuration steps.

2. **Minimal interaction**

   - Setup should run mostly unattended after entering sudo credentials.
   - Scripts should avoid unnecessary prompts and use non-interactive installs where possible.

3. **Overwrite semantics**

   - Setup overwrites existing configs without creating backups.
   - The repo (`assets/`) is the single source of truth—to change config, edit the repo and re-run setup.
   - Fonts and configs are installed to user-level locations, minimizing system-wide risk.

4. **Consistency across machines**

   - Running the same version of this repository should produce nearly identical terminal and tooling behavior on different machines.
   - Rerunning scripts should be idempotent enough not to break an existing installation.

5. **Discoverability of features**

   - [`README.md`](../../README.md:1) documents:
     - Available scripts and options.
     - What gets installed by each script.
     - Post-enhancement steps and key aliases/keybindings.
   - Users can run individual scripts (e.g., only VS Code setup or only Qdrant) when desired.

6. **Personal but portable**

   - The environment is tailored to the user’s preferences (themes, fonts, tools) while remaining portable via git.
   - All critical customizations live in this repository rather than being scattered across the filesystem.
