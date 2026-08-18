#!/bin/bash
# =============================================================================
# 70-gtk.sh - GTK3/GTK4 + Flatpak coherence
# =============================================================================
# GTK4/libadwaita: NOTHING to theme manually — kde-gtk-config's kded module
# regenerates ~/.config/gtk-4.0/colors.css from the LIVE KDE color scheme, so
# after 20-theme.sh those apps are already Mocha. This script only:
#   - GTK3 -> adw-gtk3-dark (maintained; catppuccin/gtk is archived since 2024)
#   - restarts kded6 so both bridges regenerate NOW instead of next login
#   - Flatpak overrides so sandboxed apps see themes/cursors/colors
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 70: GTK + Flatpak"

kset kdeglobals KDE GtkTheme adw-gtk3-dark

# Nudge the kde-gtk-config bridge (regenerates gtk-3.0/settings.ini and
# gtk-4.0/{colors.css,gtk.css}). kded6 restart is cheap and safe.
if check_command kquitapp6 && check_command kstart; then
    kquitapp6 kded6 2>/dev/null || true
    sleep 1
    kstart kded6 >/dev/null 2>&1 &
    sleep 2
    log_success "kded6 restarted (GTK bridges regenerated)"
fi

if grep -qs "colors.css" "$HOME/.config/gtk-4.0/gtk.css"; then
    log_success "GTK4 bridge active (gtk.css imports colors.css)"
else
    log_warn "GTK4 gtk.css doesn't import colors.css — GTK4 apps may not follow the scheme"
fi

# Flatpak: read-only access to host theme bits + explicit theme/cursor env
if check_command flatpak; then
    flatpak override --user \
        --filesystem=xdg-config/gtk-3.0:ro \
        --filesystem=xdg-config/gtk-4.0:ro \
        --filesystem=xdg-data/themes:ro \
        --filesystem=xdg-data/icons:ro \
        --filesystem="$HOME/.local/share/color-schemes:ro" \
        --env=GTK_THEME=adw-gtk3-dark \
        --env=XCURSOR_THEME=catppuccin-mocha-mauve-cursors \
        --env=XCURSOR_SIZE=24
    log_success "Flatpak user overrides set (theme/cursor visible in sandboxes)"

    # Theme runtime for GTK3 flatpaks (no-op if already installed)
    flatpak install -y --noninteractive flathub org.gtk.Gtk3theme.adw-gtk3-dark >/dev/null 2>&1 || true
    log_success "Flatpak GTK3 theme runtime ensured (adw-gtk3-dark)"
fi
