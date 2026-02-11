#!/bin/bash
# Bootstrap a new project with Agent Global Hub integration
# Usage: bootstrap-project.sh /path/to/new/project [project-name]

set -e

PROJECT_PATH="${1:-.}"
PROJECT_NAME="${2:-$(basename "$PROJECT_PATH")}"

echo "🚀 Bootstrapping project: $PROJECT_NAME"
echo "📁 Location: $PROJECT_PATH"
echo ""

# Check if project directory exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Error: Directory $PROJECT_PATH does not exist"
    exit 1
fi

# Create memory-bank directory structure
MEMORY_BANK="$PROJECT_PATH/.agent/rules/memory-bank"
echo "📝 Creating memory bank structure..."
mkdir -p "$MEMORY_BANK"

# Copy memory bank templates if they exist and files don't already exist
TEMPLATES="$HOME/.agent_global/templates/memory-bank"
if [ -d "$TEMPLATES" ]; then
    for template in "$TEMPLATES"/*.md; do
        if [ -f "$template" ]; then
            filename=$(basename "$template")
            if [ ! -f "$MEMORY_BANK/$filename" ]; then
                cp "$template" "$MEMORY_BANK/"
                echo "  ✓ Created $filename"
            else
                echo "  ⏭  Skipped $filename (already exists)"
            fi
        fi
    done
else
    # Create basic template files if templates directory doesn't exist
    echo "  ℹ  Templates not found, creating basic files..."

    [ ! -f "$MEMORY_BANK/brief.md" ] && cat > "$MEMORY_BANK/brief.md" << 'EOF'
# Brief

## Project Goals


## Scope


## Success Criteria

EOF

    [ ! -f "$MEMORY_BANK/product.md" ] && cat > "$MEMORY_BANK/product.md" << 'EOF'
# Product Context

## Overview


## Key Features


## Constraints

EOF

    [ ! -f "$MEMORY_BANK/context.md" ] && cat > "$MEMORY_BANK/context.md" << 'EOF'
# Current Context

## Active Workstreams


## Recent Changes


## Next Steps

EOF

    [ ! -f "$MEMORY_BANK/architecture.md" ] && cat > "$MEMORY_BANK/architecture.md" << 'EOF'
# Architecture

## System Structure


## Key Components


## Data Flow

EOF

    [ ! -f "$MEMORY_BANK/tech.md" ] && cat > "$MEMORY_BANK/tech.md" << 'EOF'
# Tech Stack

## Languages


## Frameworks & Libraries


## Tools & Services

EOF

    echo "  ✓ Created basic memory bank files"
fi

# Check for project-specific memory bank files
echo ""
echo "💡 Tip: You can add project-specific memory bank files (e.g., gameDesign.md, tasks.md)"

# Create CLAUDE.md
CLAUDE_MD="$PROJECT_PATH/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
    echo ""
    echo "⏭  CLAUDE.md already exists, skipping..."
else
    echo ""
    echo "📋 Creating CLAUDE.md..."

    # Get list of memory bank files for the template
    MB_FILES=$(ls "$MEMORY_BANK"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null || echo "")

    cat > "$CLAUDE_MD" << 'EOF'
# Project Context for Claude

**CRITICAL**: Load Memory Bank from `.agent/rules/memory-bank/` before starting any task.

## Memory Bank Location
Read these files at the start of EVERY task to ground yourself in project context:
- **Brief**: `.agent/rules/memory-bank/brief.md` — Project goals and scope
- **Product**: `.agent/rules/memory-bank/product.md` — Product context and constraints
- **Context**: `.agent/rules/memory-bank/context.md` — Current focus, active workstreams, recent changes
- **Architecture**: `.agent/rules/memory-bank/architecture.md` — System architecture and structure
- **Tech Stack**: `.agent/rules/memory-bank/tech.md` — Tech stack and tooling

## Global Rules
See `~/.claude/rules/CLAUDE.md` (symlinked to Agent Global Hub)

## Workflows
All workflows are symlinked from `~/.claude/workflows/`:
- `core-directives.md` — Fundamental behavioral guidelines
- `commit-protocol.md` — Git commit standards
- `memory-bank-protocol.md` — Memory Bank maintenance protocol
- `documentation-sync.md` — Documentation synchronization

## Memory Bank Maintenance
After completing major tasks or architectural changes, update the relevant Memory Bank files to keep context fresh for all agents (Claude, Kilo, Antigravity).

## Priority Chain
Claude → Antigravity → Kilo (use Claude for complex interactive work, Antigravity for UI-based tasks, Kilo for VS Code integration)
EOF

    echo "  ✓ Created CLAUDE.md"
fi

# Summary
echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "📂 Created structure:"
echo "   $PROJECT_PATH/.agent/rules/memory-bank/"
if [ -n "$MB_FILES" ]; then
    echo "$MB_FILES" | while read file; do
        [ -n "$file" ] && echo "      ├── $file"
    done
fi
echo "   $PROJECT_PATH/CLAUDE.md"
echo ""
echo "📝 Next steps:"
echo "   1. Fill in the memory bank files with project details"
echo "   2. Run Claude from the project directory: cd $PROJECT_PATH && claude"
echo "   3. Claude will automatically load the memory bank context"
echo ""
