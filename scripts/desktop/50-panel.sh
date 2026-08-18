#!/bin/bash
# =============================================================================
# 50-panel.sh - Panel -> centered floating dock (translucent + blur)
# =============================================================================
# Uses the PlasmaShell scripting API: writes plasmashellrc [PlasmaViews] keys
# exactly like the Edit-Mode UI does, and applies LIVE with no plasmashell
# restart. Deliberately does NOT touch plasma-org.kde.plasma.desktop-appletsrc
# (AppletOrder / launchers): the Nobara panel carries distro-specific applets
# and rewriting appletsrc is the highest-risk, zero-gain move in this rice.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 50: panel (floating centered dock)"

plasma_script '
for (const p of panels()) {
    p.floating   = true;
    p.height     = 44;
    p.opacity    = "translucent";   // lets the KWin blur show through
    p.lengthMode = "fit";           // shrink to content -> dock look
    p.alignment  = "center";
    p.hiding     = "none";
}' >/dev/null

log_success "Panel: floating, 44px, translucent, fit-content, centered (applied live)"
