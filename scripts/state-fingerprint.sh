#!/usr/bin/env bash
# Fingerprint critical state for side-by-side compare
# Output: JSON to stdout
set -uo pipefail

# Helpers
sha256_file() { [[ -f "$1" ]] && sha256sum "$1" | cut -d' ' -f1 || echo "MISSING"; }
size_or_zero() { [[ -e "$1" ]] && stat -c %s "$1" 2>/dev/null || echo 0; }
file_count() { [[ -d "$1" ]] && find "$1" -type f 2>/dev/null | wc -l || echo 0; }

cat <<EOF
{
  "host": "$(hostname)",
  "user": "$(whoami)",
  "captured_at": "$(date -Iseconds)",

  "brain": {
    "db_size": $(size_or_zero "$HOME/.local/share/haingt-brain/brain.db"),
    "memory_count": $(sqlite3 "$HOME/.local/share/haingt-brain/brain.db" "SELECT COUNT(*) FROM memories;" 2>/dev/null || echo 0),
    "latest_memory_date": "$(sqlite3 "$HOME/.local/share/haingt-brain/brain.db" "SELECT MAX(created_at) FROM memories;" 2>/dev/null || echo none)"
  },

  "claude_dir": {
    "claude_md_sha": "$(sha256_file "$HOME/.claude/CLAUDE.md")",
    "core_memory_sha": "$(sha256_file "$HOME/.claude/core-memory.md")",
    "settings_sha": "$(sha256_file "$HOME/.claude/settings.json")",
    "keybindings_sha": "$(sha256_file "$HOME/.claude/keybindings.json")",
    "projects_count": $(find "$HOME/.claude/projects" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l),
    "plans_count": $(file_count "$HOME/.claude/plans"),
    "plugins_cache_count": $(find "$HOME/.claude/plugins/cache" -maxdepth 2 -type d 2>/dev/null | wc -l)
  },

  "global_mcp": {
    "claude_json_sha": "$(sha256_file "$HOME/.claude.json")",
    "claude_json_size": $(size_or_zero "$HOME/.claude.json"),
    "mcp_servers": $(python3 -c "
import json
try:
    d = json.load(open('$HOME/.claude.json'))
    print(json.dumps(sorted(d.get('mcpServers',{}).keys())))
except: print('[]')
" 2>/dev/null || echo "[]")
  },

  "secrets": {
    "ssh_key_sha": "$(sha256_file "$HOME/.ssh/id_ed25519")",
    "gpg_dir_files": $(file_count "$HOME/.gnupg"),
    "gh_token_present": $(if gh auth status >/dev/null 2>&1; then echo true; else echo false; fi),
    "bundle_pass_sha": "$(sha256_file "$HOME/.config/recovery/bundle.pass")",
    "rclone_conf_sha": "$(sha256_file "$HOME/.config/rclone/rclone.conf")"
  },

  "envs": {
    "agent_env_sha": "$(sha256_file "$HOME/Projects/agent/.env")",
    "agent_brain_env_sha": "$(sha256_file "$HOME/Projects/agent/mcp/haingt-brain/.env")",
    "home_server_env_sha": "$(sha256_file "$HOME/Projects/home-server/.env")",
    "home_server_dashboard_sha": "$(sha256_file "$HOME/Projects/home-server/dashboard/.env")",
    "home_server_media_sha": "$(sha256_file "$HOME/Projects/home-server/media/.env")",
    "ironcradle_env_sha": "$(sha256_file "$HOME/Projects/IronCradle/.env")",
    "idea_vault_env_sha": "$(sha256_file "$HOME/Projects/Idea_Vault/.env")"
  },

  "repos": {
    "agent_head": "$(cd $HOME/Projects/agent 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo none)",
    "digital_identity_head": "$(cd $HOME/Projects/digital-identity 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo none)",
    "home_server_head": "$(cd $HOME/Projects/home-server 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo none)",
    "idea_vault_head": "$(cd $HOME/Projects/Idea_Vault 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo none)",
    "ironcradle_head": "$(cd $HOME/Projects/IronCradle 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo none)",
    "workstation_setup_head": "$(cd $HOME/Projects/workstation-setup 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo none)"
  },

  "symlinks": {
    "claude_skills_target": "$(readlink $HOME/.claude/skills 2>/dev/null || echo none)",
    "claude_brains_target": "$(readlink $HOME/.claude/brains 2>/dev/null || echo none)",
    "claude_md_target": "$(readlink $HOME/.claude/CLAUDE.md 2>/dev/null || echo none)",
    "claude_settings_target": "$(readlink $HOME/.claude/settings.json 2>/dev/null || echo none)",
    "ironcradle_gdd_target": "$(readlink $HOME/Projects/IronCradle/docs/gdd 2>/dev/null || echo none)"
  },

  "cron_lines": $(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | python3 -c "
import sys, json
print(json.dumps([l.strip() for l in sys.stdin]))
"),

  "binaries": {
    "rclone": "$(rclone --version 2>/dev/null | head -1 || echo MISSING)",
    "gh": "$(gh --version 2>/dev/null | head -1 || echo MISSING)",
    "uv": "$(uv --version 2>/dev/null || echo MISSING)",
    "godot": "$(godot --version 2>/dev/null | head -1 || echo MISSING)",
    "code": "$(command -v code >/dev/null && echo installed || echo MISSING)"
  },

  "rclone": {
    "remotes": $(rclone listremotes 2>/dev/null | python3 -c "
import sys, json
print(json.dumps([l.strip() for l in sys.stdin]))
" 2>/dev/null || echo "[]")
  },

  "plugin_marketplaces": $(ls $HOME/.claude/plugins/marketplaces 2>/dev/null | python3 -c "
import sys, json
print(json.dumps(sorted([l.strip() for l in sys.stdin])))
" 2>/dev/null || echo "[]")
}
EOF
