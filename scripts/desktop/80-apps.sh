#!/bin/bash
# =============================================================================
# 80-apps.sh - Per-app polish (Konsole, Dolphin, notifications)
# =============================================================================
# Konsole is secondary (kitty is the daily terminal) but should not clash when
# it opens. Its colour scheme is GENERATED with everything else — see
# assets/desktop/palette/ — and installed by 15-palette.sh; this stage only
# points the profile at it.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 80: apps"

# Konsole profile (vendored, symlinked — repo is source of truth). The colour
# scheme it names is installed by 15-palette.sh.
SCHEME_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' \
    "$PROJECT_ROOT/assets/desktop/palette/tokens.json")"
link_file ".local/share/konsole/Rice.profile" "$HOME/.local/share/konsole/Rice.profile"
kset konsolerc "Desktop Entry" DefaultProfile Rice.profile
PROFILE_SCHEME="$(kreadconfig6 --file "$HOME/.local/share/konsole/Rice.profile" \
    --group Appearance --key ColorScheme 2>/dev/null || true)"
if [[ "$PROFILE_SCHEME" != "$SCHEME_NAME" ]]; then
    log_warn "Rice.profile names colour scheme '$PROFILE_SCHEME' but the palette is '$SCHEME_NAME'"
    log_info "Fix: edit assets/.local/share/konsole/Rice.profile (ColorScheme=$SCHEME_NAME)"
fi

# Dolphin
kset dolphinrc General ShowFullPath true bool
kset dolphinrc General BrowseThroughArchives true bool
kset dolphinrc PreviewSettings Plugins "ffmpegthumbs,imagethumbnail,jpegthumbnail,svgthumbnail,directorythumbnail"

# Notifications top-right (out of the way of the bottom dock)
kset plasmanotifyrc Notifications PopupPosition TopRight

log_success "App polish applied"
