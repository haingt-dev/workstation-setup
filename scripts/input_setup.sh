#!/bin/bash
# =============================================================================
# input_setup.sh - Vietnamese input method support (fcitx5-unikey)
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

PROFILE_FILE="$HOME/.profile"

# =============================================================================
# Migration: Clean up previous ibus installation
# =============================================================================

# Remove ibus-bamboo OBS repo if present
if [ -f /etc/yum.repos.d/ibus-bamboo.repo ]; then
    log_info "Removing old ibus-bamboo repository..."
    sudo rm -f /etc/yum.repos.d/ibus-bamboo.repo
    log_success "Removed ibus-bamboo.repo"
fi

# Remove ibus-bamboo package if installed
if rpm -q ibus-bamboo &>/dev/null; then
    log_info "Removing ibus-bamboo package..."
    sudo dnf remove -y ibus-bamboo
    log_success "Removed ibus-bamboo"
fi

# Remove old ibus env vars from .profile
if grep -q "GTK_IM_MODULE=ibus" "$PROFILE_FILE" 2>/dev/null; then
    log_info "Removing old ibus environment variables from ~/.profile..."
    sed -i '/# IBus input method configuration/d' "$PROFILE_FILE"
    sed -i '/GTK_IM_MODULE=ibus/d' "$PROFILE_FILE"
    sed -i '/QT_IM_MODULE=ibus/d' "$PROFILE_FILE"
    sed -i '/XMODIFIERS=@im=ibus/d' "$PROFILE_FILE"
    log_success "Removed ibus environment variables from ~/.profile"
fi

# =============================================================================
# Install fcitx5 with Unikey
# =============================================================================
log_section "Installing Vietnamese Input Method (fcitx5-unikey)"

dnf_install fcitx5 fcitx5-unikey fcitx5-gtk fcitx5-qt fcitx5-configtool kcm-fcitx5

log_success "fcitx5 packages installed"

# =============================================================================
# Configure environment variables
# =============================================================================
log_section "Configuring input method environment..."

if ! grep -q "GTK_IM_MODULE=fcitx" "$PROFILE_FILE" 2>/dev/null; then
    cat >> "$PROFILE_FILE" << 'EOF'

# fcitx5 input method configuration
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF
    log_success "Added fcitx5 environment variables to ~/.profile"
else
    log_info "fcitx5 environment variables already configured in ~/.profile"
fi

# =============================================================================
# Configure default input method profile
# =============================================================================
log_section "Configuring fcitx5 default profile..."

FCITX5_CONFIG_DIR="$HOME/.config/fcitx5"
mkdir -p "$FCITX5_CONFIG_DIR"

cat > "$FCITX5_CONFIG_DIR/profile" << 'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=unikey

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=unikey
Layout=

[GroupOrder]
0=Default
EOF

log_success "fcitx5 profile configured with Unikey (Vietnamese)"

# =============================================================================
# Configure trigger key (Super+Space to avoid Ctrl+Space conflict with Kitty)
# =============================================================================
log_section "Configuring fcitx5 trigger key..."

cat > "$FCITX5_CONFIG_DIR/config" << 'EOF'
[Hotkey/TriggerKeys]
0=Super+space

[Hotkey/EnumerateWithTriggerKeys]
0=True

[Hotkey/EnumerateForwardKeys]
0=Super+space

[Hotkey/EnumerateBackwardKeys]
0=Shift+Super+space
EOF

log_success "fcitx5 trigger key set to Super+Space"

# =============================================================================
# Disable imsettings (conflicts with fcitx5 on Wayland)
# =============================================================================
if rpm -q imsettings &>/dev/null; then
    log_info "Disabling imsettings (conflicts with fcitx5 on Wayland)..."
    imsettings-switch none 2>/dev/null || true
    log_success "imsettings disabled"
fi

# =============================================================================
# KDE Wayland: Set fcitx5 as virtual keyboard in KWin
# =============================================================================
if command -v kwriteconfig6 &>/dev/null; then
    log_section "Configuring KDE for fcitx5..."

    # Set fcitx5 as Wayland virtual keyboard
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboard fcitx5
        log_success "Set fcitx5 as KDE Wayland virtual keyboard"
    fi

    # Remove KDE keyboard layout switcher shortcut (conflicts with fcitx5 Super+Space)
    kwriteconfig6 --file kglobalshortcutsrc --group "KDE Keyboard Layout Switcher" \
        --key "Switch to Next Keyboard Layout" "none,Meta+Alt+K,Switch to Next Keyboard Layout"
    kwriteconfig6 --file kglobalshortcutsrc --group "org.kde.keyboard_layout_switcher" \
        --key "Switch to Next Keyboard Layout" "none,Meta+Alt+K,Switch to Next Keyboard Layout"
    log_success "Cleared KDE Meta+Space shortcut conflict"
fi

# =============================================================================
# XDG autostart (fallback for X11 / non-KDE)
# =============================================================================
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/fcitx5-autostart.desktop"

if [ ! -f "$AUTOSTART_FILE" ]; then
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_FILE" << 'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx 5
Comment=Start fcitx5 input method framework
Exec=fcitx5
Icon=fcitx
Categories=System;Utility;
X-GNOME-Autostart-enabled=true
EOF
    log_success "Created fcitx5 XDG autostart entry"
else
    log_info "fcitx5 autostart entry already exists"
fi

# =============================================================================
# Summary
# =============================================================================
log_section "Vietnamese Input Method Setup Complete!"
echo ""
echo "To complete setup:"
echo "  1. Log out and log back in (or reboot)"
echo "  2. fcitx5 will start automatically with Unikey enabled"
echo ""
echo "Keyboard shortcut to switch input: Super+Space"
echo ""
log_info "Typing method: Telex by default. Configure via fcitx5-configtool."
log_info "KDE Wayland: Virtual keyboard set to Fcitx 5 (System Settings > Virtual Keyboard)"
