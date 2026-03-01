#!/bin/bash
# =============================================================================
# vscode_setup.sh - Visual Studio Code installation via Microsoft RPM repo
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Installing Visual Studio Code"

# =============================================================================
# Add Microsoft RPM Repository
# =============================================================================
if ! rpm -q code &>/dev/null; then
    log_info "Adding Microsoft VS Code repository..."

    # Import Microsoft GPG key
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

    # Add the repository
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

    # Install VS Code
    dnf_install code
    log_success "Visual Studio Code installed"
else
    log_success "Visual Studio Code already installed"
fi

# =============================================================================
# Restore Settings (if backup exists)
# =============================================================================
VSCODE_CONFIG_DIR="$HOME/.config/Code/User"
VSCODE_BACKUP_DIR="$BACKUP_DIR/.config/Code/User"

if [[ -d "$VSCODE_BACKUP_DIR" ]]; then
    log_info "Restoring VS Code settings from backup..."
    ensure_dir "$VSCODE_CONFIG_DIR"

    if [[ -f "$VSCODE_BACKUP_DIR/settings.json" ]]; then
        copy_file "$VSCODE_BACKUP_DIR/settings.json" "$VSCODE_CONFIG_DIR/settings.json"
        log_success "Settings restored"
    fi

    if [[ -f "$VSCODE_BACKUP_DIR/keybindings.json" ]]; then
        copy_file "$VSCODE_BACKUP_DIR/keybindings.json" "$VSCODE_CONFIG_DIR/keybindings.json"
        log_success "Keybindings restored"
    fi
else
    log_info "No VS Code backup found in $VSCODE_BACKUP_DIR — skipping config restore"
fi

# =============================================================================
# Restore Extensions (if list exists)
# =============================================================================
EXTENSIONS_LIST="$BACKUP_DIR/.config/Code/extensions.txt"

if [[ -f "$EXTENSIONS_LIST" ]]; then
    log_info "Installing VS Code extensions from backup list..."
    while IFS= read -r ext; do
        [[ -z "$ext" || "$ext" == \#* ]] && continue
        log_info "Installing extension: $ext"
        code --install-extension "$ext" --force 2>/dev/null || log_warn "Failed to install: $ext"
    done < "$EXTENSIONS_LIST"
    log_success "Extensions installed"
else
    log_info "No extensions list found at $EXTENSIONS_LIST — skipping"
    log_info "To save your extensions: code --list-extensions > $EXTENSIONS_LIST"
fi

# =============================================================================
# Summary
# =============================================================================
log_section "Visual Studio Code Setup Complete!"
echo ""
echo "Installed:"
echo "  - Visual Studio Code (Microsoft RPM repo)"
echo ""
echo "Tips:"
echo "  - Save settings: cp ~/.config/Code/User/settings.json $VSCODE_BACKUP_DIR/"
echo "  - Save extensions: code --list-extensions > $EXTENSIONS_LIST"
