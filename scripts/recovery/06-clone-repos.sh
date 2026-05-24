#!/usr/bin/env bash
# Phase 6: Clone 6 critical repos + restore .env + post-hooks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}

STAGING=$(cat "$HOME/.local/share/recovery/.staging-path" 2>/dev/null)
[[ -z "$STAGING" ]] && { log_error "Bundle staging missing"; exit 1; }

PROJECTS="$HOME/Projects"
mkdir -p "$PROJECTS"

# Repos to clone (skip if already exists)
declare -A REPOS=(
    ["agent"]="haingt-dev/agent"
    ["digital-identity"]="haingt-dev/digital-identity"
    ["home-server"]="haingt-dev/home-server"
    ["Idea_Vault"]="haingt-dev/my-obsidian-vault"
    ["IronCradle"]="haingt-dev/IronCradle"
    ["workstation-setup"]="haingt-dev/workstation-setup"
)

# ─────────────────────────────────────────────────────────────
# Clone loop
# ─────────────────────────────────────────────────────────────
for name in "${!REPOS[@]}"; do
    target="$PROJECTS/$name"

    if [[ -d "$target/.git" ]]; then
        log_success "$name already cloned"
        continue
    fi

    remote="${REPOS[$name]}"
    log_info "Cloning $name from $remote"
    if $DRY_RUN; then
        log_info "[DRY-RUN] gh repo clone $remote $target"
    else
        gh repo clone "$remote" "$target"
        log_success "  $name"
    fi
done

# ─────────────────────────────────────────────────────────────
# Restore per-repo .env from bundle
# ─────────────────────────────────────────────────────────────
log_info ""
log_info "Restoring .env files"

for envfile in "$STAGING/envs/"*; do
    [[ -f "$envfile" ]] || continue
    flat=$(basename "$envfile")

    # Decode: repo--path-to-env → repo + relative path
    repo="${flat%%--*}"
    rest="${flat#*--}"
    rel=$(echo "$rest" | tr '-' '/' | sed 's|//|.|')

    # Special case: top-level .env stored as "repo--.env"
    [[ "$rest" == ".env" ]] && rel=".env"

    target="$PROJECTS/$repo/$rel"

    if [[ ! -d "$PROJECTS/$repo" ]]; then
        log_warn "  $repo not cloned, skip .env"
        continue
    fi

    if $DRY_RUN; then
        log_info "[DRY-RUN] $envfile → $target"
    else
        mkdir -p "$(dirname "$target")"
        /bin/cp "$envfile" "$target"
        chmod 600 "$target"
        log_success "  $repo/$rel"
    fi
done

# ─────────────────────────────────────────────────────────────
# Post-hooks
# ─────────────────────────────────────────────────────────────
log_info ""
log_info "Running post-hooks"

# Hook: declarative symlinks
if [[ -x "$SCRIPT_DIR/restore_symlinks.sh" ]]; then
    log_info "  Restoring cross-project symlinks"
    $DRY_RUN && log_info "  [DRY-RUN]" || "$SCRIPT_DIR/restore_symlinks.sh" || log_warn "    symlinks failed"
fi

# Hook: home-server full restore
HS="$PROJECTS/home-server"
HS_BUNDLE="$STAGING/home-server"
if [[ -d "$HS" && -d "$HS_BUNDLE" ]]; then
    log_info "  Home-server tier restore"
    for tier in tier1-secrets tier2-state tier3-outputs; do
        ar="$HS_BUNDLE/${tier}.tar.gz"
        if [[ -f "$ar" ]]; then
            if $DRY_RUN; then
                log_info "  [DRY-RUN] tar xzf $ar -C $HS"
            else
                tar xzf "$ar" -C "$HS"
                log_success "    $tier"
            fi
        fi
    done
fi

# Hook: IronCradle dev env
IC="$PROJECTS/IronCradle"
IC_BUNDLE="$STAGING/ironcradle"
if [[ -d "$IC" && -d "$IC_BUNDLE" ]]; then
    log_info "  IronCradle dev env"

    # Godot version
    if [[ -f "$IC_BUNDLE/godot-version.txt" && -x "$SCRIPT_DIR/godot_setup.sh" ]]; then
        log_info "    Installing Godot via project pin"
        $DRY_RUN || "$SCRIPT_DIR/godot_setup.sh" --from-project "$IC" || log_warn "    Godot install failed (manual install needed)"
    fi

    # Godot user config
    if [[ -f "$IC_BUNDLE/godot-user-config.tar.gz" ]]; then
        if $DRY_RUN; then
            log_info "    [DRY-RUN] extract godot-user-config.tar.gz"
        else
            mkdir -p "$HOME/.config"
            tar xzf "$IC_BUNDLE/godot-user-config.tar.gz" -C "$HOME/.config"
            log_success "    Godot user config"
        fi
    fi

    # VS Code User
    if [[ -f "$IC_BUNDLE/vscode-user.tar.gz" ]]; then
        if $DRY_RUN; then
            log_info "    [DRY-RUN] extract vscode-user.tar.gz"
        else
            mkdir -p "$HOME/.config/Code"
            tar xzf "$IC_BUNDLE/vscode-user.tar.gz" -C "$HOME/.config/Code"
            log_success "    VS Code User"
        fi
    fi

    # VS Code extensions
    if [[ -f "$IC_BUNDLE/vscode-extensions.txt" ]] && command -v code >/dev/null; then
        log_info "    Installing VS Code extensions"
        if $DRY_RUN; then
            log_info "    [DRY-RUN] $(wc -l < $IC_BUNDLE/vscode-extensions.txt) extensions"
        else
            while IFS= read -r ext; do
                [[ -z "$ext" || "$ext" == \#* ]] && continue
                code --install-extension "$ext" --force >/dev/null 2>&1 && log_success "      $ext" || log_warn "      Failed: $ext"
            done < "$IC_BUNDLE/vscode-extensions.txt"
        fi
    fi
fi

# Hook: restore crontab
if [[ -f "$STAGING/crontabs/user-crontab.txt" ]]; then
    log_info "  Crontab restore"
    if $DRY_RUN; then
        log_info "  [DRY-RUN] would import crontab"
    else
        # Merge with existing — don't overwrite daily-bundle cron from Phase 5
        current=$(crontab -l 2>/dev/null || true)
        bundle_cron=$(cat "$STAGING/crontabs/user-crontab.txt")
        # Strip daily-bundle entries from current (already installed in Phase 5)
        # and from bundle (avoid duplication)
        merged=$(echo -e "$current\n$bundle_cron" | grep -v "daily-bundle.sh" | grep -v "managed by workstation-setup" | sort -u)
        # Re-add Phase 5's daily-bundle
        merged="$merged
$(echo "$current" | grep "daily-bundle.sh" || true)"
        echo "$merged" | crontab -
        log_success "  Crontab merged"
    fi
fi

log_success "Phase 6 done — 6 repos cloned, .env restored, post-hooks executed"
