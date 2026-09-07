#!/bin/bash
# =============================================================================
# 90-verify.sh - Assert every rice layer actually applied
# =============================================================================
# Read-only. Prints a pass/fail table; exits non-zero if any hard check fails.
# Soft checks (things that depend on a login the machine may not have done yet)
# warn instead.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 90: verify"

FAIL=0

chk() {  # chk LABEL EXPECTED ACTUAL
    local label="$1" want="$2" got="$3"
    if [[ "$got" == "$want" ]]; then
        log_success "$label = $got"
    else
        log_error "$label: want '$want', got '${got:-<unset>}'"
        FAIL=1
    fi
}

rd() { kreadconfig6 --file "$1" --group "$2" --key "$3" 2>/dev/null || true; }

PALETTE_DIR="$PROJECT_ROOT/assets/desktop/palette"
read -r SCHEME_NAME WP_FILE SURFACE_HEX < <(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(d["name"], d["wallpaper"], d["tokens"]["surfaceContainer"])' "$PALETTE_DIR/tokens.json")
STYLE_DIR="$HOME/.local/share/plasma/desktoptheme/rice-glass"

# --- Palette -------------------------------------------------------------------
chk "colour scheme"  "$SCHEME_NAME"           "$(rd kdeglobals General ColorScheme)"
chk "look-and-feel"  "org.kde.breezedark.desktop" "$(rd kdeglobals KDE LookAndFeelPackage)"
chk "plasma style"   "rice-glass"             "$(rd plasmarc Theme name)"
chk "accent fixed"   "false"                  "$(rd kdeglobals General accentColorFromWallpaper)"

# The generated scheme must be the one installed, not a stale copy.
if [[ -L "$HOME/.local/share/color-schemes/$SCHEME_NAME.colors" ]] \
   && cmp -s "$HOME/.local/share/color-schemes/$SCHEME_NAME.colors" "$PALETTE_DIR/$SCHEME_NAME.colors"; then
    log_success "colour scheme file linked to the repo's generated one"
else
    log_error "~/.local/share/color-schemes/$SCHEME_NAME.colors is not the generated file — run 15-palette.sh"
    FAIL=1
fi

if cmp -s "$PALETTE_DIR/tokens.sh" "$HOME/.config/rice/tokens.sh"; then
    log_success "shell tokens installed (~/.config/rice/tokens.sh)"
else
    log_error "~/.config/rice/tokens.sh missing or stale — run 15-palette.sh"
    FAIL=1
fi

# --- Plasma style overrides ----------------------------------------------------
for pair in "widgets/translucentbackground.svg:opacity:0.40:card glass" \
            "translucent/dialogs/background.svg:opacity:0.60:dialog glass"; do
    IFS=: read -r rel key val label <<< "$pair"
    if grep -qs "$key:$val" "$STYLE_DIR/$rel"; then
        log_success "$label present ($key:$val)"
    else
        log_error "$label missing or wrong in $STYLE_DIR/$rel — run 20-theme.sh"
        FAIL=1
    fi
done
if grep -qs 'hint-left-margin' "$STYLE_DIR/widgets/panel-background.svg"; then
    log_success "panel-background override present (slim content margins)"
else
    log_error "panel-background override missing (dock content gets inset ~16px)"
    FAIL=1
fi

# --- Desktop chrome ------------------------------------------------------------
chk "decoration lib" "org.kde.breeze"  "$(rd kwinrc org.kde.kdecoration2 library)"
chk "cursor theme"   "breeze_cursors"  "$(rd kcminputrc Mouse cursorTheme)"
chk "icon theme"     "Papirus-Dark"    "$(rd kdeglobals Icons Theme)"
chk "blur"           "true"            "$(rd kwinrc Plugins blurEnabled)"
chk "night light"    "false"           "$(rd kwinrc NightColor Active)"   # OFF per Hải
chk "anim factor"    "0.5"             "$(rd kdeglobals KDE AnimationDurationFactor)"
chk "gtk3 theme"     "adw-gtk3-dark"   "$(rd kdeglobals KDE GtkTheme)"

PANEL_FLOATING="$(grep -A20 '^\[PlasmaViews\]\[Panel' "$HOME/.config/plasmashellrc" 2>/dev/null | grep -m1 '^floating=' | cut -d= -f2 || true)"
chk "panel floating" "1" "${PANEL_FLOATING:-}"

# GTK4 bridge must carry the generated palette, not a leftover one
if grep -qsi "${SURFACE_HEX#\#}" "$HOME/.config/gtk-4.0/colors.css"; then
    log_success "GTK4 colors.css carries the generated palette"
else
    log_warn "GTK4 colors.css has no $SURFACE_HEX — run 70-gtk.sh (kded bridge) or re-login"
fi

# --- Wallpaper ------------------------------------------------------------------
WP_PLUGIN="$(grep -m1 '^wallpaperplugin=' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | cut -d= -f2 || true)"
chk "wallpaper plugin" "org.kde.image" "${WP_PLUGIN:-}"
WP_IMG="$HOME/.local/share/wallpapers/$SCHEME_NAME/contents/images/$SCHEME_NAME.jpg"
if cmp -s "$PROJECT_ROOT/assets/desktop/wallpapers/$WP_FILE" "$WP_IMG"; then
    log_success "wallpaper installed from the repo ($WP_FILE)"
else
    log_error "installed wallpaper differs from assets/desktop/wallpapers/$WP_FILE — run 60-wallpaper.sh"
    FAIL=1
fi
if [[ -f "$HOME/.config/environment.d/50-video-wallpaper.conf" ]]; then
    log_error "stale video-wallpaper env drop-in still present — run 60-wallpaper.sh"
    FAIL=1
else
    log_success "no leftover video-wallpaper environment drop-in"
fi

# --- Widgets --------------------------------------------------------------------
for pkg in dev.haint.dashboard dev.haint.claudequota; do
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$pkg"; then
        log_success "plasmoid installed: $pkg"
    else
        log_error "plasmoid missing: $pkg — run 55-widgets.sh / 58-claude-quota.sh"
        FAIL=1
    fi
done
for pkg in com.socrates.reactorhud luisbocanegra.audio.visualizer; do
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$pkg"; then
        log_error "retired plasmoid still installed: $pkg — run 55-widgets.sh"
        FAIL=1
    else
        log_success "retired plasmoid gone: $pkg"
    fi
done

if QD="$(qdbus_cmd)"; then
    W="$("$QD" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
    const d = desktops()[0];
    var clockOk = 1;
    for (const p of panels()) for (const c of p.widgets("org.kde.plasma.digitalclock")) {
        c.currentConfigGroup = ["Appearance"];
        if (String(c.readConfig("showDate", true)) !== "false") clockOk = 0;
        if (String(c.readConfig("autoFontAndSize", true)) !== "true") clockOk = 0;
    }
    var quota = 0;
    for (const p of panels()) quota += p.widgets("dev.haint.claudequota").length;
    print([d.widgets("dev.haint.dashboard").length, quota, clockOk,
           d.widgets("com.socrates.reactorhud").length
             + d.widgets("luisbocanegra.audio.visualizer").length].join(","));' 2>/dev/null)"
    IFS=, read -r N_DASH N_QUOTA CLOCK_OK N_OLD <<< "$W"
    chk "dashboard on the desktop"        "1" "${N_DASH:-}"
    chk "quota gauge in the dock"         "1" "${N_QUOTA:-}"
    chk "panel clock time-only+auto-font" "1" "${CLOCK_OK:-}"
    chk "old HUD widgets removed"         "0" "${N_OLD:-}"
else
    log_warn "qdbus unreachable — widget checks skipped"
fi

# --- Helpers inside the packages -------------------------------------------------
QUOTA_HELPER="$HOME/.local/share/plasma/plasmoids/dev.haint.claudequota/contents/tools/claude-quota.py"
if [[ ! -f "$HOME/.claude/.credentials.json" ]]; then
    log_warn "quota helper not testable (no ~/.claude/.credentials.json yet)"
elif python3 "$QUOTA_HELPER" >/dev/null 2>&1; then
    log_success "quota helper returns a fresh snapshot"
else
    log_warn "quota helper returned stale/failed (expired token or no network) — gauge shows cache"
fi
WEATHER_HELPER="$HOME/.local/share/plasma/plasmoids/dev.haint.dashboard/contents/tools/weather.py"
if [[ -f "$WEATHER_HELPER" ]] && python3 "$WEATHER_HELPER" 2>/dev/null | python3 -c '
import json, sys
sys.exit(0 if json.load(sys.stdin).get("temp") is not None else 1)'; then
    log_success "weather helper returns a temperature"
else
    log_warn "weather helper gave no temperature (offline?) — card shows the cached value"
fi

# --- Panel Colorizer -------------------------------------------------------------
# One preset, no autoload (v4, 2026-09-07). "Dock Solid" and the maximized flip
# are retired — their presence means 57-panel-style.sh has not run since.
PC_PRESETS="$HOME/.config/panel-colorizer/presets"
if python3 -c "import json; json.load(open('$PC_PRESETS/Dock Slim/settings.json'))" 2>/dev/null; then
    log_success "Colorizer preset 'Dock Slim' present"
else
    log_error "Colorizer preset 'Dock Slim' missing/invalid under $PC_PRESETS — run 57-panel-style.sh"
    FAIL=1
fi
if [[ -d "$PC_PRESETS/Dock Solid" ]]; then
    log_error "Retired preset 'Dock Solid' still present — run 57-panel-style.sh"
    FAIL=1
fi

# Read the LIVE key only: the widget reads [Configuration][General], and v1
# left dead copies in [Configuration] root (57-panel-style.sh clears those).
AUTOLOAD="$(python3 - "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
hit = re.search(r"^\[Containments\]\[\d+\]\[Applets\]\[\d+\]\[Configuration\]\[General\]$(.*?)(?=^\[|\Z)",
                txt, re.M | re.S)
vals = re.findall(r"^presetAutoloading=(.*)$", txt, re.M) if hit else []
print(vals[-1] if vals else "")
PY
)"
case "$AUTOLOAD" in
    *'"enabled":false'*) log_success "Panel Colorizer autoload off" ;;
    "")                  log_warn "Colorizer autoload state not in appletsrc yet (needs flush/restart or 57-panel-style.sh)" ;;
    *)                   log_error "Colorizer autoload still on: $AUTOLOAD — run 57-panel-style.sh"; FAIL=1 ;;
esac

echo ""
if [[ $FAIL -eq 0 ]]; then
    log_success "All rice layers verified"
else
    log_error "Some layers failed verification (see above)"
    exit 1
fi
