#!/bin/bash
# =============================================================================
# onedrive_setup.sh - Setup onedriver (FUSE on-demand client) for OneDrive
# =============================================================================
#
# Replaces abraunegg/onedrive sync client with jstaf/onedriver — true Files-On-Demand
# semantics (placeholder files, download on access) instead of full sync.
#
# Mount layout:
#   /home/haint/Data/OneDrive/Dev/      ← Dev account (work/code/calibre cloud view)
#   /home/haint/Data/OneDrive/Personal/ ← Personal account
#
# Calibre Library NOT in this sync — it lives at /home/haint/Data/Calibre Library/
# (real local btrfs) and is backed up daily via calibre-sync.timer (see home-server
# scripts/calibre-sync-setup.sh).
#
# Auth tokens persist in ~/.cache/onedriver/<escaped-mountpoint>/auth_tokens.json
# and are bundled by workstation-setup daily-bundle.sh for recovery.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Setting up onedriver (OneDrive Files-On-Demand)"

# Mount layout — paths are systemd-escaped to derive unit names
DATA_ROOT="$HOME/Data/OneDrive"
ACCOUNTS=(Dev Personal)

# =============================================================================
# Install onedriver from Fedora COPR (jstaf/onedriver)
# =============================================================================
if ! check_command onedriver; then
    log_info "Enabling COPR repo: jstaf/onedriver"
    sudo dnf copr enable -y jstaf/onedriver
    log_info "Installing onedriver..."
    dnf_install onedriver
    log_success "onedriver installed"
else
    log_info "onedriver already installed: $(rpm -q onedriver 2>/dev/null || echo unknown)"
fi

# =============================================================================
# Create mount points
# =============================================================================
ensure_dir "$DATA_ROOT"
for acct in "${ACCOUNTS[@]}"; do
    ensure_dir "$DATA_ROOT/$acct"
done
log_success "Mount points ready: $DATA_ROOT/{$(IFS=,; echo "${ACCOUNTS[*]}")}/"

# =============================================================================
# Detect existing tokens (restored by Phase 3 / 03-restore-secrets.sh)
# =============================================================================
# Tokens encode the OAuth refresh token. If already present (e.g., restored
# from encrypted recovery bundle), systemd units mount without OAuth.
# Phase 3 puts tokens at ~/.cache/onedriver/<escaped-path>/auth_tokens.json.
TOKEN_FOUND=()
for acct in "${ACCOUNTS[@]}"; do
    escaped=$(systemd-escape --path "$DATA_ROOT/$acct" | sed 's|^-||')
    if [[ -f "$HOME/.cache/onedriver/$escaped/auth_tokens.json" ]]; then
        TOKEN_FOUND+=("$acct")
    fi
done
[[ ${#TOKEN_FOUND[@]} -gt 0 ]] && log_info "Existing tokens detected for: ${TOKEN_FOUND[*]}"

# =============================================================================
# Enable + start systemd user units (only for accounts that already have tokens)
# =============================================================================
# OAuth + enable for missing accounts is handled in 2 contexts:
#   - Recovery: Phase 3 (03-restore-secrets.sh) restores tokens from bundle
#     → enables units automatically. Phase 1 just preps the mountpoint.
#   - Fresh setup: user runs OAuth manually after this script (instructions below).
# This keeps Phase 1 non-interactive and idempotent.
AUTH_NEEDED=()
for acct in "${ACCOUNTS[@]}"; do
    escaped=$(systemd-escape --path "$DATA_ROOT/$acct" | sed 's|^-||')
    unit="onedriver@${escaped}.service"

    if [[ ! -f "$HOME/.cache/onedriver/$escaped/auth_tokens.json" ]]; then
        AUTH_NEEDED+=("$acct")
        log_info "  $acct — no tokens yet (defer to Phase 3 or manual OAuth)"
        continue
    fi

    systemctl --user reset-failed "$unit" 2>/dev/null || true
    if systemctl --user enable --now "$unit" 2>/dev/null; then
        log_success "  $unit enabled"
    else
        log_warn "  Failed to enable $unit — check: systemctl --user status $unit"
    fi
done

# =============================================================================
# Disable abraunegg/onedrive remnants if present (migration leftover)
# =============================================================================
if rpm -q onedrive >/dev/null 2>&1; then
    log_warn "abraunegg/onedrive package still installed — migration leftover."
    log_warn "Remove after verifying onedriver works: sudo dnf remove onedrive"
fi

OLD_AUTOSTART="$HOME/.config/autostart/OneDriveGUI.desktop"
if [[ -f "$OLD_AUTOSTART" ]]; then
    log_info "Disabling old OneDriveGUI autostart..."
    mv "$OLD_AUTOSTART" "${OLD_AUTOSTART}.disabled-by-onedrive-setup"
    log_success "  Renamed to ${OLD_AUTOSTART}.disabled-by-onedrive-setup"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "onedriver setup complete"
echo "Mounts (Files-On-Demand):"
for acct in "${ACCOUNTS[@]}"; do
    echo "  $DATA_ROOT/$acct"
done
echo ""
echo "Manage:"
echo "  systemctl --user status onedriver@<escaped-path>.service"
echo "  systemctl --user restart onedriver@<escaped-path>.service"
echo "  onedriver-launcher                                # GUI"
echo ""
echo "Drop a file into a mount → uploads to cloud automatically (like Windows OneDrive)."
echo "List a folder → shows placeholders (no download until read)."
echo ""
if (( ${#TOKEN_FOUND[@]} > 0 )); then
    echo "Mounts enabled (tokens present): ${TOKEN_FOUND[*]}"
fi
if (( ${#AUTH_NEEDED[@]} > 0 )); then
    echo ""
    log_section "Manual OAuth required for: ${AUTH_NEEDED[*]}"
    echo "Run each of these in a terminal (browser opens, sign in, returns):"
    echo ""
    for acct in "${AUTH_NEEDED[@]}"; do
        echo "  WEBKIT_DISABLE_DMABUF_RENDERER=1 GDK_BACKEND=x11 onedriver --auth-only \"$DATA_ROOT/$acct\""
    done
    echo ""
    echo "Then enable mount: systemctl --user enable --now 'onedriver@<escaped-path>.service'"
    echo ""
    echo "(In recovery context, Phase 3 restores tokens + enables units automatically — skip this.)"
fi

cat <<'EOF'

Notes:
- onedriver does NOT support pinning ("always keep local") nor selective folder
  exclusion. Calibre Library is therefore kept OUTSIDE this mount tree, at
  /home/haint/Data/Calibre Library/ (real local btrfs, backed up daily by
  home-server scripts/calibre-sync-setup.sh).
- A phantom Calibre Library folder will appear inside the Dev mount as
  on-demand placeholders (mirroring cloud). Ignore — CWA uses the real path.
- Individual files > ~1 GB load into memory on access. Avoid storing GB-size
  files inside the mount; use rclone copy instead for large transfers.
- KDE Plasma Wayland: WebKit OAuth fails with Gdk Error 71. Workaround flags
  WEBKIT_DISABLE_DMABUF_RENDERER=1 + GDK_BACKEND=x11 are documented above.
EOF
