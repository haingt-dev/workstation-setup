# Technologies

## Languages and Scripting

- Bash shell scripts for all automation logic:
  - Orchestration in [`setup.sh`](../../setup.sh:1)
  - Shared utilities in [`scripts/common.sh`](../../scripts/common.sh:1)
  - Feature-specific installers under [`scripts/`](../../scripts:1)

## Target Platform

- Linux distributions:
  - Nobara 42 (primary target)
  - Other Fedora-based distributions (expected to work with minor or no changes)
- Requirements:
  - User account with `sudo` privileges
  - Internet access for package repositories and external installers

## Core System Tools

- Package manager:
  - `dnf` for system packages and most tooling installs
- Shell and terminal:
  - `zsh` as the default interactive shell
  - `bash` as the scripting shell for all setup scripts
  - `kitty` as the primary GPU-accelerated terminal emulator
- Multiplexer:
  - `tmux` for session management and plugins via TPM
- Containers:
  - `podman` and `podman-compose` for containerized services
- Fonts:
  - CaskaydiaCove Nerd Font under [`assets/fonts/`](../../assets/fonts:1)
- Input Method:
  - `ibus-bamboo` (Vietnamese) installed via [`scripts/input_setup.sh`](../../scripts/input_setup.sh:1)

## Developer Productivity Stack

- Prompt and shell utilities:
  - Starship prompt (`starship`) with custom config under [`assets/.config/starship/`](../../assets/.config/starship:1)
  - Atuin (`atuin`) for shell history sync/search
  - Zsh plugins:
    - `zsh-autosuggestions`
    - `zsh-syntax-highlighting`
    - `zsh-autocomplete` (via DNF when available, else GitHub clone under `$HOME/.local/share/zsh/plugins`)
- Power tools (installed by [`scripts/terminal_setup.sh`](../../scripts/terminal_setup.sh:1)):
  - `zoxide` (smart `cd`)
  - `eza` (modern `ls`)
  - `bat` (syntax-highlighted `cat`)
  - `fzf` (fuzzy finder)
  - `ripgrep` (fast grep)
  - `fd-find` (fast find)
  - `lazygit` (terminal git UI, via COPR `atim/lazygit`)
  - `yazi` (terminal file manager via prebuilt GitHub binary)

## Applications and Services

- Editor:
  - Visual Studio Code (VS Code), installed via [`scripts/vscode_setup.sh`](../../scripts/vscode_setup.sh:1)
  - Extensions list under [`assets/vscode/extensions.txt`](../../assets/vscode/extensions.txt:1)
  - Settings are NOT restored (to avoid storing secrets in version control)
- Vector database:
  - Qdrant, provisioned via Podman and systemd user service by [`scripts/qdrant_setup.sh`](../../scripts/qdrant_setup.sh:1)
- Game engine:
  - Godot Engine, installed by [`scripts/godot_setup.sh`](../../scripts/godot_setup.sh:1) to `~/.local/bin/godot`
- Desktop applications (installed by [`scripts/apps_setup.sh`](../../scripts/apps_setup.sh:1)):
  - Google Chrome and Dropbox (DNF)
  - Discord, Obsidian, Anki (Flatpak)
- Cloud Storage:
  - OneDrive (`abraunegg/onedrive`), configured via [`scripts/onedrive_setup.sh`](../../scripts/onedrive_setup.sh:1) with multi-account support using named systemd services.
- Networking tool:
  - Cisco Packet Tracer, installed via converted `.deb` with Qt5 dependencies by [`scripts/packettracer_setup.sh`](../../scripts/packettracer_setup.sh:1) when the installer is present in [`assets/`](../../assets:1)
- Audio processing:
  - EasyEffects, installed via [`scripts/easyeffects_setup.sh`](../../scripts/easyeffects_setup.sh:1), with presets/configuration under [`assets/.config/easyeffects`](../../assets/.config/easyeffects:1), used to keep speaker/headphone audio tuning reproducible

## Configuration and Assets

- Dotfiles:
  - `.zshrc`, `.bashrc`, `.gitconfig` at the root of [`assets/`](../../assets:1)
- Application configs under [`assets/.config/`](../../assets/.config:1):
  - `starship` (with Gruvbox theme by default, Catppuccin alternative available)
  - `atuin`
  - `fastfetch`
  - `fish`
  - `kitty` (with Catppuccin Mocha theme)
  - `tmux` (with TPM plugin declarations)
  - `easyeffects` (audio presets and autoload rules)
  - Optional: `yazi`, `bat` and other tool-specific configs
- Visual assets:
  - Custom Fastfetch logo at [`assets/images/jedi.png`](../../assets/images/jedi.png:1)

## Technical Constraints and Patterns

- Execution:
  - All scripts must be run as a non-root user; root execution is explicitly blocked via `check_not_root` in [`scripts/common.sh`](../../scripts/common.sh:1).
  - Privileged operations go through `sudo` wrappers such as `dnf_install`.
- Overwrite semantics:
  - Copy helpers (`copy_file`, `copy_dir`) in [`scripts/common.sh`](../../scripts/common.sh:1) overwrite existing config files without backup.
  - The repo is the single source of truth; to update config, edit in repo and re-run setup.
  - Fonts and configuration directories can be re-copied without harm.
- Structure:
  - Logic lives in Bash scripts under [`scripts/`](../../scripts:1).
  - User-specific and app-specific configuration lives entirely under [`assets/`](../../assets:1).
- Single profile:
  - Terminal setup installs a single, full-featured configuration with all power tools and themes.
  - No separate "core" vs "enhanced" modes.

## Tool Usage Patterns

- Preferred install path:
  - Try `dnf` first for system packages (Starship, Atuin, plugins, power tools).
  - Fallback to official installers or GitHub releases when packages are not available (Starship script, Atuin script, Yazi prebuilt binary).
- Service management:
  - Use user-level `systemd` units (e.g., for Qdrant) so services start automatically without system-wide root services.
- Post-install UX:
  - Scripts print clear next steps (e.g., `chsh` shell change reminder, tmux plugin install key chord, Starship theme copy command).
