#!/bin/bash
# =============================================================================
# vscode_setup.sh - Visual Studio Code installation via Microsoft RPM repo
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Installing Visual Studio Code"

# =============================================================================
# Add Microsoft RPM Repository
# =============================================================================
if ! rpm -q code &>/dev/null; then
    log_info "Adding Microsoft VS Code repository..."

    # Import Microsoft GPG key
    run_sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

    # Add the repository
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | run_sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

    # Install VS Code
    dnf_install code
    log_success "Visual Studio Code installed"
else
    log_success "Visual Studio Code already installed"
fi

# =============================================================================
# Configuration (NOT seeded from this repo)
# =============================================================================
# VS Code User settings/keybindings/snippets + the extension list are live state
# you author — NOT seeded from this repo. They are captured by
# scripts/backup/daily-bundle.sh (Section 6: vscode-user.tar.gz + vscode-extensions.txt)
# and restored by recover.sh Phase 6.
log_info "VS Code config not seeded from repo — restored from backup bundle during recovery."

# =============================================================================
# Summary
# =============================================================================
log_section "Visual Studio Code Setup Complete!"
echo ""
echo "Installed:"
echo "  - Visual Studio Code (Microsoft RPM repo)"
echo ""
echo "Tips:"
echo "  - Settings + extensions are captured by the daily backup bundle, not this repo"
echo "  - Fresh-machine restore happens via recover.sh"
