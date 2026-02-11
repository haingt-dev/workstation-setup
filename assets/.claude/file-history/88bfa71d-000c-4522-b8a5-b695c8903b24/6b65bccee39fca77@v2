#!/usr/bin/env bash
# Bi-directional sync between project Memory Bank and Obsidian
# Usage: sync-obsidian.sh <project-name> [--to-obsidian | --from-obsidian | --status]

set -e

OBSIDIAN_ROOT="$HOME/Dropbox/Apps/Obsidian/Idea_Vault"
PROJECTS_ROOT="$HOME/Projects"

show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║       OBSIDIAN ↔ MEMORY BANK SYNC                          ║
╚════════════════════════════════════════════════════════════╝

Usage: sync-obsidian.sh <project-name> [options]

Options:
  --to-obsidian      Sync FROM code repo TO Obsidian (default)
  --from-obsidian    Sync FROM Obsidian TO code repo
  --status           Show sync status without syncing
  --symlink          Create symlinks (Obsidian as source of truth)
  --help             Show this help

Examples:
  sync-obsidian.sh Wildtide --to-obsidian
  sync-obsidian.sh Wildtide --status
  sync-obsidian.sh Wildtide --symlink

Projects:
EOF
    ls -1 "$PROJECTS_ROOT/"
}

PROJECT_NAME="$1"
MODE="${2:---to-obsidian}"

if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "--help" ]; then
    show_help
    exit 0
fi

CODE_MB="$PROJECTS_ROOT/$PROJECT_NAME/.agent/rules/memory-bank"
OBSIDIAN_MB="$OBSIDIAN_ROOT/20 Projects/$PROJECT_NAME/Memory Bank"

# Check if code project exists
if [ ! -d "$PROJECTS_ROOT/$PROJECT_NAME" ]; then
    echo "❌ Project not found: $PROJECTS_ROOT/$PROJECT_NAME"
    exit 1
fi

# Status mode
if [ "$MODE" = "--status" ]; then
    echo "📊 Sync Status for $PROJECT_NAME"
    echo "════════════════════════════════════"
    echo ""
    echo "Code Memory Bank:     $CODE_MB"
    if [ -d "$CODE_MB" ]; then
        echo "  Status: ✅ Exists"
        echo "  Files:  $(ls -1 "$CODE_MB"/*.md 2>/dev/null | wc -l) markdown files"
    else
        echo "  Status: ❌ Not found"
    fi
    echo ""
    echo "Obsidian Memory Bank: $OBSIDIAN_MB"
    if [ -d "$OBSIDIAN_MB" ]; then
        echo "  Status: ✅ Exists"
        echo "  Files:  $(ls -1 "$OBSIDIAN_MB"/*.md 2>/dev/null | wc -l) markdown files"

        # Check if it's a symlink
        if [ -L "$CODE_MB" ]; then
            echo "  Type:   🔗 Symlinked to $(readlink "$CODE_MB")"
        fi
    else
        echo "  Status: ❌ Not found"
    fi
    exit 0
fi

# Symlink mode
if [ "$MODE" = "--symlink" ]; then
    echo "🔗 Setting up symlink (Obsidian as source of truth)..."

    # Create Obsidian Memory Bank if it doesn't exist
    if [ ! -d "$OBSIDIAN_MB" ]; then
        echo "📁 Creating Memory Bank in Obsidian..."
        mkdir -p "$OBSIDIAN_MB"

        # Copy from code if it exists
        if [ -d "$CODE_MB" ]; then
            echo "📋 Copying existing Memory Bank from code repo..."
            cp -r "$CODE_MB"/* "$OBSIDIAN_MB/"
        else
            echo "📝 Creating from templates..."
            cp ~/.agent_global/templates/memory-bank/*.md "$OBSIDIAN_MB/"
        fi
    fi

    # Backup existing code Memory Bank if not a symlink
    if [ -d "$CODE_MB" ] && [ ! -L "$CODE_MB" ]; then
        BACKUP="$CODE_MB.backup.$(date +%s)"
        echo "💾 Backing up existing Memory Bank to $(basename "$BACKUP")"
        mv "$CODE_MB" "$BACKUP"
    fi

    # Remove old symlink or directory
    rm -rf "$CODE_MB"

    # Create symlink
    mkdir -p "$(dirname "$CODE_MB")"
    ln -s "$OBSIDIAN_MB" "$CODE_MB"

    echo "✅ Symlink created!"
    echo "   $CODE_MB"
    echo "   → $OBSIDIAN_MB"
    echo ""
    echo "💡 Now edit Memory Bank in Obsidian, and code agents will see it automatically"
    exit 0
fi

# Sync modes
if [ "$MODE" = "--to-obsidian" ]; then
    if [ ! -d "$CODE_MB" ]; then
        echo "❌ No Memory Bank in code repo"
        exit 1
    fi

    echo "📤 Syncing TO Obsidian..."
    mkdir -p "$OBSIDIAN_MB"
    rsync -av --delete "$CODE_MB/" "$OBSIDIAN_MB/"
    echo "✅ Synced to Obsidian"

elif [ "$MODE" = "--from-obsidian" ]; then
    if [ ! -d "$OBSIDIAN_MB" ]; then
        echo "❌ No Memory Bank in Obsidian"
        exit 1
    fi

    echo "📥 Syncing FROM Obsidian..."
    mkdir -p "$CODE_MB"
    rsync -av --delete "$OBSIDIAN_MB/" "$CODE_MB/"
    echo "✅ Synced from Obsidian"

else
    echo "❌ Unknown mode: $MODE"
    show_help
    exit 1
fi
