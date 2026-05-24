#!/usr/bin/env bash
# Phase 2: Pull recovery bundle from cloud + GPG decrypt
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}
BUNDLE_DIR="$HOME/.local/share/recovery"
mkdir -p "$BUNDLE_DIR"

# Load bundle config
CONFIG_FILE="$HOME/.config/recovery/bundle.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    log_warn "No bundle config — using defaults"
    RCLONE_REMOTE_PRIMARY="onedrive-dev:dev/recovery-bundle"
    BUNDLE_PASS_FILE="$HOME/.config/recovery/bundle.pass"
fi

# ─────────────────────────────────────────────────────────────
# Step 1: rclone OAuth if not configured
# ─────────────────────────────────────────────────────────────
log_info "Step 1: Check rclone remote configured"

REMOTE_NAME="${RCLONE_REMOTE_PRIMARY%%:*}"
if rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    log_success "  rclone remote '$REMOTE_NAME' already configured"
else
    log_warn "  rclone remote '$REMOTE_NAME' NOT configured"
    log_info "  Will open interactive rclone config (browser OAuth)"
    if $DRY_RUN; then
        log_info "  [DRY-RUN] would run: rclone config"
    else
        read -rp "  Run 'rclone config' now? [Y/n] " ans
        [[ "$ans" =~ ^[nN]$ ]] && { log_error "Cannot continue without remote"; exit 1; }
        rclone config
    fi
fi

# ─────────────────────────────────────────────────────────────
# Step 2: Find latest bundle on cloud
# ─────────────────────────────────────────────────────────────
log_info "Step 2: Find latest bundle on $RCLONE_REMOTE_PRIMARY/daily/"

if $DRY_RUN; then
    log_info "[DRY-RUN] would list cloud + pick latest"
    exit 0
fi

LATEST=$(rclone lsf "$RCLONE_REMOTE_PRIMARY/daily/" --include "recovery-bundle-*.tar.gz.gpg" 2>/dev/null | sort -r | head -1)

if [[ -z "$LATEST" ]]; then
    log_error "No bundles found at $RCLONE_REMOTE_PRIMARY/daily/"
    log_info "Check rclone setup or try fallback if configured"
    [[ -n "${RCLONE_REMOTE_FALLBACK:-}" ]] && {
        log_info "Trying fallback: $RCLONE_REMOTE_FALLBACK"
        LATEST=$(rclone lsf "$RCLONE_REMOTE_FALLBACK/daily/" --include "recovery-bundle-*.tar.gz.gpg" 2>/dev/null | sort -r | head -1)
        SOURCE_REMOTE="$RCLONE_REMOTE_FALLBACK"
    }
    [[ -z "$LATEST" ]] && { log_error "No bundles in fallback either"; exit 1; }
else
    SOURCE_REMOTE="$RCLONE_REMOTE_PRIMARY"
fi

log_success "  Latest: $LATEST"

# ─────────────────────────────────────────────────────────────
# Step 3: Pull bundle
# ─────────────────────────────────────────────────────────────
log_info "Step 3: Pull bundle (this is the big download ~200MB)"
rclone copy "$SOURCE_REMOTE/daily/$LATEST" "$BUNDLE_DIR/" --progress

BUNDLE_FILE="$BUNDLE_DIR/$LATEST"
[[ -f "$BUNDLE_FILE" ]] || { log_error "Pull failed: $BUNDLE_FILE missing"; exit 1; }
log_success "  Downloaded $(du -h "$BUNDLE_FILE" | cut -f1)"

# ─────────────────────────────────────────────────────────────
# Step 4: GPG decrypt
# ─────────────────────────────────────────────────────────────
log_info "Step 4: GPG decrypt"

PLAIN="$BUNDLE_DIR/${LATEST%.gpg}"

if [[ -f "$BUNDLE_PASS_FILE" ]]; then
    log_info "  Using passphrase file: $BUNDLE_PASS_FILE"
    gpg --batch --yes --decrypt --passphrase-file "$BUNDLE_PASS_FILE" \
        --output "$PLAIN" "$BUNDLE_FILE"
else
    log_info "  Passphrase prompt (interactive)"
    gpg --decrypt --output "$PLAIN" "$BUNDLE_FILE"
fi

[[ -f "$PLAIN" ]] || { log_error "Decrypt failed"; exit 1; }
log_success "  Decrypted $(du -h "$PLAIN" | cut -f1)"

# ─────────────────────────────────────────────────────────────
# Step 5: Extract to staging
# ─────────────────────────────────────────────────────────────
log_info "Step 5: Extract"

STAGING="$BUNDLE_DIR/extracted"
/bin/rm -rf "$STAGING"
mkdir -p "$STAGING"
tar xzf "$PLAIN" -C "$STAGING"

# Verify expected dirs
[[ -d "$STAGING/recovery-bundle" ]] || { log_error "Unexpected bundle structure"; exit 1; }

log_success "  Extracted to $STAGING/recovery-bundle/"
log_info "  Contents:"
ls "$STAGING/recovery-bundle/" | sed 's/^/    /'

# Save staging path for downstream phases
echo "$STAGING/recovery-bundle" > "$BUNDLE_DIR/.staging-path"
log_success "Phase 2 ready — downstream phases will read from $STAGING/recovery-bundle/"
