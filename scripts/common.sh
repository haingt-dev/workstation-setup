#!/bin/bash
# =============================================================================
# common.sh - Shared utilities for terminal-custom setup scripts
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

# Copy file with backup of existing
copy_with_backup() {
    local src="$1"
    local dest="$2"
    
    if [[ -f "$dest" ]]; then
        cp "$dest" "${dest}.backup.$(date +%Y%m%d%H%M%S)"
        log_warn "Backed up existing: $dest"
    fi
    
    cp "$src" "$dest"
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

# =============================================================================
# Export for sourcing
# =============================================================================
export SCRIPT_DIR PROJECT_ROOT BACKUP_DIR
export RED GREEN YELLOW BLUE CYAN BOLD NC