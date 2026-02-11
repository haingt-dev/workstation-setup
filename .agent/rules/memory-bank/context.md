# Context

## Current Work Focus

- Repo is stable with single-profile terminal setup and no backup pipeline.

## Recent Changes

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
- ✅ Push to remote repository (backup agent system)
- Install Node.js for MCP servers (unlock Obsidian MCP)
- Enable Obsidian MCP server in Claude

### Future
- Test agent system restore on clean machine/VM
- Setup Obsidian sync for other projects (chimera-protocol, media-server)
- Add more patterns to knowledge base as discovered
- Consider adding more MCP servers (Brave Search, GitHub)
