#!/bin/bash
# =============================================================================
# common.sh - Shared utilities for workstation-setup scripts
# =============================================================================

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/assets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${GREEN}${BOLD}>>> $1${NC}"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_success "Created directory: $dir"
    fi
}

# Check if a command exists
check_command() {
    command -v "$1" &> /dev/null
}

# Run command with sudo, non-interactive
run_sudo() {
    sudo "$@"
}

# Install packages via dnf (non-interactive)
dnf_install() {
    sudo dnf install -y "$@"
}

# Check if running as root (we don't want that)
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root. Use a regular user with sudo access."
        exit 1
    fi
}

# Verify backup directory exists
verify_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
}

# Copy file (overwrite if exists, no backup)
copy_file() {
    local src="$1"
    local dest="$2"
    
    cp -f "$src" "$dest"
    log_success "Copied: $src -> $dest"
}

# Copy directory recursively
copy_dir() {
    local src="$1"
    local dest="$2"
    
    ensure_dir "$dest"
    cp -r "$src"/* "$dest"/ 2>/dev/null || true
    log_success "Copied directory: $src -> $dest"
}

# Restore a file from backup dir. Usage: restore_file "relative/path" "dest"
# Returns 0 on success, 1 if backup not found (with warning).
restore_file() {
    local rel_path="$1"
    local dest="$2"
    local src="$BACKUP_DIR/$rel_path"

    if [[ -f "$src" ]]; then
        ensure_dir "$(dirname "$dest")"
        cp -f "$src" "$dest"
        log_success "Restored: $rel_path"
        return 0
    else
        log_warn "Backup not found: $rel_path"
        return 1
    fi
}

# Restore a directory from backup dir. Usage: restore_dir "relative/path" "dest"
# Returns 0 on success, 1 if backup not found (with warning).
restore_dir() {
    local rel_path="$1"
    local dest="$2"
    local src="$BACKUP_DIR/$rel_path"

    if [[ -d "$src" ]]; then
        ensure_dir "$dest"
        cp -r "$src"/* "$dest"/ 2>/dev/null || true
        log_success "Restored: $rel_path"
        return 0
    else
        log_warn "Backup not found: $rel_path"
        return 1
    fi
}

# Symlink a file from assets/ into place (idempotent). The repo is the source of
# truth: editing the live file edits the repo file (zero drift), with git history.
# Usage: link_file "relative/path/in/assets" "$HOME/dest"
#   - dest is already the correct symlink  -> skip
#   - dest is a real file/dir that differs -> back up to <dest>.pre-symlink.<ts>.bak, then link
#   - dest does not exist (fresh machine)  -> just link
# Returns 1 (with warning) if the source is missing in assets/.
link_file() {
    local rel_path="$1"
    local dest="$2"
    local src="$BACKUP_DIR/$rel_path"

    if [[ ! -e "$src" ]]; then
        log_warn "Source missing in assets: $rel_path (skip)"
        return 1
    fi

    ensure_dir "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        if [[ "$(readlink "$dest")" == "$src" ]]; then
            log_success "Already linked: $dest"
            return 0
        fi
        rm -f "$dest"                       # stale/wrong symlink -> re-point
    elif [[ -e "$dest" ]]; then
        local backup="${dest}.pre-symlink.$(date +%Y%m%d-%H%M%S).bak"
        mv "$dest" "$backup"                 # real file/dir -> preserve once
        log_warn "Backed up existing $dest -> $backup"
    fi

    ln -s "$src" "$dest"
    log_success "Linked: $dest -> $src"
}

# Symlink a whole directory from assets/ into place (idempotent).
# Use ONLY for dirs that contain solely user-authored files (no tool-written
# state), e.g. fastfetch. Usage: link_dir "relative/path" "$HOME/dest"
link_dir() {
    local rel_path="$1"
    local dest="$2"
    local src="$BACKUP_DIR/$rel_path"

    if [[ ! -d "$src" ]]; then
        log_warn "Source dir missing in assets: $rel_path (skip)"
        return 1
    fi

    ensure_dir "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        if [[ "$(readlink "$dest")" == "$src" ]]; then
            log_success "Already linked: $dest"
            return 0
        fi
        rm -f "$dest"
    elif [[ -e "$dest" ]]; then
        local backup="${dest}.pre-symlink.$(date +%Y%m%d-%H%M%S).bak"
        mv "$dest" "$backup"
        log_warn "Backed up existing dir $dest -> $backup"
    fi

    ln -s "$src" "$dest"
    log_success "Linked dir: $dest -> $src"
}

# =============================================================================
# Export for sourcing
# =============================================================================
export SCRIPT_DIR PROJECT_ROOT BACKUP_DIR
export RED GREEN YELLOW BLUE CYAN BOLD NC