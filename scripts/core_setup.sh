#!/bin/bash
# =============================================================================
# core_setup.sh - Core system setup: packages, shell, fonts, dotfiles
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root
verify_backup_dir

# =============================================================================
# System Update
# =============================================================================
log_section "Updating system..."
sudo dnf update -y
log_success "System updated"

# =============================================================================
# Install Core Packages
# =============================================================================
log_section "Installing core packages..."

CORE_PACKAGES=(
    zsh
    git
    curl
    wget
    util-linux-user
    fastfetch
    kitty
    podman
    podman-compose
    tmux
)

dnf_install "${CORE_PACKAGES[@]}"
log_success "Core packages installed"

# =============================================================================
# Install Starship
# =============================================================================
log_section "Installing Starship..."
if dnf_install starship 2>/dev/null; then
    log_success "Starship installed via dnf"
else
    log_warn "Starship not in repos, installing via official script..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    log_success "Starship installed via official script"
fi

# =============================================================================
# Install Atuin
# =============================================================================
log_section "Installing Atuin..."
if dnf_install atuin 2>/dev/null; then
    log_success "Atuin installed via dnf"
else
    log_warn "Atuin not in repos, installing via official script..."
    curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | bash
    log_success "Atuin installed via official script"
fi

# =============================================================================
# Install Zsh Plugins
# =============================================================================
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

# =============================================================================
# Restore Dotfiles
# =============================================================================
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

# =============================================================================
# Restore .config directories
# =============================================================================
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

# =============================================================================
# Install Fonts
# =============================================================================
log_section "Installing fonts..."
if [[ -d "$BACKUP_DIR/fonts" ]]; then
    ensure_dir ~/.local/share/fonts
    cp "$BACKUP_DIR/fonts/"*.ttf ~/.local/share/fonts/ 2>/dev/null || true
    fc-cache -fv
    log_success "Fonts installed and cache updated"
else
    log_warn "No fonts directory found in backup"
fi

# =============================================================================
# Change Default Shell to Zsh
# =============================================================================
log_section "Setting default shell to Zsh..."
ZSH_PATH="$(which zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    chsh -s "$ZSH_PATH"
    log_success "Default shell changed to zsh (takes effect on next login)"
else
    log_success "Zsh is already the default shell"
fi

log_section "Core setup complete!"