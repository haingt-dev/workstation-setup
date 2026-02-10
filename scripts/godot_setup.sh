#!/bin/bash
# =============================================================================
# godot_setup.sh - Godot Engine installation and configuration
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

# Configuration
GODOT_INSTALL_DIR="$HOME/.local/bin"
GODOT_CONFIG_DIR="$HOME/.config/godot"
DOWNLOADS_DIR="$HOME/Downloads"

# =============================================================================
# Handle Uninstall
# =============================================================================
if [[ "$1" == "--uninstall" ]]; then
    log_section "Uninstalling Godot..."
    rm -f "$GODOT_INSTALL_DIR/godot"
    rm -f "$HOME/.local/share/applications/godot.desktop"
    log_success "Godot uninstalled (config preserved in ~/.config/godot)"
    exit 0
fi

# =============================================================================
# Auto-detect Godot zip in ~/Downloads
# =============================================================================
log_section "Searching for Godot zip in $DOWNLOADS_DIR..."

# Find the most recently modified Godot zip
GODOT_ZIP_PATH=$(find "$DOWNLOADS_DIR" -maxdepth 1 -name "Godot_v*_linux.x86_64.zip" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

if [[ -z "$GODOT_ZIP_PATH" ]]; then
    log_error "No Godot zip found in $DOWNLOADS_DIR"
    echo "  Expected pattern: Godot_v*_linux.x86_64.zip"
    echo ""
    echo "  Download Godot from: https://godotengine.org/download/linux/"
    echo "  Place the zip in $DOWNLOADS_DIR and re-run this script."
    exit 1
fi

GODOT_ZIP=$(basename "$GODOT_ZIP_PATH")
# Extract version from filename (e.g., "Godot_v4.6-stable_linux.x86_64.zip" -> "4.6-stable")
GODOT_VERSION=$(echo "$GODOT_ZIP" | sed -n 's/^Godot_v\(.*\)_linux\.x86_64\.zip$/\1/p')

if [[ -z "$GODOT_VERSION" ]]; then
    log_error "Could not extract version from filename: $GODOT_ZIP"
    exit 1
fi

log_success "Found: $GODOT_ZIP (version: $GODOT_VERSION)"

# =============================================================================
# Remove Old Godot Installation
# =============================================================================
if [[ -f "$GODOT_INSTALL_DIR/godot" ]]; then
    log_section "Removing old Godot installation..."
    OLD_VERSION=$("$GODOT_INSTALL_DIR/godot" --version 2>/dev/null || echo "unknown")
    rm -f "$GODOT_INSTALL_DIR/godot"
    log_success "Removed old Godot ($OLD_VERSION)"
fi

# =============================================================================
# Create Directories
# =============================================================================
log_section "Installing Godot Engine ${GODOT_VERSION}..."

ensure_dir "$GODOT_INSTALL_DIR"
ensure_dir "$HOME/.local/share/applications"
ensure_dir "$HOME/.local/share/icons"

# =============================================================================
# Ensure Dependencies
# =============================================================================
# Ensure dependencies are installed
if ! check_command unzip; then
    log_info "unzip not found, installing..."
    dnf_install unzip
fi

# =============================================================================
# Extract and Install
# =============================================================================
log_section "Extracting $GODOT_ZIP..."

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

unzip -q "$GODOT_ZIP_PATH"
GODOT_BINARY=$(find . -maxdepth 1 -name "Godot_v*" -type f | head -1)

if [[ -z "$GODOT_BINARY" ]]; then
    log_error "Could not find Godot binary in archive"
    rm -rf "$TEMP_DIR"
    exit 1
fi

chmod +x "$GODOT_BINARY"
mv "$GODOT_BINARY" "$GODOT_INSTALL_DIR/godot"
log_success "Installed to $GODOT_INSTALL_DIR/godot"

# Cleanup temp
cd - > /dev/null
rm -rf "$TEMP_DIR"

# =============================================================================
# Restore Configuration
# =============================================================================
log_section "Restoring Godot configuration..."

if [[ -d "$BACKUP_DIR/godot" ]]; then
    ensure_dir "$GODOT_CONFIG_DIR"
    cp -r "$BACKUP_DIR/godot/"* "$GODOT_CONFIG_DIR/"
    log_success "Configuration restored to $GODOT_CONFIG_DIR"
    
    # Check external editor integration
    if grep -q 'text_editor/external/use_external_editor = true' "$GODOT_CONFIG_DIR/"editor_settings*.tres 2>/dev/null; then
        log_success "External editor integration preserved"
    fi
else
    log_warn "No Godot config backup found in $BACKUP_DIR/godot"
fi

# =============================================================================
# Desktop Integration
# =============================================================================
log_section "Setting up desktop integration..."

ICON_PATH="$HOME/.local/share/icons/godot.svg"
if [[ -f "$BACKUP_DIR/godot/godot.svg" ]]; then
    cp "$BACKUP_DIR/godot/godot.svg" "$ICON_PATH"
    log_success "Icon copied from backup"
else
    curl -sL -o "$ICON_PATH" "https://raw.githubusercontent.com/godotengine/godot/master/icon.svg" 2>/dev/null || true
    log_success "Icon downloaded from GitHub"
fi

# Create desktop entry
cat > "$HOME/.local/share/applications/godot.desktop" << EOF
[Desktop Entry]
Name=Godot Engine
Comment=Multi-platform 2D and 3D game engine
Exec=$GODOT_INSTALL_DIR/godot %f
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=application/x-godot-project;
Keywords=game;engine;development;
EOF
log_success "Desktop entry created"

# Update desktop database
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# =============================================================================
# Verify Installation
# =============================================================================
echo ""
if "$GODOT_INSTALL_DIR/godot" --version 2>/dev/null; then
    log_success "Godot installed successfully!"
else
    log_warn "Godot installed but may require additional dependencies"
fi

log_section "Godot setup complete!"
echo ""
log_info "Run Godot with: godot"
log_info "Or launch from your application menu"