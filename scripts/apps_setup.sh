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
# System Update
# =============================================================================
log_section "Updating System..."

run_sudo dnf update -y
if check_command flatpak; then
    flatpak update -y
fi
log_success "System updated"

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
    run_sudo dnf config-manager setopt google-chrome.enabled=1
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
# Calibre
# =============================================================================
log_section "Installing Calibre..."

dnf_install calibre
log_success "Calibre installed"

# =============================================================================
# VLC
# =============================================================================
log_section "Installing VLC..."

dnf_install vlc
log_success "VLC installed"

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

# Anki
log_info "Installing Anki..."
flatpak install -y flathub net.ankiweb.Anki
log_success "Anki installed"

# Todoist
log_info "Installing Todoist..."
flatpak install -y flathub com.todoist.Todoist
flatpak override --user com.todoist.Todoist \
    --talk-name=org.kde.StatusNotifierWatcher \
    --talk-name=org.freedesktop.Notifications
log_success "Todoist installed"

# =============================================================================
# Obsidian (AppImage)
# =============================================================================
log_section "Installing Obsidian (AppImage)..."

OBSIDIAN_DIR="$HOME/Applications"
OBSIDIAN_APPIMAGE="$OBSIDIAN_DIR/Obsidian.AppImage"
mkdir -p "$OBSIDIAN_DIR"

# Fetch latest AppImage URL (x86_64, not arm64)
OBSIDIAN_URL=$(curl -sfL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
    | grep -oP '"browser_download_url": "\K[^"]*\.AppImage(?=")' \
    | grep -v arm64)

if [ -z "$OBSIDIAN_URL" ]; then
    log_error "Failed to fetch Obsidian download URL"
else
    log_info "Downloading from: $OBSIDIAN_URL"
    curl -L "$OBSIDIAN_URL" -o "$OBSIDIAN_APPIMAGE"
    chmod +x "$OBSIDIAN_APPIMAGE"

    # Extract icon from AppImage (the root obsidian.png is a symlink, extract the real file)
    EXTRACT_DIR=$(mktemp -d)
    (cd "$EXTRACT_DIR" && "$OBSIDIAN_APPIMAGE" --appimage-extract "usr/share/icons/hicolor/512x512/apps/obsidian.png" 2>/dev/null) || true
    ICON_FILE="$EXTRACT_DIR/squashfs-root/usr/share/icons/hicolor/512x512/apps/obsidian.png"
    if [ -f "$ICON_FILE" ]; then
        mkdir -p "$HOME/.local/share/icons"
        cp "$ICON_FILE" "$HOME/.local/share/icons/obsidian.png"
    fi
    rm -rf "$EXTRACT_DIR"

    # Create desktop entry
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/obsidian.desktop" << DESKTOP_EOF
[Desktop Entry]
Name=Obsidian
Exec=$OBSIDIAN_APPIMAGE %u
Icon=obsidian
Type=Application
Categories=Office;
MimeType=x-scheme-handler/obsidian;
Comment=Knowledge base
DESKTOP_EOF

    log_success "Obsidian AppImage installed to $OBSIDIAN_APPIMAGE"
fi

# =============================================================================
# Summary
# =============================================================================
log_section "Additional Applications Installation Complete!"
echo ""
echo "Installed applications:"
echo "  - Firefox (DNF)"
echo "  - Google Chrome (DNF)"
echo "  - Dropbox (DNF)"
echo "  - Calibre (DNF)"
echo "  - VLC (DNF)"
echo "  - Discord (Flatpak)"
echo "  - Obsidian (AppImage)"
echo "  - Anki (Flatpak)"
echo "  - Todoist (Flatpak)"
