#!/bin/bash
# =============================================================================
# easyeffects_setup.sh - EasyEffects audio presets setup
# =============================================================================

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Setting up EasyEffects"

# =============================================================================
# Install EasyEffects
# =============================================================================
log_info "Installing EasyEffects..."
dnf_install easyeffects

log_success "EasyEffects installed"

# =============================================================================
# Restore presets and configuration
# =============================================================================
log_section "Restoring EasyEffects presets..."

EASYEFFECTS_BACKUP="$BACKUP_DIR/.config/easyeffects"
EASYEFFECTS_TARGET="$HOME/.config/easyeffects"

if [[ -d "$EASYEFFECTS_BACKUP" ]]; then
    copy_dir "$EASYEFFECTS_BACKUP" "$EASYEFFECTS_TARGET"
    log_success "EasyEffects presets restored to $EASYEFFECTS_TARGET"
    
    # Also copy to Flatpak location if it exists
    FLATPAK_CONFIG="$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects"
    if [[ -d "$HOME/.var/app/com.github.wwmm.easyeffects" ]]; then
        log_info "Detected Flatpak EasyEffects, copying presets there too..."
        copy_dir "$EASYEFFECTS_BACKUP" "$FLATPAK_CONFIG"
        log_success "EasyEffects presets also restored to Flatpak location"
    fi
else
    log_warn "EasyEffects backup not found at $EASYEFFECTS_BACKUP"
    log_info "No presets to restore. Configure EasyEffects manually."
fi

# =============================================================================
# Summary
# =============================================================================
log_section "EasyEffects Setup Complete!"
echo ""
echo "Restored presets include:"
echo "  - Output presets (G560, G435)"
echo "  - Autoload rules for automatic preset switching"
echo ""
echo "To use:"
echo "  1. Launch EasyEffects from your application menu"
echo "  2. Presets should auto-load based on your audio device"
echo "  3. Or manually select a preset from the Presets menu"
echo ""