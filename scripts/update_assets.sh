#!/bin/bash
# =============================================================================
# update_assets.sh - Update assets from current system configuration
# =============================================================================
# This script copies your current system configuration back to the assets/
# directory to keep your backup in sync with your latest changes.
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

log_section "Updating assets from system configuration..."

# =============================================================================
# Dotfiles
# =============================================================================
log_section "Updating dotfiles..."

# .zshrc
if [[ -f ~/.zshrc ]]; then
    cp ~/.zshrc "$BACKUP_DIR/.zshrc"
    log_success "Updated .zshrc"
fi

# .zshrc.enhanced (if exists and different from .zshrc)
if [[ -f ~/.zshrc.enhanced ]]; then
    cp ~/.zshrc.enhanced "$BACKUP_DIR/.zshrc.enhanced"
    log_success "Updated .zshrc.enhanced"
fi

# .bashrc
if [[ -f ~/.bashrc ]]; then
    cp ~/.bashrc "$BACKUP_DIR/.bashrc"
    log_success "Updated .bashrc"
fi

# .gitconfig
if [[ -f ~/.gitconfig ]]; then
    cp ~/.gitconfig "$BACKUP_DIR/.gitconfig"
    log_success "Updated .gitconfig"
fi

# =============================================================================
# Config Directories
# =============================================================================
log_section "Updating .config directories..."

ensure_dir "$BACKUP_DIR/.config"

# Starship
if [[ -f ~/.config/starship.toml ]]; then
    ensure_dir "$BACKUP_DIR/.config/starship"
    cp ~/.config/starship.toml "$BACKUP_DIR/.config/starship/starship.toml"
    log_success "Updated starship.toml"
fi
if [[ -d ~/.config/starship ]]; then
    cp -r ~/.config/starship/* "$BACKUP_DIR/.config/starship/" 2>/dev/null || true
    log_success "Updated starship config directory"
fi

# Atuin
if [[ -d ~/.config/atuin ]]; then
    ensure_dir "$BACKUP_DIR/.config/atuin"
    cp -r ~/.config/atuin/* "$BACKUP_DIR/.config/atuin/" 2>/dev/null || true
    log_success "Updated atuin config"
fi

# Fastfetch
if [[ -d ~/.config/fastfetch ]]; then
    ensure_dir "$BACKUP_DIR/.config/fastfetch"
    # Copy config files but not the assets subdirectory (we handle jedi.png separately)
    find ~/.config/fastfetch -maxdepth 1 -type f -exec cp {} "$BACKUP_DIR/.config/fastfetch/" \;
    log_success "Updated fastfetch config"
fi

# Fastfetch custom logo
if [[ -f ~/.config/fastfetch/assets/jedi.png ]]; then
    ensure_dir "$BACKUP_DIR/images"
    cp ~/.config/fastfetch/assets/jedi.png "$BACKUP_DIR/images/"
    log_success "Updated jedi.png"
fi

# Fish
if [[ -d ~/.config/fish ]]; then
    ensure_dir "$BACKUP_DIR/.config/fish"
    cp -r ~/.config/fish/* "$BACKUP_DIR/.config/fish/" 2>/dev/null || true
    log_success "Updated fish config"
fi

# Kitty
if [[ -d ~/.config/kitty ]]; then
    ensure_dir "$BACKUP_DIR/.config/kitty"
    cp -r ~/.config/kitty/* "$BACKUP_DIR/.config/kitty/" 2>/dev/null || true
    log_success "Updated kitty config"
fi

# Tmux
if [[ -d ~/.config/tmux ]]; then
    ensure_dir "$BACKUP_DIR/.config/tmux"
    cp -r ~/.config/tmux/* "$BACKUP_DIR/.config/tmux/" 2>/dev/null || true
    log_success "Updated tmux config"
fi

# Yazi
if [[ -d ~/.config/yazi ]]; then
    ensure_dir "$BACKUP_DIR/.config/yazi"
    cp -r ~/.config/yazi/* "$BACKUP_DIR/.config/yazi/" 2>/dev/null || true
    log_success "Updated yazi config"
fi

# Bat
if [[ -d ~/.config/bat ]]; then
    ensure_dir "$BACKUP_DIR/.config/bat"
    cp -r ~/.config/bat/* "$BACKUP_DIR/.config/bat/" 2>/dev/null || true
    log_success "Updated bat config"
fi

# EasyEffects
if [[ -d ~/.config/easyeffects ]]; then
    ensure_dir "$BACKUP_DIR/.config/easyeffects"
    cp -r ~/.config/easyeffects/* "$BACKUP_DIR/.config/easyeffects/" 2>/dev/null || true
    log_success "Updated easyeffects config"
fi

# =============================================================================
# VS Code
# =============================================================================
log_section "Updating VS Code configuration..."

VSCODE_USER_DIR="$HOME/.config/Code/User"

if [[ -d "$VSCODE_USER_DIR" ]]; then
    ensure_dir "$BACKUP_DIR/vscode"
    
    # settings.json
    if [[ -f "$VSCODE_USER_DIR/settings.json" ]]; then
        cp "$VSCODE_USER_DIR/settings.json" "$BACKUP_DIR/vscode/"
        log_success "Updated VS Code settings.json"
    fi
    
    # keybindings.json
    if [[ -f "$VSCODE_USER_DIR/keybindings.json" ]]; then
        cp "$VSCODE_USER_DIR/keybindings.json" "$BACKUP_DIR/vscode/"
        log_success "Updated VS Code keybindings.json"
    fi
    
    # snippets
    if [[ -d "$VSCODE_USER_DIR/snippets" ]]; then
        ensure_dir "$BACKUP_DIR/vscode/snippets"
        cp -r "$VSCODE_USER_DIR/snippets/"* "$BACKUP_DIR/vscode/snippets/" 2>/dev/null || true
        log_success "Updated VS Code snippets"
    fi
    
    # Generate extensions list
    # Note: Unset VSCODE_* vars to avoid crash when running from VS Code terminal
    if check_command code; then
        (
            unset VSCODE_ESM_ENTRYPOINT VSCODE_CODE_CACHE_PATH VSCODE_IPC_HOOK
            unset VSCODE_PID VSCODE_CWD VSCODE_CRASH_REPORTER_PROCESS_TYPE
            unset VSCODE_NLS_CONFIG VSCODE_HANDLES_UNCAUGHT_ERRORS VSCODE_L10N_BUNDLE_LOCATION
            code --list-extensions > "$BACKUP_DIR/vscode/extensions.txt"
        )
        log_success "Updated VS Code extensions.txt"
    fi
    
    # Kilo Code global storage
    KILO_CODE_STORAGE="$VSCODE_USER_DIR/globalStorage/kilocode.kilo-code"
    if [[ -d "$KILO_CODE_STORAGE" ]]; then
        ensure_dir "$BACKUP_DIR/vscode/globalStorage"
        rm -rf "$BACKUP_DIR/vscode/globalStorage/kilocode.kilo-code" 2>/dev/null || true
        cp -r "$KILO_CODE_STORAGE" "$BACKUP_DIR/vscode/globalStorage/"
        log_success "Updated Kilo Code global storage"
    fi
fi

# =============================================================================
# Godot
# =============================================================================
log_section "Updating Godot configuration..."

GODOT_CONFIG_DIR="$HOME/.config/godot"

if [[ -d "$GODOT_CONFIG_DIR" ]]; then
    ensure_dir "$BACKUP_DIR/godot"
    
    # Copy editor settings (find the most recent one)
    EDITOR_SETTINGS=$(find "$GODOT_CONFIG_DIR" -maxdepth 1 -name "editor_settings*.tres" -type f 2>/dev/null | head -1)
    if [[ -n "$EDITOR_SETTINGS" ]]; then
        cp "$EDITOR_SETTINGS" "$BACKUP_DIR/godot/"
        log_success "Updated Godot editor settings: $(basename "$EDITOR_SETTINGS")"
    fi
    
    # Copy other Godot config files
    for file in "$GODOT_CONFIG_DIR"/*.tres "$GODOT_CONFIG_DIR"/*.cfg; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/godot/" 2>/dev/null || true
        fi
    done
    
    # Copy recent_dirs if exists
    if [[ -f "$GODOT_CONFIG_DIR/recent_dirs" ]]; then
        cp "$GODOT_CONFIG_DIR/recent_dirs" "$BACKUP_DIR/godot/"
        log_success "Updated Godot recent_dirs"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
log_section "Asset Update Complete!"
echo ""
echo "Updated assets in: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Stage changes: git add ."
echo "  3. Commit: git commit -m 'chore: update assets from system'"
echo ""