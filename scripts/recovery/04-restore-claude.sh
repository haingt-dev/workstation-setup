#!/usr/bin/env bash
# Phase 4: Restore ~/.claude/ state
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}

STAGING=$(cat "$HOME/.local/share/recovery/.staging-path" 2>/dev/null)
[[ -z "$STAGING" || ! -d "$STAGING" ]] && { log_error "Bundle staging missing"; exit 1; }

CLAUDE_SRC="$STAGING/claude"
[[ -d "$CLAUDE_SRC" ]] || { log_warn "No claude/ in bundle — skipping"; exit 0; }

CLAUDE_DST="$HOME/.claude"
mkdir -p "$CLAUDE_DST"

log_info "Restoring ~/.claude/ from bundle"

# ─────────────────────────────────────────────────────────────
# Flat files
# ─────────────────────────────────────────────────────────────
for f in CLAUDE.md core-memory.md settings.json config.json keybindings.json statusline-command.sh; do
    src="$CLAUDE_SRC/$f"
    if [[ -f "$src" ]]; then
        if $DRY_RUN; then
            log_info "[DRY-RUN] cp $src → $CLAUDE_DST/$f"
        else
            /bin/cp "$src" "$CLAUDE_DST/$f"
            log_success "  $f"
        fi
    fi
done

# Global MCP config (~/.claude.json — sibling of ~/.claude/ dir)
if [[ -f "$CLAUDE_SRC/dot-claude.json" ]]; then
    if $DRY_RUN; then
        log_info "[DRY-RUN] cp dot-claude.json → ~/.claude.json"
    else
        /bin/cp "$CLAUDE_SRC/dot-claude.json" "$HOME/.claude.json"
        chmod 600 "$HOME/.claude.json"
        log_success "  ~/.claude.json (global MCP config — haingt-brain, todoist, etc.)"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Directories (brains, agents, plans)
# ─────────────────────────────────────────────────────────────
for d in brains agents plans skills hooks; do
    src="$CLAUDE_SRC/$d"
    if [[ -d "$src" ]]; then
        if $DRY_RUN; then
            log_info "[DRY-RUN] cp -r $src → $CLAUDE_DST/$d"
        else
            /bin/rm -rf "$CLAUDE_DST/$d"
            /bin/cp -r "$src" "$CLAUDE_DST/"
            log_success "  $d/"
        fi
    fi
done

# ─────────────────────────────────────────────────────────────
# Compressed: projects/ (conversation history)
# ─────────────────────────────────────────────────────────────
if [[ -f "$CLAUDE_SRC/projects.tar.gz" ]]; then
    log_info "Extracting projects.tar.gz (conversation history)..."
    if $DRY_RUN; then
        log_info "[DRY-RUN] would extract"
    else
        /bin/rm -rf "$CLAUDE_DST/projects"
        tar xzf "$CLAUDE_SRC/projects.tar.gz" -C "$CLAUDE_DST"
        cnt=$(find "$CLAUDE_DST/projects" -maxdepth 1 -mindepth 1 -type d | wc -l)
        log_success "  projects/ restored ($cnt project dirs)"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Compressed: plugins/ (cache for version pin, no internet needed)
# ─────────────────────────────────────────────────────────────
if [[ -f "$CLAUDE_SRC/plugins.tar.gz" ]]; then
    log_info "Extracting plugins.tar.gz (cache + installed_plugins.json)..."
    if $DRY_RUN; then
        log_info "[DRY-RUN] would extract"
    else
        /bin/rm -rf "$CLAUDE_DST/plugins"
        tar xzf "$CLAUDE_SRC/plugins.tar.gz" -C "$CLAUDE_DST"
        sz=$(du -sh "$CLAUDE_DST/plugins" | cut -f1)
        log_success "  plugins/ restored ($sz — Claude Code can launch immediately, no reinstall)"
    fi
fi

log_success "Claude state restored"
