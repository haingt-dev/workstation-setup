#!/bin/bash
# =============================================================================
# enhance_terminal.sh - Install power tools for enhanced terminal experience
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

# =============================================================================
# Install Power Tools via DNF
# =============================================================================
log_section "Installing Power Tools..."

# Tools available in Fedora repos
POWER_TOOLS=(
    zoxide      # Smart cd replacement
    eza         # Modern ls replacement
    bat         # Cat with syntax highlighting
    fzf         # Fuzzy finder
    ripgrep     # Fast grep alternative (useful with fzf)
    fd-find     # Fast find alternative (useful with fzf)
)

log_info "Installing tools from DNF repositories..."
dnf_install "${POWER_TOOLS[@]}"
log_success "DNF tools installed"

# =============================================================================
# Install Lazygit
# =============================================================================
log_section "Installing Lazygit..."

if check_command lazygit; then
    log_success "Lazygit already installed"
else
    # Add Lazygit COPR repository
    if ! sudo dnf copr list | grep -q "atim/lazygit"; then
        log_info "Adding Lazygit COPR repository..."
        sudo dnf copr enable atim/lazygit -y
    fi
    dnf_install lazygit
    log_success "Lazygit installed"
fi

# =============================================================================
# Install Yazi (Terminal File Manager)
# =============================================================================
log_section "Installing Yazi..."

if check_command yazi; then
    log_success "Yazi already installed"
else
    # Yazi is available via cargo or prebuilt binaries
    # Using prebuilt binary for faster installation
    YAZI_VERSION="0.4.2"
    YAZI_URL="https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip"
    TEMP_DIR=$(mktemp -d)
    
    log_info "Downloading Yazi v${YAZI_VERSION}..."
    curl -sL "$YAZI_URL" -o "$TEMP_DIR/yazi.zip"
    
    log_info "Extracting Yazi..."
    unzip -q "$TEMP_DIR/yazi.zip" -d "$TEMP_DIR"
    
    log_info "Installing Yazi to ~/.local/bin..."
    ensure_dir "$HOME/.local/bin"
    cp "$TEMP_DIR/yazi-x86_64-unknown-linux-gnu/yazi" "$HOME/.local/bin/"
    cp "$TEMP_DIR/yazi-x86_64-unknown-linux-gnu/ya" "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/yazi" "$HOME/.local/bin/ya"
    
    rm -rf "$TEMP_DIR"
    log_success "Yazi installed"
fi

# =============================================================================
# Install Tmux Plugin Manager (TPM)
# =============================================================================
log_section "Installing Tmux Plugin Manager..."

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR" ]]; then
    log_success "TPM already installed"
else
    log_info "Cloning TPM..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    log_success "TPM installed"
fi

# =============================================================================
# Copy Enhanced Configurations
# =============================================================================
log_section "Copying enhanced configurations..."

# Backup existing configs
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# Copy enhanced .zshrc
if [[ -f "$BACKUP_DIR/.zshrc.enhanced" ]]; then
    if [[ -f ~/.zshrc ]]; then
        cp ~/.zshrc ~/.zshrc.backup.$TIMESTAMP
        log_warn "Backed up existing .zshrc"
    fi
    cp "$BACKUP_DIR/.zshrc.enhanced" ~/.zshrc
    log_success "Enhanced .zshrc installed"
fi

# Copy enhanced tmux config
if [[ -f "$BACKUP_DIR/.config/tmux/tmux.conf.enhanced" ]]; then
    ensure_dir ~/.config/tmux
    if [[ -f ~/.config/tmux/tmux.conf ]]; then
        cp ~/.config/tmux/tmux.conf ~/.config/tmux/tmux.conf.backup.$TIMESTAMP
        log_warn "Backed up existing tmux.conf"
    fi
    cp "$BACKUP_DIR/.config/tmux/tmux.conf.enhanced" ~/.config/tmux/tmux.conf
    log_success "Enhanced tmux.conf installed"
fi

# Copy enhanced kitty config
ensure_dir ~/.config/kitty
if [[ -f "$BACKUP_DIR/.config/kitty/kitty.conf.enhanced" ]]; then
    if [[ -f ~/.config/kitty/kitty.conf ]]; then
        cp ~/.config/kitty/kitty.conf ~/.config/kitty/kitty.conf.backup.$TIMESTAMP
        log_warn "Backed up existing kitty.conf"
    fi
    cp "$BACKUP_DIR/.config/kitty/kitty.conf.enhanced" ~/.config/kitty/kitty.conf
    log_success "Enhanced kitty.conf installed"
fi

# Copy Catppuccin theme for kitty
if [[ -f "$BACKUP_DIR/.config/kitty/catppuccin-mocha.conf" ]]; then
    cp "$BACKUP_DIR/.config/kitty/catppuccin-mocha.conf" ~/.config/kitty/
    log_success "Catppuccin Mocha theme for kitty installed"
fi

# Copy Catppuccin starship config (optional - user can choose)
if [[ -f "$BACKUP_DIR/.config/starship/starship-catppuccin.toml" ]]; then
    ensure_dir ~/.config/starship
    # Keep both themes available
    cp "$BACKUP_DIR/.config/starship/starship-catppuccin.toml" ~/.config/starship/
    log_success "Catppuccin Starship theme available at ~/.config/starship/starship-catppuccin.toml"
    log_info "To use Catppuccin theme for Starship, run:"
    log_info "  cp ~/.config/starship/starship-catppuccin.toml ~/.config/starship.toml"
fi

# Copy yazi config if exists
if [[ -d "$BACKUP_DIR/.config/yazi" ]]; then
    copy_dir "$BACKUP_DIR/.config/yazi" ~/.config/yazi
fi

# Copy bat config if exists
if [[ -d "$BACKUP_DIR/.config/bat" ]]; then
    copy_dir "$BACKUP_DIR/.config/bat" ~/.config/bat
fi

# =============================================================================
# Post-installation Setup
# =============================================================================
log_section "Post-installation setup..."

# Build bat cache for themes
if check_command bat; then
    log_info "Building bat theme cache..."
    bat cache --build 2>/dev/null || true
    log_success "Bat cache built"
fi

# Initialize zoxide database
if check_command zoxide; then
    log_info "Zoxide will initialize on first use"
fi

# =============================================================================
# Instructions
# =============================================================================
log_section "Enhancement complete!"

echo ""
echo -e "${CYAN}${BOLD}Next steps:${NC}"
echo ""
echo "1. Restart your terminal or run: source ~/.zshrc"
echo ""
echo "2. Install tmux plugins by pressing: Ctrl+a then I (capital i)"
echo "   (This will install Catppuccin theme and session plugins)"
echo ""
echo "3. New aliases available:"
echo "   - ls  → eza (with icons and colors)"
echo "   - ll  → eza -la (detailed list)"
echo "   - lt  → eza --tree (tree view)"
echo "   - cat → bat (syntax highlighting)"
echo "   - cd  → z (smart directory jumping)"
echo "   - lg  → lazygit"
echo "   - y   → yazi (file manager)"
echo ""
echo "4. FZF keybindings:"
echo "   - Ctrl+R → Search command history"
echo "   - Ctrl+T → Search files"
echo "   - Alt+C  → cd to directory"
echo ""