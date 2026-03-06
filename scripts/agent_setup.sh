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
#   - ~/.claude/ settings (MCP, plugins)
#   - Shell aliases integration
#   - Git hooks installation to all projects
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
AGENT_REPO="git@github.com:hailazy/agent.git"

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
    [[ -f "$AGENT_DIR/hooks/post-commit-mb-reminder" ]] && chmod +x "$AGENT_DIR/hooks/post-commit-mb-reminder"

    # Restore Claude configuration
    if [[ -d "$BACKUP_DIR/.claude" ]]; then
        log_info "Restoring Claude configuration..."
        ensure_dir "$HOME/.claude"

        [[ -f "$BACKUP_DIR/.claude/mcp_settings.json" ]] && \
            cp "$BACKUP_DIR/.claude/mcp_settings.json" "$HOME/.claude/"

        if [[ -d "$BACKUP_DIR/.claude/plugins" ]]; then
            ensure_dir "$HOME/.claude/plugins"
            [[ -f "$BACKUP_DIR/.claude/plugins/known_marketplaces.json" ]] && \
                cp "$BACKUP_DIR/.claude/plugins/known_marketplaces.json" "$HOME/.claude/plugins/"
            [[ -f "$BACKUP_DIR/.claude/plugins/installed_plugins.json" ]] && \
                cp "$BACKUP_DIR/.claude/plugins/installed_plugins.json" "$HOME/.claude/plugins/"
        fi

        log_success "Claude configuration restored"
    fi

    # Verify shell aliases integration
    log_info "Verifying shell aliases integration..."

    if grep -q "Projects/agent/shell-aliases.sh" "$HOME/.zshrc" 2>/dev/null; then
        log_success "Shell aliases already integrated in ~/.zshrc"
    else
        log_warn "Shell aliases not found in ~/.zshrc"
        log_info "Add this line to ~/.zshrc:"
        echo "    source ~/Projects/agent/shell-aliases.sh"
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

    if [[ -f "$AGENT_DIR/hooks/install-all-projects.sh" ]]; then
        log_info "Installing Memory Bank git hooks to all projects..."
        "$AGENT_DIR/hooks/install-all-projects.sh"
        log_success "Git hooks installed"
    fi

    log_success "Project configuration complete!"
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

    if [[ ! -f "$AGENT_DIR/shell-aliases.sh" ]]; then
        log_error "Shell aliases script not found"
        ((ERRORS++))
    fi

    if [[ ! -x "$AGENT_DIR/bootstrap-project.sh" ]]; then
        log_error "bootstrap-project.sh not executable"
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
echo "  mbk           - Edit Memory Bank"
echo "  cdc <project> - Switch to project"
echo "  ag-help       - Show all commands"
echo ""
