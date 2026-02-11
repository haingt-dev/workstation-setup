#!/bin/bash
# =============================================================================
# agent_setup.sh - Restore Agent Global Hub configuration
# =============================================================================
#
# Usage:
#   ./agent_setup.sh    # Restore agent global configuration
#
# This script restores the Agent Global Hub including:
#   - ~/.agent_global/ structure (rules, workflows, knowledge, hooks, etc.)
#   - ~/.claude/ MCP settings and documentation
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
# Agent Global Hub Setup
# =============================================================================

setup_agent_global() {
    log_section "Setting up Agent Global Hub..."

    # 1. Restore .agent_global directory
    if [[ -d "$BACKUP_DIR/.agent_global" ]]; then
        log_info "Restoring Agent Global Hub structure..."

        # Remove existing if present
        if [[ -d "$HOME/.agent_global" ]]; then
            log_warn "Existing ~/.agent_global found, backing up..."
            mv "$HOME/.agent_global" "$HOME/.agent_global.backup.$(date +%s)"
        fi

        # Copy entire structure
        cp -r "$BACKUP_DIR/.agent_global" "$HOME/"

        # Make scripts executable
        chmod +x "$HOME/.agent_global/bootstrap-project.sh"
        chmod +x "$HOME/.agent_global/sync-obsidian.sh"
        chmod +x "$HOME/.agent_global/shell-aliases.sh"
        chmod +x "$HOME/.agent_global/hooks/"*.sh
        chmod +x "$HOME/.agent_global/hooks/post-commit-mb-reminder"
        chmod +x "$HOME/.agent_global/analytics/token-tracker.sh"

        log_success "Agent Global Hub restored to ~/.agent_global/"
    else
        log_error ".agent_global not found in backup directory"
        return 1
    fi

    # 2. Setup Claude symlinks
    log_info "Setting up Claude integration..."

    mkdir -p "$HOME/.claude/rules"
    mkdir -p "$HOME/.claude/workflows"

    # Create symlinks to Agent Global Hub
    ln -sf "$HOME/.agent_global/rules/global_rules.md" "$HOME/.claude/rules/CLAUDE.md"
    ln -sf "$HOME/.agent_global/workflows/core-directives.md" "$HOME/.claude/workflows/"
    ln -sf "$HOME/.agent_global/workflows/commit-protocol.md" "$HOME/.claude/workflows/"
    ln -sf "$HOME/.agent_global/workflows/memory-bank-protocol.md" "$HOME/.claude/workflows/"
    ln -sf "$HOME/.agent_global/workflows/documentation-sync.md" "$HOME/.claude/workflows/"

    log_success "Claude symlinks created"

    # 3. Copy Claude MCP configuration
    if [[ -d "$BACKUP_DIR/.claude" ]]; then
        log_info "Restoring Claude MCP configuration..."

        # Copy MCP settings
        if [[ -f "$BACKUP_DIR/.claude/mcp_settings.json" ]]; then
            cp "$BACKUP_DIR/.claude/mcp_settings.json" "$HOME/.claude/"
        fi

        # Copy MCP setup guide
        if [[ -f "$BACKUP_DIR/.claude/MCP_SETUP.md" ]]; then
            cp "$BACKUP_DIR/.claude/MCP_SETUP.md" "$HOME/.claude/"
        fi

        log_success "Claude MCP configuration restored"
    fi

    # 4. Setup auto memory
    log_info "Setting up Claude auto memory..."
    mkdir -p "$HOME/.claude/projects/-home-haint/memory"

    if [[ -f "$BACKUP_DIR/.claude/projects/-home-haint/memory/MEMORY.md" ]]; then
        cp "$BACKUP_DIR/.claude/projects/-home-haint/memory/MEMORY.md" \
           "$HOME/.claude/projects/-home-haint/memory/"
        log_success "Claude auto memory restored"
    else
        log_warn "No auto memory backup found, will be created on first Claude run"
    fi

    # 5. Verify shell aliases integration
    log_info "Verifying shell aliases integration..."

    if grep -q "agent_global/shell-aliases.sh" "$HOME/.zshrc" 2>/dev/null; then
        log_success "Shell aliases already integrated in ~/.zshrc"
    else
        log_warn "Shell aliases not found in ~/.zshrc"
        log_info "They should have been added by terminal_setup.sh"
        log_info "If not present, add this line to ~/.zshrc:"
        echo "    source ~/.agent_global/shell-aliases.sh"
    fi

    log_success "Agent Global Hub setup complete!"
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
    if [[ -f "$HOME/.agent_global/hooks/install-all-projects.sh" ]]; then
        log_info "Installing Memory Bank git hooks to all projects..."
        "$HOME/.agent_global/hooks/install-all-projects.sh"
        log_success "Git hooks installed"
    fi

    # Check for Obsidian vault
    OBSIDIAN_VAULT="$HOME/Dropbox/Apps/Obsidian/Idea_Vault"
    if [[ -d "$OBSIDIAN_VAULT" ]]; then
        log_success "Obsidian vault found at $OBSIDIAN_VAULT"
        log_info "You can setup Obsidian sync for projects using:"
        echo "    ~/.agent_global/sync-obsidian.sh <project-name> --symlink"
    else
        log_warn "Obsidian vault not found at $OBSIDIAN_VAULT"
        log_info "Sync features will not work until vault is available"
    fi

    log_success "Project configuration complete!"
}

# =============================================================================
# Verification
# =============================================================================

verify_installation() {
    log_section "Verifying installation..."

    local ERRORS=0

    # Check Agent Global Hub
    if [[ ! -d "$HOME/.agent_global" ]]; then
        log_error "~/.agent_global not found"
        ((ERRORS++))
    fi

    # Check Claude integration
    if [[ ! -L "$HOME/.claude/rules/CLAUDE.md" ]]; then
        log_error "Claude symlinks not created"
        ((ERRORS++))
    fi

    # Check shell aliases script
    if [[ ! -f "$HOME/.agent_global/shell-aliases.sh" ]]; then
        log_error "Shell aliases script not found"
        ((ERRORS++))
    fi

    # Check key scripts are executable
    if [[ ! -x "$HOME/.agent_global/bootstrap-project.sh" ]]; then
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

setup_agent_global
configure_projects
verify_installation

log_success "Agent Global Hub setup complete!"

echo ""
echo -e "${CYAN}${BOLD}Next Steps:${NC}"
echo "1. Restart terminal (or run: source ~/.zshrc)"
echo "2. Test aliases: ag-help"
echo "3. Bootstrap new projects: bootstrap /path/to/project"
echo "4. Setup Obsidian sync for projects: sync-obsidian.sh <project> --symlink"
echo "5. Install Node.js for MCP servers (see ~/.claude/MCP_SETUP.md)"
echo ""
echo -e "${CYAN}${BOLD}Quick Commands:${NC}"
echo "  ag            - Go to Agent Global Hub"
echo "  mbk           - Edit Memory Bank"
echo "  cdc <project> - Switch to project"
echo "  ag-help       - Show all commands"
echo ""
