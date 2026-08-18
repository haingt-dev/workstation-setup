#!/bin/bash
# =============================================================================
# 10-packages.sh - Packages for the desktop rice
# =============================================================================
# Everything comes from repos already enabled on Nobara 44:
#   plasma-smart-video-wallpaper-reborn  (nobara repo — do NOT add the COPR on
#       top; two sources for one package is a future dnf conflict)
#   libva-utils   -> vainfo, to verify HW decode is real (not silent CPU)
#   nvtop         -> decode-engine utilisation check while gaming
#   rsms-inter-fonts -> Inter UI font
# Already installed (verified 2026-08-18, listed so nobody re-adds them):
#   qt6-qtmultimedia (ffmpeg backend), ffmpeg-free (h264/vp9 + cuda/vaapi),
#   libva-nvidia-driver, adw-gtk3-theme, papirus-icon-theme, kde-gtk-config
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 10: packages"

PKGS=(
    plasma-smart-video-wallpaper-reborn
    libva-utils
    nvtop
    rsms-inter-fonts
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
