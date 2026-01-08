# Terminal Custom Setup

Automated terminal and development environment setup for Nobara 42 / Fedora.

## Features

- **Shell Environment**: Zsh, Starship prompt, Atuin history, Fastfetch
- **Terminal**: Kitty GPU-accelerated terminal with Catppuccin theme
- **Fonts**: CaskaydiaCove Nerd Font
- **Tmux**: Multiplexer with TPM plugins, session persistence, Catppuccin theme
- **Power Tools**: zoxide, eza, bat, fzf, ripgrep, fd-find, lazygit, yazi
- **Containers**: Podman & Podman Compose
- **VS Code**: Installation and extensions
- **Qdrant**: Vector database with auto-start systemd service
- **Godot Engine**: Game engine with VS Code integration
- **Additional Apps**: Chrome, Dropbox, Discord, Obsidian, Anki, Calibre, Super Productivity
- **OneDrive**: Multi-account support via `abraunegg/onedrive` client
- **Audio Processing**: EasyEffects with pre-tuned presets
- **DNS**: Cloudflare Block Malware configuration
- **OBS Studio**: Recording and streaming software (Flatpak)
- **Cisco Packet Tracer**: Network simulation tool
- **Vietnamese Input**: ibus-bamboo for Vietnamese typing

## Quick Start

```bash
# Clone the repository
git clone <repo-url> terminal-custom
cd terminal-custom

# Full installation
./setup.sh
```

## Philosophy

- **Single source of truth**: The `assets/` directory contains all configurations
- **No backups**: Running setup overwrites existing configs without creating backups
- **One profile**: Single, full-featured terminal configuration (no "core" vs "enhanced")
- **Opinionated**: Curated, clean configs with Catppuccin theming throughout

## Usage

```bash
./setup.sh [OPTIONS]

Options:
  --full              Run full setup (same as default)
  --terminal          Run terminal setup only
  --skip-terminal     Skip terminal setup
  --skip-vscode       Skip VS Code installation
  --skip-qdrant       Skip Qdrant setup
  --skip-godot        Skip Godot installation
  --skip-apps         Skip additional apps
  --skip-packettracer Skip Cisco Packet Tracer
  --skip-obs          Skip OBS Studio
  --skip-easyeffects  Skip EasyEffects audio setup
  --skip-dns          Skip DNS setup
  --onedrive          Setup OneDrive (multiple accounts)
  --vietnamese        Install Vietnamese input method
  --obs               Setup OBS Studio
  --onedrive          Setup OneDrive (multiple accounts)
  --vietnamese        Install Vietnamese input method
  --help              Show help message

Exclusive Mode (Run ONLY specific components):
  ./setup.sh --vscode         # ONLY install VS Code
  ./setup.sh --terminal       # ONLY run terminal setup
  ./setup.sh --qdrant         # ONLY setup Qdrant
  ./setup.sh --obs            # ONLY setup OBS Studio
  ./setup.sh --dns            # ONLY setup DNS

Examples:
  ./setup.sh                  # Full installation
  ./setup.sh --terminal       # Terminal setup only
  ./setup.sh --skip-godot     # Full setup EXCEPT Godot
  ./setup.sh --obs            # OBS Studio setup only
```

## Project Structure

```
.
├── setup.sh                    # Master orchestrator script
├── assets/                     # Configuration data (source of truth)
│   ├── .zshrc                  # Zsh configuration
│   ├── .bashrc                 # Bash configuration
│   ├── .gitconfig              # Git configuration
│   ├── .config/                # App configs
│   │   ├── starship/           # Starship prompt config
│   │   ├── atuin/              # Atuin shell history config
│   │   ├── fastfetch/          # Fastfetch system info config
│   │   ├── kitty/              # Kitty terminal + Catppuccin theme
│   │   ├── tmux/               # Tmux + TPM plugins
│   │   └── easyeffects/        # Audio presets
│   ├── fonts/                  # CaskaydiaCove Nerd Font
│   ├── godot/                  # Godot editor settings
│   ├── vscode/                 # VS Code extensions list
│   └── images/                 # Custom assets (fastfetch logo)
└── scripts/
    ├── common.sh               # Shared utilities
    ├── terminal_setup.sh       # Terminal setup (single profile)
    ├── vscode_setup.sh         # VS Code installation
    ├── qdrant_setup.sh         # Qdrant vector database
    ├── godot_setup.sh          # Godot Engine installation
    ├── obs_setup.sh            # OBS Studio installation
    ├── apps_setup.sh           # Chrome, Dropbox, Flatpak apps
    ├── onedrive_setup.sh       # OneDrive multi-account setup
    ├── easyeffects_setup.sh    # EasyEffects audio presets
    ├── dns_setup.sh            # DNS configuration
    ├── packettracer_setup.sh   # Cisco Packet Tracer
    └── input_setup.sh          # Vietnamese input method
```

## What Gets Installed

### Terminal Setup (`terminal_setup.sh`)

Single, full-featured terminal configuration:

**Packages**:
- zsh, git, curl, wget, util-linux-user, fastfetch
- kitty (GPU-accelerated terminal)
- podman, podman-compose
- tmux

**Shell Tools**:
- Starship prompt (Gruvbox theme)
- Atuin (shell history with sync)
- Zsh plugins: autosuggestions, syntax-highlighting, autocomplete

**Power Tools**:
- `zoxide` - Smart cd replacement
- `eza` - Modern ls with icons and git status
- `bat` - Cat with syntax highlighting
- `fzf` - Fuzzy finder with Catppuccin theme
- `ripgrep` - Fast grep alternative
- `fd-find` - Fast find alternative
- `lazygit` - Terminal UI for git
- `yazi` - Terminal file manager

**Configs Installed**:
- `.zshrc` with all tool integrations
- `kitty.conf` with Catppuccin Mocha theme
- `tmux.conf` with TPM and Catppuccin theme
- `starship.toml` with Gruvbox Dark theme

**Aliases Available**:
```bash
ls  → eza --icons              # List with icons
ll  → eza -la --icons --git    # Detailed list with git status
lt  → eza --tree               # Tree view
cat → bat                       # Syntax highlighted cat
lg  → lazygit                   # Git TUI
y   → yazi                      # File manager (cd on exit)
z   → zoxide                    # Smart directory jumping
```

### Other Components

- **VS Code**: Installation via Microsoft repo, extensions from list
- **Qdrant**: Podman container with systemd service at http://localhost:6333
- **Godot**: Downloads to ~/.local/bin, creates desktop entry
- **OBS Studio**: Installed via Flatpak (com.obsproject.Studio)
- **Apps**: Chrome, Dropbox (DNF), Discord, Obsidian, Anki, Calibre, Super Productivity (Flatpak)
- **OneDrive**: Multi-account sync with systemd services
- **EasyEffects**: Audio presets for speakers/headsets
- **DNS**: Cloudflare Block Malware (1.1.1.2/1.0.0.2)
- **Packet Tracer**: Cisco network simulation
- **Vietnamese Input**: ibus-bamboo (auto-configured as default input source)

## Post-Setup Steps

1. **Log out and log back in** (for shell change to take effect)

2. **Install tmux plugins**: Open tmux and press `Ctrl+a` then `I`

3. **Start using power tools**:
   - `z` learns your directories automatically
   - `Ctrl+R` for fuzzy history search (fzf + atuin)
   - `Ctrl+T` for fuzzy file search
   - `Alt+C` for fuzzy directory navigation

## Requirements

- Nobara 42 or Fedora-based distribution
- User with sudo access
- Internet connection

## Customization

To customize configs:
1. Edit files directly in `assets/`
2. Run `./setup.sh --terminal` to apply changes

The repo is your source of truth - changes are tracked in git.

## License

Personal configuration - use at your own discretion.