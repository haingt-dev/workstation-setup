#!/bin/bash
# =============================================================================
# 55-widgets.sh - Desktop widgets (sci-fi HUD round) + Panel Colorizer install
# =============================================================================
# Evolved with Hải across 2026-08-18/19 (deep-research vòng 3):
#   Right column = big clock -> Reactor HUD (sci-fi terminal monitor) ->
#   Kurve (CAVA audio visualizer). Panel clock shows TIME ONLY (vertical panel
#   is narrow; the date lives on the desktop clock).
#   DESKTOP_CLASSIC_HUD=1 reverts to the older 4-card systemmonitor stack
#   (CPU/GPU/RAM/Net) in case Reactor HUD misbehaves on a future Plasma.
#
# Component sources (verified via deep-research 2026-08-19):
#   - Reactor HUD  github.com/prudhvibungatavula/reactor-hud (QML + helper
#     shell scripts into ~/.config/reactor-hud; tiny repo -> commit pinned)
#   - Kurve        github.com/luisbocanegra/kurve — installed as PURE QML
#     package (kpackagetool6 on package/); talks to cava via the
#     python3-websockets bridge, so NO compiled plugin, nothing ABI-tied.
#     Runtime deps: cava (nobara repo), qt6-qtwebsockets-devel,
#     python3-websockets. commandMonitor needs its exec bit restored
#     (kpackagetool6 drops it — upstream install.sh does the same chmod).
#   - Panel Colorizer github.com/luisbocanegra/plasma-panel-colorizer —
#     installed here, STYLED in 57-panel-style.sh. Its optional C++ blur
#     plugin is deliberately NOT built (author warns it breaks on updates).
#
# Hard-won facts (2026-08-18, all discovered live — keep in mind when editing):
#   - systemmonitor presets added via scripting get NO [Sensors] config ->
#     blank boxes; write Sensors/Appearance/FaceConfig explicitly.
#   - Widget transparency = scripting property `userBackgroundHints`, assign
#     the enum NAME as a string; numbers are silently ignored.
#   - Positions: addWidget coords are re-flowed by the folder-view grid. The
#     durable store is `ItemGeometries-<WxH>` DIRECTLY under [Containments][N]
#     (NOT [General]); only writable while plasmashell is stopped. Done below
#     only when drift >56px, so manual Edit-Mode moves survive re-runs.
#   - plasmashell auto-respawn after TERM is unreliable -> plasma_restart.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 55: widgets (sci-fi HUD) + Panel Colorizer"

CLASSIC_HUD="${DESKTOP_CLASSIC_HUD:-0}"
CACHE_ROOT="$HOME/.cache/workstation-setup"

# Pinned upstream commits (tiny repos — pin against silent drift; bump after review)
REACTOR_COMMIT="a2eaab93717afa3e3a7dcf03121bdce86aca6442"   # 2026-08 state
KURVE_COMMIT="133d6f77a743465f2bf767901be2e9a6d3956fb0"     # 2026-08 state

fetch_pinned() {  # fetch_pinned NAME URL COMMIT -> clone/update cache at pinned commit
    local name="$1" url="$2" commit="$3" dir="$CACHE_ROOT/$1"
    if [[ ! -d "$dir/.git" ]]; then
        ensure_dir "$CACHE_ROOT"
        git clone https://github.com/"$url" "$dir"
    fi
    if [[ "$(git -C "$dir" rev-parse HEAD)" != "$commit" ]]; then
        git -C "$dir" fetch --quiet origin || true
        git -C "$dir" checkout --quiet "$commit"
    fi
}

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

# --- Reactor HUD (unless classic layout requested) ------------------------------
REACTOR_ID="com.socrates.reactorhud"
if [[ "$CLASSIC_HUD" != "1" ]]; then
    fetch_pinned reactor-hud prudhvibungatavula/reactor-hud "$REACTOR_COMMIT"
    if [[ -d "$HOME/.local/share/plasma/plasmoids/$REACTOR_ID" ]] \
       && [[ -d "$HOME/.config/reactor-hud/scripts/sys" ]]; then
        log_success "OK  Reactor HUD already installed"
    else
        # upstream install.sh = plain copies (plasmoid -> ~/.local/share, helper
        # scripts -> ~/.config/reactor-hud); idempotent, run from its dir
        (cd "$CACHE_ROOT/reactor-hud" && bash install.sh >/dev/null)
        log_success "Installed Reactor HUD (pinned $REACTOR_COMMIT)"
    fi
    # Upstream hardcodes the author's own $HOME as scriptPath in main.qml, so
    # every sensor script silently returns 0 on any other machine (found
    # 2026-08-19: CPU temp stuck at +0°C). Re-point it; idempotent no-op after.
    REACTOR_QML="$HOME/.local/share/plasma/plasmoids/$REACTOR_ID/contents/ui/main.qml"
    sed -i "s|/home/akash/|$HOME/|" "$REACTOR_QML"
    # Contrast patches (Hải 2026-08-19, tuned live over 3 rounds): Reactor
    # declares NoBackground WITHOUT ConfigurableBackground, so user background
    # hints are IGNORED, and its thin blueprint lines wash out over bright
    # wallpapers. Chosen look = HYBRID glassmorphism:
    #   (1) MultiEffect dark outer-glow layer -> every line/text gets a black
    #       halo (Hải's idea: shadow instead of a solid bg). Alone it fixes
    #       white text but pale cyan labels still sink on snowy scenes...
    #   (2) ...so a LIGHT cockpit-glass backing separates the widget from the
    #       wallpaper. Opacity dial history: 0.78 (too solid) -> 0.45 -> 0.25 -> 0.40
    #       (Hải final pick 2026-08-19).
    # All guarded -> idempotent, and they re-apply after any reinstall.
    grep -q 'import QtQuick.Effects' "$REACTOR_QML" || sed -i \
        's|^import QtQuick$|import QtQuick\nimport QtQuick.Effects|' "$REACTOR_QML"
    grep -q 'reactorShadowLayer' "$REACTOR_QML" || sed -i \
        's|fullRepresentation: Item {|fullRepresentation: Item {\n        layer.enabled: true\n        layer.effect: MultiEffect { id: reactorShadowLayer; shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 1.0; shadowBlur: 1.0; shadowVerticalOffset: 0; shadowHorizontalOffset: 0; shadowScale: 1.02 }|' \
        "$REACTOR_QML"
    grep -q 'reactorCockpitGlass' "$REACTOR_QML" || sed -i \
        's|fullRepresentation: Item {|fullRepresentation: Item {\n        Rectangle { id: reactorCockpitGlass; anchors.fill: parent; anchors.margins: -6; color: "#131420"; opacity: 0.40; radius: 10; z: -1 }|' \
        "$REACTOR_QML"
fi

# --- Kurve (audio visualizer; pure-QML install, websockets bridge) --------------
KURVE_ID="luisbocanegra.audio.visualizer"
KURVE_DEPS=(cava qt6-qtwebsockets-devel python3-websockets)
MISSING=()
for p in "${KURVE_DEPS[@]}"; do rpm -q "$p" >/dev/null 2>&1 || MISSING+=("$p"); done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    log_info "Installing Kurve runtime deps: ${MISSING[*]}"
    dnf_install "${MISSING[@]}"
fi
fetch_pinned kurve luisbocanegra/kurve "$KURVE_COMMIT"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "$KURVE_ID"; then
    log_success "OK  Kurve already installed"
else
    kpackagetool6 -t Plasma/Applet -i "$CACHE_ROOT/kurve/package"
    log_success "Installed Kurve (pinned $KURVE_COMMIT)"
fi
# kpackagetool drops the exec bit on the cava bridge (upstream chmods it too)
chmod 700 "$HOME/.local/share/plasma/plasmoids/$KURVE_ID/contents/ui/tools/commandMonitor" 2>/dev/null || true

# --- Backup appletsrc before widget surgery -------------------------------------
APPLETSRC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
cp -a "$APPLETSRC" "$APPLETSRC.rice-bak.$(date +%Y%m%d-%H%M%S)"
ls -t "$APPLETSRC".rice-bak.* 2>/dev/null | tail -n +4 | xargs -r rm -f
log_success "appletsrc backed up"

# --- Add widgets (guarded), converge config + transparency, report layout -------
# JS prints "<containmentId>|<GEO>|<fix>": GEO = desired ItemGeometries value
# (available-area coords), fix=1 when any widget sits >56px from its slot.
PANEL_OFFSET=60   # left panel strip: thickness 44 + floating margin (verified live)

LAYOUT="$(plasma_script '
const OFFSET = '"$PANEL_OFFSET"';
const CLASSIC = '"$CLASSIC_HUD"' === 1;
// Declared layout, absolute screen px: [type, x, y, w, h]
const SLOTS = CLASSIC ? [
    ["org.kde.plasma.digitalclock",          2076,  48, 480, 176],
    ["org.kde.plasma.systemmonitor.cpu",     2076, 240, 480, 176],
    ["org.kde.plasma.systemmonitor",         2076, 432, 480, 176],
    ["org.kde.plasma.systemmonitor.memory",  2076, 624, 480, 176],
    ["org.kde.plasma.systemmonitor.net",     2076, 816, 480, 176],
    ["luisbocanegra.audio.visualizer",       2076, 1008, 480, 144],
] : [
    ["org.kde.plasma.digitalclock",          2076,  48, 480, 176],
    ["com.socrates.reactorhud",              2076, 240, 480, 768],   // full content needs ~750px, less clips POWER/COOLING
    ["luisbocanegra.audio.visualizer",       2076, 1024, 480, 144],
];
function ensure(cont, type, x, y, w, h) {
    var ws = cont.widgets(type);
    if (ws.length > 0) { return [ws[0], false]; }
    return [cont.addWidget(type, x, y, w, h), true];
}
function cfg(w, group, obj) {
    w.currentConfigGroup = [group];
    for (const k in obj) w.writeConfig(k, obj[k]);
}
function monitor(w, title, sensors, fixedRange) {
    // lowPrioritySensorIds=[] kills the preset noise rows
    cfg(w, "Sensors", {highPrioritySensorIds: JSON.stringify(sensors),
                       totalSensors: JSON.stringify([sensors[0]]),
                       lowPrioritySensorIds: "[]"});
    cfg(w, "Appearance", {chartFace: "org.kde.ksysguard.linechart", title: title});
    var face = {lineChartSmooth: true};
    if (fixedRange) { face.rangeAuto = false; face.rangeFrom = 0; face.rangeTo = 100; }
    cfg(w, "FaceConfig", face);
}
const d = desktops()[0];
var byType = {};

for (const s of SLOTS) {
    var r = ensure(d, s[0], s[1] - OFFSET, s[2], s[3], s[4]);
    byType[s[0]] = r[0];
    if (r[1] && s[0] === "org.kde.plasma.digitalclock") {
        cfg(r[0], "Appearance", {autoFontAndSize: false, fontSize: 60,
                                 showDate: true, dateDisplayFormat: "BelowTime"});
    }
    if (r[1] && s[0] === "luisbocanegra.audio.visualizer") {
        // Transparent over the wallpaper, bars follow the system accent
        // (= Mocha Mauve) instead of the default rainbow list.
        // sourceType enum (FormColors.qml order): 0 Custom, 1 System,
        // 2 Custom list, 3 Random, 4 Follow, 5 Gradient, 6 Image, 7 Hue.
        var bar = {enabled: true, sourceType: 1, systemColor: "highlightColor",
                   systemColorSet: "Window", alpha: 1, lightness: 0.5,
                   saturation: 0.5, custom: "#cba6f7", list: [],
                   reverseList: false, followColor: 0, saturationEnabled: false,
                   lightnessEnabled: false, smoothGradient: true,
                   colorsOrientation: 0, image: {source: "", fillMode: 2},
                   hueStart: 0, hueEnd: 360};
        r[0].currentConfigGroup = [];
        r[0].writeConfig("desktopWidgetBg", 0);      // NoBackground
        r[0].writeConfig("roundedBars", true);
        r[0].writeConfig("barCount", 48);
        r[0].writeConfig("barColors", JSON.stringify(bar));
        r[0].writeConfig("waveFillColors", JSON.stringify(Object.assign({}, bar, {alpha: 0.3})));
    }
}
if (CLASSIC) {
    monitor(byType["org.kde.plasma.systemmonitor.cpu"],    "CPU", ["cpu/all/usage"], true);
    monitor(byType["org.kde.plasma.systemmonitor"],        "GPU", ["gpu/gpu0/usage"], true);
    monitor(byType["org.kde.plasma.systemmonitor.memory"], "RAM", ["memory/physical/usedPercent"], true);
    monitor(byType["org.kde.plasma.systemmonitor.net"],    "Net", ["network/all/download","network/all/upload"], false);
}

// Migration between layouts + legacy cleanups
for (const w of d.widgets("org.kde.plasma.weather")) { w.remove(); }   // moved to systray long ago
if (CLASSIC) {
    for (const w of d.widgets("com.socrates.reactorhud")) { w.remove(); }
} else {
    for (const t of ["org.kde.plasma.systemmonitor.cpu","org.kde.plasma.systemmonitor",
                     "org.kde.plasma.systemmonitor.memory","org.kde.plasma.systemmonitor.net"]) {
        for (const w of d.widgets(t)) { w.remove(); }
    }
}

// Backgrounds: TranslucentBackground = dark glass card (readable, theme-synced)
// for the classic systemmonitor cards. Reactor IGNORES user hints (declares
// NoBackground without ConfigurableBackground) — its contrast comes from the
// cockpit-glass rectangle injected into its QML above. Kurve = bare accent
// bars, reads fine without a card.
for (const t in byType) {
    if (t === "org.kde.plasma.digitalclock") continue;                    // native shadow style
    if (t === "luisbocanegra.audio.visualizer" || t === "com.socrates.reactorhud") {
        byType[t].userBackgroundHints = "NoBackground";
    } else {
        byType[t].userBackgroundHints = "TranslucentBackground";
    }
}

// Panel: ensure Colorizer present + clock shows TIME ONLY (narrow vertical bar;
// the date lives on the desktop clock) — Hải 2026-08-19.
// autoFontAndSize STAYS true: in a vertical panel the clock uses
// Text.HorizontalFit against the applet width (DigitalClock.qml state
// "verticalPanel"), so a fixed fontSize can't make it bigger — only wider.
// Clock size is governed by panel thickness (50-panel.sh, 42px), the theme
// panel-background margin override (20-theme.sh), and the Colorizer Dock
// preset's panel margin/padding (57-panel-style.sh disables them).
// Measured on 2026-08-19: fixed 13-24pt all rendered identically.
for (const p of panels()) {
    if (p.widgets("luisbocanegra.panel.colorizer").length === 0) {
        p.addWidget("luisbocanegra.panel.colorizer");
    }
    for (const pc of p.widgets("org.kde.plasma.digitalclock")) {
        pc.currentConfigGroup = ["Appearance"];
        pc.writeConfig("showDate", false);
        pc.writeConfig("autoFontAndSize", true);
    }
}

// Layout report for the bash side
var geo = "", fix = 0;
for (const s of SLOTS) {
    var w = byType[s[0]];
    geo += "Applet-" + w.id + ":" + (s[1] - OFFSET) + "," + s[2] + "," + s[3] + "," + s[4] + ",0;";
    // 56px tolerance: the folder-view grid re-snaps some widgets ~48px off
    // and pixel-fighting it just restarts plasmashell forever.
    if (Math.abs(w.geometry.x - s[1]) > 56 || Math.abs(w.geometry.y - s[2]) > 56) { fix = 1; }
}
print(d.id + "|" + geo + "|" + fix);
')"
log_success "Widgets ensured + config/transparency converged"

# --- Snap drifted widgets back to the declared layout ---------------------------
CTN_ID="${LAYOUT%%|*}"; REST="${LAYOUT#*|}"; GEO="${REST%%|*}"; NEED_FIX="${REST##*|}"
if [[ "$NEED_FIX" == "1" ]]; then
    log_info "Widget positions drifted — rewriting ItemGeometries (containment $CTN_ID)"
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
    log_success "Layout snapped to declared positions"
else
    log_success "OK  widget layout already in place"
fi

log_info "Panel style (islands/presets) is applied by 57-panel-style.sh"
