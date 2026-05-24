#!/bin/bash
# =============================================================================
# audit_symlinks.sh - Compare live symlinks vs assets/symlinks.yml manifest
# =============================================================================
#
# Usage:
#   ./audit_symlinks.sh
#
# Reports:
#   - Links in manifest but missing on disk
#   - Links on disk but not in manifest (cross-project links found via scan)
#   - Drift (link exists but points to different target than manifest)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

MANIFEST="$BACKUP_DIR/symlinks.yml"

if [[ ! -f "$MANIFEST" ]]; then
    log_error "Manifest not found: $MANIFEST"
    exit 1
fi

if ! check_command yq; then
    log_error "yq not installed. Install: sudo dnf install yq"
    exit 1
fi

log_section "Auditing symlinks vs $MANIFEST"

# ─────────────────────────────────────────────────────────────
# 1. Check each manifest entry exists on disk
# ─────────────────────────────────────────────────────────────
echo ""
log_info "Phase 1: Manifest → Disk consistency"

count=$(yq '.links | length' "$MANIFEST")
missing=0
drift=0
ok=0

declare -A MANIFEST_LINKS

for i in $(seq 0 $((count - 1))); do
    link=$(yq ".links[$i].link" "$MANIFEST")
    target=$(yq ".links[$i].target" "$MANIFEST")

    link="${link/#\~/$HOME}"
    target="${target/#\~/$HOME}"
    MANIFEST_LINKS["$link"]="$target"

    if [[ ! -L "$link" ]]; then
        if [[ -e "$link" ]]; then
            log_warn "  EXISTS-NOT-SYMLINK: $link"
        else
            log_warn "  MISSING: $link → (would point to $target)"
        fi
        ((missing++))
    else
        current=$(readlink "$link")
        if [[ "$current" != "$target" ]]; then
            log_warn "  DRIFT: $link"
            log_warn "    manifest → $target"
            log_warn "    actual   → $current"
            ((drift++))
        else
            ((ok++))
        fi
    fi
done

echo ""
log_info "Manifest entries: $count total | $ok ok | $missing missing | $drift drift"

# ─────────────────────────────────────────────────────────────
# 2. Scan disk for cross-project links not in manifest
# ─────────────────────────────────────────────────────────────
echo ""
log_info "Phase 2: Disk → Manifest (unmanaged cross-project links)"

unmanaged=0
while IFS= read -r link; do
    # Skip if inside node_modules or .venv (pkg manager symlinks)
    [[ "$link" == *node_modules* ]] && continue
    [[ "$link" == *.venv* ]] && continue
    [[ "$link" == *.git* ]] && continue

    target=$(readlink "$link")
    [[ "$target" != *Projects/* ]] && continue

    # Check if in manifest
    if [[ -z "${MANIFEST_LINKS[$link]:-}" ]]; then
        log_warn "  UNMANAGED: $link → $target"
        ((unmanaged++))
    fi
done < <(find "$HOME/Projects" -maxdepth 5 -type l 2>/dev/null)

echo ""
log_info "Unmanaged cross-project links: $unmanaged"

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo ""
if [[ $missing -eq 0 ]] && [[ $drift -eq 0 ]] && [[ $unmanaged -eq 0 ]]; then
    log_section "All clean — manifest matches disk"
    exit 0
else
    log_section "Drift detected"
    log_info "Fix actions:"
    [[ $missing -gt 0 ]] && log_info "  - Run: ./restore_symlinks.sh (creates missing)"
    [[ $drift -gt 0 ]] && log_info "  - Run: ./restore_symlinks.sh --force (overrides drift)"
    [[ $unmanaged -gt 0 ]] && log_info "  - Edit $MANIFEST to add unmanaged links"
    exit 1
fi
