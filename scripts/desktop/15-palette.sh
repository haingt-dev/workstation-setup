#!/bin/bash
# =============================================================================
# 15-palette.sh - Install the generated colour palette (KDE + terminals + rice)
# =============================================================================
# The colours of this rice are DERIVED, not typed: one source colour in
# assets/desktop/palette/palette.toml is expanded by gen-palette.py into a KDE
# colour scheme, Konsole/kitty themes, QML tokens and shell tokens. This stage
# only installs those generated files and applies the scheme — it never
# computes a colour, so `./setup.sh --desktop` can't drift between runs and a
# fresh machine needs no python colour libraries.
#
# To change the look: edit palette.toml -> `bash scripts/desktop/gen-palette.sh`
# -> review the diff -> commit -> re-run this stage.
#
# Everything is symlinked from assets/ (repo = source of truth), except
# tokens.sh which is copied to ~/.config/rice/ so anything sourcing it (the
# Claude Code statusline) does not depend on the repo being checked out.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 15: colour palette"

PALETTE_DIR="$PROJECT_ROOT/assets/desktop/palette"
SCHEME_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$PALETTE_DIR/tokens.json")"
KITTY_CONF_NAME="$(echo "$SCHEME_NAME" | tr "[:upper:]" "[:lower:]").kitty.conf"

[[ -f "$PALETTE_DIR/$SCHEME_NAME.colors" ]] || {
    log_error "Missing $PALETTE_DIR/$SCHEME_NAME.colors — run scripts/desktop/gen-palette.sh"
    exit 1
}

# --- 1. KDE colour scheme ------------------------------------------------------
link_file "desktop/palette/$SCHEME_NAME.colors" \
          "$HOME/.local/share/color-schemes/$SCHEME_NAME.colors"

# --- 2. Terminals --------------------------------------------------------------
link_file "desktop/palette/$SCHEME_NAME.colorscheme" \
          "$HOME/.local/share/konsole/$SCHEME_NAME.colorscheme"
link_file "desktop/palette/$KITTY_CONF_NAME" "$HOME/.config/kitty/$KITTY_CONF_NAME"

# kitty.conf lives in assets/ and is symlinked into place, so point its theme
# include at the generated file. Only the ONE include line carrying a theme is
# touched (matched narrowly) — kitty.conf has other directives that mention
# .conf files (startup_session) and must not be disturbed.
KITTY_CONF="$BACKUP_DIR/.config/kitty/kitty.conf"
if [[ -f "$KITTY_CONF" ]]; then
    if grep -qx "include $KITTY_CONF_NAME" "$KITTY_CONF"; then
        log_success "OK  kitty includes $KITTY_CONF_NAME"
    elif grep -qE "^include ([a-z0-9-]+\.kitty\.conf|catppuccin-mocha\.conf)$" "$KITTY_CONF"; then
        # '@' delimiter: the alternation below contains '|'
        sed -i -E "s@^include ([a-z0-9-]+\.kitty\.conf|catppuccin-mocha\.conf)\$@include $KITTY_CONF_NAME@" "$KITTY_CONF"
        log_success "SET kitty include -> $KITTY_CONF_NAME"
    else
        log_warn "kitty.conf has no recognisable theme include — add: include $KITTY_CONF_NAME"
    fi
fi

# --- 3. Shell tokens (statusline & friends) ------------------------------------
# Copied, not symlinked: ~/.config/rice must keep working if the repo moves.
ensure_dir "$HOME/.config/rice"
if cmp -s "$PALETTE_DIR/tokens.sh" "$HOME/.config/rice/tokens.sh"; then
    log_success "OK  ~/.config/rice/tokens.sh up to date"
else
    install -m 644 "$PALETTE_DIR/tokens.sh" "$HOME/.config/rice/tokens.sh"
    log_success "SET ~/.config/rice/tokens.sh"
fi

# --- 4. Apply the scheme -------------------------------------------------------
CURRENT="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || true)"
if [[ "$CURRENT" == "$SCHEME_NAME" ]]; then
    log_success "OK  colour scheme already $SCHEME_NAME"
else
    plasma-apply-colorscheme "$SCHEME_NAME" >/dev/null
    log_success "SET colour scheme: '${CURRENT:-<unset>}' -> $SCHEME_NAME"
fi
