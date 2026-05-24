#!/usr/bin/env bash
# Phase 0: Verify prerequisites are in place
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}

log_info "Checking prerequisites..."

ok=true

# Command checks
for cmd in git curl gh gnupg2:gpg rclone tar; do
    name="${cmd%%:*}"
    binary="${cmd##*:}"
    [[ "$name" == "$binary" ]] && binary="$name"
    if command -v "$binary" >/dev/null; then
        log_success "  $name installed"
    else
        log_error "  $name MISSING — run ./bootstrap.sh first"
        ok=false
    fi
done

# gh auth check
if gh auth status >/dev/null 2>&1; then
    log_success "  gh authenticated: $(gh auth status 2>&1 | grep 'account' | head -1)"
else
    log_error "  gh NOT authenticated — run: gh auth login --web"
    ok=false
fi

# Internet check
if curl -s --head --connect-timeout 5 https://github.com >/dev/null; then
    log_success "  Internet OK (github.com reachable)"
else
    log_error "  No internet (github.com unreachable)"
    ok=false
fi

# Disk space
free=$(df -BG "$HOME" | awk 'NR==2 {gsub("G","",$4); print $4}')
if (( free > 50 )); then
    log_success "  Disk free: ${free}GB"
else
    log_warn "  Low disk: ${free}GB (need 50GB+ for safe restore)"
fi

# Recovery passphrase file
PASS_FILE="$HOME/.config/recovery/bundle.pass"
if [[ -f "$PASS_FILE" ]]; then
    log_success "  Passphrase file exists ($PASS_FILE)"
else
    log_warn "  Passphrase file missing — Phase 2 will prompt for passphrase manually"
fi

$ok || { log_error "Prerequisites failed"; exit 1; }
log_success "All prerequisites satisfied"
