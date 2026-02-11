# Obsidian ↔ Code Project Integration

**Category**: Workflow Integration
**Tags**: #obsidian #pkm #documentation

## Problem
Knowledge lives in two places:
- Code repository (Memory Bank, README, docs)
- Obsidian vault (notes, design docs, research)

This creates sync burden and fragmentation.

## Solution
Use Obsidian as source of truth for project knowledge, symlink to code repo:

```bash
~/.agent_global/sync-obsidian.sh ProjectName --symlink
```

## Architecture
```
Obsidian Vault (20 Projects/ProjectName/Memory Bank/)
         ↑ (source of truth)
         |
         | (symlink)
         ↓
Code Repo (.agent/rules/memory-bank/)
```

## Benefits
- ✅ Edit in Obsidian with full PKM features (Dataview, links, tags)
- ✅ Agents read from code repo (no change to workflow)
- ✅ Single source of truth
- ✅ Version control (if Obsidian vault is git-tracked)
- ✅ Rich metadata and querying in Obsidian

## When to Use
- Projects that exist in both code and Obsidian
- Projects with significant design documentation
- When Obsidian is your primary knowledge tool

## When NOT to Use
- Code-only projects without Obsidian presence
- Projects where code repo needs to be self-contained
- Shared projects where collaborators don't use Obsidian

## Alternatives
- **Bi-directional sync**: Use `sync-obsidian.sh --to-obsidian` or `--from-obsidian`
- **Code-only**: Keep Memory Bank only in code repo
- **Obsidian-only**: Keep docs only in vault, link from README

## Example
```bash
# Setup Wildtide with Obsidian as source of truth
cd ~/Projects/Wildtide
~/.agent_global/sync-obsidian.sh Wildtide --symlink

# Now edit in Obsidian:
# ~/Dropbox/Apps/Obsidian/Idea_Vault/20 Projects/Wildtide/Memory Bank/

# Agents automatically see changes in:
# ~/Projects/Wildtide/.agent/rules/memory-bank/
```

## Related
- See: `~/.agent_global/sync-obsidian.sh`
- Used in: Wildtide (active symlink)
