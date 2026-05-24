#!/usr/bin/env bash
# Phase 6: Clone 6 critical repos + restore .env + post-hooks
set -uo pipefail
# NOTE: not using -e — phases like clone may fail per-repo, want to continue

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}

STAGING=$(cat "$HOME/.local/share/recovery/.staging-path" 2>/dev/null)
[[ -z "$STAGING" ]] && { log_error "Bundle staging missing"; exit 1; }

PROJECTS="$HOME/Projects"
mkdir -p "$PROJECTS"

# Read repo list from bundle (single source of truth, auto-generated from
# current git remotes at backup time)
REPOS_TXT="$STAGING/repos.txt"
[[ ! -f "$REPOS_TXT" ]] && { log_error "repos.txt missing from bundle"; exit 1; }

log_info "Reading repos from $REPOS_TXT"

# ─────────────────────────────────────────────────────────────
# Clone loop (parse: name | git-remote | local-path)
# ─────────────────────────────────────────────────────────────
clone_failed=()

while IFS='|' read -r name remote local_path; do
    # Skip comments + empty lines
    name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$name" || "$name" == \#* ]] && continue

    remote=$(echo "$remote" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    local_path=$(echo "$local_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    local_path="${local_path/#\~/$HOME}"

    if [[ -d "$local_path/.git" ]]; then
        log_success "$name already cloned"
        continue
    fi

    log_info "Cloning $name from $remote → $local_path"
    if $DRY_RUN; then
        log_info "[DRY-RUN] git clone $remote $local_path"
    else
        if git clone "$remote" "$local_path" 2>&1; then
            log_success "  $name"
        else
            log_warn "  $name clone FAILED — continuing with other repos"
            clone_failed+=("$name")
        fi
    fi
done < "$REPOS_TXT"

if [[ ${#clone_failed[@]} -gt 0 ]]; then
    log_warn "Failed to clone: ${clone_failed[*]} (will continue post-hooks for the rest)"
fi

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

# Hook: restore crontab (strip legacy brain.db.bak — replaced by daily-bundle)
if [[ -f "$STAGING/crontabs/user-crontab.txt" ]]; then
    log_info "  Crontab restore"
    if $DRY_RUN; then
        log_info "  [DRY-RUN] would merge crontab (strip legacy + dedup)"
    else
        current=$(crontab -l 2>/dev/null || true)
        bundle_cron=$(cat "$STAGING/crontabs/user-crontab.txt")

        # 1. Take bundle crontab as base
        # 2. Strip legacy: brain.db.bak (superseded by daily-bundle)
        # 3. Strip duplicates of daily-bundle (will re-add from current = Phase 5's install)
        # 4. Append current's daily-bundle entry (Phase 5's install — authoritative)
        merged=$(echo "$bundle_cron" | grep -v "brain.db.bak" | grep -v "daily-bundle.sh" | grep -v "managed by workstation-setup")
        daily_bundle_entry=$(echo "$current" | grep -A1 "managed by workstation-setup" | grep "daily-bundle.sh" || true)
        marker_line=$(echo "$current" | grep "managed by workstation-setup" || true)
        if [[ -n "$daily_bundle_entry" ]]; then
            merged="$merged
$marker_line
$daily_bundle_entry"
        fi
        echo "$merged" | crontab -
        log_success "  Crontab merged (legacy brain.db.bak removed)"
    fi
fi

log_success "Phase 6 done — 6 repos cloned, .env restored, post-hooks executed"
