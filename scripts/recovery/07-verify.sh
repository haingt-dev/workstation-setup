#!/usr/bin/env bash
# Phase 7: Verify recovery + report manual steps remaining
set -uo pipefail
# No -e: per-check failures must continue scanning all checks before reporting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

DRY_RUN=${DRY_RUN:-false}

log_info "Running verification checks"

# Counters
PASS=0
FAIL=0

check() {
    local desc="$1" cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        log_success "  $desc"
        PASS=$((PASS + 1))
    else
        log_warn "  $desc"
        FAIL=$((FAIL + 1))
    fi
}

# ─────────────────────────────────────────────────────────────
# Hard checks
# ─────────────────────────────────────────────────────────────
log_info ""
log_info "Hard checks:"

check "git via SSH (github.com)"                 "ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 | grep -q 'successfully'"
check "gh auth status"                            "gh auth status"
check "GPG secret keys present"                   "gpg --list-secret-keys 2>/dev/null | grep -q sec"

# Repos
for repo in agent digital-identity home-server Idea_Vault IronCradle workstation-setup; do
    check "Repo cloned: $repo"                    "[[ -d $HOME/Projects/$repo/.git ]]"
done

# Brain
check "brain.db exists"                           "[[ -f $HOME/.local/share/haingt-brain/brain.db ]]"
check "Brain MCP venv"                            "[[ -d $HOME/Projects/agent/mcp/haingt-brain/.venv ]]"

# Claude state
check "~/.claude/CLAUDE.md"                       "[[ -f $HOME/.claude/CLAUDE.md ]]"
check "~/.claude/projects/ has dirs"             "[[ \$(find $HOME/.claude/projects -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l) -gt 0 ]]"
check "~/.claude/skills → agent (symlink)"       "[[ -L $HOME/.claude/skills ]] && [[ \$(readlink $HOME/.claude/skills) == */agent/global/skills ]]"

# Symlinks per manifest
check "IronCradle docs/gdd symlink"               "[[ -L $HOME/Projects/IronCradle/docs/gdd ]]"

# Daily bundle cron
check "daily-bundle cron installed"               "crontab -l 2>/dev/null | grep -q daily-bundle.sh"

# ─────────────────────────────────────────────────────────────
# Soft checks (warnings only)
# ─────────────────────────────────────────────────────────────
log_info ""
log_info "Soft checks:"

if [[ -d "$HOME/Projects/home-server" ]]; then
    if (cd "$HOME/Projects/home-server" && ./scripts/up.sh dashboard 2>/dev/null && sleep 3 && curl -s --connect-timeout 3 http://localhost:7575 >/dev/null); then
        log_success "  home-server dashboard reachable"
        (cd "$HOME/Projects/home-server" && ./scripts/down.sh dashboard >/dev/null 2>&1) || true
    else
        log_warn "  home-server dashboard didn't come up — check podman + .env"
    fi
fi

if [[ -d "$HOME/Projects/IronCradle" && -x "$(command -v godot)" ]]; then
    current_godot=$(godot --version 2>/dev/null | head -1)
    pinned=$(cat "$HOME/Projects/IronCradle/.godot-version" 2>/dev/null || echo "n/a")
    log_info "  Godot: installed=$current_godot, pinned=$pinned"
fi

# ─────────────────────────────────────────────────────────────
# Summary + manual remaining
# ─────────────────────────────────────────────────────────────
echo ""
log_section "Verification: $PASS passed, $FAIL failed"

cat <<EOF

Manual steps remaining (cannot automate):
  1. Forge models (~9GB): cd ~/Projects/home-server && ./scripts/forge-pull-models.sh
     - Civitai LoRAs need modelVersionId in forge/models.yml (pre-disaster homework)
  2. HuggingFace CLI login (if gated models): huggingface-cli login
  3. IronCradle: open Godot once → reimport assets (5-30 min, one-time)
  4. home-server: ./scripts/up.sh all (verify all 4 sections come up)
  5. Optional: bring up media stack — AirVPN keys already in media/.env from bundle

Auto-restored (no action):
  ✓ SSH/GPG/gh tokens, all .env files (incl AirVPN, Civitai, Anthropic API)
  ✓ Conversation history + plans + memories + plugins/cache
  ✓ Cross-project symlinks
  ✓ Daily backup cron (will run tonight)

EOF

# Exit non-zero if hard checks failed (signals to orchestrator)
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
