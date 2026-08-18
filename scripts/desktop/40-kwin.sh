#!/bin/bash
# =============================================================================
# 40-kwin.sh - KWin effects, animation speed, Night Light
# =============================================================================
# Rounded corners: NOTHING to configure — KWin >=6.5 rounds KDecoration3
# (Breeze) windows natively. Do NOT install matinlotfali/KDE-Rounded-Corners
# (targets <=6.3, fights the native path).
# magiclamp and minimizeanimation are mutually exclusive minimize effects.
# AnimationDurationFactor: was 0.125 (near-instant); 0.5 chosen with Hải
# (2026-08-18) so the rice's motion is visible but still snappy.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 40: KWin effects"

# Blur (the translucent panel depends on it)
kset kwinrc Plugins blurEnabled     true  bool
kset kwinrc Plugins contrastEnabled true  bool
kset kwinrc Blur    BlurStrength    8
kset kwinrc Blur    NoiseStrength   4

# Motion
kset kwinrc Plugins slideEnabled             true  bool
kset kwinrc Plugins overviewEnabled          true  bool
kset kwinrc Plugins magiclampEnabled         true  bool
kset kwinrc Plugins minimizeanimationEnabled false bool
kset kwinrc Plugins wobblywindowsEnabled     false bool
kset kwinrc Plugins diminactiveEnabled       false bool

kset kdeglobals KDE AnimationDurationFactor 0.5

# Night Light OFF — Hải's call (2026-08-18): 4000K tints the whole screen
# "vàng khè" and fights the Mocha palette. Re-enable manually in System
# Settings if ever wanted (a gentler value would be ~5200K).
kset kwinrc NightColor Active false bool

kwin_reconfigure
log_success "KWin reconfigured live"
