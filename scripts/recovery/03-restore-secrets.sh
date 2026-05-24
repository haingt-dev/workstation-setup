#!/usr/bin/env bash
# Phase 3: Restore SSH, GPG, gh CLI auth
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}

STAGING=$(cat "$HOME/.local/share/recovery/.staging-path" 2>/dev/null)
[[ -z "$STAGING" || ! -d "$STAGING" ]] && { log_error "Bundle staging missing — run Phase 2 first"; exit 1; }

SECRETS="$STAGING/secrets"
[[ -d "$SECRETS" ]] || { log_warn "No secrets/ in bundle — skipping"; exit 0; }

# ─────────────────────────────────────────────────────────────
# SSH keys
# ─────────────────────────────────────────────────────────────
if [[ -d "$SECRETS/ssh" ]]; then
    log_info "Restoring ~/.ssh/"
    if $DRY_RUN; then
        log_info "[DRY-RUN] would cp -r $SECRETS/ssh/* ~/.ssh/"
    else
        mkdir -p "$HOME/.ssh"
        /bin/cp -r "$SECRETS/ssh/." "$HOME/.ssh/"
        # Restore proper permissions (critical for SSH)
        chmod 700 "$HOME/.ssh"
        chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
        chmod 644 "$HOME/.ssh"/*.pub 2>/dev/null || true
        chmod 644 "$HOME/.ssh/known_hosts" 2>/dev/null || true
        chmod 644 "$HOME/.ssh/config" 2>/dev/null || true
        log_success "  $(ls $HOME/.ssh | wc -l) files restored, permissions fixed"
    fi
fi

# ─────────────────────────────────────────────────────────────
# GPG keys
# ─────────────────────────────────────────────────────────────
if [[ -d "$SECRETS/gnupg" ]]; then
    log_info "Restoring ~/.gnupg/"
    if $DRY_RUN; then
        log_info "[DRY-RUN] would cp -r $SECRETS/gnupg/* ~/.gnupg/"
    else
        mkdir -p "$HOME/.gnupg"
        /bin/cp -r "$SECRETS/gnupg/." "$HOME/.gnupg/"
        chmod 700 "$HOME/.gnupg"
        find "$HOME/.gnupg" -type f -exec chmod 600 {} \;
        find "$HOME/.gnupg" -type d -exec chmod 700 {} \;
        log_success "  GPG keys restored"
    fi
fi

# ─────────────────────────────────────────────────────────────
# gh CLI hosts (token)
# ─────────────────────────────────────────────────────────────
if [[ -f "$SECRETS/gh-hosts.yml" ]]; then
    log_info "Restoring gh CLI token"
    if $DRY_RUN; then
        log_info "[DRY-RUN] would write to ~/.config/gh/hosts.yml"
    else
        mkdir -p "$HOME/.config/gh"
        /bin/cp "$SECRETS/gh-hosts.yml" "$HOME/.config/gh/hosts.yml"
        chmod 600 "$HOME/.config/gh/hosts.yml"
        log_success "  gh token restored"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Verify
# ─────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
    log_info "Verification:"
    [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" ]] && log_success "  SSH key present"
    gpg --list-secret-keys 2>/dev/null | grep -q "sec" && log_success "  GPG secret key importable"
    gh auth status 2>&1 | grep -q "Logged in" && log_success "  gh auth OK"
fi
