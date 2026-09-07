# Workstation Setup

Automated workstation setup for Nobara 42 / Fedora — terminal, dev tools, apps, and agent system.

## Features

### Terminal & Shell
- **Shell Environment**: Zsh, Starship prompt, Atuin history, Fastfetch
- **Terminal**: Kitty GPU-accelerated terminal, themed from the desktop palette
- **Fonts**: CaskaydiaCove Nerd Font
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
- **DPI Bypass**: zapret/nfqws — reach SNI-blocked sites (Steam store, Medium, Luật Khoa) without VPN
- **Vietnamese Input**: fcitx5-unikey for Vietnamese typing
- **Display (NVIDIA)**: DisplayPort EDID-loss mitigation — monitor-OSD reminder + known-good EDID staged + suspend/resume auto-recovery hook (KDE never-blank layer retired 2026-08-18: normal screen-off restored; occasional 640x480 hit is fixed by power-cycling the monitor)

### Desktop Rice (KDE Plasma)
- **One derived palette**: a single source colour in `assets/desktop/palette/palette.toml` is expanded by `gen-palette.py` (Material You) into the KDE colour scheme, Konsole and kitty themes (colours and the backdrop crop), the starship prompt palette, QML tokens for our widgets and shell tokens for the Claude Code statusline. `bat` and `fzf` are set to follow the terminal's own ANSI colours, so they need no generated file at all. Generated once and committed — setup only installs the files, so the desktop cannot drift between runs. Change the look: edit the toml, run `bash scripts/desktop/gen-palette.sh`, review the diff, commit.
- **Static wallpaper**: the picture the palette came from (`assets/desktop/wallpapers/`), installed as a proper wallpaper package. Two more crops are generated from it: a blurred+darkened one for the lock screen and the plasmalogin greeter, and a zoomed one that kitty draws as its background (opaque — a translucent terminal over a near-black picture showed nothing but whatever window sat underneath). Crop and tint live in `palette.toml` under `[terminal]`. Zero GPU, and none of the video plugin's failure modes.
- **Own widgets**: `dev.haint.dashboard` on the desktop (clock + date, CPU/RAM/GPU/Disk cards, HCMC weather from Open-Meteo) and `dev.haint.claudequota` in the dock (ring gauge of the worst Claude Code rate-limit window, popup with every window and its reset time — including the per-model weekly limit that nothing else exposes). Both read the generated tokens, so they match everything else by construction.
- **Zero cost while gaming** (hard rule): both widgets share `GameGuard.qml`, which watches `TasksModel`/`IsFullScreen` plus `gamemoded -s` (for borderless-windowed games) and stops every timer, sensor subscription and helper process while a game is on screen.
- **Panel**: slim 42px vertical dock styled by Panel Colorizer (one "Dock Slim" preset: translucent + blur, no window-state autoload) — theme panel-background margins collapsed so icons/clock get the full width
- All applied by idempotent `scripts/desktop/` stages; KDE state backed up (bundle Section 9) and restored by recovery phase 8 + `./setup.sh --desktop`

## Quick Start

```bash
# Clone the repository
git clone <repo-url> workstation-setup
cd workstation-setup

# Full installation
./setup.sh
```

## Philosophy

- **Symlink, don't copy**: User-authored configs (zsh, kitty, starship, …) are
  **symlinked** from `assets/` into `$HOME` — the repo is the source of truth and editing
  either side is the same file (zero drift, full git history). First link of an existing
  real file backs it up to `<path>.pre-symlink.<ts>.bak`.
- **Config in git, state in backup**: Tool-managed state (VS Code, Godot, Claude, shell
  history) is **not** vendored here — it's captured by the encrypted backup pipeline
  (below) and restored by `recover.sh`. Fonts are downloaded on-demand.
- **One profile**: Single, full-featured terminal configuration (no "core" vs "enhanced")
- **Opinionated**: Curated, clean configs; one palette, generated from the wallpaper, across the desktop and the terminal

## Backup & Recovery

This repo provisions a *fresh* machine; a separate pipeline preserves *state* that can't
be regenerated:

- **`scripts/backup/daily-bundle.sh`** — bundles non-git state (SSH/GPG keys, `.env` files,
  brain DB, `~/.claude` state, VS Code/Godot config, home-server data) into one GPG-encrypted
  tarball pushed to OneDrive + optional Backblaze B2 (cron via `scripts/backup/install-cron.sh`).
- **`recover.sh`** — 8-phase disaster recovery: runs `setup.sh` (dotfiles via symlink), then
  restores secrets/brain/Claude/repos from the latest bundle, and finally the KDE rice
  (phase 8; the wallpaper source is listed in `assets/desktop/wallpapers.manifest`). See
  `docs/RECOVERY.md` and `DISASTER-CARD.txt`.

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
  --dpi               ISP DPI bypass (zapret/nfqws)
  --skip-dpi          Skip DPI bypass setup
  --onedrive          Setup onedriver Files-On-Demand (Dev + Personal accounts)
  --vietnamese        Install Vietnamese input method
  --display           NVIDIA DisplayPort EDID-loss fix (EDID staging + sleep hook)
  --skip-display      Skip display/NVIDIA setup
  --desktop           Desktop rice (generated palette + static wallpaper + dashboard/quota widgets)
  --skip-desktop      Skip desktop rice
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
│   ├── .config/                # App configs
│       ├── starship/           # Starship prompt (palette spliced in by gen-palette.py)
│       ├── atuin/              # Atuin config (config.toml)
│       ├── fastfetch/          # Fastfetch config + logo
│       ├── kitty/              # Kitty terminal (theme + backdrop are generated)
│       └── fish/               # fish conf.d
│   ├── .local/share/
│   │   ├── easyeffects/        # Audio presets (G560/G435) — EE >= 8.0 layout
│   │   └── konsole/            # Konsole profile (colour scheme is generated)
│   └── desktop/                # Everything the KDE rice is made of
│       ├── palette/            # palette.toml + gen-palette.py + generated colour artefacts
│       ├── wallpapers/         # the wallpaper the palette is derived from
│       └── plasmoids/          # our own Plasma widgets (dashboard, Claude quota) + shared QML
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
    ├── dpi_bypass_setup.sh     # ISP DPI bypass (zapret/nfqws build + service)
    ├── input_setup.sh          # Vietnamese input method
    ├── agent_setup.sh          # Agent Hub setup (clones from GitHub) + awake-guard
    ├── retire_remote_stack.sh  # One-shot: removes the retired iPad remote stack
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

**Shell Tools**:
- Starship prompt
- Atuin (shell history with sync)
- Zsh plugins: autosuggestions, syntax-highlighting (autocomplete disabled 2026-06-29 — segfaults on zsh 5.9)

**Power Tools**:
- `zoxide` - Smart cd replacement
- `eza` - Modern ls with icons and git status
- `bat` - Cat with syntax highlighting
- `fzf` - Fuzzy finder (follows the terminal's ANSI colours)
- `ripgrep` - Fast grep alternative
- `fd-find` - Fast find alternative
- `lazygit` - Terminal UI for git
- `yazi` - Terminal file manager

**Configs Installed**:
- `.zshrc` with all tool integrations
- `kitty.conf` — colours and backdrop come from the desktop rice's palette
- `starship.toml` — prompt layout, with a generated `[palettes.rice]` block

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

### Awake guard (`agent_setup.sh`)

Plasma suspends after 15 minutes without **local** input, so reading a long answer,
thinking between prompts, or driving a session from the phone through Claude Code's
Remote Control all look like an idle machine. Two layers keep it awake only when
there is a reason, and the KDE auto-suspend setting stays at its default:

- the Claude Code inhibit hooks (`~/.claude/hooks/claude-inhibit-*.sh`, wired to
  UserPromptSubmit + PreToolUse + Stop in `~/.claude/settings.json`) hold a sleep
  inhibitor while a turn **runs**;
- `awake-guard.service` (`assets/.local/bin/awake-guard.sh`) holds one while a session
  is merely **in use** — it polls transcript mtimes under `~/.claude/projects` and keeps
  the lock while anything was written in the last 20 minutes.

PowerDevil imports logind inhibitors with `mode=block` only (PolicyAgent skips other
modes — Plasma/6.6 source), which is what both layers use. Accepted side effect: while a
lock is held a **manual** Sleep is refused too; `systemctl --user stop awake-guard` is the
escape hatch. Check it with `journalctl --user -u awake-guard` — it logs every ON/OFF.

**Retired 2026-09-07 — the iPad remote stack.** From July 2026 this box was reachable
from an iPad: Tailscale, sshd + mosh, tmux session `work` with auto-attach, Wake-on-LAN
and a smart plug for power, a glyph-free `starship-remote.toml` for Termius. Claude Code's
Remote Control (`/rc`, session driven from claude.ai or the phone app) replaced the whole
lane, and the iPad had been off the tailnet for weeks. `scripts/retire_remote_stack.sh`
removes the machine state (services, packages, firewall rule, WoL, leftover symlinks);
the repo side went with the same commit. There is no SSH into this machine any more —
outbound SSH, and so git, is untouched. Everything is in git history if it is ever needed
back, but the intent is to start from what is actually needed then.

### Other Components

- **Qdrant**: Podman container with systemd service at http://localhost:6333
- **Godot**: Downloads to ~/.local/bin, creates desktop entry
- **Apps**: Chrome (DNF), Discord, Obsidian, Anki, Todoist, Krita (Flatpak)
- **OneDrive**: `onedriver` FUSE mounts at `~/Data/OneDrive/{Dev,Personal}` (Files-On-Demand). Calibre Library lives separately at `~/Data/Calibre Library/` with daily rclone backup (`calibre-sync.timer`).
- **EasyEffects**: Audio presets for speakers/headsets
- **DNS**: Cloudflare Block Malware (1.1.1.2/1.0.0.2)
- **DPI Bypass** (`dpi_bypass_setup.sh`): FPT Telecom's DPI sits at the international gateway, reads the TLS SNI and injects RST — `store.steampowered.com`, `medium.com`, `luatkhoa.net` die instantly while DNS/TCP/no-SNI TLS all work (diagnosed 2026-08-27). DNS changes don't help (Cloudflare/Quad9 lack ECS → Akamai hands out international edges; Google/OpenDNS happen to fix Steam only via FPT's domestic Akamai edge, and nothing on Cloudflare-hosted sites). Fix = [zapret](https://github.com/bol-van/zapret) `nfqws`, built from a pinned commit into `/usr/local/bin/nfqws`; `zapret.service` loads an `inet zapret` nft table that queues the first 6 packets of each outbound TCP 80/443 flow on physical NICs only (`meta oiftype ether` → VPN tunnels untouched) and nfqws splits the ClientHello (`multisplit`, pos `1,midsld`) so the DPI can't see the hostname. Verified strategy in `assets/zapret/nfqws.conf`; `fake+badseq` does NOT work on FPT. Toggle: `sudo systemctl stop|start zapret`; remove: `./scripts/dpi_bypass_setup.sh --uninstall`. VPN (`vpn on`) stays only for IP-level blocks.
- **Vietnamese Input**: fcitx5-unikey (auto-configured with Super+Space trigger)
- **Display (NVIDIA)**: monitor-OSD reminder + a `systemd-sleep` hook (`scripts/display/nvidia-dp-edid.sleep.sh`) that pre-sets the debugfs `edid_override` before sleep and nudges KWin on resume if the EDID came back broken. The old KDE never-blank layer was retired 2026-08-18 (kept the display at full power all day); the script now removes that override if present. If the screen drops to 640x480, power-cycle the monitor. Self-logs to `/var/log/nvidia-dp-edid.log`. Deep-dive: brain `4db7e40bc653`.

## Post-Setup Steps

1. **Log out and log back in** (for shell change to take effect)

2. **Start using power tools**:
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