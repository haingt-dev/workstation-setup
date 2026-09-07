#!/bin/bash
# =============================================================================
# gen-palette.sh - Regenerate the rice colour artefacts from palette.toml
# =============================================================================
# DEV-TIME ONLY — deliberately NOT part of ./setup.sh --desktop.
#
# Why: a colour decision should be reviewable. Editing
# assets/desktop/palette/palette.toml and running this prints a diff you can
# read before committing; the setup stages then only ever COPY the generated
# files, so a fresh machine needs neither python deps nor this script, and the
# desktop can never shift colour on its own between two runs of setup.
#
# Usage:
#   bash scripts/desktop/gen-palette.sh          # regenerate + show diff
#   bash scripts/desktop/gen-palette.sh --apply  # ...then run the install stage
#
# Dependencies are resolved in this order (nothing is installed system-wide
# unless you ask dnf yourself):
#   1. system python3 that can already import materialyoucolor
#   2. a throwaway venv under ~/.cache/workstation-setup/palette-venv (pip)
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"

log_section "Palette: regenerate from palette.toml"

PALETTE_DIR="$PROJECT_ROOT/assets/desktop/palette"
VENV="$HOME/.cache/workstation-setup/palette-venv"

pick_python() {
    if python3 -c 'import materialyoucolor, PIL' 2>/dev/null; then
        echo python3; return
    fi
    if [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" -c 'import materialyoucolor, PIL' 2>/dev/null; then
        echo "$VENV/bin/python"; return
    fi
    log_info "Creating palette venv at $VENV (materialyoucolor + pillow)" >&2
    python3 -m venv "$VENV" >&2
    "$VENV/bin/pip" -q install --upgrade pip >&2
    "$VENV/bin/pip" -q install materialyoucolor pillow >&2
    echo "$VENV/bin/python"
}

PY="$(pick_python)"
log_info "Using $PY"

BEFORE="$(mktemp -d)"
trap 'rm -rf "$BEFORE"' EXIT
cp -a "$PALETTE_DIR/." "$BEFORE/" 2>/dev/null || true

"$PY" "$PALETTE_DIR/gen-palette.py"

echo
if diff -qr "$BEFORE" "$PALETTE_DIR" >/dev/null 2>&1; then
    log_success "No colour changes (artefacts already match palette.toml)"
else
    log_info "Changes (review, then commit):"
    diff -ru "$BEFORE" "$PALETTE_DIR" | grep -vE '^(diff|---|\+\+\+|@@|Only in)' | grep -E '^[+-]' | head -40 || true
    echo
    log_info "Full diff:  git -C $PROJECT_ROOT diff assets/desktop/palette"
fi

if [[ "${1:-}" == "--apply" ]]; then
    bash "$DESKTOP_DIR/15-palette.sh"
fi
