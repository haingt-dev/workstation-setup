#!/bin/bash
# =============================================================================
# 10-packages.sh - Packages for the desktop rice
# =============================================================================
# Everything comes from repos already enabled on Nobara 44:
#   rsms-inter-fonts -> Inter, the UI font
#   manrope-fonts    -> Manrope, the display face for the big numbers in the
#                       desktop dashboard (round 6). Inter is a fine UI font but
#                       reads flat at 60px; Manrope's heavier weights carry the
#                       Material-3-style figures.
#   nvtop            -> GPU/decode utilisation, used to prove the "zero cost
#                       while gaming" rule still holds
# Already installed (verified 2026-08-18, listed so nobody re-adds them):
#   ffmpeg-free, adw-gtk3-theme, papirus-icon-theme, kde-gtk-config,
#   gamemode (GameGuard reads `gamemoded -s`)
#
# Round 6 dropped plasma-smart-video-wallpaper-reborn and libva-utils from this
# list: the wallpaper is a still image now, so there is no decoder to verify.
# The package is left installed if it already is — removing it is the user's
# call, not a side effect of running setup.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 10: packages"

PKGS=(
    rsms-inter-fonts
    manrope-fonts
    nvtop
)

MISSING=()
for p in "${PKGS[@]}"; do
    rpm -q "$p" >/dev/null 2>&1 || MISSING+=("$p")
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    log_success "All rice packages already installed"
else
    log_info "Installing: ${MISSING[*]}"
    dnf_install "${MISSING[@]}"
fi
