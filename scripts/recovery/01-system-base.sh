#!/usr/bin/env bash
# Phase 1: System base install (delegates to ./setup.sh)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/common.sh"

DRY_RUN=${DRY_RUN:-false}

log_info "Running ./setup.sh --full --onedrive (skip Vietnamese input)"

if $DRY_RUN; then
    log_info "[DRY-RUN] Would run: $REPO_ROOT/setup.sh --full --onedrive"
    exit 0
fi

cd "$REPO_ROOT"
./setup.sh --full --onedrive
