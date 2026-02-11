# Memory Bank Becomes Stale

**Category**: Maintenance
**Tags**: #memory-bank #context-drift #maintenance

## Problem
Memory Bank files (`context.md`, `architecture.md`) become outdated:
- Agents make incorrect assumptions
- Architecture diagrams don't match reality
- Recent changes not reflected
- Wasted time correcting agents

## Root Causes
1. Forgetting to update after significant changes
2. No reminder system in place
3. Unclear when updates are needed
4. Updates feel like extra work

## Solutions

### Prevention
1. **Git Hook Reminders** (Automated):
   ```bash
   # Already installed via:
   ~/.agent_global/hooks/install-all-projects.sh
   ```
   Hook reminds you after significant commits.

2. **Shell Alias** (Quick access):
   ```bash
   mbc  # Edit context.md quickly
   mbk  # Edit full Memory Bank
   ```

3. **Update Checklist** (In context.md template):
   - After merging feature branch
   - After architectural refactoring
   - After changing tech stack
   - Before long breaks (preserve context)

### Detection
Check for staleness:
```bash
mb-status  # Shows last modified dates

# In project directory:
git log -1 --format=%cd .agent/rules/memory-bank/
```

If context.md is >7 days old and you've had active commits, likely stale.

### Recovery
1. **Review recent commits**:
   ```bash
   git log --oneline --since="1 week ago"
   ```

2. **Update relevant files**:
   - Changes to code → `context.md`
   - Architecture changes → `architecture.md`
   - New dependencies → `tech.md`
   - Scope changes → `brief.md`

3. **Ask agent to help**:
   ```
   "Review the last 20 commits and suggest updates to context.md"
   ```

## Prevention Workflow
1. Make significant code changes
2. Git hook reminds you (automatic)
3. Run `mbc` to quickly update context
4. Commit Memory Bank updates separately:
   ```bash
   git add .agent/rules/memory-bank/
   git commit -m "docs: update Memory Bank context"
   ```

## Metrics
- **Healthy**: Context updated within 3 days of major changes
- **At Risk**: Context >7 days old with active development
- **Stale**: Context >2 weeks old OR mentions completed features as "upcoming"

## Related
- See: `~/.agent_global/hooks/post-commit-mb-reminder`
- Pattern: Memory Bank Pattern
