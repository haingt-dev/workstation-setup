#!/bin/bash
# =============================================================================
# 30-fonts.sh - UI fonts (Inter) + rendering
# =============================================================================
# Inter for UI, JetBrainsMono Nerd Font for fixed-width (already installed by
# terminal_setup). Font string format is Qt's 16-field QFont::toString(); the
# weight field (5th) is 400=regular / 600=semibold.
# Rendering: explicit subpixel RGB + slight hinting for the Gigabyte M27Q.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 30: fonts"

UI_FONT="Inter"

if ! fc-list | grep -qi "Inter" ; then
    log_warn "Inter font not found (rsms-inter-fonts missing?) — keeping current fonts"
    exit 0
fi

kset kdeglobals General font                 "$UI_FONT,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kset kdeglobals General menuFont             "$UI_FONT,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kset kdeglobals General toolBarFont          "$UI_FONT,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kset kdeglobals General smallestReadableFont "$UI_FONT,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kset kdeglobals General fixed                "JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kset kdeglobals WM      activeFont           "$UI_FONT,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"

kset kdeglobals General XftAntialias true bool
kset kdeglobals General XftHintStyle hintslight
kset kdeglobals General XftSubPixel  rgb

log_success "Fonts set (full effect after re-login; running apps keep old fonts)"
