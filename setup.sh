#!/bin/bash
# =============================================================================
# setup.sh - Master orchestrator for terminal-custom setup
# =============================================================================
#
# Usage:
#   ./setup.sh              # Full installation (Standard components)
#   ./setup.sh --minimal    # Core setup only
#   ./setup.sh --full       # Full setup (Standard components)
#   ./setup.sh --vscode     # Exclusive mode: ONLY setup VS Code
#   ./setup.sh --enhance    # Exclusive mode: ONLY run enhancement
#   ./setup.sh --skip-godot # Full installation EXCEPT Godot
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
# Configuration & Defaults
# =============================================================================

# Standard components (Run by default)
INSTALL_CORE=true
INSTALL_VSCODE=true
INSTALL_QDRANT=true
INSTALL_GODOT=true
INSTALL_APPS=true
INSTALL_PACKETTRACER=true
INSTALL_EASYEFFECTS=true

# Optional components (Do not run by default)
INSTALL_ONEDRIVE=false
INSTALL_VIETNAMESE=false
INSTALL_ENHANCE=false

# =============================================================================
# Argument Parsing
# =============================================================================

show_help() {
    echo "Terminal Custom Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Modes:"
    echo "  Default (no args)   Run full standard setup."
    echo "  Exclusive           If any component flag is used, ONLY that component runs."
    echo ""
    echo "Component Flags (Triggers Exclusive Mode):"
    echo "  --full              Run full standard setup (useful to combine with --enhance)"
    echo "  --core, --minimal   Core setup (shell, dotfiles, fonts)"
    echo "  --vscode            VS Code setup"
    echo "  --qdrant            Qdrant setup"
    echo "  --godot             Godot setup"
    echo "  --apps              Additional apps (Chrome, Dropbox, Flatpaks)"
    echo "  --packettracer      Cisco Packet Tracer setup"
    echo "  --easyeffects       EasyEffects audio setup"
    echo "  --onedrive          OneDrive setup (supports multiple accounts)"
    echo "  --vietnamese        Vietnamese input setup (ibus-bamboo)"
    echo "  --enhance           Terminal enhancement (power tools)"
    echo ""
    echo "Skip Flags (For Default Mode):"
    echo "  --skip-vscode       Skip VS Code"
    echo "  --skip-qdrant       Skip Qdrant"
    echo "  --skip-godot        Skip Godot"
    echo "  --skip-apps         Skip Apps"
    echo "  --skip-packettracer Skip Packet Tracer"
    echo "  --skip-easyeffects  Skip EasyEffects"
    echo ""
    echo "Examples:"
    echo "  $0                  # Full standard installation"
    echo "  $0 --vscode         # ONLY install VS Code"
    echo "  $0 --core --enhance # Core setup + Enhancement"
    echo "  $0 --skip-godot     # Full setup EXCEPT Godot"
    exit 0
}

# Detect Exclusive Mode
# If any positive component flag is present, switch to exclusive mode.
EXCLUSIVE_MODE=false
for arg in "$@"; do
    case $arg in
        --full|--core|--minimal|--vscode|--qdrant|--godot|--apps|--packettracer|--easyeffects|--onedrive|--vietnamese|--enhance)
            EXCLUSIVE_MODE=true
            break
            ;;
    esac
done

if $EXCLUSIVE_MODE; then
    # In exclusive mode, disable all standard components by default.
    # Only explicitly requested components will be enabled in the loop below.
    INSTALL_CORE=false
    INSTALL_VSCODE=false
    INSTALL_QDRANT=false
    INSTALL_GODOT=false
    INSTALL_APPS=false
    INSTALL_PACKETTRACER=false
    INSTALL_EASYEFFECTS=false
    INSTALL_ONEDRIVE=false
    INSTALL_VIETNAMESE=false
    INSTALL_ENHANCE=false
fi

# Parse Flags
for arg in "$@"; do
    case $arg in
        # Component Flags
        --full)
            INSTALL_CORE=true
            INSTALL_VSCODE=true
            INSTALL_QDRANT=true
            INSTALL_GODOT=true
            INSTALL_APPS=true
            INSTALL_PACKETTRACER=true
            INSTALL_EASYEFFECTS=true
            ;;
        --core|--minimal)     INSTALL_CORE=true ;;
        --vscode)             INSTALL_VSCODE=true ;;
        --qdrant)             INSTALL_QDRANT=true ;;
        --godot)              INSTALL_GODOT=true ;;
        --apps)               INSTALL_APPS=true ;;
        --packettracer)       INSTALL_PACKETTRACER=true ;;
        --easyeffects)        INSTALL_EASYEFFECTS=true ;;
        --onedrive)           INSTALL_ONEDRIVE=true ;;
        --vietnamese)         INSTALL_VIETNAMESE=true ;;
        --enhance)            INSTALL_ENHANCE=true ;;

        # Skip Flags
        --skip-vscode)        INSTALL_VSCODE=false ;;
        --skip-qdrant)        INSTALL_QDRANT=false ;;
        --skip-godot)         INSTALL_GODOT=false ;;
        --skip-apps)          INSTALL_APPS=false ;;
        --skip-packettracer)  INSTALL_PACKETTRACER=false ;;
        --skip-easyeffects)   INSTALL_EASYEFFECTS=false ;;

        # Other
        --help|-h)            show_help ;;
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

if $EXCLUSIVE_MODE; then
    log_info "Running in EXCLUSIVE MODE (Selected components only)"
fi

# =============================================================================
# Run Setup Scripts
# =============================================================================

# 1. Core Setup
if $INSTALL_CORE; then
    log_section "Running Core Setup..."
    bash "$SCRIPTS_DIR/core_setup.sh"
fi

# 2. VS Code Setup
if $INSTALL_VSCODE; then
    log_section "Running VS Code Setup..."
    bash "$SCRIPTS_DIR/vscode_setup.sh"
elif ! $EXCLUSIVE_MODE; then
    log_warn "Skipping VS Code setup"
fi

# 3. Qdrant Setup
if $INSTALL_QDRANT; then
    log_section "Running Qdrant Setup..."
    bash "$SCRIPTS_DIR/qdrant_setup.sh"
elif ! $EXCLUSIVE_MODE; then
    log_warn "Skipping Qdrant setup"
fi

# 4. Godot Setup
if $INSTALL_GODOT; then
    log_section "Running Godot Setup..."
    bash "$SCRIPTS_DIR/godot_setup.sh"
elif ! $EXCLUSIVE_MODE; then
    log_warn "Skipping Godot setup"
fi

# 5. Additional Apps Setup
if $INSTALL_APPS; then
    log_section "Running Apps Setup..."
    bash "$SCRIPTS_DIR/apps_setup.sh"
elif ! $EXCLUSIVE_MODE; then
    log_warn "Skipping additional apps setup"
fi

# 6. Packet Tracer Setup
if $INSTALL_PACKETTRACER; then
    # Check if .deb file exists before attempting
    PT_DEB=$(find "$BACKUP_DIR" "$HOME" -maxdepth 1 -type f \( -name "Cisco*Packet*.deb" -o -name "Packet*Tracer*.deb" \) 2>/dev/null | head -1)
    if [[ -n "$PT_DEB" ]]; then
        log_section "Running Packet Tracer Setup..."
        bash "$SCRIPTS_DIR/packettracer_setup.sh"
    else
        log_warn "Skipping Packet Tracer setup (installer not found)"
        log_info "To install later, place the .deb file in $BACKUP_DIR and run:"
        echo "    ./setup.sh --packettracer"
    fi
elif ! $EXCLUSIVE_MODE; then
    log_warn "Skipping Packet Tracer setup"
fi

# 7. EasyEffects Setup
if $INSTALL_EASYEFFECTS; then
    log_section "Running EasyEffects Setup..."
    bash "$SCRIPTS_DIR/easyeffects_setup.sh"
elif ! $EXCLUSIVE_MODE; then
    log_warn "Skipping EasyEffects setup"
fi

# 8. Vietnamese Input Method
if $INSTALL_VIETNAMESE; then
    log_section "Running Vietnamese Input Setup..."
    bash "$SCRIPTS_DIR/input_setup.sh"
fi

# 9. OneDrive Setup
if $INSTALL_ONEDRIVE; then
    log_section "Running OneDrive Setup..."
    bash "$SCRIPTS_DIR/onedrive_setup.sh"
fi

# 10. Terminal Enhancement
if $INSTALL_ENHANCE; then
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

if $INSTALL_QDRANT; then
    log_info "Qdrant is running at: http://localhost:6333"
fi

if $INSTALL_GODOT; then
    log_info "Run Godot with: godot"
fi

if $INSTALL_ENHANCE; then
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