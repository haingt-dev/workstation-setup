# =============================================================================
# Enhanced Zsh Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# Starship Prompt
# -----------------------------------------------------------------------------
eval "$(starship init zsh)"

# -----------------------------------------------------------------------------
# Zsh Plugins
# -----------------------------------------------------------------------------
# Try system-wide first, then fall back to local installation
if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [[ -f ~/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source ~/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ -f ~/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source ~/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [[ -f /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
    source /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
elif [[ -f ~/.local/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
    source ~/.local/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
fi

# -----------------------------------------------------------------------------
# Atuin (Shell History)
# -----------------------------------------------------------------------------
if [[ -f "$HOME/.atuin/bin/env" ]]; then
    . "$HOME/.atuin/bin/env"
    eval "$(atuin init zsh)"
fi

# -----------------------------------------------------------------------------
# Path Configuration
# -----------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# -----------------------------------------------------------------------------
# Zoxide (Smart cd)
# -----------------------------------------------------------------------------
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# -----------------------------------------------------------------------------
# FZF (Fuzzy Finder)
# -----------------------------------------------------------------------------
if command -v fzf &> /dev/null; then
    # FZF key bindings and completion
    if [[ -f /usr/share/fzf/shell/key-bindings.zsh ]]; then
        source /usr/share/fzf/shell/key-bindings.zsh
    fi
    
    # Catppuccin Mocha theme for FZF
    export FZF_DEFAULT_OPTS=" \
        --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
        --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
        --color=selected-bg:#45475a \
        --multi"
    
    # Use fd for file searching if available (faster than find)
    if command -v fd &> /dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi
fi

# -----------------------------------------------------------------------------
# Eza (Modern ls)
# -----------------------------------------------------------------------------
if command -v eza &> /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza --tree --icons --level=2'
    alias lta='eza --tree --icons --level=2 -a'
    alias l='eza -l --icons --group-directories-first'
else
    alias ll='ls -la'
    alias la='ls -a'
    alias l='ls -l'
fi

# -----------------------------------------------------------------------------
# Bat (Modern cat)
# -----------------------------------------------------------------------------
if command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
    alias catp='bat'  # with paging
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export BAT_THEME="Catppuccin-mocha"
fi

# -----------------------------------------------------------------------------
# Application Aliases
# -----------------------------------------------------------------------------
# Lazygit
if command -v lazygit &> /dev/null; then
    alias lg='lazygit'
fi

# Yazi file manager with directory change on exit
if command -v yazi &> /dev/null; then
    function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi

# -----------------------------------------------------------------------------
# Useful Aliases
# -----------------------------------------------------------------------------
# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Misc
alias cls='clear'
alias h='history'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# -----------------------------------------------------------------------------
# Custom Functions
# -----------------------------------------------------------------------------
# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.tar.xz)    tar xJf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick find
qf() {
    find . -name "*$1*" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Fastfetch (System Info on Terminal Start)
# -----------------------------------------------------------------------------
if command -v fastfetch &> /dev/null; then
    fastfetch -c ~/.config/fastfetch/sample_2.jsonc
fi

# -----------------------------------------------------------------------------
# Zsh Options
# -----------------------------------------------------------------------------
setopt AUTO_CD              # cd by typing directory name
setopt AUTO_PUSHD           # Push directories to stack
setopt PUSHD_IGNORE_DUPS    # Don't push duplicates
setopt CORRECT              # Spell correction for commands
setopt EXTENDED_GLOB        # Extended globbing
setopt NO_BEEP              # Disable beep

# History options
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY        # Share history between sessions
setopt HIST_IGNORE_DUPS     # Ignore duplicate commands
setopt HIST_IGNORE_SPACE    # Ignore commands starting with space
setopt HIST_REDUCE_BLANKS   # Remove extra blanks

# -----------------------------------------------------------------------------
# Completion Settings
# -----------------------------------------------------------------------------
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # Case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"    # Colored completion

# -----------------------------------------------------------------------------
# Key Bindings
# -----------------------------------------------------------------------------
bindkey -e                          # Emacs keybindings
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[H' beginning-of-line    # Home key
bindkey '^[[F' end-of-line          # End key
bindkey '^[[3~' delete-char         # Delete key