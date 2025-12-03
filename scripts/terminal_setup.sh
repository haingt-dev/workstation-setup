#!/bin/bash
# =============================================================================
# terminal_setup.sh - Combined terminal setup (Core + Enhancements)
# =============================================================================
#
# Usage:
#   ./terminal_setup.sh --core          # Run core setup
#   ./terminal_setup.sh --enhance       # Run enhancement setup
#   ./terminal_setup.sh --core --enhance # Run both
#
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

# =============================================================================
# Argument Parsing
# =============================================================================

DO_CORE=false
DO_ENHANCE=false

# If no arguments provided, assume core setup only (safe default)
if [[ $# -eq 0 ]]; then
    DO_CORE=true
fi

for arg in "$@"; do
    case $arg in
        --core)
            DO_CORE=true
            ;;
        --enhance)
            DO_ENHANCE=true
            ;;
        *)
            log_error "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# =============================================================================
# Core Setup Logic
# =============================================================================

run_core_setup() {
    log_section "Starting Core Terminal Setup..."

    # 1. System Update
    log_section "Updating system..."
    sudo dnf update -y
    log_success "System updated"

    # 2. Install Core Packages
    log_section "Installing core packages..."
    CORE_PACKAGES=(
        zsh
        git
        curl
        wget
        unzip
        util-linux-user
        fastfetch
        kitty
        podman
        podman-compose
        tmux
    )
    dnf_install "${CORE_PACKAGES[@]}"
    log_success "Core packages installed"

    # 3. Install Starship
    log_section "Installing Starship..."
    if dnf_install starship 2>/dev/null; then
        log_success "Starship installed via dnf"
    else
        log_warn "Starship not in repos, installing via official script..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
        log_success "Starship installed via official script"
    fi

    # 4. Install Atuin
    log_section "Installing Atuin..."
    if dnf_install atuin 2>/dev/null; then
        log_success "Atuin installed via dnf"
    else
        log_warn "Atuin not in repos, installing via official script..."
        curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | bash
        log_success "Atuin installed via official script"
    fi

    # 5. Install Zsh Plugins
    log_section "Installing Zsh plugins..."
    dnf_install zsh-autosuggestions zsh-syntax-highlighting
    log_success "zsh-autosuggestions and zsh-syntax-highlighting installed"

    # zsh-autocomplete
    ZSH_AUTOCOMPLETE_SYSTEM="/usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
    ZSH_AUTOCOMPLETE_LOCAL="$HOME/.local/share/zsh/plugins/zsh-autocomplete"

    if dnf_install zsh-autocomplete 2>/dev/null && [[ -f "$ZSH_AUTOCOMPLETE_SYSTEM" ]]; then
        log_success "zsh-autocomplete installed via dnf"
    else
        log_warn "zsh-autocomplete not in repos, cloning from GitHub..."
        ensure_dir "$HOME/.local/share/zsh/plugins"
        rm -rf "$ZSH_AUTOCOMPLETE_LOCAL" 2>/dev/null || true
        git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git "$ZSH_AUTOCOMPLETE_LOCAL"
        log_success "zsh-autocomplete cloned to $ZSH_AUTOCOMPLETE_LOCAL"
    fi

    # 6. Restore Dotfiles
    log_section "Restoring dotfiles..."

    # .zshrc
    if [[ -f "$BACKUP_DIR/.zshrc" ]]; then
        cp "$BACKUP_DIR/.zshrc" ~/
        # Update zsh-autocomplete path if using local installation
        if [[ ! -f "$ZSH_AUTOCOMPLETE_SYSTEM" ]] && [[ -d "$ZSH_AUTOCOMPLETE_LOCAL" ]]; then
            sed -i "s|source /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh|source $ZSH_AUTOCOMPLETE_LOCAL/zsh-autocomplete.plugin.zsh|g" ~/.zshrc
            log_success ".zshrc copied and updated with local zsh-autocomplete path"
        else
            log_success ".zshrc copied"
        fi
    fi

    # .bashrc
    if [[ -f "$BACKUP_DIR/.bashrc" ]]; then
        cp "$BACKUP_DIR/.bashrc" ~/
        log_success ".bashrc copied"
    fi

    # .gitconfig
    if [[ -f "$BACKUP_DIR/.gitconfig" ]]; then
        if [[ -f ~/.gitconfig ]]; then
            cp ~/.gitconfig ~/.gitconfig.backup
            log_warn "Existing .gitconfig backed up"
        fi
        cp "$BACKUP_DIR/.gitconfig" ~/
        log_success ".gitconfig copied"
    fi

    # 7. Restore .config directories
    log_section "Restoring .config directories..."
    ensure_dir ~/.config

    # starship.toml
    if [[ -f "$BACKUP_DIR/.config/starship/starship.toml" ]]; then
        ensure_dir ~/.config/starship
        cp "$BACKUP_DIR/.config/starship/starship.toml" ~/.config/starship/
        log_success "starship.toml copied"
    elif [[ -f "$BACKUP_DIR/.config/starship.toml" ]]; then
        cp "$BACKUP_DIR/.config/starship.toml" ~/.config/
        log_success "starship.toml copied"
    fi

    # atuin config
    if [[ -d "$BACKUP_DIR/.config/atuin" ]]; then
        copy_dir "$BACKUP_DIR/.config/atuin" ~/.config/atuin
    fi

    # fastfetch config
    if [[ -d "$BACKUP_DIR/.config/fastfetch" ]]; then
        copy_dir "$BACKUP_DIR/.config/fastfetch" ~/.config/fastfetch
    fi

    # fastfetch custom logo
    if [[ -f "$BACKUP_DIR/images/jedi.png" ]]; then
        ensure_dir ~/.config/fastfetch/assets
        cp "$BACKUP_DIR/images/jedi.png" ~/.config/fastfetch/assets/
        log_success "fastfetch custom logo (jedi.png) copied"
    fi

    # fish config
    if [[ -d "$BACKUP_DIR/.config/fish" ]]; then
        copy_dir "$BACKUP_DIR/.config/fish" ~/.config/fish
    fi

    # kitty config
    if [[ -d "$BACKUP_DIR/.config/kitty" ]]; then
        copy_dir "$BACKUP_DIR/.config/kitty" ~/.config/kitty
    fi

    # tmux config
    if [[ -d "$BACKUP_DIR/.config/tmux" ]]; then
        copy_dir "$BACKUP_DIR/.config/tmux" ~/.config/tmux
    elif [[ -f "$BACKUP_DIR/.tmux.conf" ]]; then
        ensure_dir ~/.config/tmux
        cp "$BACKUP_DIR/.tmux.conf" ~/.config/tmux/tmux.conf
        log_success "tmux.conf copied to ~/.config/tmux/"
    fi

    # 8. Install Fonts
    log_section "Installing fonts..."
    if [[ -d "$BACKUP_DIR/fonts" ]]; then
        ensure_dir ~/.local/share/fonts
        cp "$BACKUP_DIR/fonts/"*.ttf ~/.local/share/fonts/ 2>/dev/null || true
        fc-cache -fv
        log_success "Fonts installed and cache updated"
    else
        log_warn "No fonts directory found in backup"
    fi

    # 9. Change Default Shell to Zsh
    log_section "Setting default shell to Zsh..."
    ZSH_PATH="$(which zsh)"
    if [[ "$SHELL" != "$ZSH_PATH" ]]; then
        chsh -s "$ZSH_PATH"
        log_success "Default shell changed to zsh (takes effect on next login)"
    else
        log_success "Zsh is already the default shell"
    fi

    log_success "Core setup complete!"
}

# =============================================================================
# Enhancement Logic
# =============================================================================

run_enhancement() {
    log_section "Starting Terminal Enhancement..."

    # 1. Install Power Tools via DNF
    log_section "Installing Power Tools..."
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

    # 2. Install Lazygit
    log_section "Installing Lazygit..."
    if check_command lazygit; then
        log_success "Lazygit already installed"
    else
        if ! sudo dnf copr list | grep -q "atim/lazygit"; then
            log_info "Adding Lazygit COPR repository..."
            sudo dnf copr enable atim/lazygit -y
        fi
        dnf_install lazygit
        log_success "Lazygit installed"
    fi

    # 3. Install Yazi
    log_section "Installing Yazi..."
    if check_command yazi; then
        log_success "Yazi already installed"
    else
        if ! check_command unzip; then dnf_install unzip; fi
        if ! check_command curl; then dnf_install curl; fi
        if ! check_command git; then dnf_install git; fi

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

    # 4. Install Tmux Plugin Manager (TPM)
    log_section "Installing Tmux Plugin Manager..."
    TPM_DIR="$HOME/.tmux/plugins/tpm"
    if [[ -d "$TPM_DIR" ]]; then
        log_success "TPM already installed"
    else
        log_info "Cloning TPM..."
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        log_success "TPM installed"
    fi

    # 5. Copy Enhanced Configurations
    log_section "Copying enhanced configurations..."
    TIMESTAMP=$(date +%Y%m%d%H%M%S)

    # Enhanced .zshrc
    if [[ -f "$BACKUP_DIR/.zshrc.enhanced" ]]; then
        if [[ -f ~/.zshrc ]]; then
            cp ~/.zshrc ~/.zshrc.backup.$TIMESTAMP
            log_warn "Backed up existing .zshrc"
        fi
        cp "$BACKUP_DIR/.zshrc.enhanced" ~/.zshrc
        log_success "Enhanced .zshrc installed"
    fi

    # Enhanced tmux config
    if [[ -f "$BACKUP_DIR/.config/tmux/tmux.conf.enhanced" ]]; then
        ensure_dir ~/.config/tmux
        if [[ -f ~/.config/tmux/tmux.conf ]]; then
            cp ~/.config/tmux/tmux.conf ~/.config/tmux/tmux.conf.backup.$TIMESTAMP
            log_warn "Backed up existing tmux.conf"
        fi
        cp "$BACKUP_DIR/.config/tmux/tmux.conf.enhanced" ~/.config/tmux/tmux.conf
        log_success "Enhanced tmux.conf installed"
    fi

    # Enhanced kitty config
    ensure_dir ~/.config/kitty
    if [[ -f "$BACKUP_DIR/.config/kitty/kitty.conf.enhanced" ]]; then
        if [[ -f ~/.config/kitty/kitty.conf ]]; then
            cp ~/.config/kitty/kitty.conf ~/.config/kitty/kitty.conf.backup.$TIMESTAMP
            log_warn "Backed up existing kitty.conf"
        fi
        cp "$BACKUP_DIR/.config/kitty/kitty.conf.enhanced" ~/.config/kitty/kitty.conf
        log_success "Enhanced kitty.conf installed"
    fi

    # Catppuccin theme for kitty
    if [[ -f "$BACKUP_DIR/.config/kitty/catppuccin-mocha.conf" ]]; then
        cp "$BACKUP_DIR/.config/kitty/catppuccin-mocha.conf" ~/.config/kitty/
        log_success "Catppuccin Mocha theme for kitty installed"
    fi

    # Catppuccin starship config
    if [[ -f "$BACKUP_DIR/.config/starship/starship-catppuccin.toml" ]]; then
        ensure_dir ~/.config/starship
        cp "$BACKUP_DIR/.config/starship/starship-catppuccin.toml" ~/.config/starship/
        log_success "Catppuccin Starship theme available at ~/.config/starship/starship-catppuccin.toml"
    fi

    # Copy yazi config
    if [[ -d "$BACKUP_DIR/.config/yazi" ]]; then
        copy_dir "$BACKUP_DIR/.config/yazi" ~/.config/yazi
    fi

    # Copy bat config
    if [[ -d "$BACKUP_DIR/.config/bat" ]]; then
        copy_dir "$BACKUP_DIR/.config/bat" ~/.config/bat
    fi

    # 6. Post-installation Setup
    log_section "Post-installation setup..."

    # Build bat cache
    if check_command bat; then
        log_info "Building bat theme cache..."
        bat cache --build 2>/dev/null || true
        log_success "Bat cache built"
    fi

    # Initialize zoxide
    if check_command zoxide; then
        log_info "Zoxide will initialize on first use"
    fi

    log_success "Enhancement complete!"
    
    echo ""
    echo -e "${CYAN}${BOLD}Enhancement Next Steps:${NC}"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Install tmux plugins: Press Ctrl+a then I (capital i)"
    echo "3. Enjoy your new power tools (eza, bat, zoxide, lazygit, yazi)!"
    echo ""
}

# =============================================================================
# Execution
# =============================================================================

if $DO_CORE; then
    run_core_setup
fi

if $DO_ENHANCE; then
    run_enhancement
fi