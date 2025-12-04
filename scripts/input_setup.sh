#!/bin/bash
# =============================================================================
# input_setup.sh - Vietnamese input method support (ibus-bamboo)
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Installing Vietnamese Input Method (ibus-bamboo)"

# =============================================================================
# Install ibus-bamboo
# =============================================================================
log_info "Installing ibus and ibus-bamboo..."
dnf_install ibus ibus-bamboo

log_success "ibus-bamboo installed"

# =============================================================================
# Configure environment variables
# =============================================================================
log_section "Configuring input method environment..."

# Add IBus environment variables to .profile if not already present
PROFILE_FILE="$HOME/.profile"
if ! grep -q "GTK_IM_MODULE=ibus" "$PROFILE_FILE" 2>/dev/null; then
    cat >> "$PROFILE_FILE" << 'EOF'

# IBus input method configuration
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
EOF
    log_success "Added IBus environment variables to ~/.profile"
else
    log_info "IBus environment variables already configured in ~/.profile"
fi

# =============================================================================
# Summary
# =============================================================================
log_section "Vietnamese Input Method Setup Complete!"
echo ""
echo "To complete setup:"
echo "  1. Log out and log back in (or reboot)"
echo "  2. Run: ibus-daemon -drx"
echo "  3. Open Settings → Keyboard → Input Sources"
echo "  4. Add 'Vietnamese (Bamboo)' as an input source"
echo ""
echo "Keyboard shortcut to switch input: Super+Space (default)"
echo ""
log_info "Typing method: Telex by default. Configure via ibus-bamboo settings."