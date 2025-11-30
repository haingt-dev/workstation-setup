# Terminal Custom Setup

Automated terminal and development environment setup for Nobara 42 / Fedora.

## Features

- **Shell Environment**: Zsh, Starship prompt, Atuin history, Fastfetch
- **Terminal**: Kitty GPU-accelerated terminal
- **Fonts**: Nerd Fonts (CaskaydiaCove, FiraCode, JetBrains Mono)
- **Containers**: Podman & Podman Compose
- **VS Code**: Installation, extensions, and settings restoration
- **Qdrant**: Vector database with auto-start systemd service
- **Godot Engine**: Game engine with VS Code integration
- **Additional Apps**: Chrome, Dropbox, Discord, Obsidian, Anki
- **Cisco Packet Tracer**: Network simulation tool

## Quick Start

```bash
# Clone the repository
git clone <repo-url> terminal-custom
cd terminal-custom

# Full installation
./setup.sh

# Or minimal (core only)
./setup.sh --minimal
```

## Usage

```bash
./setup.sh [OPTIONS]

Options:
  --minimal           Core setup only (shell, dotfiles, fonts)
  --skip-vscode       Skip VS Code installation
  --skip-qdrant       Skip Qdrant setup
  --skip-godot        Skip Godot installation
  --skip-apps         Skip additional apps (Chrome, Dropbox, Flatpaks)
  --skip-packettracer Skip Cisco Packet Tracer installation
  --help              Show help message

Examples:
  ./setup.sh                              # Full installation
  ./setup.sh --minimal                    # Core setup only
  ./setup.sh --skip-godot --skip-apps     # Skip Godot and apps
```

## Project Structure

```
.
├── setup.sh                    # Master orchestrator script
├── assets/                     # Configuration data and assets
│   ├── .zshrc, .bashrc, .gitconfig
│   ├── .config/                # App configs (starship, atuin, fastfetch, kitty)
│   ├── fonts/                  # Nerd Fonts collection
│   ├── godot/                  # Godot editor settings
│   ├── vscode/                 # VS Code settings and extensions
│   ├── images/                 # Custom assets (fastfetch logo)
│   └── CiscoPacketTracer*.deb  # Packet Tracer installer (optional)
└── scripts/
    ├── common.sh               # Shared utilities and logging
    ├── core_setup.sh           # System updates, packages, shell, fonts, dotfiles
    ├── vscode_setup.sh         # VS Code installation and configuration
    ├── qdrant_setup.sh         # Qdrant vector database with Podman
    ├── godot_setup.sh          # Godot Engine installation
    ├── apps_setup.sh           # Chrome, Dropbox, Flatpak apps
    └── packettracer_setup.sh   # Cisco Packet Tracer installation
```

## What Gets Installed

### Core Setup (`core_setup.sh`)
- System update (dnf)
- Packages: zsh, git, curl, wget, util-linux-user, fastfetch, kitty, podman, podman-compose
- Starship prompt, Atuin shell history
- Zsh plugins: autosuggestions, syntax-highlighting, autocomplete
- Dotfiles: .zshrc, .bashrc, .gitconfig
- Config directories: starship, atuin, fastfetch, kitty
- Fonts installed to ~/.local/share/fonts
- Default shell changed to Zsh

### VS Code Setup (`vscode_setup.sh`)
- VS Code installation via Microsoft repo
- Settings and keybindings restoration
- Extensions installation from extensions.txt
- Kilo Code global storage restoration

### Qdrant Setup (`qdrant_setup.sh`)
- Podman container setup
- Systemd user service (auto-start on boot)
- Available at http://localhost:6333

### Godot Setup (`godot_setup.sh`)
- Downloads Godot (default: 4.4.1, configurable via `GODOT_VERSION` env var)
- Installs to ~/.local/bin/godot
- Restores editor settings with VS Code integration
- Creates desktop entry

### Apps Setup (`apps_setup.sh`)
- Google Chrome (DNF)
- Dropbox (DNF)
- Discord, Obsidian, Anki (Flatpak)

### Packet Tracer Setup (`packettracer_setup.sh`)
- Converts Ubuntu .deb package for Fedora
- Installs Qt5 dependencies
- Non-interactive installation

## Individual Script Usage

You can run individual scripts directly:

```bash
# Run only VS Code setup
bash scripts/vscode_setup.sh

# Run only Qdrant setup
bash scripts/qdrant_setup.sh

# Install Godot with specific version
GODOT_VERSION=4.3 bash scripts/godot_setup.sh

# Uninstall Godot
bash scripts/godot_setup.sh --uninstall

# Uninstall Packet Tracer
bash scripts/packettracer_setup.sh --uninstall
```

## Requirements

- Nobara 42 or Fedora-based distribution
- User with sudo access
- Internet connection

## Legacy Scripts

Previous installation scripts are preserved in `terminal_backup/` for reference:
- `install.sh` - Original all-in-one script
- `install_apps.sh` - Original apps installer
- `install_godot.sh` - Original Godot installer
- `install_packettracer.sh` - Original Packet Tracer installer

## License

Personal configuration backup - use at your own discretion.