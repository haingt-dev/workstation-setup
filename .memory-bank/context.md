# Context

## Current Work Focus

- Repo is stable. Last backup sync: 2026-03-04.

## Recent Changes

### 2026-03-04: Apps + Terminal Dashboard Overhaul

**What**: Replaced Super Productivity with Todoist, added Wayland tray support, major terminal dashboard rework, full config sync.

**Apps changes**:
1. **Super Productivity → Todoist** (Flatpak `com.todoist.Todoist`) with DBus permissions for notifications
2. **kwin-minimize2tray** — Wayland-native KWin Script for minimize-to-tray (built from source with Qt6/KF6 deps)
   - kdocker was tried first but is X11-only, incompatible with Wayland
3. Updated `scripts/apps_setup.sh`, README.md, product.md, tech.md

**Terminal dashboard overhaul**:
1. **Auto tmux 3-pane layout** on Kitty launch (`.zshrc`):
   - Top-left: fastfetch (tmux profile) → btop
   - Bottom-left: lazygit-pane (auto cwd sync)
   - Right: interactive shell (focused)
2. **lazygit-pane** (`~/.local/bin/lazygit-pane`) — wrapper that reads `/tmp/tmux-main-cwd`, restarts on quit, polls when not in git repo
3. **Zsh chpwd hook** writes `$PWD` to `/tmp/tmux-main-cwd` for lazygit sync
4. **Tmux additions**: fzf session/window switcher popups, yazi popup, `prefix+g` lazygit resync, `allow-passthrough on`, `extended-keys always` (CSI-u format)
5. **Kitty startup session** (`startup.conf`) — launches maximized, `ctrl+enter` mapped to CSI-u sequence
6. **Fastfetch tmux.jsonc** — text-only profile for tmux pane (no image logo)
7. **Continuum-restore off** — .zshrc handles layout, continuum conflicts with it

**Config sync**: Live → assets/ for .zshrc, kitty.conf, startup.conf (new), tmux.conf, lazygit-pane (new), tmux.jsonc (new)

**Known issue**: Extended keys (Ctrl+Enter) configured in tmux but not functional in practice. Alt+Enter used for newline.

**Cleanup**: Removed obsolete commit-protocol.md (3 copies), settings.local.json. Added .memory-bank/stories/ structure.

### 2026-03-01: Backup Sync — Agent Hub Migration
**What**: Full backup sync reflecting `~/.agent_global` → `~/agent` restructure
**Why**: Agent Global Hub was completely restructured as a git repo at `~/agent/` (symlinked from `~/.agent_global`). Old `assets/.agent_global/` (analytics/, knowledge/, rules/, workflows/) was obsolete.

**Changes**:
1. **`assets/.agent_global/`** — Full replace via rsync (excl .git):
   - Removed: analytics/, knowledge/, rules/, workflows/, skills/, sync-obsidian.sh, mcp_settings.json, SETUP.md, MEMORY_STRATEGY.md
   - Added: .claude-plugin/, plugins/ (haint-core, godot-dev), templates/ (agents, rules), ag-sync-rules.sh
   - Updated: bootstrap-project.sh, shell-aliases.sh, hooks/

2. **`scripts/agent_setup.sh`** — Complete rewrite:
   - Now copies backup → `~/agent/` (not `~/.agent_global/`)
   - Creates symlink `~/.agent_global` → `~/agent`
   - Removed obsolete symlink creation for `~/.claude/rules/`, `~/.claude/workflows/`
   - Restores Claude settings (settings.local.json, mcp_settings.json, plugin registry)
   - Updated verification checks for new structure

3. **`assets/.claude/`** — Cleaned up:
   - Removed obsolete: config.json, projects/, rules/, workflows/, session-env/, file-history/, ide/, plans/, tasks/, todos/, shell-snapshots/, stats-cache.json
   - Kept: settings.local.json, mcp_settings.json, plugins/ (known_marketplaces.json, installed_plugins.json), config.json.template, MCP_SETUP.md

4. **Dotfiles & configs synced**: .zshrc, fastfetch (new assets/ dir), easyeffects (new autoload/output profiles)

5. **`.gitignore`** — Updated patterns for new structure

### 2026-02-11: Security Hardening 🔒 CRITICAL
**What**: Comprehensive secret management and leak prevention
**Why**: Prevent repeat of API key leak incident (blocked by GitHub secret scanning)
**Impact**: All agents now enforce strict .env usage for secrets

**Changes**:
1. **Global Security Rules** (`~/.agent_global/rules/global_rules.md`):
   - Mandatory .env pattern for ALL secrets
   - Pre-commit secret detection checklist
   - Agent workflow for handling sensitive files
   - Never commit: API keys, tokens, credentials, config.json

2. **Enhanced .gitignore Patterns**:
   - systems-migration-main/.gitignore: +20 lines of secret patterns
   - Wildtide/.gitignore: +15 lines of secret patterns
   - Template: `~/.agent_global/templates/.gitignore-secrets`

3. **Documentation**:
   - Created: `~/.agent_global/knowledge/security-secrets-management.md`
   - Created: `~/.agent_global/templates/.env.example`
   - Documents the incident, .env pattern, recovery procedures

4. **MCP Server Update**:
   - Enabled Obsidian MCP: `@mauricio.wolff/mcp-obsidian`
   - Updated: `~/.claude/mcp_settings.json` (disabled: false)
   - Documentation: `~/.agent_global/knowledge/mcp-obsidian-options.md`

**Testing**: All future commits are now protected by enhanced .gitignore patterns. Agents will check for secrets before staging files.

**Commits**:
- `045fd76` - feat(security): Add comprehensive secret protection patterns
- `278476d` - feat(security): Add secret protection patterns to .gitignore (Wildtide)

### 2026-02-11: Agent Global Hub Integration ⭐ MAJOR
- **Integrated complete Agent Global Hub system** into systems-migration-main:
  - Backed up entire `~/.agent_global/` structure to `assets/.agent_global/` (50+ files)
  - Backed up `~/.claude/` configuration to `assets/.claude/` (MCP settings, auto memory, projects)
  - Created `scripts/agent_setup.sh` for complete agent system restoration
  - Updated `assets/.zshrc` to source `~/.agent_global/shell-aliases.sh`
  - Integrated `--agent` flag into `setup.sh` for agent-only setup
  - Updated README.md with comprehensive agent system documentation
  - Committed 119 files, 14,549+ lines of agent infrastructure
- **Agent System Features** now backed up:
  - Agent Global Hub (unified config for Claude/Kilo/Antigravity)
  - Memory Bank templates (enhanced with structured prompts)
  - Shell aliases (50+ commands: mbk, mbc, ag, cdc, token-*, etc.)
  - Git hooks (post-commit Memory Bank reminders)
  - Obsidian sync tool (bi-directional sync script)
  - Knowledge base (patterns, troubleshooting, learnings, recipes)
  - MCP server configuration (Obsidian, Filesystem, Brave Search, GitHub)
  - Token usage analytics framework
  - Auto memory optimization strategy
- **Impact**: systems-migration-main is now a **complete backup solution**:
  - Terminal environment (zsh, kitty, tmux, power tools) ✅
  - Agent workflow system (all AI agent infrastructure) ✅
  - Single command restore: `./setup.sh` now installs everything
  - Can restore on new machine with full terminal + agent setup

### Previous Changes

- Updated `godot_setup.sh` to auto-detect Godot zip from `~/Downloads`:
  - Removed hardcoded `GODOT_VERSION` and download-from-GitHub logic.
  - Script now searches `~/Downloads` for `Godot_v*_linux.x86_64.zip` (uses most recently modified if multiple found).
  - Extracts version from filename automatically.
  - Removes old Godot installation before installing new one.
  - Installed Godot v4.6-stable (upgraded from v4.5.1).
- Removed VS Code support entirely:
  - Deleted `scripts/vscode_setup.sh`, `assets/vscode/extensions.txt`, and all VS Code flags (`--vscode`, `--skip-vscode`).
  - VS Code is no longer installed or configured by this project.
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
- Added Calibre to desktop apps installed by [`scripts/apps_setup.sh`](../../scripts/apps_setup.sh:1).
- Fixed `ibus-bamboo` repository URL in [`scripts/input_setup.sh`](../../scripts/input_setup.sh:1) (changed `home:lamlng` to `home:/lamlng`).
- Improved `ibus-bamboo` repo resolution in [`scripts/input_setup.sh`](../../scripts/input_setup.sh:1) to support Fedora 42 and Rawhide with fallback logic.
- Enhanced `ibus-bamboo` setup to automatically configure GNOME input sources and set Bamboo as default using `gsettings` and `dconf`.
- Added DNS setup script (`scripts/dns_setup.sh`) to configure Cloudflare Block Malware DNS (1.1.1.2/1.0.0.2) via `nmcli`.
- Integrated **Antigravity Global Rules**:
  - Rules backed up to `assets/.gemini/GEMINI.md`.
  - Added `scripts/antigravity_setup.sh` to deploy rules to `~/.gemini/GEMINI.md`.
  - Updated `setup.sh` with `--antigravity` flag (default in full mode).
- Synced Memory Bank (product, architecture, tech, context) with current state.
- Renamed `assets/.config/fastfetch/sample_2_vscode.jsonc` → `sample_2_fallback.jsonc` to remove VS Code naming; updated `.zshrc` references in both project and live machine.


## Next Steps

### Immediate
- Test agent restore on clean machine/VM (validate agent_setup.sh rewrite)

### Future
- Automate periodic backup sync
- Add more patterns to knowledge base as discovered
