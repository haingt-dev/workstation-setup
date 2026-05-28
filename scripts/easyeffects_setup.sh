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
log_section "Linking EasyEffects presets..."

EASYEFFECTS_BACKUP="$BACKUP_DIR/.config/easyeffects"
EASYEFFECTS_TARGET="$HOME/.config/easyeffects"

# Symlink preset files individually (NOT the whole dir): EasyEffects writes its
# own state into ~/.config/easyeffects/, so only the user-authored presets are
# linked back to the repo. Editing a preset in the GUI then writes through to git.
if [[ -d "$EASYEFFECTS_BACKUP" ]]; then
    for preset in "$EASYEFFECTS_BACKUP"/output/*.json \
                  "$EASYEFFECTS_BACKUP"/autoload/output/*.json; do
        [[ -e "$preset" ]] || continue
        link_file "${preset#"$BACKUP_DIR"/}" "$EASYEFFECTS_TARGET/${preset#"$EASYEFFECTS_BACKUP"/}"
    done
    log_success "EasyEffects presets linked into $EASYEFFECTS_TARGET"
    
else
    log_warn "EasyEffects presets not found at $EASYEFFECTS_BACKUP"
    log_info "No presets to link. Configure EasyEffects manually."
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