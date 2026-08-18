#!/bin/bash
# =============================================================================
# 20-theme.sh - Catppuccin Mocha (Mauve) theme core
# =============================================================================
# Order is LOAD-BEARING:
#   1. catppuccin/kde installer (fetches cursors too — must exist BEFORE the
#      look-and-feel apply references them)
#   2. plasma-apply-lookandfeel (NO --resetLayout: the package ships no
#      contents/layouts/, so the Nobara panel + applets survive)
#   3-4. color scheme + accent (belt and braces over the L&F defaults)
#   5. Plasma style -> `default`. MANDATORY: the `Nobara` and `breeze-dark`
#      desktop themes ship their own `colors` file which OVERRIDES the color
#      scheme; `default` follows it.
#   6. Window decoration -> back to Breeze, OVERRIDING the Aurorae theme the
#      L&F just set. Why: KWin >=6.5 native rounded corners need a
#      KDecoration3 decoration (Breeze has it, Aurorae does not), and Breeze
#      picks up the Catppuccin [WM] colors anyway. Group name is still
#      `org.kde.kdecoration2` on Plasma 6.7 — do not "fix" it.
#   7. cursors / icons / splash (L&F upstream writes [KSplash] at top level —
#      a bug — so the splash must be set explicitly).
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 20: Catppuccin Mocha theme core"

CATPPUCCIN_CACHE="$HOME/.cache/workstation-setup/catppuccin-kde"
LNF_NAME="Catppuccin-Mocha-Mauve"
SCHEME_NAME="CatppuccinMochaMauve"
CURSOR_NAME="catppuccin-mocha-mauve-cursors"
ACCENT_RGB="203,166,247"   # Mocha Mauve #cba6f7

# --- 1. Fetch + run the catppuccin/kde installer (idempotent upstream) --------
if [[ -d "$CATPPUCCIN_CACHE/.git" ]]; then
    git -C "$CATPPUCCIN_CACHE" pull --ff-only --quiet || log_warn "catppuccin/kde pull failed — using cached copy"
else
    ensure_dir "$(dirname "$CATPPUCCIN_CACHE")"
    git clone --depth=1 https://github.com/catppuccin/kde "$CATPPUCCIN_CACHE"
fi

# install.sh -q 1 4 1 = quiet, Mocha, Mauve accent, Modern window decorations.
# Installs to ~/.local/share/{color-schemes,plasma/look-and-feel,aurorae/themes}
# and fetches the matching cursor release into ~/.local/share/icons/.
if [[ -d "$HOME/.local/share/plasma/look-and-feel/$LNF_NAME" ]] \
   && [[ -f "$HOME/.local/share/color-schemes/$SCHEME_NAME.colors" ]] \
   && [[ -d "$HOME/.local/share/icons/$CURSOR_NAME" ]]; then
    log_success "Catppuccin artefacts already installed (re-run installer with FORCE_CATPPUCCIN=1)"
    [[ "${FORCE_CATPPUCCIN:-0}" == "1" ]] && (cd "$CATPPUCCIN_CACHE" && ./install.sh -q 1 4 1)
else
    (cd "$CATPPUCCIN_CACHE" && ./install.sh -q 1 4 1)
    log_success "catppuccin/kde installed (Mocha / Mauve / Modern)"
fi

# --- 2. Global theme (Look and Feel) -----------------------------------------
CUR_LNF="$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null || true)"
if [[ "$CUR_LNF" == "$LNF_NAME" ]]; then
    log_success "OK  look-and-feel already $LNF_NAME"
else
    plasma-apply-lookandfeel --apply "$LNF_NAME"
    log_success "SET look-and-feel -> $LNF_NAME"
fi

# --- 3. Color scheme ----------------------------------------------------------
CUR_SCHEME="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || true)"
if [[ "$CUR_SCHEME" == "$SCHEME_NAME" ]]; then
    log_success "OK  color scheme already $SCHEME_NAME"
else
    plasma-apply-colorscheme "$SCHEME_NAME"
    log_success "SET color scheme -> $SCHEME_NAME"
fi

# --- 4. Accent (fixed Mauve, never wallpaper-derived) --------------------------
kset kdeglobals General accentColorFromWallpaper false bool
kset kdeglobals General AccentColor "$ACCENT_RGB"

# --- 5. Plasma style -> catppuccin-glass (derived from `default`) --------------
# Why derived: `Nobara`/`breeze-dark` ship a `colors` file that overrides the
# color scheme; `default` follows the scheme but renders widget cards at
# opacity 0.9 (near-solid). Our theme = default + ONE overridden SVG
# (widgets/translucentbackground.svg) with the glass opacity below; every
# other asset falls back to `default`, and no `colors` file means the Mocha
# scheme still drives all colors. Generated (not vendored): survives Plasma
# updates by re-running this script.
GLASS_OPACITY=0.40   # main card opacity — Hải's pick 2026-08-18 (show off the wallpaper)
GLASS_FRAME=0.8      # frame/edge opacity, raised from 0.6 to compensate contrast
GLASS_DIR="$HOME/.local/share/plasma/desktoptheme/catppuccin-glass"
GLASS_SVG="$GLASS_DIR/widgets/translucentbackground.svg"
GLASS_SRC="/usr/share/plasma/desktoptheme/default/widgets/translucentbackground.svgz"

if [[ -f "$GLASS_SVG" ]] && grep -q "opacity:$GLASS_OPACITY" "$GLASS_SVG"; then
    log_success "OK  catppuccin-glass theme present (opacity $GLASS_OPACITY)"
else
    ensure_dir "$GLASS_DIR/widgets"
    cat > "$GLASS_DIR/metadata.json" <<EOF
{
    "KPlugin": {
        "Id": "catppuccin-glass",
        "Name": "Catppuccin Glass",
        "Description": "default theme + ${GLASS_OPACITY} glass widget cards (generated by workstation-setup)",
        "License": "LGPL-2.1+"
    },
    "X-Plasma-API": "5.0"
}
EOF
    # 0.9 = main 9-patch background layers; 0.6 = frame layer (see plan notes)
    zcat "$GLASS_SRC" | sed -e "s/opacity:0\.9/opacity:$GLASS_OPACITY/g" \
                            -e "s/opacity:0\.6/opacity:$GLASS_FRAME/g" > "$GLASS_SVG"
    rm -rf "$HOME/.cache/plasma-svgelements"* "$HOME/.cache/plasma_theme_"* 2>/dev/null || true
    log_success "Generated catppuccin-glass theme (glass $GLASS_OPACITY, frame $GLASS_FRAME)"
fi

CUR_STYLE="$(kreadconfig6 --file plasmarc --group Theme --key name 2>/dev/null || true)"
if [[ "$CUR_STYLE" == "catppuccin-glass" ]]; then
    log_success "OK  Plasma style already 'catppuccin-glass'"
else
    plasma-apply-desktoptheme catppuccin-glass
    log_success "SET Plasma style '$CUR_STYLE' -> 'catppuccin-glass'"
fi

# --- 6. Window decoration -> Breeze (AFTER the L&F, so this wins) --------------
kset kwinrc org.kde.kdecoration2 library org.kde.breeze
kset kwinrc org.kde.kdecoration2 theme Breeze
kset kwinrc org.kde.kdecoration2 BorderSize None
kset kwinrc org.kde.kdecoration2 BorderSizeAuto false bool

# --- 7. Cursors / icons / splash ----------------------------------------------
CUR_CURSOR="$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme 2>/dev/null || true)"
if [[ "$CUR_CURSOR" == "$CURSOR_NAME" ]]; then
    log_success "OK  cursor theme already $CURSOR_NAME"
else
    plasma-apply-cursortheme "$CURSOR_NAME" --size 24
    log_success "SET cursor theme -> $CURSOR_NAME"
fi

kset kdeglobals Icons Theme Papirus-Dark
if check_command papirus-folders && sudo -n true 2>/dev/null; then
    # -l only prints the current-color marker (" > violet") when run as root
    CUR_FOLDERS="$(sudo papirus-folders -l --theme Papirus-Dark 2>/dev/null | grep '>' | tr -d ' >' || true)"
    if [[ "$CUR_FOLDERS" == "violet" ]]; then
        log_success "OK  Papirus folders already violet"
    else
        sudo papirus-folders -C violet --theme Papirus-Dark
        log_success "SET Papirus folders -> violet"
    fi
fi

kset ksplashrc KSplash Engine KSplashQML
kset ksplashrc KSplash Theme "$LNF_NAME"

kwin_reconfigure
log_success "Theme core applied (KWin reconfigured live)"
