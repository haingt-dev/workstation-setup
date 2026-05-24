#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh - Day-zero entry point for disaster recovery
# =============================================================================
#
# Run on a fresh Nobara install with NOTHING set up.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/haingt-dev/workstation-setup/master/bootstrap.sh | bash
#   # or after cloning manually:
#   ./bootstrap.sh
#
# What it does (intentionally minimal):
#   1. Install bare prerequisites (git, curl, gh, gnupg2, rclone)
#   2. Print 3-step instructions for Hải to run manually
#
# Does NOT auto-run recover.sh — Hải reads + understands each phase.
# Transparency > convenience in disaster scenarios.
# =============================================================================

set -e

# ─────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[32m'
BLUE='\033[34m'
YELLOW='\033[33m'
RESET='\033[0m'

log()     { echo -e "${BLUE}[bootstrap]${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }

# ─────────────────────────────────────────────────────────────
# Sanity checks
# ─────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    echo "Don't run as root — use sudo only where needed."
    exit 1
fi

if ! command -v dnf &>/dev/null; then
    echo "This bootstrap assumes Fedora/Nobara (dnf)."
    echo "Adapt manually for other distros."
    exit 1
fi

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD} Hải's Workstation — Day Zero Bootstrap${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""
log "Installing bare prerequisites..."

# ─────────────────────────────────────────────────────────────
# Install bare minimum
# ─────────────────────────────────────────────────────────────
PKGS=(git curl gh gnupg2 rclone)

# Check which are missing
MISSING=()
for pkg in "${PKGS[@]}"; do
    case "$pkg" in
        gh) cmd="gh" ;;
        gnupg2) cmd="gpg" ;;
        *) cmd="$pkg" ;;
    esac
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$pkg")
    else
        success "$pkg already installed"
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    log "Installing: ${MISSING[*]}"
    sudo dnf install -y "${MISSING[@]}"
fi

echo ""
success "Prerequisites ready."
echo ""

# ─────────────────────────────────────────────────────────────
# Print next steps
# ─────────────────────────────────────────────────────────────
REPO_PATH="$HOME/Projects/workstation-setup"

cat <<EOF
${BOLD}═══════════════════════════════════════════════════════${RESET}
 ${BOLD}Next steps — run these manually:${RESET}
${BOLD}═══════════════════════════════════════════════════════${RESET}

${BOLD}1.${RESET} Authenticate GitHub (browser opens):

   ${BLUE}gh auth login --web${RESET}

${BOLD}2.${RESET} Clone workstation-setup (if you ran via curl|bash, skip):

   ${BLUE}mkdir -p ~/Projects && cd ~/Projects${RESET}
   ${BLUE}gh repo clone haingt-dev/workstation-setup${RESET}

${BOLD}3.${RESET} Start the recovery pipeline:

   ${BLUE}cd ${REPO_PATH}${RESET}
   ${BLUE}./recover.sh${RESET}

${BOLD}═══════════════════════════════════════════════════════${RESET}

${YELLOW}Tips:${RESET}
  • recover.sh runs in 7 phases with interactive confirm
  • Use --skip-phase N to resume after a failure
  • Use --dry-run to preview without changes
  • Read ${REPO_PATH}/docs/RECOVERY.md for full phase details

${YELLOW}If you need to restore secrets bundle:${RESET}
  • Bundle passphrase is in your password manager
  • Recovery bundle lives in OneDrive:/dev/recovery-bundle/
  • Phase 2 of recover.sh handles bundle pull + decrypt

EOF
