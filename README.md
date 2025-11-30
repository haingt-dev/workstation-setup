# Terminal Configuration & Migration

A backup of my custom terminal setup intended for easy migration to Nobara 42 (Fedora-based).

## Description

This repository contains configuration files, fonts, and an automated installation script to quickly restore a fully-featured terminal environment featuring:

- **Zsh** - Modern shell with powerful features
- **Starship** - Cross-shell prompt with extensive customization
- **Atuin** - Magical shell history with sync capabilities
- **Fastfetch** - System information display tool
- **Kitty** - GPU-accelerated terminal emulator
- **Nerd Fonts** - Patched fonts with icon support (CaskaydiaCove, FiraCode, JetBrains Mono)

## Contents

```
terminal_backup/
├── .zshrc                    # Zsh configuration
├── .bashrc                   # Bash configuration (backup)
├── .config/                  # Application configs (starship, atuin, fastfetch)
├── fonts/                    # Nerd Fonts collection
├── install.sh                # Automated installation script
└── restore_instructions.txt  # Manual plugin installation guide
```

## Quick Start

### Automated Installation (Recommended)

1. Clone the repository:
   ```bash
   git clone <repo-url> systems-migration
   cd systems-migration
   ```

2. Navigate to the backup directory:
   ```bash
   cd terminal_backup
   ```

3. Run the installation script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

4. Log out and log back in for the shell change to take effect.

The script will:
- Update the system
- Install Zsh, Starship, Atuin, and Fastfetch
- Install Zsh plugins (autosuggestions, syntax-highlighting, autocomplete)
- Restore all configuration files
- Install fonts and refresh font cache
- Set Zsh as the default shell

## Manual Installation

If you prefer manual installation or need to customize the setup:

1. Copy configuration files manually to their respective locations:
   - `.zshrc` → `~/`
   - `.bashrc` → `~/`
   - `.config/*` → `~/.config/`
   - `fonts/*.ttf` → `~/.local/share/fonts/`

2. Install required Zsh plugins - see [`restore_instructions.txt`](terminal_backup/restore_instructions.txt) for details.

3. Refresh font cache:
   ```bash
   fc-cache -fv
   ```

4. Change default shell:
   ```bash
   chsh -s $(which zsh)
   ```

## Screenshots

*Add screenshots here*

## License

Personal configuration backup - use at your own discretion.