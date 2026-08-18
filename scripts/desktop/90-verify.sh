#!/bin/bash
# =============================================================================
# 90-verify.sh - Assert every rice layer actually applied
# =============================================================================
# Read-only. Prints a pass/fail table; exits non-zero if any hard check fails.
# Soft checks (video wallpaper when no videos exist yet) warn instead.
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

chk "color scheme"   "CatppuccinMochaMauve" "$(rd kdeglobals General ColorScheme)"
chk "look-and-feel"  "Catppuccin-Mocha-Mauve" "$(rd kdeglobals KDE LookAndFeelPackage)"
chk "plasma style"   "catppuccin-glass"     "$(rd plasmarc Theme name)"
GLASS_SVG="$HOME/.local/share/plasma/desktoptheme/catppuccin-glass/widgets/translucentbackground.svg"
if grep -qs 'opacity:0\.4' "$GLASS_SVG"; then
    log_success "glass theme SVG present (opacity 0.40)"
else
    log_error "glass theme SVG missing or wrong opacity: $GLASS_SVG"
    FAIL=1
fi
chk "decoration lib" "org.kde.breeze"       "$(rd kwinrc org.kde.kdecoration2 library)"
chk "cursor theme"   "catppuccin-mocha-mauve-cursors" "$(rd kcminputrc Mouse cursorTheme)"
chk "icon theme"     "Papirus-Dark"         "$(rd kdeglobals Icons Theme)"
chk "splash theme"   "Catppuccin-Mocha-Mauve" "$(rd ksplashrc KSplash Theme)"
chk "blur"           "true"                 "$(rd kwinrc Plugins blurEnabled)"
chk "night light"    "false"                "$(rd kwinrc NightColor Active)"   # OFF per Hải (tints screen yellow)
chk "anim factor"    "0.5"                  "$(rd kdeglobals KDE AnimationDurationFactor)"
chk "gtk3 theme"     "adw-gtk3-dark"        "$(rd kdeglobals KDE GtkTheme)"

# Panel: find the panel group(s) in plasmashellrc
PANEL_FLOATING="$(grep -A20 '^\[PlasmaViews\]\[Panel' "$HOME/.config/plasmashellrc" 2>/dev/null | grep -m1 '^floating=' | cut -d= -f2 || true)"
chk "panel floating" "1" "${PANEL_FLOATING:-}"

# GTK4 bridge carries Mocha colors
if grep -qsiE '1e1e2e|cba6f7' "$HOME/.config/gtk-4.0/colors.css"; then
    log_success "GTK4 colors.css carries Mocha palette"
else
    log_error "GTK4 colors.css has no Mocha colors (kded bridge didn't regenerate?)"
    FAIL=1
fi

# Widgets — sci-fi HUD round (Reactor/Kurve/panel clock time-only)
if QD="$(qdbus_cmd)"; then
    W="$("$QD" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
    const d = desktops()[0];
    var dateless = 1;
    for (const p of panels()) for (const c of p.widgets("org.kde.plasma.digitalclock")) {
        c.currentConfigGroup = ["Appearance"];
        if (String(c.readConfig("showDate", true)) !== "false") dateless = 0;
    }
    print([d.widgets("com.socrates.reactorhud").length,
           d.widgets("luisbocanegra.audio.visualizer").length,
           d.widgets("org.kde.plasma.systemmonitor.cpu").length,
           dateless].join(","));' 2>/dev/null)"
    IFS=, read -r N_REACTOR N_KURVE N_CPU CLOCK_OK <<< "$W"
    if [[ "${DESKTOP_CLASSIC_HUD:-0}" == "1" ]]; then
        chk "classic HUD (CPU card)" "1" "${N_CPU:-}"
    else
        chk "Reactor HUD widget" "1" "${N_REACTOR:-}"
    fi
    chk "Kurve visualizer"      "1" "${N_KURVE:-}"
    chk "panel clock time-only" "1" "${CLOCK_OK:-}"
else
    log_warn "qdbus unreachable — widget checks skipped"
fi

# Panel Colorizer style (soft: GUI may legitimately change the preset later)
if grep -qs 'lastPreset=' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"; then
    log_success "Panel Colorizer has a preset applied"
else
    log_warn "Panel Colorizer preset not yet in appletsrc (needs flush/restart or 57-panel-style.sh)"
fi

# Video wallpaper (soft when no videos yet)
WP_PLUGIN="$(grep -m1 '^wallpaperplugin=' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | cut -d= -f2 || true)"
if [[ "$WP_PLUGIN" == "luisbocanegra.smart.video.wallpaper.reborn" ]]; then
    PAUSE="$(grep -A40 'Wallpaper\]\[luisbocanegra.smart.video.wallpaper.reborn\]\[General\]' \
        "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | grep -m1 '^PauseMode=' | cut -d= -f2 || true)"
    # PauseMode=0 is the plugin default; an absent key means default = 0 = correct
    if [[ -z "$PAUSE" || "$PAUSE" == "0" ]]; then
        log_success "video wallpaper active, PauseMode=MaximizedOrFullScreen"
    else
        log_error "video wallpaper PauseMode=$PAUSE (want 0 — pause on fullscreen!)"
        FAIL=1
    fi
elif compgen -G "$HOME/Videos/wallpapers/*.mp4" >/dev/null 2>&1 || compgen -G "$HOME/Videos/wallpapers/*.webm" >/dev/null 2>&1; then
    log_error "videos exist but wallpaper plugin is '$WP_PLUGIN' — re-run 60-wallpaper.sh"
    FAIL=1
else
    log_warn "video wallpaper not active (no videos in ~/Videos/wallpapers yet — expected)"
fi

echo ""
if [[ $FAIL -eq 0 ]]; then
    log_success "All rice layers verified"
else
    log_error "Some layers failed verification (see above)"
    exit 1
fi
