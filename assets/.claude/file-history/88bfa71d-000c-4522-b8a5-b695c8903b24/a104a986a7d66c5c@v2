# Agent Global Hub Setup Guide

## Quick Setup for New Projects

### Method 1: Bootstrap Script
```bash
~/.agent_global/bootstrap-project.sh /path/to/new/project
```

### Method 2: Manual Setup
```bash
PROJECT=/path/to/new/project
mkdir -p "$PROJECT/.agent/rules/memory-bank"

# Create CLAUDE.md (copy from existing project or use bootstrap script)
cp ~/Projects/Wildtide/CLAUDE.md "$PROJECT/"

# Fill in memory bank files
# - brief.md, product.md, context.md, architecture.md, tech.md
```

### Method 3: Shell Alias (Optional)
Add to your `~/.bashrc` or `~/.zshrc`:
```bash
alias bootstrap-project='~/.agent_global/bootstrap-project.sh'
```

Then simply run:
```bash
bootstrap-project /path/to/new/project
```

## Verify Setup

After bootstrapping, verify the structure:
```bash
cd /path/to/new/project
ls -la .agent/rules/memory-bank/  # Should show: brief.md, product.md, context.md, architecture.md, tech.md
ls -la CLAUDE.md                  # Should exist in project root
```

## Testing

Start Claude in the project directory:
```bash
cd /path/to/new/project
claude
```

Claude should automatically detect and load the CLAUDE.md file.

## Maintenance

### Update Memory Bank
After significant changes, update the relevant files:
```bash
# Edit the memory bank files
$EDITOR .agent/rules/memory-bank/context.md
$EDITOR .agent/rules/memory-bank/architecture.md
```

### Sync Global Rules
Global rules are automatically synced via symlinks. Edit once in `.agent_global/`:
```bash
$EDITOR ~/.agent_global/rules/global_rules.md
$EDITOR ~/.agent_global/workflows/*.md
```

Changes propagate to:
- Claude: `~/.claude/rules/CLAUDE.md` and `~/.claude/workflows/`
- Kilo: `~/.kilocode/rules/` and `~/.kilocode/workflows/`
- Antigravity: `~/.gemini/GEMINI.md` and `~/.gemini/antigravity/global_workflows/`
