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
# gh CLI hosts.yml + oauth token (token via keyring or fallback)
# ─────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────
# Recovery self-files (bundle.pass, bundle.conf, rclone.conf)
# Without these, restored cron fires but fails — circular dependency broken
# ─────────────────────────────────────────────────────────────
if [[ -d "$SECRETS/recovery-self" ]]; then
    log_info "Restoring recovery self-files (cron will work post-restore)"
    if $DRY_RUN; then
        log_info "[DRY-RUN] would restore bundle.pass, bundle.conf, rclone.conf"
    else
        mkdir -p "$HOME/.config/recovery" "$HOME/.config/rclone"
        for f in "$SECRETS/recovery-self/"*; do
            [[ -f "$f" ]] || continue
            name=$(basename "$f")
            case "$name" in
                rclone.conf)
                    /bin/cp "$f" "$HOME/.config/rclone/rclone.conf"
                    chmod 600 "$HOME/.config/rclone/rclone.conf"
                    log_success "  rclone.conf (OneDrive token preserved)"
                    ;;
                bundle.pass|bundle.conf)
                    /bin/cp "$f" "$HOME/.config/recovery/$name"
                    chmod 600 "$HOME/.config/recovery/$name"
                    log_success "  recovery/$name"
                    ;;
            esac
        done
    fi
fi

if [[ -f "$SECRETS/gh-hosts.yml" ]]; then
    log_info "Restoring gh CLI config"
    if $DRY_RUN; then
        log_info "[DRY-RUN] would write to ~/.config/gh/hosts.yml + gh auth login --with-token"
    else
        mkdir -p "$HOME/.config/gh"
        /bin/cp "$SECRETS/gh-hosts.yml" "$HOME/.config/gh/hosts.yml"
        chmod 600 "$HOME/.config/gh/hosts.yml"
        log_success "  gh hosts.yml"

        # Re-auth using bundled token (writes to keyring or .config/gh/hosts.yml fallback)
        if [[ -f "$SECRETS/gh-token" ]]; then
            if gh auth login --with-token < "$SECRETS/gh-token" 2>/dev/null; then
                log_success "  gh oauth token restored (via gh auth login --with-token)"
            else
                # Fallback: write token directly to hosts.yml oauth_token field
                token=$(cat "$SECRETS/gh-token")
                python3 -c "
import yaml, sys
with open('$HOME/.config/gh/hosts.yml') as f: data = yaml.safe_load(f) or {}
data.setdefault('github.com', {})['oauth_token'] = '$token'
with open('$HOME/.config/gh/hosts.yml', 'w') as f: yaml.safe_dump(data, f)
" 2>/dev/null && log_success "  gh token written to hosts.yml (keyring fallback)" || log_warn "  gh token restore failed — login manually: gh auth login"
            fi
        else
            log_warn "  No bundled token — run: gh auth login"
        fi
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
