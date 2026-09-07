#!/bin/bash
# =============================================================================
# 55-widgets.sh - Desktop widgets: one dashboard + Panel Colorizer
# =============================================================================
# Round 6 replaced the sci-fi HUD stack. What was here before (Reactor HUD, a
# CAVA audio visualizer, a separate big clock) was three third-party widgets
# with three visual languages, two of which needed QML patching on every
# install. Hải's verdict 2026-09-07: "thô và xấu, nhiều chi tiết không thân
# thiết" — too much detail nobody reads, and nothing matched anything else.
#
# Now: ONE widget we own (dev.haint.dashboard) — clock, four stat cards, the
# weather — drawing from the same generated palette as the rest of the desktop.
# Because we own it, the colours, the layout and the "cost nothing while a game
# is fullscreen" rule live in the package instead of in sed patches here.
#
# Kept from the old rounds:
#   - Panel Colorizer (installed here, STYLED in 57-panel-style.sh)
#   - the appletsrc backup before any widget surgery
#   - the ItemGeometries snap, because addWidget coordinates get re-flowed by
#     the folder-view grid and the durable store is that key (see below)
#
# Hard-won facts that still apply (do not "simplify" these away):
#   - Widget position: addWidget(x,y,w,h) is a SUGGESTION. The durable value is
#     `ItemGeometries-<WxH>` directly under [Containments][N] (NOT [General]),
#     and it is only writable while plasmashell is stopped.
#   - `userBackgroundHints` takes the enum NAME as a string; numbers are
#     silently ignored, and the hint only applies if the plasmoid declares
#     ConfigurableBackground (ours does).
#   - plasmashell does not reliably respawn after TERM -> plasma_restart().
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 55: dashboard widget + Panel Colorizer"

CACHE_ROOT="$HOME/.cache/workstation-setup"
DASH_ID="dev.haint.dashboard"

# --- Panel Colorizer (user-level kpackage; styled in 57-panel-style.sh) --------
PC_ID="luisbocanegra.panel.colorizer"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "$PC_ID"; then
    log_success "OK  Panel Colorizer already installed"
else
    if [[ -d "$CACHE_ROOT/plasma-panel-colorizer/.git" ]]; then
        git -C "$CACHE_ROOT/plasma-panel-colorizer" pull --ff-only --quiet || true
    else
        ensure_dir "$CACHE_ROOT"
        git clone --depth=1 https://github.com/luisbocanegra/plasma-panel-colorizer "$CACHE_ROOT/plasma-panel-colorizer"
    fi
    kpackagetool6 -t Plasma/Applet -i "$CACHE_ROOT/plasma-panel-colorizer/package"
    log_success "Installed Panel Colorizer"
fi

# --- Our dashboard --------------------------------------------------------------
DASH_STATE="$(install_own_plasmoid "$DASH_ID")"
case "$DASH_STATE" in
    installed) log_success "Installed $DASH_ID" ;;
    updated)   log_success "Updated $DASH_ID (package content changed)" ;;
    current)   log_success "OK  $DASH_ID already up to date" ;;
esac

# --- Backup appletsrc before widget surgery -------------------------------------
APPLETSRC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
cp -a "$APPLETSRC" "$APPLETSRC.rice-bak.$(date +%Y%m%d-%H%M%S)"
ls -t "$APPLETSRC".rice-bak.* 2>/dev/null | tail -n +4 | xargs -r rm -f
log_success "appletsrc backed up"

# --- Place the dashboard, retire the round 1-5 widgets ---------------------------
# Screen is 2560x1440; the right-hand column starts at x=2076. addWidget takes
# AVAILABLE-area coordinates, so the left dock strip (thickness 42 + floating
# margin) has to come off the x.
PANEL_OFFSET=60

LAYOUT="$(plasma_script '
const OFFSET = '"$PANEL_OFFSET"';
const SLOTS = [
    ["'"$DASH_ID"'", 2076, 48, 480, 720],
];
// Widgets from earlier rounds. Removing them here (rather than by hand) keeps
// `./setup.sh --desktop` a complete description of the desktop.
const RETIRED = [
    "com.socrates.reactorhud",
    "luisbocanegra.audio.visualizer",
    "org.kde.plasma.systemmonitor",
    "org.kde.plasma.systemmonitor.cpu",
    "org.kde.plasma.systemmonitor.memory",
    "org.kde.plasma.systemmonitor.net",
    "org.kde.plasma.digitalclock",   // the dashboard draws the clock now
];

const d = desktops()[0];
var byType = {};
var removed = 0;

for (const s of SLOTS) {
    var ws = d.widgets(s[0]);
    var w = ws.length > 0 ? ws[0] : d.addWidget(s[0], s[1] - OFFSET, s[2], s[3], s[4]);
    byType[s[0]] = w;
    w.userBackgroundHints = "NoBackground";   // the widget paints its own cards
}

for (const t of RETIRED) {
    for (const w of d.widgets(t)) { w.remove(); removed++; }
}

var geo = "", fix = 0;
for (const s of SLOTS) {
    var w = byType[s[0]];
    geo += "Applet-" + w.id + ":" + (s[1] - OFFSET) + "," + s[2] + "," + s[3] + "," + s[4] + ",0;";
    // 56px tolerance: the folder-view grid re-snaps widgets ~48px and
    // pixel-fighting it just restarts plasmashell forever.
    if (Math.abs(w.geometry.x - s[1]) > 56 || Math.abs(w.geometry.y - s[2]) > 56) { fix = 1; }
}
print(d.id + "|" + geo + "|" + fix + "|" + removed);
')"

CTN_ID="${LAYOUT%%|*}"; REST="${LAYOUT#*|}"
GEO="${REST%%|*}"; REST="${REST#*|}"
NEED_FIX="${REST%%|*}"; REMOVED="${REST##*|}"
[[ "${REMOVED:-0}" != "0" ]] && log_success "Retired $REMOVED widget(s) from earlier rounds"

# --- Uninstall the packages those widgets came from ------------------------------
for pkg in com.socrates.reactorhud luisbocanegra.audio.visualizer; do
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$pkg"; then
        kpackagetool6 -t Plasma/Applet -r "$pkg" >/dev/null 2>&1 || true
        log_success "Uninstalled $pkg"
    fi
done
if [[ -d "$HOME/.config/reactor-hud" ]]; then
    rm -rf "$HOME/.config/reactor-hud"
    log_success "Removed leftover ~/.config/reactor-hud"
fi

# --- Panel: Colorizer present, clock stays time-only ------------------------------
# The panel clock shows TIME ONLY: the dock is 42px wide, and in a vertical
# panel DigitalClock uses Text.HorizontalFit against the applet width, so the
# date would shrink the time to nothing. autoFontAndSize STAYS true for the
# same reason — a fixed fontSize is a no-op there (measured 2026-08-19: 13-24pt
# rendered identically). The date lives in the dashboard.
plasma_script '
for (const p of panels()) {
    if (p.widgets("luisbocanegra.panel.colorizer").length === 0) {
        p.addWidget("luisbocanegra.panel.colorizer");
    }
    for (const pc of p.widgets("org.kde.plasma.digitalclock")) {
        pc.currentConfigGroup = ["Appearance"];
        pc.writeConfig("showDate", false);
        pc.writeConfig("autoFontAndSize", true);
    }
}' >/dev/null
log_success "Panel: Colorizer present, clock time-only"

# --- Snap the dashboard to its declared position ----------------------------------
if [[ "$NEED_FIX" == "1" || "$DASH_STATE" != "current" ]]; then
    log_info "Writing ItemGeometries (containment $CTN_ID) — needs plasmashell stopped"
    PID="$(pgrep -x plasmashell || true)"
    [[ -n "$PID" ]] && kill -TERM "$PID"
    sleep 3
    pgrep -x plasmashell >/dev/null && { kill -TERM "$(pgrep -x plasmashell)"; sleep 3; }
    RES="$(kscreen-doctor -o 2>/dev/null | grep -oE 'Geometry: *[0-9]+,[0-9]+ [0-9]+x[0-9]+' | grep -oE '[0-9]+x[0-9]+' | head -1)"
    kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group Containments --group "$CTN_ID" --key "ItemGeometries-${RES:-2560x1440}" "$GEO"
    kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group Containments --group "$CTN_ID" --key "ItemGeometriesHorizontal" "$GEO"
    plasma_restart
    log_success "Dashboard snapped to its declared position"
else
    log_success "OK  widget layout already in place"
fi

log_info "Panel style (presets/autoload) is applied by 57-panel-style.sh"
