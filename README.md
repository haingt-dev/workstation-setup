# Workstation Setup

Automated workstation setup for Nobara 42 / Fedora — terminal, dev tools, apps, and agent system.

## Features

### Terminal & Shell
- **Shell Environment**: Zsh, Starship prompt, Atuin history, Fastfetch
- **Terminal**: Kitty GPU-accelerated terminal with Catppuccin theme
- **Fonts**: CaskaydiaCove Nerd Font
- **Tmux**: Multiplexer with TPM plugins, session persistence, Catppuccin theme
- **Power Tools**: zoxide, eza, bat, fzf, ripgrep, fd-find, lazygit, yazi

### Agent System
- **Agent Hub**: Unified configuration for Claude Code ([separate repo](https://github.com/haingt-dev/agent))
- **Brain Memory**: Semantic memory via `haingt-brain` MCP (cross-session/cross-project, full CRUD)
- **Shell Aliases**: Quick commands for agent workflows (ag, cdc, bootstrap, etc.)
- **Claude Plugins**: haint-core (hooks, skills), godot-dev (GDScript patterns)

### Development & Tools
- **Containers**: Podman & Podman Compose
- **Qdrant**: Vector database with auto-start systemd service
- **Godot Engine**: Game engine setup and configuration

### Applications
- **Additional Apps**: Chrome, Discord, Obsidian, Anki, Todoist, Krita
- **OneDrive**: Multi-account Files-On-Demand via `jstaf/onedriver` (FUSE, drop-and-go upload, on-demand download)
- **Audio Processing**: EasyEffects with pre-tuned presets
- **DNS**: Cloudflare Block Malware configuration
- **Vietnamese Input**: fcitx5-unikey for Vietnamese typing
- **Display (NVIDIA)**: DisplayPort EDID-loss mitigation — stops the post-sleep 640x480 collapse (KDE never-blank + monitor-OSD reminder + known-good EDID staged for recovery)

## Quick Start

```bash
# Clone the repository
git clone <repo-url> workstation-setup
cd workstation-setup

# Full installation
./setup.sh
```

## Philosophy

- **Symlink, don't copy**: User-authored configs (zsh, kitty, starship, tmux, …) are
  **symlinked** from `assets/` into `$HOME` — the repo is the source of truth and editing
  either side is the same file (zero drift, full git history). First link of an existing
  real file backs it up to `<path>.pre-symlink.<ts>.bak`.
- **Config in git, state in backup**: Tool-managed state (VS Code, Godot, Claude, shell
  history) is **not** vendored here — it's captured by the encrypted backup pipeline
  (below) and restored by `recover.sh`. Fonts are downloaded on-demand.
- **One profile**: Single, full-featured terminal configuration (no "core" vs "enhanced")
- **Opinionated**: Curated, clean configs with Catppuccin theming throughout

## Backup & Recovery

This repo provisions a *fresh* machine; a separate pipeline preserves *state* that can't
be regenerated:

- **`scripts/backup/daily-bundle.sh`** — bundles non-git state (SSH/GPG keys, `.env` files,
  brain DB, `~/.claude` state, VS Code/Godot config, home-server data) into one GPG-encrypted
  tarball pushed to OneDrive + optional Backblaze B2 (cron via `scripts/backup/install-cron.sh`).
- **`recover.sh`** — 7-phase disaster recovery: runs `setup.sh` (dotfiles via symlink), then
  restores secrets/brain/Claude/repos from the latest bundle. See `docs/RECOVERY.md` and
  `DISASTER-CARD.txt`.

## Usage

```bash
./setup.sh [OPTIONS]

Options:
  --full              Run full setup (same as default)
  --terminal          Run terminal setup only
  --agent             Run agent system setup only ⭐ NEW
  --skip-terminal     Skip terminal setup
  --skip-agent        Skip agent system setup
  --skip-qdrant       Skip Qdrant setup
  --skip-godot        Skip Godot installation
  --skip-apps         Skip additional apps
  --skip-easyeffects  Skip EasyEffects audio setup
  --skip-dns          Skip DNS setup
  --onedrive          Setup onedriver Files-On-Demand (Dev + Personal accounts)
  --vietnamese        Install Vietnamese input method
  --remote            Remote access (Tailscale, SSH, WoL)
  --skip-remote       Skip remote access setup
  --display           NVIDIA DisplayPort EDID-loss fix (KDE never-blank + EDID)
  --skip-display      Skip display/NVIDIA setup
  --help              Show help message

Exclusive Mode (Run ONLY specific components):
  ./setup.sh --terminal       # ONLY run terminal setup
  ./setup.sh --agent          # ONLY setup agent system ⭐ NEW
  ./setup.sh --qdrant         # ONLY setup Qdrant
  ./setup.sh --dns            # ONLY setup DNS

Examples:
  ./setup.sh                  # Full installation (terminal + agent + apps)
  ./setup.sh --terminal       # Terminal setup only
  ./setup.sh --agent          # Agent system setup only
  ./setup.sh --skip-godot     # Full setup EXCEPT Godot
```

## Project Structure

```
.
├── setup.sh                    # Master orchestrator script
├── TERMINAL_CAPABILITIES.md    # Terminal features & shortcuts guide
├── assets/                     # User-authored configs (symlinked into $HOME)
│   ├── .zshrc                  # Zsh configuration
│   ├── .bashrc                 # Bash configuration
│   ├── .gitconfig              # Git configuration
│   ├── symlinks.yml            # Declarative cross-project symlink manifest
│   └── .config/                # App configs
│       ├── starship/           # Starship prompt config
│       ├── atuin/              # Atuin config (config.toml)
│       ├── fastfetch/          # Fastfetch config + logo
│       ├── kitty/              # Kitty terminal + Catppuccin + background
│       ├── tmux/               # Tmux + TPM plugins
│       ├── fish/               # fish conf.d
│       └── easyeffects/        # Audio presets (G560/G435)
│   # fonts downloaded on-demand; Godot/VS Code/Claude state → backup bundle
└── scripts/
    ├── common.sh               # Shared utilities
    ├── terminal_setup.sh       # Terminal setup (single profile)
    ├── qdrant_setup.sh         # Qdrant vector database
    ├── godot_setup.sh          # Godot Engine installation
    ├── apps_setup.sh           # Chrome, Flatpak apps
    ├── onedrive_setup.sh       # onedriver Files-On-Demand setup (Dev + Personal mounts)
    ├── easyeffects_setup.sh    # EasyEffects audio presets
    ├── dns_setup.sh            # DNS configuration
    ├── input_setup.sh          # Vietnamese input method
    ├── agent_setup.sh          # Agent Hub setup (clones from GitHub)
    ├── remote_access_setup.sh  # Remote access (Tailscale, SSH, WoL)
    └── display_setup.sh        # NVIDIA DisplayPort EDID-loss mitigation
```

## What Gets Installed

### Agent System Setup (`agent_setup.sh`)

AI agent workflow integration for Claude Code:

**Agent Hub** (`~/Projects/agent/` — [separate git repo](https://github.com/haingt-dev/agent)):
- Cloned from GitHub by `agent_setup.sh` (not backed up in this repo)
- Project bootstrapping (`bootstrap-project.sh`)
- Shell aliases (ag, cdc, bootstrap, etc.)
- Claude plugins (haint-core, godot-dev)

**Claude Integration** (`~/.claude/`):
- MCP servers + plugin registry are live, tool-managed state — seeded by Claude Code on
  first run and restored from the backup bundle (not vendored in this repo)

**Per-Project Structure** (created by `bootstrap`):
- `AGENTS.md` - Shared project context (all agents)
- `.claude/` - Claude Code config + skills

**Quick Commands**:
```bash
ag              # Go to Agent Hub
cdc <project>   # Switch to project
bootstrap <dir> # Initialize a project
ag-help         # Show all commands
```

**Documentation**:
- `~/Projects/agent/README.md` - Agent Hub overview

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

### Remote Access Setup (`remote_access_setup.sh`)

iPad Pro M2 as mobile workstation — remote into home PC from anywhere:

**Services**:
- OpenSSH server (enabled, port 22)
- Tailscale (mesh VPN — no port forwarding needed)
- Wake-on-LAN (ethtool on Realtek 2.5G, persistent via NetworkManager)
- tmux for session persistence (survives SSH disconnects)

**Hardware**: ASUS TUF B650M-E WIFI, Ethernet `eno1`

**BIOS Setup** (manual, one-time):
- Delete → Advanced → APM Configuration
- `Restore AC Power Loss` = Power On (for smart plug remote boot)
- `Power On By PCI-E` = Enabled (for Wake-on-LAN)

**iPad Apps**:
- Tailscale (free) — same account, auto-connects
- Termius (free) — SSH client + tmux for session persistence
- Working Copy ($25) — Obsidian Git sync + offline code

**Usage**:
```bash
# From iPad (Termius)
ssh haint@100.86.91.49     # Tailscale IP — works from anywhere
tmux new -s work           # Start persistent session
# If disconnected → reconnect SSH → tmux attach -t work

# Shutdown PC remotely when done
sudo shutdown -h now
```

### Other Components

- **Qdrant**: Podman container with systemd service at http://localhost:6333
- **Godot**: Downloads to ~/.local/bin, creates desktop entry
- **Apps**: Chrome (DNF), Discord, Obsidian, Anki, Todoist, Krita (Flatpak)
- **OneDrive**: `onedriver` FUSE mounts at `~/Data/OneDrive/{Dev,Personal}` (Files-On-Demand). Calibre Library lives separately at `~/Data/Calibre Library/` with daily rclone backup (`calibre-sync.timer`).
- **EasyEffects**: Audio presets for speakers/headsets
- **DNS**: Cloudflare Block Malware (1.1.1.2/1.0.0.2)
- **Vietnamese Input**: fcitx5-unikey (auto-configured with Super+Space trigger)
- **Display (NVIDIA)**: KDE never-blank + monitor-OSD reminder so a DisplayPort wake doesn't collapse to 640x480; known-good EDID staged at `~/.local/share/edid/` for a future suspend auto-recovery. Deep-dive: brain `4db7e40bc653`.

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

Configs are symlinked, so **editing `~/.zshrc` (or any linked config) edits the repo file
directly** — changes show up in `git status` immediately, no re-run needed. Run
`./setup.sh --terminal` only to (re)create links on a fresh machine or after adding a new
config file. Commit from the repo to keep history.

## License

Personal configuration - use at your own discretion.