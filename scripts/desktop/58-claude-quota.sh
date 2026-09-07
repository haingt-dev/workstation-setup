#!/bin/bash
# =============================================================================
# 58-claude-quota.sh - Claude Code quota gauge in the dock
# =============================================================================
# A ring gauge on the dock showing how much of the Claude subscription is used,
# with a popup breaking it down per window and per reset time.
#
# Why our own plasmoid: the idea came from PR #43 of pctrade/end4-pC, which
# does this for Hyprland via Quickshell — not portable to Plasma. And the data
# that matters most is only available from one place: the usage endpoint's
# `limits` array carries a PER-MODEL weekly window (weekly_scoped) that is
# routinely the binding limit while the aggregate still looks healthy. Claude
# Code's own statusline JSON only exposes the 5-hour and 7-day aggregates.
#
# Data path (undocumented endpoint, verified live 2026-09-07, HTTP 200):
#   ~/.claude/.credentials.json .claudeAiOauth.accessToken
#     -> GET https://api.anthropic.com/api/oauth/usage
#        (Authorization: Bearer, anthropic-beta: oauth-2025-04-20)
# The helper inside the package does the request with python urllib so the
# token never lands in argv, caches the last good answer, and always prints one
# line of JSON — so a rotated token or a dead network dims the gauge instead of
# breaking the dock.
#
# The applet is added to the panel only when it is missing, so dragging it to a
# different slot in Edit Mode survives every later run. (Plasma 6.7's scripting
# API reports Applet.index as -1 for panel applets, so there is no supported
# way to place it programmatically, and rewriting AppletOrder by hand is the
# one appletsrc edit this rice has always refused to make.)
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 58: Claude quota gauge"

QUOTA_ID="dev.haint.claudequota"
HELPER="$HOME/.local/share/plasma/plasmoids/$QUOTA_ID/contents/tools/claude-quota.py"

STATE="$(install_own_plasmoid "$QUOTA_ID")"
case "$STATE" in
    installed) log_success "Installed $QUOTA_ID" ;;
    updated)   log_success "Updated $QUOTA_ID (package content changed)" ;;
    current)   log_success "OK  $QUOTA_ID already up to date" ;;
esac

# --- Smoke-test the helper (soft: a fresh machine has no Claude login yet) ------
if [[ ! -f "$HOME/.claude/.credentials.json" ]]; then
    log_warn "No ~/.claude/.credentials.json — the gauge shows '—' until you run claude once"
elif OUT="$(python3 "$HELPER" --refresh 2>/dev/null)"; then
    log_success "Quota helper OK: $(printf '%s' "$OUT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(", ".join("%s %d%%" % (l["short"], l["percent"]) for l in d["limits"]) or "no windows")')"
else
    log_warn "Quota helper could not refresh: $(printf '%s' "${OUT:-}" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("error") or "unknown")
except Exception:
    print("no JSON on stdout")')"
fi

# --- Add to the dock once --------------------------------------------------------
ADDED="$(plasma_script '
var added = 0;
for (const p of panels()) {
    if (p.widgets("'"$QUOTA_ID"'").length === 0) { p.addWidget("'"$QUOTA_ID"'"); added++; }
}
print(added);
' | tr -dc '0-9')"

if [[ "${ADDED:-0}" != "0" ]]; then
    log_success "Added the quota gauge to the dock"
else
    log_success "OK  quota gauge already in the dock"
fi

# addWidget applies live; only a package change needs the QML reloaded.
if [[ "$STATE" != "current" ]]; then
    log_info "Package changed — restarting plasmashell to reload the QML"
    plasma_restart
fi
