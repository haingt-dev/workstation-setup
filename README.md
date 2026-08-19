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
- **Display (NVIDIA)**: DisplayPort EDID-loss mitigation — monitor-OSD reminder + known-good EDID staged + suspend/resume auto-recovery hook (KDE never-blank layer retired 2026-08-18: normal screen-off restored; occasional 640x480 hit is fixed by power-cycling the monitor)

### Desktop Rice (KDE Plasma)
- **Theme**: Catppuccin Mocha (Mauve accent) everywhere — global theme, Breeze decoration with native rounded corners, Papirus icons, Inter UI font, custom `catppuccin-glass` Plasma style (generated, 40%-opacity glass widget cards)
- **Video wallpaper**: Smart Video Wallpaper Reborn with `PauseMode=MaximizedOrFullScreen` — zero perf cost while gaming (HW decode via NVDEC; H.264/VP9 only, never AV1)
- **Sci-fi HUD**: Reactor HUD (patched: portable scriptPath + hybrid glass/shadow contrast), Kurve CAVA audio visualizer (accent bars), glassy desktop clock; panel clock = time-only
- **Panel**: slim 42px vertical dock styled by Panel Colorizer (Dock preset, GUI = source of truth) — theme panel-background margins collapsed so icons/clock get the full width
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
- **`recover.sh`** — 8-phase disaster recovery: runs `setup.sh` (dotfiles via symlink), then
  restores secrets/brain/Claude/repos from the latest bundle, and finally the KDE rice
  (phase 8; wallpaper videos re-download per `assets/desktop/wallpapers.manifest`). See
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
  --onedrive          Setup onedriver Files-On-Demand (Dev + Personal accounts)
  --vietnamese        Install Vietnamese input method
  --remote            Remote access (Tailscale, SSH, WoL)
  --skip-remote       Skip remote access setup
  --display           NVIDIA DisplayPort EDID-loss fix (EDID staging + sleep hook)
  --skip-display      Skip display/NVIDIA setup
  --desktop           Desktop rice (Catppuccin Mocha theme + video wallpaper + HUD widgets)
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
│       ├── starship/           # Starship prompts (remote variant → ~/.config/starship-remote.toml)
│       ├── atuin/              # Atuin config (config.toml)
│       ├── fastfetch/          # Fastfetch config + logo
│       ├── kitty/              # Kitty terminal + Catppuccin + background
│       ├── tmux/               # Tmux + TPM plugins
│       └── fish/               # fish conf.d
│   └── .local/share/
│       └── easyeffects/        # Audio presets (G560/G435) — EE >= 8.0 layout
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
- Zsh plugins: autosuggestions, syntax-highlighting (autocomplete disabled 2026-06-29 — segfaults on zsh 5.9)

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
- `starship-remote.toml` — glyph-free variant, auto-selected over SSH/Mosh

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
- Mosh (resilient UDP shell — survives roaming / sleep-wake / IP change)
- tmux for session persistence (survives SSH disconnects) — auto-attaches to session `work` on every remote connect (guard in `assets/.zshrc`)
- Glyph-free Starship prompt for remote sessions — Termius/non-Nerd-Font clients render the local Catppuccin powerline icons as tofu; `starship-remote.toml` (letters + `…` + `❯` only, same Catppuccin colors) is auto-selected via `STARSHIP_CONFIG` when `$SSH_CONNECTION` is set (`assets/.zshrc`); local terminals keep the full prompt
- Awake guard — KDE auto-suspend stays at **default** (PC sleeps normally at home); suspend is blocked only when there's a reason, via three conditional layers: the Claude Code inhibit hooks (`~/.claude/hooks/claude-inhibit-*.sh`, wired to UserPromptSubmit + PreToolUse + Stop in `~/.claude/settings.json`) hold a sleep inhibitor while a task runs · `awake-guard.service` (`assets/.local/bin/awake-guard.sh`) holds one while a remote mosh/SSH session is open — detected by **live processes** (`mosh-server`, `sshd-session: user [priv]`/`user@pts`), NOT by `who`/utmp: on Fedora 43 `who` (coreutils ≥9.4, Y2038 utmp deprecation) reads logind sessions and **never lists mosh** (its SSH bootstrap session is TTY-less and closes instantly), which is how the who-based guard v1 went blind · `MOSH_SERVER_NETWORK_TMOUT=3600` (`assets/.zshenv`) reaps stale mosh-servers so a force-killed Termius can't hold the inhibitor forever. On remote login `assets/.zshrc` kicks the guard (USR1) for an instant poll, closing the connect-time race against the idle deadline. Background: Plasma's 15-min idle suspend counts only **local** input — remote SSH/mosh activity doesn't reset it, which froze the host mid-iPad-session three times (2026-07-07, 2026-07-08, 2026-07-10 — the third *after* guard v1 shipped, exposing the `who` trap). PowerDevil honors systemd inhibitors with `mode=block` only (PolicyAgent imports logind inhibitors, skips other modes — Plasma/6.6 source). Accepted side effect: while a lock is held, **manual** Sleep is refused too — close the remote session or `systemctl --user stop awake-guard` first

**Hardware**: ASUS TUF B650M-E WIFI, Ethernet `eno1`

**BIOS Setup** (manual, one-time):
- Delete → Advanced → APM Configuration
- `Restore AC Power Loss` = Power On (for smart plug remote boot)
- `Power On By PCI-E` = Enabled (for Wake-on-LAN)

**iPad Apps**:
- Tailscale (free) — same account, auto-connects
- Termius (free) — SSH/Mosh client; enable Mosh per host for resilient sessions
- Working Copy ($25) — Obsidian Git sync + offline code

**Usage**:
```bash
# From iPad (Termius) — Mosh recommended; survives roaming/sleep
ssh haint@100.86.91.49     # Tailscale IP — works from anywhere
# → auto-attaches to tmux session `work` on connect (assets/.zshrc)
# Detach: Ctrl-a d · reconnecting re-attaches automatically

# Shutdown PC remotely when done
sudo shutdown -h now
```

**Trip protocol — smart-plug boot (PC default OFF, no always-on box)**:
1. **Boot**: smart-plug app → OFF → wait 5s → ON. BIOS `Restore AC Power Loss = Power On` boots the PC; `sshd` + `tailscaled` are enabled at boot. Wait ~2 min.
2. **Work**: `ssh haint@100.86.91.49` → auto-attaches to tmux `work` (via `assets/.zshrc`; falls back to `tmux new -s work` if none).
3. **Done**: `sudo shutdown -h now` from the SSH session; optionally plug OFF after ~1 min.

Auto-suspend reality check: **every boot autologs into a full Plasma session** (`plasmalogin-autologin` — there is NO idle greeter on this box), so PowerDevil's 15-min suspend timer runs from power-on even when nobody is home. A remotely-booted host therefore **suspends ~15 min after power-on unless a remote session connects first** — connect promptly after an eWeLink boot; once mosh/SSH is in, the guard holds it awake. Logged-in sessions suspend normally EXCEPT while a Claude task runs or a remote session is open (see Awake guard in Services). A finished, disconnected session is *allowed* to sleep — that's the design, not a failure. Pre-departure drill: run the full cycle once from cellular (wifi off) — verified 2026-07-__.

**Host unreachable mid-session** (Tailscale dead, was working minutes ago)? Recovery ladder — wake before you cut:
1. **It may be legitimately asleep** (no remote session + no running task ≥15 min — e.g. mosh reaped after 1h of a force-killed Termius, or a fresh boot nobody connected to). A WoL magic packet to `eno1` (MAC: `ip link show eno1`) or a tap on the power button wakes from S3 **losslessly** — tmux, finished task output, everything is still there. **WoL works from the home LAN only**: it's an ethernet broadcast, and a suspended host's tailscaled is asleep too, so nothing can carry it over the tailnet from outside. Away from home, a suspended host leaves only step 2.
2. **eWeLink power-cycle = last resort**: RAM is lost → cold boot → tmux session + task output die.
3. **Post-mortem after reboot**: `journalctl -b -1 -e` — a suspend ends with `systemd-logind: The system will suspend now!`; a real freeze/crash ends with an abrupt log stop instead. Was the guard holding? `journalctl --user -u awake-guard` shows every inhibit ON/OFF transition.

### Other Components

- **Qdrant**: Podman container with systemd service at http://localhost:6333
- **Godot**: Downloads to ~/.local/bin, creates desktop entry
- **Apps**: Chrome (DNF), Discord, Obsidian, Anki, Todoist, Krita (Flatpak)
- **OneDrive**: `onedriver` FUSE mounts at `~/Data/OneDrive/{Dev,Personal}` (Files-On-Demand). Calibre Library lives separately at `~/Data/Calibre Library/` with daily rclone backup (`calibre-sync.timer`).
- **EasyEffects**: Audio presets for speakers/headsets
- **DNS**: Cloudflare Block Malware (1.1.1.2/1.0.0.2)
- **Vietnamese Input**: fcitx5-unikey (auto-configured with Super+Space trigger)
- **Display (NVIDIA)**: monitor-OSD reminder + a `systemd-sleep` hook (`scripts/display/nvidia-dp-edid.sleep.sh`) that pre-sets the debugfs `edid_override` before sleep and nudges KWin on resume if the EDID came back broken. The old KDE never-blank layer was retired 2026-08-18 (kept the display at full power all day); the script now removes that override if present. If the screen drops to 640x480, power-cycle the monitor. Self-logs to `/var/log/nvidia-dp-edid.log`. Deep-dive: brain `4db7e40bc653`.

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