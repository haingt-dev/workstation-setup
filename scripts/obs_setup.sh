#!/bin/bash
# =============================================================================
# obs_setup.sh - OBS Studio installation and configuration
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

# Configuration
OBS_CONFIG_DIR="$HOME/.config/obs-studio"

# =============================================================================
# Install OBS
# =============================================================================
log_section "Installing OBS Studio..."

if ! check_command flatpak; then
    log_info "Flatpak not found, installing..."
    dnf_install flatpak
fi

# Add Flathub if not present
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install OBS
log_info "Installing com.obsproject.Studio..."
flatpak install -y flathub com.obsproject.Studio
log_success "OBS Studio installed"

# =============================================================================
# Restore Configuration
# =============================================================================
log_section "Restoring OBS configuration..."

if ! restore_dir "obs-studio" "$OBS_CONFIG_DIR"; then
    log_info "Skipping configuration restore"
fi

# =============================================================================
# Summary
# =============================================================================
log_section "OBS Studio setup complete!"
echo ""
log_info "Run OBS with: flatpak run com.obsproject.Studio"
