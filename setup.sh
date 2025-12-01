#!/bin/bash
# =============================================================================
# setup.sh - Master orchestrator for terminal-custom setup
# =============================================================================
#
# Usage:
#   ./setup.sh              # Full installation
#   ./setup.sh --minimal    # Core setup only (no apps, no godot)
#   ./setup.sh --enhance    # Run terminal enhancement (power tools)
#   ./setup.sh --skip-vscode
#   ./setup.sh --skip-qdrant
#   ./setup.sh --skip-godot
#   ./setup.sh --skip-apps
#   ./setup.sh --skip-packettracer
#   ./setup.sh --help
#
# =============================================================================

set -e

# Resolve paths
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SETUP_DIR/scripts"

# Source common utilities
source "$SCRIPTS_DIR/common.sh"

# =============================================================================
# Parse Arguments
# =============================================================================
SKIP_VSCODE=false
SKIP_QDRANT=false
SKIP_GODOT=false
SKIP_APPS=false
SKIP_PACKETTRACER=false
SKIP_EASYEFFECTS=false
SKIP_VIETNAMESE=false
MINIMAL=false
ENHANCE=false

show_help() {
    echo "Terminal Custom Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --minimal           Core setup only (shell, dotfiles, fonts)"
    echo "  --enhance           Install power tools (zoxide, eza, bat, fzf, lazygit, yazi)"
    echo "  --skip-vscode       Skip VS Code installation"
    echo "  --skip-qdrant       Skip Qdrant setup"
    echo "  --skip-godot        Skip Godot installation"
    echo "  --skip-apps         Skip additional apps (Chrome, Dropbox, Flatpaks)"
    echo "  --skip-packettracer Skip Cisco Packet Tracer installation"
    echo "  --skip-easyeffects  Skip EasyEffects audio setup"
    echo "  --vietnamese        Install Vietnamese input method (ibus-bamboo)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Full installation"
    echo "  $0 --minimal        # Core setup only"
    echo "  $0 --enhance        # Add power tools to existing setup"
    echo "  $0 --skip-godot --skip-packettracer"
    exit 0
}

for arg in "$@"; do
    case $arg in
        --minimal)
            MINIMAL=true
            SKIP_QDRANT=true
            SKIP_GODOT=true
            SKIP_APPS=true
            SKIP_PACKETTRACER=true
            ;;
        --enhance)
            ENHANCE=true
            ;;
        --skip-vscode)
            SKIP_VSCODE=true
            ;;
        --skip-qdrant)
            SKIP_QDRANT=true
            ;;
        --skip-godot)
            SKIP_GODOT=true
            ;;
        --skip-apps)
            SKIP_APPS=true
            ;;
        --skip-packettracer)
            SKIP_PACKETTRACER=true
            ;;
        --skip-easyeffects)
            SKIP_EASYEFFECTS=true
            ;;
        --vietnamese)
            SKIP_VIETNAMESE=false
            INSTALL_VIETNAMESE=true
            ;;
        --help|-h)
            show_help
            ;;
        *)
            log_error "Unknown option: $arg"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# =============================================================================
# Pre-flight Checks
# =============================================================================
check_not_root
verify_backup_dir

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║          Terminal Custom Setup for Nobara/Fedora            ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if $MINIMAL; then
    log_info "Running in MINIMAL mode (core setup only)"
fi

# =============================================================================
# Run Setup Scripts
# =============================================================================

# Handle enhance-only mode
if $ENHANCE && [[ $# -eq 1 ]]; then
    log_section "Running Terminal Enhancement..."
    bash "$SCRIPTS_DIR/enhance_terminal.sh"
    echo ""
    echo -e "${GREEN}${BOLD}Terminal enhancement complete!${NC}"
    echo "Please restart your terminal to apply changes."
    exit 0
fi

# 1. Core Setup (always runs)
log_section "Running Core Setup..."
bash "$SCRIPTS_DIR/core_setup.sh"

# 2. VS Code Setup
if ! $SKIP_VSCODE; then
    log_section "Running VS Code Setup..."
    bash "$SCRIPTS_DIR/vscode_setup.sh"
else
    log_warn "Skipping VS Code setup"
fi

# 3. Qdrant Setup
if ! $SKIP_QDRANT; then
    log_section "Running Qdrant Setup..."
    bash "$SCRIPTS_DIR/qdrant_setup.sh"
else
    log_warn "Skipping Qdrant setup"
fi

# 4. Godot Setup
if ! $SKIP_GODOT; then
    log_section "Running Godot Setup..."
    bash "$SCRIPTS_DIR/godot_setup.sh"
else
    log_warn "Skipping Godot setup"
fi

# 5. Additional Apps Setup
if ! $SKIP_APPS; then
    log_section "Running Apps Setup..."
    bash "$SCRIPTS_DIR/apps_setup.sh"
else
    log_warn "Skipping additional apps setup"
fi

# 6. Packet Tracer Setup
if ! $SKIP_PACKETTRACER; then
    # Check if .deb file exists before attempting
    PT_DEB=$(find "$BACKUP_DIR" "$HOME" -maxdepth 1 -type f \( -name "Cisco*Packet*.deb" -o -name "Packet*Tracer*.deb" \) 2>/dev/null | head -1)
    if [[ -n "$PT_DEB" ]]; then
        log_section "Running Packet Tracer Setup..."
        bash "$SCRIPTS_DIR/packettracer_setup.sh"
    else
        log_warn "Skipping Packet Tracer setup (installer not found)"
        log_info "To install later, place the .deb file in $BACKUP_DIR and run:"
        echo "    bash $SCRIPTS_DIR/packettracer_setup.sh"
    fi
else
    log_warn "Skipping Packet Tracer setup"
fi

# 7. EasyEffects Setup
if ! $SKIP_EASYEFFECTS; then
    log_section "Running EasyEffects Setup..."
    bash "$SCRIPTS_DIR/easyeffects_setup.sh"
else
    log_warn "Skipping EasyEffects setup"
fi

# 8. Vietnamese Input Method (if requested)
if [[ "${INSTALL_VIETNAMESE:-false}" == "true" ]]; then
    log_section "Running Vietnamese Input Setup..."
    bash "$SCRIPTS_DIR/input_setup.sh"
fi

# 9. Terminal Enhancement (if requested)
if $ENHANCE; then
    log_section "Running Terminal Enhancement..."
    bash "$SCRIPTS_DIR/enhance_terminal.sh"
fi

# =============================================================================
# Complete
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║                    Setup Complete!                           ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Please log out and log back in for the shell change to take effect."
echo "Then open a new terminal to enjoy your restored setup!"
echo ""

if ! $SKIP_QDRANT; then
    log_info "Qdrant is running at: http://localhost:6333"
fi

if ! $SKIP_GODOT; then
    log_info "Run Godot with: godot"
fi

if $ENHANCE; then
    echo ""
    log_info "Power tools installed! New commands available:"
    echo "  - ls  → eza (with icons)"
    echo "  - cat → bat (syntax highlighting)"
    echo "  - cd  → z (smart directory jumping)"
    echo "  - lg  → lazygit"
    echo "  - y   → yazi (file manager)"
    echo ""
    log_info "Install tmux plugins: Press Ctrl+a then I inside tmux"
fi