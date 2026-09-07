#!/bin/bash
# =============================================================================
# agent_setup.sh - Setup Agent Hub from git repo
# =============================================================================
#
# Usage:
#   ./agent_setup.sh    # Clone agent hub + restore Claude config
#
# This script sets up:
#   - ~/Projects/agent/ (clone from GitHub if not present)
#   - Shell aliases integration (verifies ~/.zshrc sources shell-aliases.sh)
#   - awake-guard: keeps the machine awake while a Claude Code session is in use
#
# Note: This script complements terminal_setup.sh and should be run AFTER it.
#
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

AGENT_DIR="$HOME/Projects/agent"
AGENT_REPO="git@github.com:haingt-dev/agent.git"

# =============================================================================
# Agent Hub Setup
# =============================================================================

setup_agent_hub() {
    log_section "Setting up Agent Hub..."

    # Clean up legacy locations
    if [[ -L "$HOME/.agent_global" ]]; then
        rm "$HOME/.agent_global"
        log_info "Removed legacy ~/.agent_global symlink"
    fi

    if [[ -d "$HOME/agent" && ! -L "$HOME/agent" ]]; then
        log_warn "Found stale ~/agent/ directory, removing..."
        rm -rf "$HOME/agent"
        log_info "Removed ~/agent/"
    fi

    # Clone or verify agent repo
    if [[ -d "$AGENT_DIR/.git" ]]; then
        log_success "Agent Hub already exists at $AGENT_DIR"
        log_info "Pulling latest changes..."
        git -C "$AGENT_DIR" pull --ff-only 2>/dev/null || log_warn "Could not pull (check remote access)"
    else
        log_info "Cloning Agent Hub to $AGENT_DIR..."
        ensure_dir "$HOME/Projects"
        git clone "$AGENT_REPO" "$AGENT_DIR"
        log_success "Agent Hub cloned to $AGENT_DIR"
    fi

    # Make scripts executable
    find "$AGENT_DIR" -name '*.sh' -type f -exec chmod +x {} +

    # Claude config (~/.claude.json MCP servers + ~/.claude/plugins/) is live,
    # tool-managed state — seeded fresh by Claude Code on first run, backed up by
    # scripts/backup/daily-bundle.sh (Section 2) and restored by recover.sh Phase 4.
    # Nothing to seed from this repo.

    # Verify shell aliases integration
    log_info "Verifying shell aliases integration..."

    if grep -q "Projects/agent/bin/shell-aliases.sh" "$HOME/.zshrc" 2>/dev/null; then
        log_success "Shell aliases already integrated in ~/.zshrc"
    else
        log_warn "Shell aliases not found in ~/.zshrc"
        log_info "Add this line to ~/.zshrc:"
        echo "    source ~/Projects/agent/bin/shell-aliases.sh"
    fi

    log_success "Agent Hub setup complete!"
}

# =============================================================================
# Project Configuration
# =============================================================================

configure_projects() {
    log_section "Configuring projects..."

    if [[ ! -d "$HOME/Projects" ]]; then
        log_warn "~/Projects directory not found, creating..."
        mkdir -p "$HOME/Projects"
    fi

    log_success "Project configuration complete!"
}

# =============================================================================
# Awake guard
# =============================================================================
# Plasma suspends after 15 min without LOCAL input, and reading an answer,
# thinking between prompts, or driving a session from the phone through Remote
# Control all look idle to it. The Claude inhibit hooks
# (~/.claude/hooks/claude-inhibit-*.sh) cover a turn while it RUNS; this guard
# covers the quiet time around it, watching transcript mtimes under
# ~/.claude/projects. Lives here rather than in a remote-access stage because
# what it protects is a Claude session, not a connection — the iPad/Tailscale
# stack it was originally written for was retired 2026-09-07.

setup_awake_guard() {
    log_section "Setting up awake-guard..."

    # link_file returns 1 on a missing asset — guard the chain so `set -e` can't
    # abort mid-section, and don't enable a unit whose script failed to link.
    if link_file ".local/bin/awake-guard.sh" ~/.local/bin/awake-guard.sh \
        && link_file ".config/systemd/user/awake-guard.service" ~/.config/systemd/user/awake-guard.service; then
        if systemctl --user daemon-reload 2>/dev/null \
            && systemctl --user enable --now awake-guard.service 2>/dev/null; then
            # An older version may already be running with the previous script.
            systemctl --user restart awake-guard.service 2>/dev/null || true
            if systemctl --user is-active --quiet awake-guard.service; then
                log_success "awake-guard running (blocks sleep while Claude Code is in use)"
            else
                log_warn "awake-guard enabled but not active — check: systemctl --user status awake-guard"
            fi
        else
            log_warn "systemd user manager unavailable — run later: systemctl --user enable --now awake-guard"
        fi
    else
        log_warn "awake-guard assets missing — section skipped (incomplete checkout?)"
    fi
}

# =============================================================================
# Verification
# =============================================================================

verify_installation() {
    log_section "Verifying installation..."

    local ERRORS=0

    if [[ ! -d "$AGENT_DIR/.git" ]]; then
        log_error "$AGENT_DIR is not a git repository"
        ((ERRORS++))
    fi

    if [[ -d "$HOME/agent" ]]; then
        log_warn "Stale ~/agent/ directory still exists"
    fi

    if [[ -L "$HOME/.agent_global" ]]; then
        log_warn "Legacy ~/.agent_global symlink still exists"
    fi

    if [[ ! -f "$AGENT_DIR/bin/shell-aliases.sh" ]]; then
        log_error "Shell aliases script not found"
        ((ERRORS++))
    fi

    # The agent hub moved its scripts under bin/ — this check still pointed at
    # the old top-level path and failed the whole stage (found 2026-09-07).
    if [[ ! -x "$AGENT_DIR/bin/bootstrap-project.sh" ]]; then
        log_error "bin/bootstrap-project.sh not executable"
        ((ERRORS++))
    fi

    if [[ $ERRORS -eq 0 ]]; then
        log_success "All checks passed!"
        return 0
    else
        log_error "Installation verification failed with $ERRORS error(s)"
        return 1
    fi
}

# =============================================================================
# Execution
# =============================================================================

setup_agent_hub
configure_projects
setup_awake_guard
verify_installation

log_success "Agent Hub setup complete!"

echo ""
echo -e "${CYAN}${BOLD}Next Steps:${NC}"
echo "1. Restart terminal (or run: source ~/.zshrc)"
echo "2. Test aliases: ag-help"
echo "3. Bootstrap new projects: bootstrap /path/to/project"
echo ""
echo -e "${CYAN}${BOLD}Quick Commands:${NC}"
echo "  ag            - Go to Agent Hub"
echo "  cdc <project> - Switch to project"
echo "  bootstrap <d> - Initialize a project"
echo "  ag-help       - Show all commands"
echo ""
