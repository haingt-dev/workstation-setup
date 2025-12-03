#!/bin/bash
# =============================================================================
# vscode_setup.sh - VS Code installation and extensions
# =============================================================================
# NOTE: This script intentionally does NOT restore any VS Code user
# configuration (settings.json, keybindings, globalStorage, etc.) to avoid
# storing secrets (API keys, tokens) in version control.
# Use VS Code Settings Sync or manage your config manually.
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

# =============================================================================
# Install VS Code
# =============================================================================
log_section "Installing VS Code..."

if check_command code; then
    log_success "VS Code is already installed"
else
    log_info "VS Code not found, installing..."
    
    # Import Microsoft GPG key
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    
    # Add VSCode repository
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    
    sudo dnf check-update || true
    dnf_install code
    log_success "VS Code installed"
fi

log_section "VS Code setup complete!"
log_info "Note: VS Code settings are NOT restored from this repo."
log_info "Use VS Code Settings Sync or configure manually."