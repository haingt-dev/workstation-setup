#!/usr/bin/env bash
# =============================================================================
# daily-bundle.sh - Single consolidated backup daemon
# =============================================================================
#
# Bundles ALL critical non-git state into ONE encrypted tarball pushed to
# OneDrive + optional B2 fallback.
#
# Includes:
#   - brain.db (replaces standalone brain.db.bak cron)
#   - home-server tier1/2/3 (configs, DBs, optional outputs)
#   - ~/.claude/ state (CLAUDE.md, plans, projects, plugins/cache, config)
#   - secrets (~/.ssh, ~/.gnupg, gh token)
#   - .env files from 6 critical repos
#   - IronCradle dev state (Godot config, VS Code User, extensions list)
#   - crontab snapshot
#
# Usage:
#   ./daily-bundle.sh             # Full bundle (use TIER3_FREQUENCY logic)
#   ./daily-bundle.sh --tier3     # Force tier3 inclusion
#   ./daily-bundle.sh --dry-run   # Build bundle locally, no push
#   ./daily-bundle.sh --no-push   # Build + GPG, skip cloud push
#
# Config: ~/.config/recovery/bundle.conf
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Load config
# ─────────────────────────────────────────────────────────────
CONFIG_FILE="${BUNDLE_CONF:-$HOME/.config/recovery/bundle.conf}"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[err] Config missing: $CONFIG_FILE"
    echo "      Copy template: cp scripts/backup/bundle.conf.example $CONFIG_FILE"
    exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log()     { echo -e "[$(date +%H:%M:%S)] $*"; }
err()     { echo -e "[$(date +%H:%M:%S)] [ERR] $*" >&2; }
success() { echo -e "[$(date +%H:%M:%S)] [OK]  $*"; }

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
INCLUDE_TIER3=false
DRY_RUN=false
NO_PUSH=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier3) INCLUDE_TIER3=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --no-push) NO_PUSH=true; shift ;;
        *) shift ;;
    esac
done

# Default tier3 logic by frequency
if ! $INCLUDE_TIER3; then
    case "${TIER3_FREQUENCY:-skip}" in
        daily) INCLUDE_TIER3=true ;;
        weekly) [[ "$(date +%u)" == "7" ]] && INCLUDE_TIER3=true ;;  # Sunday
        skip|*) ;;
    esac
fi

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
log "Daily recovery bundle — $(date)"
log "Config: $CONFIG_FILE"
log "Tier3 (Forge outputs): $INCLUDE_TIER3"
$DRY_RUN && log "Mode: DRY-RUN"
$NO_PUSH && log "Mode: NO-PUSH"

for cmd in tar gpg rclone; do
    command -v "$cmd" >/dev/null || { err "Missing: $cmd"; exit 1; }
done

[[ -f "$BUNDLE_PASS_FILE" ]] || { err "Passphrase missing: $BUNDLE_PASS_FILE"; exit 1; }
[[ "$(stat -c %a "$BUNDLE_PASS_FILE")" == "600" ]] || {
    err "Passphrase file mode != 600: $BUNDLE_PASS_FILE"
    exit 1
}

# ─────────────────────────────────────────────────────────────
# Work dir
# ─────────────────────────────────────────────────────────────
DATE=$(date +%Y-%m-%d)
WORK=$(mktemp -d -t recovery-bundle.XXXXXX)
trap '/bin/rm -rf "$WORK"' EXIT

STAGE="$WORK/recovery-bundle"
mkdir -p "$STAGE"/{secrets,claude,envs,home-server,ironcradle,brain,crontabs}

# ─────────────────────────────────────────────────────────────
# Section 1: Secrets
# ─────────────────────────────────────────────────────────────
log ""
log "=== Section 1: Secrets ==="

if [[ -d "$HOME/.ssh" ]]; then
    /bin/cp -r "$HOME/.ssh" "$STAGE/secrets/ssh"
    success "  ~/.ssh ($(ls $HOME/.ssh | wc -l) files)"
fi

if [[ -d "$HOME/.gnupg" ]]; then
    /bin/cp -r "$HOME/.gnupg" "$STAGE/secrets/gnupg"
    # Don't ship runtime lock/socket files — they carry the source host's pid/name
    # and make keyboxd/gpg-agent hang on restore (keys appear missing until removed).
    find "$STAGE/secrets/gnupg" \( -name '*.lock' -o -name '.#lk*' \
        -o -name 'S.gpg-agent*' -o -name 'S.keyboxd' -o -name 'S.scdaemon' \) \
        -delete 2>/dev/null || true
    success "  ~/.gnupg (runtime lock/socket files excluded)"
fi

if [[ -f "$HOME/.config/gh/hosts.yml" ]]; then
    /bin/cp "$HOME/.config/gh/hosts.yml" "$STAGE/secrets/gh-hosts.yml"
    success "  gh CLI hosts (config only — token in keyring)"
fi

# Recovery system self-files (bundle.pass + bundle.conf + rclone.conf)
# CRITICAL: without these, restored cron will fire but daily-bundle fails
mkdir -p "$STAGE/secrets/recovery-self"
for f in "$HOME/.config/recovery/bundle.pass" \
         "$HOME/.config/recovery/bundle.conf" \
         "$HOME/.config/rclone/rclone.conf"; do
    if [[ -f "$f" ]]; then
        /bin/cp "$f" "$STAGE/secrets/recovery-self/$(basename "$f")"
        success "  recovery-self/$(basename "$f")"
    fi
done

# onedriver OAuth refresh tokens (per-mount; without these, recovery requires
# re-OAuth which needs interactive browser + WEBKIT_DISABLE_DMABUF_RENDERER
# workaround on Wayland). Only the tokens — skip file-content cache (large + rebuildable).
if [[ -d "$HOME/.cache/onedriver" ]]; then
    mkdir -p "$STAGE/secrets/onedriver-cache"
    found=0
    for tok in "$HOME/.cache/onedriver"/*/auth_tokens.json; do
        [[ -f "$tok" ]] || continue
        mount_id=$(basename "$(dirname "$tok")")
        mkdir -p "$STAGE/secrets/onedriver-cache/$mount_id"
        /bin/cp "$tok" "$STAGE/secrets/onedriver-cache/$mount_id/auth_tokens.json"
        found=$((found+1))
    done
    [[ $found -gt 0 ]] && success "  onedriver-cache/ ($found auth_tokens.json files)"
fi

# onedriver launcher config (optional — only present if user customized via GUI)
if [[ -d "$HOME/.config/onedriver" ]]; then
    /bin/cp -r "$HOME/.config/onedriver" "$STAGE/secrets/onedriver-config"
    success "  onedriver-config/"
fi

# Extract gh oauth token from keyring → plain file (restored via `gh auth login --with-token`)
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    gh auth token > "$STAGE/secrets/gh-token" 2>/dev/null && {
        chmod 600 "$STAGE/secrets/gh-token"
        success "  gh oauth token (from keyring)"
    }
fi

# ─────────────────────────────────────────────────────────────
# Section 2: ~/.claude/ state
# ─────────────────────────────────────────────────────────────
log ""
log "=== Section 2: Claude state ==="

CLAUDE_DIR="$HOME/.claude"
CLAUDE_DST="$STAGE/claude"

for item in CLAUDE.md core-memory.md brains settings.json config.json keybindings.json statusline-command.sh skills plans agents hooks; do
    src="$CLAUDE_DIR/$item"
    if [[ -e "$src" ]]; then
        # -L: dereference symlinks so content survives even if symlink target
        # (e.g., agent/global/CLAUDE.md) isn't restored yet
        /bin/cp -rL "$src" "$CLAUDE_DST/"
        if [[ -L "$src" ]]; then
            success "  $item (dereferenced symlink → $(readlink "$src"))"
        else
            success "  $item"
        fi
    fi
done

# Global MCP config (~/.claude.json — separate from ~/.claude/ dir)
# Contains mcpServers (haingt-brain, todoist, etc) + plugin marketplace state
# Without this: post-restore Claude Code has no MCP servers configured
if [[ -f "$HOME/.claude.json" ]]; then
    /bin/cp "$HOME/.claude.json" "$CLAUDE_DST/dot-claude.json"
    success "  ~/.claude.json (global MCP + plugin marketplace state)"
fi

# projects/ = conversation history + memory (832MB, compresses ~150-200MB)
if [[ -d "$CLAUDE_DIR/projects" ]]; then
    log "  projects/ — compressing 832MB conversation history..."
    tar czf "$CLAUDE_DST/projects.tar.gz" -C "$CLAUDE_DIR" projects 2>/dev/null
    sz=$(du -h "$CLAUDE_DST/projects.tar.gz" | cut -f1)
    success "  projects.tar.gz ($sz)"
fi

# plugins/cache + installed_plugins.json (R6 — version pin + no internet on restore)
if [[ -d "$CLAUDE_DIR/plugins" ]]; then
    log "  plugins/ — including cache for version pin..."
    tar czf "$CLAUDE_DST/plugins.tar.gz" -C "$CLAUDE_DIR" \
        --exclude='plugins/_logs' \
        --exclude='plugins/cache/engram' \
        plugins 2>/dev/null || true
    sz=$(du -h "$CLAUDE_DST/plugins.tar.gz" | cut -f1)
    success "  plugins.tar.gz ($sz, engram excluded — reinstall from marketplace post-restore)"
fi

# ─────────────────────────────────────────────────────────────
# Section 3: Per-repo .env files (6 critical repos)
# ─────────────────────────────────────────────────────────────
log ""
log "=== Section 3: Per-repo .env ==="

CRITICAL_REPOS=(
    "agent"
    "digital-identity"
    "home-server"
    "Idea_Vault"
    "IronCradle"
    "workstation-setup"
)

# Manifest preserves exact paths (filename encoding lossy with dashes in dir names)
ENVS_MANIFEST="$STAGE/envs/manifest.txt"
: > "$ENVS_MANIFEST"

idx=0
for repo in "${CRITICAL_REPOS[@]}"; do
    base="$HOME/Projects/$repo"
    [[ ! -d "$base" ]] && continue

    # Find all .env files (max depth 3 to skip node_modules etc.)
    while IFS= read -r envfile; do
        rel=$(realpath --relative-to="$base" "$envfile")
        idx=$((idx+1))
        # Sequential filename + manifest mapping (avoids dash-in-dirname mangling)
        flat="env-${idx}.bin"
        /bin/cp "$envfile" "$STAGE/envs/$flat"
        echo "${flat}|${repo}|${rel}" >> "$ENVS_MANIFEST"
        success "  $repo: $rel"
    done < <(find "$base" -maxdepth 3 -name ".env" -not -path "*/node_modules/*" -not -path "*/.venv/*" 2>/dev/null)
done

# ─────────────────────────────────────────────────────────────
# Section 4: Brain DB (replaces standalone brain.db.bak cron)
# ─────────────────────────────────────────────────────────────
log ""
log "=== Section 4: Brain DB ==="

# Source brain .env to get BRAIN_DB path
BRAIN_ENV="$HOME/Projects/agent/mcp/haingt-brain/.env"
if [[ -f "$BRAIN_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$BRAIN_ENV"
    if [[ -f "$BRAIN_DB" ]]; then
        # Use sqlite3 .backup for consistent snapshot (handles WAL)
        if command -v sqlite3 >/dev/null; then
            sqlite3 "$BRAIN_DB" ".backup '$STAGE/brain/brain.db'"
            success "  brain.db (sqlite .backup, WAL-safe)"
        else
            /bin/cp "$BRAIN_DB" "$STAGE/brain/brain.db"
            success "  brain.db (raw cp — install sqlite3 for WAL-safe)"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────
# Section 5: Home-server full state (tier1 + tier2 + optional tier3)
# ─────────────────────────────────────────────────────────────
log ""
log "=== Section 5: Home-server state ==="

HS="$HOME/Projects/home-server"
HS_DST="$STAGE/home-server"

if [[ -d "$HS" ]]; then
    # Tier 1: secrets
    log "  Tier 1: secrets (.env × 4)"
    tar czf "$HS_DST/tier1-secrets.tar.gz" -C "$HS" \
        .env dashboard/.env media/.env ebooks/.env 2>/dev/null || true
    success "    tier1-secrets.tar.gz"

    # Tier 2: state (configs + DBs + extensions; STOP relevant podman sections briefly)
    log "  Tier 2: state (configs + DBs)"

    NEED_RESTART=()
    # Stop dashboard + media + ebooks for SQLite consistency (if running)
    for section in dashboard media ebooks; do
        if podman ps --format '{{.Names}}' 2>/dev/null | grep -qE "home-${section}|${section}_"; then
            log "    Stopping $section briefly for SQLite snapshot..."
            (cd "$HS" && ./scripts/down.sh "$section" >/dev/null 2>&1) || true
            NEED_RESTART+=("$section")
        fi
    done

    # Tar tier2 (exclude logs, cache, models, outputs, jellyfin-cache)
    # --exclude must come BEFORE positional file args (GNU tar quirk)
    tar czf "$HS_DST/tier2-state.tar.gz" -C "$HS" \
        --exclude='*/forge/models' \
        --exclude='*/forge/outputs' \
        --exclude='*/_cache' \
        --exclude='*/access.log' \
        --exclude='*/content.log' \
        --exclude='*/jellyfin-cache' \
        --exclude='*/logs' \
        --exclude='*/Logs' \
        --exclude='*/transcodes' \
        forge/data/forge/config \
        forge/data/forge/extensions \
        forge/data/forge/embeddings \
        sillytavern/data \
        media/data \
        dashboard/data \
        dashboard/backups \
        ebooks/data/config \
        2>/dev/null || true
    sz=$(du -h "$HS_DST/tier2-state.tar.gz" | cut -f1)
    success "    tier2-state.tar.gz ($sz)"

    # Restart sections
    for section in "${NEED_RESTART[@]}"; do
        log "    Restarting $section..."
        (cd "$HS" && ./scripts/up.sh "$section" >/dev/null 2>&1) || true
    done

    # Tier 3: outputs (weekly or forced)
    if $INCLUDE_TIER3; then
        log "  Tier 3: Forge outputs (weekly snapshot)"
        if [[ -d "$HS/forge/data/forge/outputs" ]]; then
            tar czf "$HS_DST/tier3-outputs.tar.gz" -C "$HS" \
                forge/data/forge/outputs 2>/dev/null || true
            sz=$(du -h "$HS_DST/tier3-outputs.tar.gz" | cut -f1)
            success "    tier3-outputs.tar.gz ($sz)"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────
# Section 6: IronCradle dev environment
# ─────────────────────────────────────────────────────────────
log ""
log "=== Section 6: IronCradle dev env ==="

IC_DST="$STAGE/ironcradle"

# Godot version pin (read from project)
if [[ -f "$HOME/Projects/IronCradle/.godot-version" ]]; then
    /bin/cp "$HOME/Projects/IronCradle/.godot-version" "$IC_DST/godot-version.txt"
    success "  godot-version.txt"
fi

# Godot user config
if [[ -d "$HOME/.config/godot" ]]; then
    tar czf "$IC_DST/godot-user-config.tar.gz" -C "$HOME/.config" godot 2>/dev/null
    success "  godot-user-config.tar.gz"
fi

# VS Code User (settings, keybindings, snippets)
if [[ -d "$HOME/.config/Code/User" ]]; then
    tar czf "$IC_DST/vscode-user.tar.gz" -C "$HOME/.config/Code" \
        --exclude='User/globalStorage' \
        --exclude='User/workspaceStorage' \
        --exclude='User/History' \
        --exclude='User/sync' \
        User
    success "  vscode-user.tar.gz"
fi

# VS Code extensions list
if command -v code >/dev/null; then
    code --list-extensions > "$IC_DST/vscode-extensions.txt"
    cnt=$(wc -l < "$IC_DST/vscode-extensions.txt")
    success "  vscode-extensions.txt ($cnt extensions)"
fi

# ─────────────────────────────────────────────────────────────
# Section 7: Crontab snapshot
# ─────────────────────────────────────────────────────────────
log ""
log "=== Section 7: Crontab ==="
crontab -l > "$STAGE/crontabs/user-crontab.txt" 2>/dev/null || echo "# no crontab" > "$STAGE/crontabs/user-crontab.txt"
success "  user-crontab.txt"

# ─────────────────────────────────────────────────────────────
# Section 8: Manifest + repos.txt
# ─────────────────────────────────────────────────────────────
log ""
log "=== Section 8: Manifest ==="

cat > "$STAGE/manifest.txt" <<EOF
Recovery Bundle Manifest
========================
Date:     $DATE
Host:     $(hostname)
User:     $(whoami)
Tier3:    $INCLUDE_TIER3
Bundle generated by: workstation-setup/scripts/backup/daily-bundle.sh

Contents:
$(cd "$STAGE" && find . -maxdepth 3 -type f -o -type d | sort)
EOF

# Auto-generate repos.txt from current ~/Projects/
{
    echo "# Auto-generated $(date) from current git remotes"
    echo "# Format: name | git-remote | local-path"
    for repo in "${CRITICAL_REPOS[@]}"; do
        base="$HOME/Projects/$repo"
        [[ ! -d "$base/.git" ]] && continue
        remote=$(git -C "$base" config --get remote.origin.url 2>/dev/null || echo "LOCAL")
        echo "$repo | $remote | ~/Projects/$repo"
    done
} > "$STAGE/repos.txt"
success "  manifest.txt + repos.txt"

# ─────────────────────────────────────────────────────────────
# Tar + GPG encrypt
# ─────────────────────────────────────────────────────────────
log ""
log "=== Encrypting ==="

BUNDLE="$WORK/recovery-bundle-${DATE}.tar.gz"
ENCRYPTED="${BUNDLE}.gpg"

tar czf "$BUNDLE" -C "$WORK" recovery-bundle
sz=$(du -h "$BUNDLE" | cut -f1)
log "  Plain tarball: $sz"

gpg --batch --yes --symmetric --cipher-algo AES256 \
    --passphrase-file "$BUNDLE_PASS_FILE" \
    --output "$ENCRYPTED" "$BUNDLE"
sz=$(du -h "$ENCRYPTED" | cut -f1)
success "  Encrypted: $sz"

/bin/rm "$BUNDLE"  # plain tarball gone, only encrypted remains

# ─────────────────────────────────────────────────────────────
# Push to cloud (unless --no-push)
# ─────────────────────────────────────────────────────────────
if $NO_PUSH; then
    log "Skipping push (--no-push). Bundle stays at: $ENCRYPTED"
    # Move to a stable location so user can inspect
    persist="$HOME/recovery-bundle-${DATE}.tar.gz.gpg"
    /bin/mv "$ENCRYPTED" "$persist"
    log "Moved to: $persist"
    exit 0
fi

log ""
log "=== Pushing to cloud ==="

# Primary
log "  Primary: $RCLONE_REMOTE_PRIMARY"
if $DRY_RUN; then
    log "  [DRY-RUN] rclone copy $ENCRYPTED $RCLONE_REMOTE_PRIMARY/daily/"
else
    rclone copy "$ENCRYPTED" "$RCLONE_REMOTE_PRIMARY/daily/" \
        --bwlimit "$BANDWIDTH_SCHEDULE" --transfers 2 --progress
    success "    Pushed to primary"
fi

# Fallback (optional)
if [[ -n "${RCLONE_REMOTE_FALLBACK:-}" ]]; then
    log "  Fallback: $RCLONE_REMOTE_FALLBACK"
    if $DRY_RUN; then
        log "  [DRY-RUN] rclone copy $ENCRYPTED $RCLONE_REMOTE_FALLBACK/daily/"
    else
        rclone copy "$ENCRYPTED" "$RCLONE_REMOTE_FALLBACK/daily/" \
            --bwlimit "$BANDWIDTH_SCHEDULE" --transfers 2 --progress || \
            err "    Fallback push failed (continuing)"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Server-side retention
# ─────────────────────────────────────────────────────────────
log ""
log "=== Retention cleanup ==="

apply_retention() {
    local remote="$1"
    local daily="${2:-$RETAIN_DAILY_DAYS}"
    local weekly="${3:-$RETAIN_WEEKLY_COUNT}"
    local monthly="${4:-$RETAIN_MONTHLY_COUNT}"
    log "  $remote (daily=${daily}d weekly=${weekly} monthly=${monthly})"

    # Daily: delete older than configured days
    rclone delete "$remote/daily/" --min-age "${daily}d" \
        --include "recovery-bundle-*.tar.gz.gpg" 2>&1 | tail -3 || true

    # Weekly: promote Sunday daily → weekly
    if [[ "$(date +%u)" == "7" ]]; then
        latest=$(rclone lsf "$remote/daily/" --include "recovery-bundle-${DATE}.tar.gz.gpg")
        if [[ -n "$latest" ]]; then
            rclone copy "$remote/daily/$latest" "$remote/weekly/" 2>&1 | tail -1 || true
        fi
        rclone delete "$remote/weekly/" --min-age "$((weekly * 7))d" 2>&1 | tail -3 || true
    fi

    # Monthly: promote 1st of month
    if [[ "$(date +%d)" == "01" ]]; then
        latest=$(rclone lsf "$remote/daily/" --include "recovery-bundle-${DATE}.tar.gz.gpg")
        if [[ -n "$latest" ]]; then
            rclone copy "$remote/daily/$latest" "$remote/monthly/" 2>&1 | tail -1 || true
        fi
        rclone delete "$remote/monthly/" --min-age "$((monthly * 31))d" 2>&1 | tail -3 || true
    fi
}

if ! $DRY_RUN; then
    apply_retention "$RCLONE_REMOTE_PRIMARY"
    [[ -n "${RCLONE_REMOTE_FALLBACK:-}" ]] && apply_retention "$RCLONE_REMOTE_FALLBACK" \
        "${FALLBACK_RETAIN_DAILY_DAYS:-$RETAIN_DAILY_DAYS}" \
        "${FALLBACK_RETAIN_WEEKLY_COUNT:-$RETAIN_WEEKLY_COUNT}" \
        "${FALLBACK_RETAIN_MONTHLY_COUNT:-$RETAIN_MONTHLY_COUNT}"
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
log ""
log "=== Summary ==="
success "Bundle: recovery-bundle-${DATE}.tar.gz.gpg ($(du -h "$ENCRYPTED" | cut -f1))"
log "Log:    $LOG_FILE"

# Quick stats from cloud
log ""
log "Cloud state (primary):"
rclone size "$RCLONE_REMOTE_PRIMARY/daily/" 2>&1 | tail -2 || true
