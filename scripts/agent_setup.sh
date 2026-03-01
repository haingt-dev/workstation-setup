#!/bin/bash
# =============================================================================
# agent_setup.sh - Restore Agent Hub (~/agent) configuration
# =============================================================================
#
# Usage:
#   ./agent_setup.sh    # Restore agent hub configuration
#
# This script restores:
#   - ~/agent/ directory (hub repo with plugins, hooks, templates, etc.)
#   - ~/.agent_global symlink → ~/agent
#   - ~/.claude/ settings (MCP, plugins, settings.local.json)
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

# =============================================================================
# Agent Hub Setup
# =============================================================================

setup_agent_hub() {
    log_section "Setting up Agent Hub..."

    # 1. Restore ~/agent directory
    if [[ -d "$BACKUP_DIR/.agent_global" ]]; then
        log_info "Restoring Agent Hub to ~/agent/..."

        # Handle existing ~/agent
        if [[ -d "$HOME/agent" && ! -L "$HOME/agent" ]]; then
            log_warn "Existing ~/agent found, backing up..."
            mv "$HOME/agent" "$HOME/agent.backup.$(date +%s)"
        fi

        # Handle existing symlink
        if [[ -L "$HOME/.agent_global" ]]; then
            rm "$HOME/.agent_global"
        elif [[ -d "$HOME/.agent_global" ]]; then
            log_warn "Existing ~/.agent_global directory found, backing up..."
            mv "$HOME/.agent_global" "$HOME/.agent_global.backup.$(date +%s)"
        fi

        # Copy backup to ~/agent
        ensure_dir "$HOME/agent"
        cp -r "$BACKUP_DIR/.agent_global/"* "$HOME/agent/"
        cp -r "$BACKUP_DIR/.agent_global/".* "$HOME/agent/" 2>/dev/null || true

        # Create symlink: ~/.agent_global → ~/agent
        ln -sf "$HOME/agent" "$HOME/.agent_global"

        # Make scripts executable
        find "$HOME/agent" -name '*.sh' -type f -exec chmod +x {} +
        [[ -f "$HOME/agent/hooks/post-commit-mb-reminder" ]] && chmod +x "$HOME/agent/hooks/post-commit-mb-reminder"

        log_success "Agent Hub restored to ~/agent/ (symlinked from ~/.agent_global)"
    else
        log_error ".agent_global not found in backup directory"
        return 1
    fi

    # 2. Restore Claude configuration
    if [[ -d "$BACKUP_DIR/.claude" ]]; then
        log_info "Restoring Claude configuration..."
        ensure_dir "$HOME/.claude"

        # Copy settings
        [[ -f "$BACKUP_DIR/.claude/settings.local.json" ]] && \
            cp "$BACKUP_DIR/.claude/settings.local.json" "$HOME/.claude/"
        [[ -f "$BACKUP_DIR/.claude/mcp_settings.json" ]] && \
            cp "$BACKUP_DIR/.claude/mcp_settings.json" "$HOME/.claude/"

        # Copy plugin registry
        if [[ -d "$BACKUP_DIR/.claude/plugins" ]]; then
            ensure_dir "$HOME/.claude/plugins"
            [[ -f "$BACKUP_DIR/.claude/plugins/known_marketplaces.json" ]] && \
                cp "$BACKUP_DIR/.claude/plugins/known_marketplaces.json" "$HOME/.claude/plugins/"
            [[ -f "$BACKUP_DIR/.claude/plugins/installed_plugins.json" ]] && \
                cp "$BACKUP_DIR/.claude/plugins/installed_plugins.json" "$HOME/.claude/plugins/"
        fi

        log_success "Claude configuration restored"
    fi

    # 3. Verify shell aliases integration
    log_info "Verifying shell aliases integration..."

    if grep -q "agent_global/shell-aliases.sh\|agent/shell-aliases.sh" "$HOME/.zshrc" 2>/dev/null; then
        log_success "Shell aliases already integrated in ~/.zshrc"
    else
        log_warn "Shell aliases not found in ~/.zshrc"
        log_info "Add this line to ~/.zshrc:"
        echo "    source ~/agent/shell-aliases.sh"
    fi

    log_success "Agent Hub setup complete!"
}

# =============================================================================
# Project Configuration
# =============================================================================

configure_projects() {
    log_section "Configuring projects..."

    # Check if Projects directory exists
    if [[ ! -d "$HOME/Projects" ]]; then
        log_warn "~/Projects directory not found, creating..."
        mkdir -p "$HOME/Projects"
    fi

    # Install git hooks to all projects
    if [[ -f "$HOME/agent/hooks/install-all-projects.sh" ]]; then
        log_info "Installing Memory Bank git hooks to all projects..."
        "$HOME/agent/hooks/install-all-projects.sh"
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

    # Check Agent Hub directory
    if [[ ! -d "$HOME/agent" ]]; then
        log_error "~/agent not found"
        ((ERRORS++))
    fi

    # Check symlink
    if [[ ! -L "$HOME/.agent_global" ]]; then
        log_error "~/.agent_global symlink not found"
        ((ERRORS++))
    fi

    # Check shell aliases script
    if [[ ! -f "$HOME/agent/shell-aliases.sh" ]]; then
        log_error "Shell aliases script not found"
        ((ERRORS++))
    fi

    # Check key scripts are executable
    if [[ ! -x "$HOME/agent/bootstrap-project.sh" ]]; then
        log_error "bootstrap-project.sh not executable"
        ((ERRORS++))
    fi

    # Check Claude settings
    if [[ ! -f "$HOME/.claude/settings.local.json" ]]; then
        log_warn "~/.claude/settings.local.json not found (non-critical)"
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
echo "4. Init ~/agent as git repo if needed: cd ~/agent && git init"
echo ""
echo -e "${CYAN}${BOLD}Quick Commands:${NC}"
echo "  ag            - Go to Agent Hub"
echo "  mbk           - Edit Memory Bank"
echo "  cdc <project> - Switch to project"
echo "  ag-help       - Show all commands"
echo ""
