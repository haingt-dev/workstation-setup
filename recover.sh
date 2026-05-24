#!/usr/bin/env bash
# =============================================================================
# recover.sh - Disaster recovery orchestrator
# =============================================================================
#
# Run on fresh Nobara install AFTER bootstrap.sh has installed prereqs.
#
# Usage:
#   ./recover.sh                       # Interactive (default)
#   ./recover.sh --non-interactive     # Autonomous, no confirms
#   ./recover.sh --dry-run             # Preview, no changes
#   ./recover.sh --skip-phase N        # Skip phase N (e.g., resume)
#   ./recover.sh --from-phase N        # Start from phase N
#   ./recover.sh --only-phase N        # Run only phase N
#
# Phases:
#   0. Detect mode (verify prerequisites)
#   1. System base (apps, dotfiles, fonts via ./setup.sh)
#   2. Cloud bundle (OneDrive auth + rclone + pull + GPG decrypt)
#   3. Secrets restore (SSH, GPG, gh token)
#   4. Claude state restore (~/.claude/ full)
#   5. Agent + Brain (clone, venv, restore brain.db, symlinks)
#   6. Project repos (clone 6 critical + .env + post-hooks)
#   7. Verify (health checks + report manual steps)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECOVERY_DIR="$REPO_ROOT/scripts/recovery"

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/common.sh"

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
INTERACTIVE=true
DRY_RUN=false
SKIP_PHASES=()
FROM_PHASE=0
ONLY_PHASE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --non-interactive) INTERACTIVE=false; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --skip-phase) SKIP_PHASES+=("$2"); shift 2 ;;
        --from-phase) FROM_PHASE="$2"; shift 2 ;;
        --only-phase) ONLY_PHASE="$2"; shift 2 ;;
        -h|--help) sed -n '4,25p' "$0"; exit 0 ;;
        *) shift ;;
    esac
done

export DRY_RUN INTERACTIVE

# ─────────────────────────────────────────────────────────────
# Phase definitions
# ─────────────────────────────────────────────────────────────
declare -a PHASES=(
    "0|Bootstrap detection|00-detect-mode.sh|30s"
    "1|System base install|01-system-base.sh|20-30 min"
    "2|Cloud bundle pull + decrypt|02-cloud-bundle.sh|5-10 min"
    "3|Secrets restore (SSH/GPG/gh)|03-restore-secrets.sh|30s"
    "4|Claude state restore|04-restore-claude.sh|2-5 min"
    "5|Agent + Brain restore|05-restore-agent-brain.sh|3-5 min"
    "6|Project repos + post-hooks|06-clone-repos.sh|15-25 min"
    "7|Verify + report|07-verify.sh|1 min"
)

# ─────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────
clear
cat <<EOF
══════════════════════════════════════════════════════════
  Hải's Workstation Recovery — $(date +%Y-%m-%d\ %H:%M)
══════════════════════════════════════════════════════════

Mode:        $($INTERACTIVE && echo "Interactive (confirm each phase)" || echo "Non-interactive (autonomous)")
Dry-run:     $DRY_RUN
Skip phases: ${SKIP_PHASES[*]:-none}
From phase:  $FROM_PHASE
Only phase:  ${ONLY_PHASE:-N/A}

EOF

# ─────────────────────────────────────────────────────────────
# Phase runner
# ─────────────────────────────────────────────────────────────
run_phase() {
    local num="$1" name="$2" script="$3" duration="$4"

    # Skip logic
    for skip in "${SKIP_PHASES[@]}"; do
        if [[ "$skip" == "$num" ]]; then
            log_warn "Skipping phase $num ($name) per --skip-phase"
            return 0
        fi
    done

    [[ -n "$ONLY_PHASE" && "$ONLY_PHASE" != "$num" ]] && return 0
    [[ "$num" -lt "$FROM_PHASE" ]] && { log_warn "Phase $num before --from-phase, skip"; return 0; }

    local script_path="$RECOVERY_DIR/$script"
    [[ ! -x "$script_path" ]] && { log_error "Script not found/not exec: $script_path"; return 1; }

    log_section "Phase $num/$((${#PHASES[@]}-1)): $name (~$duration)"

    if $INTERACTIVE; then
        read -rp "Continue? [Y/n] " ans
        [[ "$ans" =~ ^[nN]$ ]] && { log_warn "Aborted at phase $num"; exit 1; }
    fi

    # Pass dry-run flag through
    local args=()
    $DRY_RUN && args+=("--dry-run")

    if "$script_path" "${args[@]}"; then
        log_success "Phase $num complete"
    else
        log_error "Phase $num FAILED"
        if $INTERACTIVE; then
            read -rp "Continue to next phase anyway? [y/N] " ans
            [[ "$ans" =~ ^[yY]$ ]] || exit 1
        else
            exit 1
        fi
    fi
}

# ─────────────────────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────────────────────
for phase in "${PHASES[@]}"; do
    IFS='|' read -r num name script duration <<< "$phase"
    run_phase "$num" "$name" "$script" "$duration"
done

echo ""
log_section "Recovery complete"
echo ""
echo "Log: ~/.local/share/recovery/recover.log"
echo "Re-run individual phase: ./recover.sh --only-phase N"
