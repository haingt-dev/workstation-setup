#!/usr/bin/env bash
# Phase 8: Restore KDE desktop rice (configs + locally-installed themes)
#
# Restores what daily-bundle.sh Section 9 captured: ~/.config KDE rc files and
# the ~/.local/share theme artefacts (Catppuccin color-schemes/L&F/konsole +
# cursors). Config files alone don't wake plasmashell — after first graphical
# login the user must run `./setup.sh --desktop`, which re-applies everything
# live and re-verifies (it's idempotent over these restored files).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}

STAGING=$(cat "$HOME/.local/share/recovery/.staging-path" 2>/dev/null)
[[ -z "$STAGING" || ! -d "$STAGING" ]] && { log_error "Bundle staging missing"; exit 1; }

KDE_SRC="$STAGING/kde-rice"
[[ -d "$KDE_SRC" ]] || { log_warn "No kde-rice/ in bundle (pre-rice bundle) — skipping"; exit 0; }

log_info "Restoring KDE rice from bundle"

# ── Config files/dirs → ~/.config ────────────────────────────
mkdir -p "$HOME/.config"
shopt -s nullglob
for src in "$KDE_SRC"/*; do
    base="$(basename "$src")"
    case "$base" in
        local-*.tar.gz|applied-state.txt|wallpaper-videos.txt|etc-plasmalogin.conf) continue ;;
    esac
    if $DRY_RUN; then
        log_info "[DRY-RUN] cp -r $base → ~/.config/"
    else
        /bin/cp -r "$src" "$HOME/.config/"
        log_success "  .config/$base"
    fi
done

# ── Theme artefacts → ~/.local/share ─────────────────────────
for tarball in "$KDE_SRC"/local-*.tar.gz; do
    if $DRY_RUN; then
        log_info "[DRY-RUN] untar $(basename "$tarball") → ~/.local/share/"
    else
        if [[ "$(basename "$tarball")" == "local-cursors.tar.gz" ]]; then
            mkdir -p "$HOME/.local/share/icons"
            tar xzf "$tarball" -C "$HOME/.local/share/icons"
        else
            mkdir -p "$HOME/.local/share"
            tar xzf "$tarball" -C "$HOME/.local/share"
        fi
        log_success "  $(basename "$tarball")"
    fi
done
shopt -u nullglob

# ── Reference copies (not auto-applied) ──────────────────────
[[ -f "$KDE_SRC/applied-state.txt" ]] && log_info "Applied-state snapshot: $KDE_SRC/applied-state.txt"
[[ -f "$KDE_SRC/wallpaper-videos.txt" ]] && {
    log_warn "Wallpaper videos are NOT in the bundle — re-download per assets/desktop/wallpapers.manifest:"
    sed 's/^/    /' "$KDE_SRC/wallpaper-videos.txt"
}

log_success "KDE rice files restored"
log_warn "MANUAL: after first graphical login, run:  cd ~/Projects/workstation-setup && ./setup.sh --desktop"
