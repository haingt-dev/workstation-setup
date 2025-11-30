#!/bin/bash
# =============================================================================
# vscode_setup.sh - VS Code installation and configuration
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

VSCODE_USER_DIR="$HOME/.config/Code/User"
VSCODE_GLOBAL_STORAGE="$HOME/.config/Code/User/globalStorage"

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

# =============================================================================
# Restore VS Code Settings
# =============================================================================
log_section "Restoring VS Code settings..."
ensure_dir "$VSCODE_USER_DIR"

if [[ -f "$BACKUP_DIR/vscode/settings.json" ]]; then
    cp "$BACKUP_DIR/vscode/settings.json" "$VSCODE_USER_DIR/"
    log_success "settings.json restored"
fi

if [[ -f "$BACKUP_DIR/vscode/keybindings.json" ]]; then
    cp "$BACKUP_DIR/vscode/keybindings.json" "$VSCODE_USER_DIR/"
    log_success "keybindings.json restored"
fi

if [[ -d "$BACKUP_DIR/vscode/snippets" ]]; then
    ensure_dir "$VSCODE_USER_DIR/snippets"
    cp -r "$BACKUP_DIR/vscode/snippets/"* "$VSCODE_USER_DIR/snippets/"
    log_success "snippets restored"
fi

# =============================================================================
# Install VS Code Extensions
# =============================================================================
if [[ -f "$BACKUP_DIR/vscode/extensions.txt" ]]; then
    log_section "Installing VS Code extensions..."
    
    while IFS= read -r extension || [[ -n "$extension" ]]; do
        if [[ -n "$extension" && ! "$extension" =~ ^# ]]; then
            log_info "Installing: $extension"
            code --install-extension "$extension" --force 2>/dev/null || log_warn "Failed to install: $extension"
        fi
    done < "$BACKUP_DIR/vscode/extensions.txt"
    
    log_success "VS Code extensions installation complete"
fi

# =============================================================================
# Restore Global Storage (Kilo Code, etc.)
# =============================================================================
if [[ -d "$BACKUP_DIR/vscode/globalStorage/kilocode.kilo-code" ]]; then
    log_section "Restoring Kilo Code configuration..."
    ensure_dir "$VSCODE_GLOBAL_STORAGE"
    cp -r "$BACKUP_DIR/vscode/globalStorage/kilocode.kilo-code" "$VSCODE_GLOBAL_STORAGE/"
    log_success "Kilo Code global storage restored"
fi

log_section "VS Code setup complete!"