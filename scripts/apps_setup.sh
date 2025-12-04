#!/bin/bash
# =============================================================================
# apps_setup.sh - Additional applications (Chrome, Dropbox, Flatpaks)
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Installing Additional Applications"

# =============================================================================
# Firefox
# =============================================================================
log_section "Installing Firefox..."

dnf_install firefox
log_success "Firefox installed"

# =============================================================================
# Google Chrome
# =============================================================================
log_section "Installing Google Chrome..."

# Ensure dnf-plugins-core is installed (provides config-manager)
if ! rpm -q dnf-plugins-core &>/dev/null; then
    log_info "Installing dnf-plugins-core..."
    dnf_install dnf-plugins-core
fi

if ! dnf repolist 2>/dev/null | grep -q google-chrome; then
    dnf_install fedora-workstation-repositories
    sudo dnf config-manager setopt google-chrome.enabled=1
fi
dnf_install google-chrome-stable
log_success "Google Chrome installed"

# =============================================================================
# Dropbox
# =============================================================================
log_section "Installing Dropbox..."

dnf_install dropbox nautilus-dropbox
log_success "Dropbox installed"

# =============================================================================
# Flatpak Setup
# =============================================================================
log_section "Setting up Flatpak..."

if ! check_command flatpak; then
    log_info "Flatpak not found, installing..."
    dnf_install flatpak
fi

# Add Flathub if not present
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
log_success "Flathub repository configured"

# =============================================================================
# Install Flatpak Applications
# =============================================================================
log_section "Installing Flatpak applications..."

# Discord
log_info "Installing Discord..."
flatpak install -y flathub com.discordapp.Discord
log_success "Discord installed"

# Obsidian
log_info "Installing Obsidian..."
flatpak install -y flathub md.obsidian.Obsidian
log_success "Obsidian installed"

# Anki
log_info "Installing Anki..."
flatpak install -y flathub net.ankiweb.Anki
log_success "Anki installed"

# =============================================================================
# Summary
# =============================================================================
log_section "Additional Applications Installation Complete!"
echo ""
echo "Installed applications:"
echo "  - Firefox (DNF)"
# echo "  - Google Chrome (DNF)"
echo "  - Dropbox (DNF)"
echo "  - Discord (Flatpak)"
echo "  - Obsidian (Flatpak)"
echo "  - Anki (Flatpak)"
