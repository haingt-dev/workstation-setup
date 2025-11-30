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
GODOT_VERSION="${GODOT_VERSION:-4.5.1}"
GODOT_INSTALL_DIR="$HOME/.local/bin"
GODOT_CONFIG_DIR="$HOME/.config/godot"

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
# Create Directories
# =============================================================================
log_section "Installing Godot Engine ${GODOT_VERSION}..."

ensure_dir "$GODOT_INSTALL_DIR"
ensure_dir "$HOME/.local/share/applications"
ensure_dir "$HOME/.local/share/icons"

# =============================================================================
# Download Godot
# =============================================================================
log_section "Downloading Godot ${GODOT_VERSION}..."

GODOT_ZIP="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${GODOT_ZIP}"

# Check if version exists
if ! curl -sIf "$GODOT_URL" > /dev/null 2>&1; then
    log_error "Godot version ${GODOT_VERSION} not found at:"
    echo "  $GODOT_URL"
    echo ""
    echo "Available stable versions: 4.4.1, 4.3, 4.2.2, 4.1.4, 4.0.4"
    echo ""
    echo "To install a different version, set GODOT_VERSION:"
    echo "  GODOT_VERSION=4.3 bash $0"
    exit 1
fi

# Download to temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

curl -L -o "$GODOT_ZIP" "$GODOT_URL"
log_success "Downloaded $GODOT_ZIP"

# =============================================================================
# Extract and Install
# =============================================================================
log_section "Extracting..."
unzip -q "$GODOT_ZIP"
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
    
    # Check VS Code integration
    if grep -q 'text_editor/external/use_external_editor = true' "$GODOT_CONFIG_DIR/"editor_settings*.tres 2>/dev/null; then
        log_success "VS Code integration preserved"
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