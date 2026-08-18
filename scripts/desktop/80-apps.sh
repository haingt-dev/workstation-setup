#!/bin/bash
# =============================================================================
# 80-apps.sh - Per-app polish (Konsole, Dolphin, notifications)
# =============================================================================
# Konsole is secondary (kitty is the daily terminal) but should not clash when
# it opens. Colorscheme vendored from github.com/catppuccin/konsole.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 80: apps"

# Konsole (vendored, symlinked — repo is source of truth)
link_file ".local/share/konsole/Catppuccin-Mocha.colorscheme" "$HOME/.local/share/konsole/Catppuccin-Mocha.colorscheme"
link_file ".local/share/konsole/Catppuccin.profile"           "$HOME/.local/share/konsole/Catppuccin.profile"
kset konsolerc "Desktop Entry" DefaultProfile Catppuccin.profile

# Dolphin
kset dolphinrc General ShowFullPath true bool
kset dolphinrc General BrowseThroughArchives true bool
# ffmpegthumbs is installed -> wallpaper videos get previews in Dolphin
kset dolphinrc PreviewSettings Plugins "ffmpegthumbs,imagethumbnail,jpegthumbnail,svgthumbnail,directorythumbnail"

# Notifications top-right (out of the way of the bottom dock)
kset plasmanotifyrc Notifications PopupPosition TopRight

log_success "App polish applied"
