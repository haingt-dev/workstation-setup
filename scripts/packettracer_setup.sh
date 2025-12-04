#!/bin/bash
# =============================================================================
# packettracer_setup.sh - Cisco Packet Tracer installation (non-interactive)
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

# =============================================================================
# Handle Uninstall
# =============================================================================
if [[ "$1" == "--uninstall" ]]; then
    log_section "Uninstalling Cisco Packet Tracer..."
    if [[ -e /opt/pt ]]; then
        sudo rm -rf /opt/pt /usr/share/applications/cisco*-pt*.desktop
        sudo xdg-desktop-menu uninstall /usr/share/applications/cisco-pt*.desktop 2>/dev/null || true
        sudo update-mime-database /usr/share/mime 2>/dev/null || true
        sudo gtk-update-icon-cache -t --force /usr/share/icons/gnome 2>/dev/null || true
        sudo rm -f /usr/local/bin/packettracer 2>/dev/null || true
        log_success "Cisco Packet Tracer uninstalled"
    else
        log_info "Cisco Packet Tracer is not installed"
    fi
    exit 0
fi

# =============================================================================
# Find Installer
# =============================================================================
log_section "Installing Cisco Packet Tracer..."

SELECTED_INSTALLER=""

# First, check the backup directory for bundled installer
log_info "Checking for bundled installer..."
for installer in "$BACKUP_DIR"/Cisco*Packet*.deb "$BACKUP_DIR"/Packet*Tracer*.deb "$BACKUP_DIR"/CiscoPacketTracer*.deb; do
    if [[ -f "$installer" ]]; then
        SELECTED_INSTALLER="$installer"
        log_success "Found bundled installer: $SELECTED_INSTALLER"
        break
    fi
done

# If not found in backup directory, search in $HOME as fallback
if [[ -z "$SELECTED_INSTALLER" ]]; then
    log_info "Searching for installer in home directory..."
    SELECTED_INSTALLER=$(find "$HOME" -maxdepth 1 -type f \( -name "Cisco*Packet*.deb" -o -name "Packet*Tracer*.deb" \) 2>/dev/null | head -1)
fi

if [[ -z "$SELECTED_INSTALLER" ]]; then
    log_error "Packet Tracer installer (.deb) not found"
    echo ""
    echo "Download the installer from:"
    echo "  - https://www.netacad.com/portal/resources/packet-tracer"
    echo "  - https://skillsforall.com/resources/lab-downloads (login required)"
    echo ""
    echo "Place the .deb file in $BACKUP_DIR or your home directory and run this script again."
    exit 1
fi

log_success "Using installer: $SELECTED_INSTALLER"

# =============================================================================
# Remove Old Version
# =============================================================================
if [[ -e /opt/pt ]]; then
    log_info "Removing old version of Packet Tracer..."
    sudo rm -rf /opt/pt /usr/share/applications/cisco*-pt*.desktop 2>/dev/null || true
    sudo xdg-desktop-menu uninstall /usr/share/applications/cisco-pt*.desktop 2>/dev/null || true
    sudo update-mime-database /usr/share/mime 2>/dev/null || true
    sudo gtk-update-icon-cache -t --force /usr/share/icons/gnome 2>/dev/null || true
    sudo rm -f /usr/local/bin/packettracer 2>/dev/null || true
    log_success "Old version removed"
fi

# =============================================================================
# Install Dependencies
# =============================================================================
log_section "Installing dependencies..."
sudo dnf -y install binutils qt5-qt{multimedia,webengine,networkauth,websockets,webchannel,script,location,svg,speech}
log_success "Dependencies installed"

# =============================================================================
# Extract and Install
# =============================================================================
log_section "Extracting files..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

ar -x "$SELECTED_INSTALLER"
tar -xf control.tar.xz
tar -xf data.tar.xz
log_success "Files extracted"

log_section "Installing Packet Tracer..."
sudo cp -r usr / 2>/dev/null || true
sudo cp -r opt /

# Fix postinst script for Fedora (run non-interactively)
sudo sed -i 's/sudo xdg-mime/sudo -u $SUDO_USER xdg-mime/' ./postinst
sudo sed -i 's/sudo gtk-update-icon-cache --force/sudo gtk-update-icon-cache -t --force/' ./postinst
sudo sed -i 's/CONTENTS="$CONTENTS\\n$line"/CONTENTS="$CONTENTS\
$line"/' ./postinst

# Run postinst script
sudo ./postinst

# Add --no-sandbox flag for running on Fedora
sudo sed -i 's/packettracer/packettracer --no-sandbox args/' /usr/share/applications/cisco-pt*.desktop
log_success "Packet Tracer installed"

# =============================================================================
# Cleanup
# =============================================================================
cd - > /dev/null
rm -rf "$TEMP_DIR"
log_success "Temporary files cleaned up"

# =============================================================================
# Restore Custom Assets
# =============================================================================
log_section "Restoring custom assets..."

# Restore custom icon if available
if [[ -f "$BACKUP_DIR/packettracer.png" ]]; then
    ensure_dir ~/.local/share/icons
    cp "$BACKUP_DIR/packettracer.png" ~/.local/share/icons/cisco-pt.png
    log_success "Custom icon restored"
fi

# Restore custom desktop shortcut if available
if [[ -f "$BACKUP_DIR/cisco-pt.desktop" ]]; then
    ensure_dir ~/.local/share/applications
    cp "$BACKUP_DIR/cisco-pt.desktop" ~/.local/share/applications/
    # Replace ~ with actual home path in Icon field
    sed -i "s|Icon=~/|Icon=$HOME/|g" ~/.local/share/applications/cisco-pt.desktop
    log_success "Custom shortcut restored"
fi

log_section "Cisco Packet Tracer installation complete!"
echo ""
log_info "Launch from the application menu or run 'packettracer' in terminal"