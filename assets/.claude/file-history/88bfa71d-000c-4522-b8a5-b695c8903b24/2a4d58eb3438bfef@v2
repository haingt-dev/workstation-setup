# Recipe: Setup New Project with Agent Integration

**Category**: Project Setup
**Tags**: #setup #bootstrap #new-project
**Time**: ~5 minutes

## Prerequisites
- Project directory created
- Git initialized (optional but recommended)

## Steps

### 1. Bootstrap Project Structure
```bash
cd /path/to/new/project

# OR from anywhere:
bootstrap /path/to/new/project
```

This creates:
- `.agent/rules/memory-bank/` directory
- Memory Bank template files
- `CLAUDE.md` configuration

### 2. Fill in Memory Bank
Edit the template files:
```bash
mbk  # Opens full Memory Bank in editor
```

Fill in at minimum:
- `brief.md` → Project goal and scope
- `context.md` → Initial focus and status
- `tech.md` → Languages and frameworks

Can leave others minimal initially and expand later.

### 3. Install Git Hook (Optional but Recommended)
```bash
~/.agent_global/hooks/install-mb-hook.sh .
```

This installs post-commit hook to remind you to update Memory Bank.

### 4. Setup Obsidian Integration (If Applicable)
If project should exist in Obsidian:

```bash
# Create in Obsidian first:
# ~/Dropbox/Apps/Obsidian/Idea_Vault/20 Projects/ProjectName/

# Then symlink:
~/.agent_global/sync-obsidian.sh ProjectName --symlink
```

### 5. Create Initial CLAUDE.md (Already done by bootstrap)
Verify it exists:
```bash
ls -la CLAUDE.md
```

### 6. First Agent Session
```bash
claude
```

In Claude, test Memory Bank loading:
```
"Load the Memory Bank and summarize the project"
```

Should see: `[memory bank active]` indicator.

### 7. Make Initial Commit
```bash
git add .agent/ CLAUDE.md
git commit -m "chore: setup agent integration with Memory Bank"
```

## Verification Checklist
- [ ] `.agent/rules/memory-bank/` exists with 5 .md files
- [ ] `CLAUDE.md` exists in project root
- [ ] Memory Bank files have content (not just templates)
- [ ] Git hook installed (check `.git/hooks/post-commit`)
- [ ] Claude loads Memory Bank successfully
- [ ] (Optional) Obsidian symlink working

## Common Issues

### "Memory Bank not loading"
- Check CLAUDE.md exists in project root
- Ensure you're running Claude from project directory
- Verify `.agent/rules/memory-bank/*.md` files exist

### "Git hook not triggering"
- Check `.git/hooks/post-commit` exists and is executable
- Test: Make a feat commit with 5+ file changes

### "Obsidian symlink broken"
- Verify paths are correct
- Check symlink: `ls -la .agent/rules/memory-bank`
- Re-run sync script if needed

## Next Steps
- Start development
- Keep Memory Bank updated as project evolves
- Use `mbc` for quick context updates
- Commit Memory Bank changes separately

## Related
- Pattern: Memory Bank Pattern
- Tool: `~/.agent_global/bootstrap-project.sh`
- Guide: `~/.agent_global/SETUP.md`
