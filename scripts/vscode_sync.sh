#!/bin/bash
# =============================================================================
# vscode_sync.sh - Sync current VS Code state → assets/ (source of truth)
# =============================================================================
#
# Usage:
#   ./scripts/vscode_sync.sh          # Sync + show diff
#   ./scripts/vscode_sync.sh --commit # Sync + auto-commit if drift
#
# Reverse of vscode_setup.sh: pulls live ~/.config/Code/User/* into repo assets.
# Run periodically (or after installing new extensions) to keep assets fresh.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

VSCODE_LIVE="$HOME/.config/Code/User"
VSCODE_ASSETS="$BACKUP_DIR/.config/Code"
EXTENSIONS_FILE="$VSCODE_ASSETS/extensions.txt"

log_section "Syncing VS Code state to assets"

ensure_dir "$VSCODE_ASSETS/User"

# Extensions list
if check_command code; then
    log_info "Capturing extensions list..."
    code --list-extensions > "$EXTENSIONS_FILE"
    ext_count=$(wc -l < "$EXTENSIONS_FILE")
    log_success "Captured $ext_count extensions → $EXTENSIONS_FILE"
else
    log_warn "code CLI not found — skipping extensions list"
fi

# settings.json
if [[ -f "$VSCODE_LIVE/settings.json" ]]; then
    cp "$VSCODE_LIVE/settings.json" "$VSCODE_ASSETS/User/settings.json"
    log_success "Copied settings.json"
fi

# keybindings.json (optional — may not exist)
if [[ -f "$VSCODE_LIVE/keybindings.json" ]]; then
    cp "$VSCODE_LIVE/keybindings.json" "$VSCODE_ASSETS/User/keybindings.json"
    log_success "Copied keybindings.json"
else
    log_info "No keybindings.json found (using defaults)"
fi

# snippets dir (if non-empty)
if [[ -d "$VSCODE_LIVE/snippets" ]] && [[ -n "$(ls -A $VSCODE_LIVE/snippets 2>/dev/null)" ]]; then
    rm -rf "$VSCODE_ASSETS/User/snippets"
    cp -r "$VSCODE_LIVE/snippets" "$VSCODE_ASSETS/User/snippets"
    log_success "Copied snippets/"
else
    log_info "No snippets found"
fi

# Diff against git
log_info "Checking for drift..."
cd "$PROJECT_ROOT"
if git diff --quiet "$VSCODE_ASSETS/"; then
    log_success "No drift — assets already match live config"
    exit 0
fi

log_info "Drift detected:"
git diff --stat "$VSCODE_ASSETS/"

if [[ "${1:-}" == "--commit" ]]; then
    log_info "Auto-committing drift..."
    git add "$VSCODE_ASSETS/"
    git commit -m "chore(vscode): sync assets from live config"
    log_success "Committed. Run 'git push' when ready."
else
    log_info "Review with: cd $PROJECT_ROOT && git diff $VSCODE_ASSETS"
    log_info "Stage with:  git add $VSCODE_ASSETS && git commit"
    log_info "Or re-run:   $0 --commit"
fi
