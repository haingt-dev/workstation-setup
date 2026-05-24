#!/usr/bin/env bash
# =============================================================================
# install-cron.sh - Register/update daily backup cron + clean legacy
# =============================================================================
#
# Replaces:
#   - Legacy: 7 4 * * * cp $BRAIN_DB $BRAIN_BACKUP_DIR/brain.db.bak
#   - With:   30 4 * * * daily-bundle.sh (covers brain.db + all critical state)
#
# Usage:
#   ./install-cron.sh             # Install (interactive confirm)
#   ./install-cron.sh --force     # Install without confirm
#   ./install-cron.sh --uninstall # Remove daily-bundle cron
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_SCRIPT="$SCRIPT_DIR/daily-bundle.sh"
CONFIG_FILE="${BUNDLE_CONF:-$HOME/.config/recovery/bundle.conf}"

# Load schedule from config
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi
SCHEDULE="${CRON_SCHEDULE:-30 4 * * *}"
MARKER="# managed by workstation-setup/scripts/backup/install-cron.sh"
LEGACY_MARKER="brain.db.bak"

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
FORCE=false
UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        *) shift ;;
    esac
done

# ─────────────────────────────────────────────────────────────
# Capture current crontab
# ─────────────────────────────────────────────────────────────
CURRENT=$(crontab -l 2>/dev/null || true)

if $UNINSTALL; then
    NEW=$(echo "$CURRENT" | grep -v "$MARKER" | grep -v "$BUNDLE_SCRIPT" || true)
    echo "$NEW" | crontab -
    echo "[ok] Removed daily-bundle cron entries"
    exit 0
fi

# ─────────────────────────────────────────────────────────────
# Show plan
# ─────────────────────────────────────────────────────────────
echo "Cron installation plan:"
echo ""
echo "  ADD:    $SCHEDULE $BUNDLE_SCRIPT"
echo "          $MARKER"
echo ""

LEGACY=$(echo "$CURRENT" | grep "$LEGACY_MARKER" || true)
if [[ -n "$LEGACY" ]]; then
    echo "  REMOVE (legacy brain.db.bak cron — superseded by daily-bundle):"
    echo "$LEGACY" | sed 's/^/          /'
    echo ""
fi

EXISTING=$(echo "$CURRENT" | grep "$BUNDLE_SCRIPT" || true)
if [[ -n "$EXISTING" ]]; then
    echo "  REPLACE existing daily-bundle entry:"
    echo "$EXISTING" | sed 's/^/          /'
    echo ""
fi

if ! $FORCE; then
    read -rp "Apply? [y/N] " ans
    [[ "$ans" =~ ^[yY]$ ]] || { echo "Aborted."; exit 0; }
fi

# ─────────────────────────────────────────────────────────────
# Rewrite crontab
# ─────────────────────────────────────────────────────────────
NEW=$(echo "$CURRENT" | grep -v "$LEGACY_MARKER" | grep -v "$MARKER" | grep -v "$BUNDLE_SCRIPT" || true)

# Append our entry
NEW="${NEW}
$MARKER
$SCHEDULE $BUNDLE_SCRIPT"

echo "$NEW" | crontab -

echo ""
echo "[ok] Crontab updated. Current entries:"
crontab -l
