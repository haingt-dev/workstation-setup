#!/usr/bin/env bash
# Phase 5: Clone agent repo + setup brain MCP venv + restore brain.db
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}

STAGING=$(cat "$HOME/.local/share/recovery/.staging-path" 2>/dev/null)
[[ -z "$STAGING" ]] && { log_error "Bundle staging missing"; exit 1; }

AGENT_DIR="$HOME/Projects/agent"

# ─────────────────────────────────────────────────────────────
# Clone agent repo (if not present)
# ─────────────────────────────────────────────────────────────
if [[ -d "$AGENT_DIR/.git" ]]; then
    log_success "Agent repo already cloned"
else
    log_info "Cloning agent repo..."
    if $DRY_RUN; then
        log_info "[DRY-RUN] gh repo clone haingt-dev/agent $AGENT_DIR"
    else
        mkdir -p "$HOME/Projects"
        gh repo clone haingt-dev/agent "$AGENT_DIR"
        log_success "  Cloned"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Restore agent/.env (if in bundle)
# ─────────────────────────────────────────────────────────────
AGENT_ENV="$STAGING/envs/agent--.env"
if [[ -f "$AGENT_ENV" ]]; then
    log_info "Restoring agent/.env"
    $DRY_RUN || /bin/cp "$AGENT_ENV" "$AGENT_DIR/.env"
    log_success "  .env"
fi

# ─────────────────────────────────────────────────────────────
# Setup brain MCP venv
# ─────────────────────────────────────────────────────────────
BRAIN_DIR="$AGENT_DIR/mcp/haingt-brain"
VENV="$BRAIN_DIR/.venv"

if [[ -d "$VENV" ]]; then
    log_success "Brain MCP venv exists"
else
    log_info "Creating brain MCP venv..."
    if $DRY_RUN; then
        log_info "[DRY-RUN] python -m venv $VENV && pip install -e $BRAIN_DIR"
    else
        cd "$BRAIN_DIR"
        python3 -m venv .venv
        ./.venv/bin/pip install --upgrade pip
        ./.venv/bin/pip install -e .
        log_success "  Venv created + dependencies installed"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Restore brain.db from bundle
# ─────────────────────────────────────────────────────────────
BRAIN_SRC="$STAGING/brain/brain.db"
if [[ -f "$BRAIN_SRC" ]]; then
    log_info "Restoring brain.db from bundle"

    # Load brain .env to get destination
    if [[ -f "$BRAIN_DIR/.env" ]]; then
        # shellcheck disable=SC1090
        source "$BRAIN_DIR/.env"
    fi
    BRAIN_DB="${BRAIN_DB:-$HOME/.local/share/haingt-brain/brain.db}"

    if $DRY_RUN; then
        log_info "[DRY-RUN] cp $BRAIN_SRC → $BRAIN_DB"
    else
        mkdir -p "$(dirname "$BRAIN_DB")"
        /bin/cp "$BRAIN_SRC" "$BRAIN_DB"
        sz=$(du -h "$BRAIN_DB" | cut -f1)
        log_success "  brain.db restored ($sz)"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Symlinks: ~/.claude/{skills,brains,CLAUDE.md,settings.json} → agent/global/
# (CLAUDE.md + settings.json were dereferenced into bundle by backup; now
#  replace them with the canonical symlink architecture)
# ─────────────────────────────────────────────────────────────
log_info "Creating Claude symlinks (skills, brains, CLAUDE.md, settings.json)"

# Restore gitignored agent/global/CLAUDE.md from ~/.claude/CLAUDE.md content
# (Phase 4 wrote real content via deref backup; here we re-seed the symlink target)
if [[ -f "$HOME/.claude/CLAUDE.md" && ! -L "$HOME/.claude/CLAUDE.md" && ! -e "$AGENT_DIR/global/CLAUDE.md" ]]; then
    log_info "  Re-seeding gitignored $AGENT_DIR/global/CLAUDE.md from bundle content"
    $DRY_RUN || /bin/cp "$HOME/.claude/CLAUDE.md" "$AGENT_DIR/global/CLAUDE.md"
fi

for link_pair in \
    "$HOME/.claude/skills:$AGENT_DIR/global/skills" \
    "$HOME/.claude/brains:$AGENT_DIR/global/brains" \
    "$HOME/.claude/CLAUDE.md:$AGENT_DIR/global/CLAUDE.md" \
    "$HOME/.claude/settings.json:$AGENT_DIR/global/settings.json"
do
    IFS=':' read -r link target <<< "$link_pair"
    [[ ! -e "$target" ]] && { log_warn "  Target missing: $target — skip"; continue; }

    if [[ -L "$link" ]]; then
        current=$(readlink "$link")
        [[ "$current" == "$target" ]] && { log_success "  $link OK"; continue; }
        log_warn "  $link → $current (drift, fixing)"
        $DRY_RUN || /bin/rm "$link"
    elif [[ -e "$link" ]]; then
        log_warn "  $link exists as file/dir (not symlink) — back up + replace"
        $DRY_RUN || /bin/mv "$link" "${link}.pre-restore-$(date +%s)"
    fi

    if $DRY_RUN; then
        log_info "  [DRY-RUN] ln -s $target $link"
    else
        ln -s "$target" "$link"
        log_success "  $link → $target"
    fi
done

# ─────────────────────────────────────────────────────────────
# Install daily backup cron (replaces legacy brain.db.bak)
# ─────────────────────────────────────────────────────────────
log_info "Installing daily-bundle cron"

# Ensure crontab available (cloud images often skip cronie)
if ! command -v crontab >/dev/null 2>&1; then
    log_warn "  crontab missing — installing cronie"
    $DRY_RUN || sudo dnf install -y cronie 2>&1 | tail -3
    $DRY_RUN || sudo systemctl enable --now crond 2>/dev/null || true
fi

if $DRY_RUN; then
    log_info "[DRY-RUN] would run install-cron.sh"
else
    "$SCRIPT_DIR/backup/install-cron.sh" --force
fi
