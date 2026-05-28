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
# Note: User-authored configs are SYMLINKED from assets/ into $HOME — the repo is
# the source of truth and editing either side is the same file (zero drift).
# An existing real file is backed up to <path>.pre-symlink.<ts>.bak on first link.
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
    run_sudo dnf update -y
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
        gh
        gnupg2
        rclone
        cronie
        sqlite
    )
    dnf_install "${CORE_PACKAGES[@]}"
    log_success "Core packages installed"

    # 3. Install Starship
    log_section "Installing Starship..."
    if dnf_install starship 2>/dev/null; then
        log_success "Starship installed via dnf"
    else
        log_warn "Starship not in repos, installing via official script..."
        STARSHIP_SCRIPT=$(mktemp)
        curl -sS https://starship.rs/install.sh -o "$STARSHIP_SCRIPT"
        sh "$STARSHIP_SCRIPT" -y
        rm -f "$STARSHIP_SCRIPT"
        log_success "Starship installed via official script"
    fi

    # 4. Install Atuin
    log_section "Installing Atuin..."
    if dnf_install atuin 2>/dev/null; then
        log_success "Atuin installed via dnf"
    else
        log_warn "Atuin not in repos, installing via official script..."
        ATUIN_SCRIPT=$(mktemp)
        curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh -o "$ATUIN_SCRIPT"
        bash "$ATUIN_SCRIPT"
        rm -f "$ATUIN_SCRIPT"
        log_success "Atuin installed via official script"
    fi

    # 5. Install Node.js + Claude Code CLI
    log_section "Installing Claude Code CLI..."
    dnf_install nodejs
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
        log_success "Claude Code CLI installed"
    else
        log_warn "npm not found, skipping Claude Code CLI"
    fi

    # 6. Install Zsh Plugins
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

    # 6. Link dotfiles (repo = source of truth; $HOME files symlink into assets/)
    log_section "Linking dotfiles..."

    # .zshrc — assets/.zshrc already resolves the zsh-autocomplete path itself
    # (system path vs ~/.local fallback via if/elif), so no post-copy sed needed.
    link_file ".zshrc" ~/.zshrc

    # .bashrc
    link_file ".bashrc" ~/.bashrc

    # .gitconfig
    link_file ".gitconfig" ~/.gitconfig

    # 7. Link .config (repo = source of truth)
    log_section "Linking .config..."
    ensure_dir ~/.config

    # starship config
    link_file ".config/starship/starship.toml" ~/.config/starship/starship.toml
    link_file ".config/starship/starship-catppuccin.toml" ~/.config/starship/starship-catppuccin.toml

    # atuin config (config.toml only — install receipt is machine state, not versioned)
    link_file ".config/atuin/config.toml" ~/.config/atuin/config.toml

    # fastfetch config (whole dir — fastfetch never writes here; carries assets/jedi.png)
    link_dir ".config/fastfetch" ~/.config/fastfetch

    # fish config (only conf.d — fish writes its own state into ~/.config/fish/)
    link_dir ".config/fish/conf.d" ~/.config/fish/conf.d

    # kitty config (per-file — kitty never writes here; background.jpg is versioned)
    link_file ".config/kitty/kitty.conf"            ~/.config/kitty/kitty.conf
    link_file ".config/kitty/catppuccin-mocha.conf" ~/.config/kitty/catppuccin-mocha.conf
    link_file ".config/kitty/startup.conf"          ~/.config/kitty/startup.conf
    link_file ".config/kitty/background.jpg"        ~/.config/kitty/background.jpg

    # Configure GNOME Kitty shortcut (Ctrl+Space)
    configure_gnome_kitty_shortcut

    # tmux config
    link_file ".config/tmux/tmux.conf" ~/.config/tmux/tmux.conf

    # 8. Install Nerd Font (downloaded on-demand; not vendored in git)
    log_section "Installing CaskaydiaCove Nerd Font..."
    FONT_DIR="$HOME/.local/share/fonts"
    if compgen -G "$FONT_DIR/CaskaydiaCove*.ttf" > /dev/null; then
        log_success "CaskaydiaCove Nerd Font already installed; skipping download"
    else
        ensure_dir "$FONT_DIR"
        FONT_TMP="$(mktemp -d)"
        # GitHub 'latest' redirect — no version pin to go stale
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
        log_info "Downloading CascadiaCode Nerd Font (latest release)..."
        if curl -fSL "$FONT_URL" -o "$FONT_TMP/CascadiaCode.zip"; then
            unzip -qo "$FONT_TMP/CascadiaCode.zip" -d "$FONT_TMP/extract"
            find "$FONT_TMP/extract" -name 'CaskaydiaCove*.ttf' -exec cp -f {} "$FONT_DIR/" \;
            fc-cache -f "$FONT_DIR"
            log_success "CaskaydiaCove Nerd Font installed and cache rebuilt"
        else
            log_warn "Font download failed (network?). Terminal still works with a fallback font."
        fi
        rm -rf "$FONT_TMP"
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
        gh          # GitHub CLI (used by agent skills)
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
        if ! run_sudo dnf copr list | grep -q "atim/lazygit"; then
            log_info "Adding Lazygit COPR repository..."
            run_sudo dnf copr enable atim/lazygit -y
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
    restore_dir ".config/yazi" ~/.config/yazi

    # Copy bat config
    restore_dir ".config/bat" ~/.config/bat

    # 6. Post-installation Setup
    log_section "Post-installation setup..."

    # Install Catppuccin Mocha theme for bat and build cache
    if check_command bat; then
        log_info "Installing Catppuccin Mocha theme for bat..."
        ensure_dir ~/.config/bat/themes
        curl -fsSL -o ~/.config/bat/themes/Catppuccin-mocha.tmTheme \
            "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme"
        log_success "Catppuccin Mocha theme installed for bat"
        
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