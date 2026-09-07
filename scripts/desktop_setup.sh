#!/bin/bash
# =============================================================================
# desktop_setup.sh - Desktop rice: one derived palette + our own widgets
# =============================================================================
#
# Full KDE Plasma 6 customization for Nobara 44 (decided with Hải 2026-08-18):
#   - One palette, DERIVED from the wallpaper (assets/desktop/palette/) and
#     applied to Plasma, Konsole, kitty, GTK and our own widgets
#   - A still wallpaper — zero GPU, and the source of that palette
#   - Our own dashboard widget (clock + stats + weather) and a Claude quota
#     gauge in the dock, both silent while a game is fullscreen
#     (hard requirement: zero perf cost while gaming)
#   - Floating dock panel, Breeze decoration (native rounded corners),
#     Inter UI font, blur, GTK/Flatpak coherence
#
# Design notes live at the top of each stage script in scripts/desktop/.
# All KDE state is applied via kwriteconfig6 / plasma-apply-* / the PlasmaShell
# scripting API (repo convention: no vendored rc files). Idempotent — stages
# read before writing and log OK vs SET.
#
# Usage:
#   ./setup.sh --desktop                 # all stages
#   bash scripts/desktop/60-wallpaper.sh # any stage standalone
#   bash scripts/desktop/gen-palette.sh  # regenerate colours (dev-time only)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Desktop Rice (derived palette + dashboard/quota widgets)"

# Applicability guard: everything here is Plasma-specific and most of it needs
# a live session bus (plasma-apply-*, evaluateScript). recover.sh may run this
# over SSH/TTY — skip cleanly there; re-run after first graphical login.
if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* ]] || ! check_command kwriteconfig6; then
    log_info "Not a KDE Plasma session — desktop rice needs a live Plasma session."
    log_info "Run './setup.sh --desktop' after logging into Plasma. Skipping."
    exit 0
fi

STAGES=(
    10-packages.sh
    15-palette.sh
    20-theme.sh
    30-fonts.sh
    40-kwin.sh
    50-panel.sh
    55-widgets.sh
    57-panel-style.sh
    58-claude-quota.sh
    60-wallpaper.sh
    70-gtk.sh
    80-apps.sh
    90-verify.sh
)

for stage in "${STAGES[@]}"; do
    bash "$SCRIPT_DIR/desktop/$stage"
done

log_section "Desktop Rice complete"
log_info "Live already: colours, panel, wallpaper, widgets. Needs re-login: fonts"
log_info "everywhere, splash screen, plasmalogin greeter wallpaper."
log_info "If the panel/wallpaper looks stale:  kill -TERM \$(pgrep -x plasmashell)"
