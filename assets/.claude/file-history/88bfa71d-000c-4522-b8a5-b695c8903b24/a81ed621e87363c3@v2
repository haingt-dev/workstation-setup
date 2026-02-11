#!/bin/bash
# Agent Global Hub - Shell Aliases
# Source this file in your ~/.zshrc or ~/.bashrc:
# source ~/.agent_global/shell-aliases.sh

# ============================================
# AGENT GLOBAL HUB NAVIGATION
# ============================================

# Quick access to Agent Global Hub
alias ag='cd ~/.agent_global && ls -la'
alias ag-edit='cd ~/.agent_global && $EDITOR .'

# Quick access to projects
alias cdp='cd ~/Projects'
alias cdv='cd ~/Dropbox/Apps/Obsidian/Idea_Vault'

# ============================================
# PROJECT MANAGEMENT
# ============================================

# Bootstrap new project
alias bootstrap='~/.agent_global/bootstrap-project.sh'

# Edit Memory Bank in current project
mbk() {
    if [ -d ".agent/rules/memory-bank" ]; then
        echo "📝 Opening Memory Bank..."
        $EDITOR .agent/rules/memory-bank/
    else
        echo "❌ No Memory Bank found in current directory"
        echo "💡 Run 'bootstrap .' to create one"
    fi
}

# Quick edit context.md (most frequently updated)
mbc() {
    if [ -f ".agent/rules/memory-bank/context.md" ]; then
        $EDITOR .agent/rules/memory-bank/context.md
    else
        echo "❌ No context.md found. Run 'mbk' to see all Memory Bank files"
    fi
}

# View Memory Bank status
mb-status() {
    if [ -d ".agent/rules/memory-bank" ]; then
        echo "📊 Memory Bank Status"
        echo "===================="
        for file in .agent/rules/memory-bank/*.md; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                size=$(wc -l < "$file")
                modified=$(stat -c %y "$file" 2>/dev/null || stat -f "%Sm" "$file" 2>/dev/null)
                printf "%-20s | %4d lines | %s\n" "$filename" "$size" "${modified:0:16}"
            fi
        done
    else
        echo "❌ No Memory Bank in current directory"
    fi
}

# ============================================
# AGENT SWITCHING
# ============================================

# Claude CLI shortcut
alias c='claude'

# Show agent priority
alias ag-priority='echo "🎯 Agent Priority Chain:\n  1. Claude (c)       → Complex work, deep analysis\n  2. Antigravity      → UI-based workflows\n  3. Kilo (VS Code)   → Editor integration"'

# Quick project switch with Claude
cdc() {
    if [ -z "$1" ]; then
        echo "Usage: cdc <project-name>"
        echo "Available projects:"
        ls -1 ~/Projects/
        return 1
    fi

    PROJECT_PATH="$HOME/Projects/$1"
    if [ -d "$PROJECT_PATH" ]; then
        cd "$PROJECT_PATH"
        echo "📂 Switched to: $PROJECT_PATH"

        # Show Memory Bank status if exists
        if [ -d ".agent/rules/memory-bank" ]; then
            echo ""
            mb-status
        fi

        # Offer to start Claude
        echo ""
        echo "💡 Start Claude? (c)"
    else
        echo "❌ Project not found: $PROJECT_PATH"
    fi
}

# ============================================
# GLOBAL RULES EDITING
# ============================================

# Edit global rules (syncs to all agents)
alias ag-rules='$EDITOR ~/.agent_global/rules/global_rules.md'

# Edit workflows
alias ag-workflows='$EDITOR ~/.agent_global/workflows/'

# ============================================
# MAINTENANCE
# ============================================

# Sync Memory Bank to/from Obsidian
alias mb-sync='~/.agent_global/sync-obsidian.sh'
alias mb-to-obsidian='~/.agent_global/sync-obsidian.sh $(basename "$PWD") --to-obsidian'
alias mb-from-obsidian='~/.agent_global/sync-obsidian.sh $(basename "$PWD") --from-obsidian'
alias mb-sync-status='~/.agent_global/sync-obsidian.sh $(basename "$PWD") --status'

# Update all project CLAUDE.md files
ag-update-claude() {
    echo "🔄 Updating CLAUDE.md in all projects..."
    for project in ~/Projects/*/; do
        if [ -f "$project/CLAUDE.md" ]; then
            echo "  ✓ $(basename "$project")"
        fi
    done
    echo "Done!"
}

# ============================================
# UTILITIES
# ============================================

# ============================================
# TOKEN ANALYTICS
# ============================================

alias token-today='~/.agent_global/analytics/token-tracker.sh today'
alias token-week='~/.agent_global/analytics/token-tracker.sh week'
alias token-summary='~/.agent_global/analytics/token-tracker.sh summary'
alias token-project='~/.agent_global/analytics/token-tracker.sh project'
alias token-log='$EDITOR ~/.agent_global/analytics/token-usage.log'

# ============================================
# HELP
# ============================================

# Show this help
ag-help() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║         AGENT GLOBAL HUB - COMMAND REFERENCE              ║
╚═══════════════════════════════════════════════════════════╝

📁 NAVIGATION
  ag              → Go to Agent Global Hub
  ag-edit         → Open Agent Global Hub in editor
  cdp             → Go to ~/Projects
  cdv             → Go to Obsidian Vault
  cdc <project>   → Switch to project + show Memory Bank

📝 MEMORY BANK
  mbk             → Edit Memory Bank (current project)
  mbc             → Edit context.md (quick access)
  mb-status       → Show Memory Bank file status
  mb-sync         → Sync Memory Bank to Obsidian

🚀 PROJECT MANAGEMENT
  bootstrap <dir> → Bootstrap new project with Memory Bank

🤖 AGENTS
  c               → Start Claude
  ag-priority     → Show agent priority chain

⚙️  CONFIGURATION
  ag-rules        → Edit global rules
  ag-workflows    → Edit workflows

📊 ANALYTICS
  token-today     → Show today's token usage
  token-week      → Show weekly summary
  token-summary   → Show overall summary
  token-project   → Show project usage
  token-log       → Edit usage log

📚 HELP
  ag-help         → Show this help

EOF
}

# Auto-completion for cdc (project names)
if [ -n "$ZSH_VERSION" ]; then
    # Zsh completion
    compdef '_files -W ~/Projects -/' cdc
elif [ -n "$BASH_VERSION" ]; then
    # Bash completion
    _cdc_completion() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        COMPREPLY=( $(compgen -W "$(ls -1 ~/Projects/)" -- "$cur") )
    }
    complete -F _cdc_completion cdc
fi

# Show welcome message on first source
if [ -z "$AG_ALIASES_LOADED" ]; then
    export AG_ALIASES_LOADED=1
    echo "✅ Agent Global Hub aliases loaded! Type 'ag-help' for commands."
fi
