#!/bin/bash
# =============================================================================
# terminal_setup.sh - Full terminal setup
# =============================================================================
#
# Usage:
#   ./terminal_setup.sh    # Run full terminal setup
#
# This script performs complete terminal setup including:
#   - System packages (zsh, kitty, tmux, podman, etc.)
#   - Shell configuration (starship, atuin, zsh plugins)
#   - Power tools (zoxide, eza, bat, fzf, ripgrep, fd-find, lazygit, yazi)
#   - Dotfiles and configs (single enhanced profile)
#   - Fonts (CaskaydiaCove Nerd Font)
#   - Catppuccin themes for kitty, tmux, fzf
#
# Note: This script overwrites existing configs without backup.
# The repo (assets/) is the single source of truth.
#
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

# =============================================================================
# GNOME Kitty Shortcut Configuration
# =============================================================================

configure_gnome_kitty_shortcut() {
    # Skip if gsettings is not available
    if ! check_command gsettings; then
        log_info "gsettings not found; skipping GNOME shortcut configuration"
        return 0
    fi

    # Skip if kitty is not installed
    if ! check_command kitty; then
        log_info "kitty not installed yet; skipping GNOME shortcut configuration"
        return 0
    fi

    # Best-effort GNOME desktop check
    if [[ "${XDG_CURRENT_DESKTOP:-}" != *"GNOME"* ]] && [[ "${DESKTOP_SESSION:-}" != *"gnome"* ]]; then
        log_info "Non-GNOME desktop detected; skipping Kitty GNOME shortcut configuration"
        return 0
    fi

    local SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
    local KEY="custom-keybindings"
    local ENTRY="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-kitty/"

    # Read current keybinding list
    local current
    current=$(gsettings get "$SCHEMA" "$KEY" 2>/dev/null) || {
        log_warn "Failed to read GNOME custom keybindings; skipping"
        return 0
    }

    local new="$current"

    # Construct new list if entry not already present
    if [[ "$current" == "@as []" ]]; then
        new="['$ENTRY']"
    elif [[ "$current" != *"$ENTRY"* ]]; then
        # Append to existing list: remove trailing ']', add ', entry]'
        new="${current%]}, '$ENTRY']"
    fi

    # Update keybinding list if changed
    if [[ "$new" != "$current" ]]; then
        if ! gsettings set "$SCHEMA" "$KEY" "$new" 2>/dev/null; then
            log_warn "Failed to update GNOME custom keybindings list"
            return 0
        fi
    fi

    # Set the shortcut attributes
    if ! gsettings set "$SCHEMA.custom-keybinding:$ENTRY" name 'Kitty' 2>/dev/null; then
        log_warn "Failed to set Kitty shortcut name"
        return 0
    fi
    if ! gsettings set "$SCHEMA.custom-keybinding:$ENTRY" command 'kitty' 2>/dev/null; then
        log_warn "Failed to set Kitty shortcut command"
        return 0
    fi
    if ! gsettings set "$SCHEMA.custom-keybinding:$ENTRY" binding '<Primary>space' 2>/dev/null; then
        log_warn "Failed to set Kitty shortcut binding"
        return 0
    fi

    log_success "Configured GNOME custom shortcut for Kitty (Ctrl+Space)"
}

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

    # 6. Restore Dotfiles (overwrite without backup)
    log_section "Restoring dotfiles..."

    # .zshrc
    if [[ -f "$BACKUP_DIR/.zshrc" ]]; then
        cp -f "$BACKUP_DIR/.zshrc" ~/
        # Update zsh-autocomplete path if using local installation
        if [[ ! -f "$ZSH_AUTOCOMPLETE_SYSTEM" ]] && [[ -d "$ZSH_AUTOCOMPLETE_LOCAL" ]]; then
            sed -i "s|source /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh|source $ZSH_AUTOCOMPLETE_LOCAL/zsh-autocomplete.plugin.zsh|g" ~/.zshrc
            log_success ".zshrc installed (updated with local zsh-autocomplete path)"
        else
            log_success ".zshrc installed"
        fi
    fi

    # .bashrc
    if [[ -f "$BACKUP_DIR/.bashrc" ]]; then
        cp -f "$BACKUP_DIR/.bashrc" ~/
        log_success ".bashrc installed"
    fi

    # .gitconfig
    if [[ -f "$BACKUP_DIR/.gitconfig" ]]; then
        cp -f "$BACKUP_DIR/.gitconfig" ~/
        log_success ".gitconfig installed"
    fi

    # 7. Restore .config directories (overwrite without backup)
    log_section "Restoring .config directories..."
    ensure_dir ~/.config

    # starship config
    if [[ -f "$BACKUP_DIR/.config/starship/starship.toml" ]]; then
        ensure_dir ~/.config/starship
        cp -f "$BACKUP_DIR/.config/starship/starship.toml" ~/.config/starship/
        log_success "starship.toml installed"
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
        cp -f "$BACKUP_DIR/images/jedi.png" ~/.config/fastfetch/assets/
        log_success "fastfetch custom logo installed"
    fi

    # fish config (if present)
    if [[ -d "$BACKUP_DIR/.config/fish" ]]; then
        copy_dir "$BACKUP_DIR/.config/fish" ~/.config/fish
    fi

    # kitty config
    if [[ -d "$BACKUP_DIR/.config/kitty" ]]; then
        ensure_dir ~/.config/kitty
        # Copy only essential files (kitty.conf and theme)
        cp -f "$BACKUP_DIR/.config/kitty/kitty.conf" ~/.config/kitty/ 2>/dev/null || true
        cp -f "$BACKUP_DIR/.config/kitty/catppuccin-mocha.conf" ~/.config/kitty/ 2>/dev/null || true
        log_success "kitty config installed"
    fi

    # Configure GNOME Kitty shortcut (Ctrl+Space)
    configure_gnome_kitty_shortcut

    # tmux config
    if [[ -f "$BACKUP_DIR/.config/tmux/tmux.conf" ]]; then
        ensure_dir ~/.config/tmux
        cp -f "$BACKUP_DIR/.config/tmux/tmux.conf" ~/.config/tmux/
        log_success "tmux.conf installed"
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
# Power Tools Installation
# =============================================================================

install_power_tools() {
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
    for pkg in "${POWER_TOOLS[@]}"; do
        if dnf_install "$pkg"; then
            log_success "$pkg installed"
        else
            if [[ "$pkg" == "eza" ]]; then
                log_warn "eza not available in current repos; skipping. You can install it manually from https://github.com/eza-community/eza if desired."
            else
                log_warn "Failed to install $pkg from DNF; continuing without it"
            fi
        fi
    done
    log_success "Power tools installation step finished"

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

    # 5. Copy additional tool configs
    log_section "Installing tool configurations..."

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

    log_success "Power tools installation complete!"
}

# =============================================================================
# Execution
# =============================================================================

run_core_setup
install_power_tools

log_success "Terminal setup complete!"

echo ""
echo -e "${CYAN}${BOLD}Next Steps:${NC}"
echo "1. Log out and log back in (for shell change to take effect)"
echo "2. Install tmux plugins: Press Ctrl+a then I (capital i) inside tmux"
echo "3. Enjoy your new terminal environment!"
echo ""