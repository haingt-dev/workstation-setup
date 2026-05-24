#!/bin/bash
# =============================================================================
# restore_symlinks.sh - Apply declarative symlinks from assets/symlinks.yml
# =============================================================================
#
# Usage:
#   ./restore_symlinks.sh              # Apply links (idempotent)
#   ./restore_symlinks.sh --dry-run    # Preview only
#   ./restore_symlinks.sh --force      # Overwrite existing files/dirs at link path
#
# Reads YAML manifest, creates each link if absent. Skips if link already exists
# pointing to correct target. Warns on drift (link exists but points elsewhere).
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

MANIFEST="$BACKUP_DIR/symlinks.yml"
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --force)   FORCE=true;   shift ;;
        *) shift ;;
    esac
done

if [[ ! -f "$MANIFEST" ]]; then
    log_error "Manifest not found: $MANIFEST"
    exit 1
fi

if ! check_command yq; then
    log_info "Installing yq (YAML parser)..."
    dnf_install yq || {
        log_error "yq install failed. Manual: sudo dnf install yq"
        exit 1
    }
fi

log_section "Applying symlinks from $MANIFEST"

count=$(yq '.links | length' "$MANIFEST")
log_info "Found $count link definitions"

for i in $(seq 0 $((count - 1))); do
    link=$(yq ".links[$i].link" "$MANIFEST")
    target=$(yq ".links[$i].target" "$MANIFEST")
    note=$(yq ".links[$i].note // \"\"" "$MANIFEST")

    # Expand ~ to $HOME
    link="${link/#\~/$HOME}"
    target="${target/#\~/$HOME}"

    echo ""
    log_info "[$((i+1))/$count] $link"
    [[ -n "$note" ]] && log_info "       $note"
    log_info "    → $target"

    # Target must exist
    if [[ ! -e "$target" ]]; then
        log_warn "    Target missing — skip (create target first)"
        continue
    fi

    # Link path exists already?
    if [[ -L "$link" ]]; then
        current=$(readlink "$link")
        if [[ "$current" == "$target" ]]; then
            log_success "    Already correct"
            continue
        else
            log_warn "    Drift: currently → $current"
            if $FORCE && ! $DRY_RUN; then
                /bin/rm "$link"
                log_info "    Removed old link"
            else
                log_warn "    Skip (use --force to overwrite)"
                continue
            fi
        fi
    elif [[ -e "$link" ]]; then
        log_warn "    Path exists as file/dir (not symlink)"
        if $FORCE && ! $DRY_RUN; then
            backup="${link}.pre-restore-$(date +%s)"
            /bin/mv "$link" "$backup"
            log_info "    Backed up to $backup"
        else
            log_warn "    Skip (use --force to backup + overwrite)"
            continue
        fi
    fi

    # Ensure parent dir
    parent=$(dirname "$link")
    if [[ ! -d "$parent" ]]; then
        log_info "    Creating parent: $parent"
        $DRY_RUN || mkdir -p "$parent"
    fi

    # Create link
    if $DRY_RUN; then
        log_info "    [DRY-RUN] ln -s '$target' '$link'"
    else
        ln -s "$target" "$link"
        log_success "    Created"
    fi
done

echo ""
log_section "Symlinks restored"
$DRY_RUN && log_info "DRY-RUN — no changes made"
