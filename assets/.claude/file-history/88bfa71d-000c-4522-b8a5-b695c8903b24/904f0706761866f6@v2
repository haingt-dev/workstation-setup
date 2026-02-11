# Memory Optimization Strategy

**Purpose**: Define clear boundaries between Auto Memory, Memory Bank, and Agent Global to optimize token usage and maintain clean knowledge architecture.

## The Three-Layer Architecture

### Layer 1: Agent Global (Behavioral Foundation)
**Location**: `~/.agent_global/`
**Scope**: All projects, all agents
**Purpose**: Behavioral guidelines, workflows, cross-project knowledge

**Contains**:
- `rules/global_rules.md` - Core behavioral guidelines
- `workflows/*.md` - Standard workflows (commit, memory-bank, etc.)
- `knowledge/` - Cross-project patterns, troubleshooting, learnings

**Update Frequency**: Rarely (when discovering new patterns)
**Loaded**: Start of every session (via CLAUDE.md reference)

### Layer 2: Memory Bank (Project Context)
**Location**: `.agent/rules/memory-bank/`
**Scope**: Project-specific
**Purpose**: Project architecture, current state, technical decisions

**Contains**:
- `brief.md` - Project goals and scope
- `product.md` - User needs and requirements
- `context.md` - Current focus and recent changes
- `architecture.md` - System structure
- `tech.md` - Stack and tooling

**Update Frequency**: After significant project changes
**Loaded**: Start of every task (via CLAUDE.md instruction)

### Layer 3: Auto Memory (Session Personalization)
**Location**: `~/.claude/projects/*/memory/MEMORY.md`
**Scope**: Cross-session, user-specific
**Purpose**: User preferences, temporary insights, session context

**Contains**:
- User communication preferences
- Cross-session debugging insights
- Temporary context and workarounds
- Meta-learnings about user workflow

**Update Frequency**: Automatically by Claude
**Loaded**: Automatically at session start

## Decision Tree: Where Does This Knowledge Go?

```
New knowledge discovered
    |
    ├─ Is it about user preferences or communication style?
    │  └─ YES → Auto Memory
    │
    ├─ Is it specific to current project?
    │  └─ YES → Memory Bank
    │     |
    │     ├─ Architecture/Structure → architecture.md
    │     ├─ Current work/status → context.md
    │     ├─ Tech stack/tools → tech.md
    │     ├─ Goals/scope → brief.md
    │     └─ User needs → product.md
    │
    └─ Is it reusable across projects?
       └─ YES → Agent Global Knowledge
          |
          ├─ Architectural pattern → knowledge/patterns/
          ├─ Troubleshooting guide → knowledge/troubleshooting/
          ├─ Step-by-step recipe → knowledge/recipes/
          └─ Lesson learned → knowledge/learnings/
```

## Token Optimization Principles

### 1. No Duplication
- Each piece of knowledge has ONE canonical location
- Other layers reference, not duplicate
- Example: Don't copy project architecture to Auto Memory

### 2. Load on Demand
- Agent Global: Loaded via symlinks (always available)
- Memory Bank: Loaded explicitly per CLAUDE.md
- Auto Memory: Loaded automatically by Claude

### 3. Right-Sized Context
- Agent Global: Concise behavioral rules (~1-2K tokens)
- Memory Bank: Comprehensive project context (~5-10K tokens)
- Auto Memory: Light personalization (~1-2K tokens)

### 4. Decay Management
- Agent Global: Curated, stable, versioned
- Memory Bank: Actively maintained, git-tracked
- Auto Memory: Auto-pruned by Claude, ephemeral OK

## For Agent Developers

### When Reading Memory
```
1. Load Agent Global (symlinked via ~/.claude/rules/CLAUDE.md)
2. Load project CLAUDE.md
3. Load Memory Bank files listed in CLAUDE.md
4. Apply Auto Memory insights (automatic)
```

### When Writing Memory
```
IF (session-specific insight about user)
    → Update Auto Memory (Claude handles this)

ELSE IF (project-specific information)
    → Update appropriate Memory Bank file
    → Show user: "Updated [file] with [change]"

ELSE IF (cross-project pattern)
    → Suggest adding to Agent Global Knowledge
    → Ask user: "Should I document this in Agent Global?"
```

### Memory Bank Update Protocol
After significant changes:
1. Identify what changed (architecture, scope, tech, status)
2. Determine which Memory Bank file(s) to update
3. Make atomic, clear updates
4. Commit separately:
   ```bash
   git add .agent/rules/memory-bank/
   git commit -m "docs: update Memory Bank [reason]"
   ```

## Anti-Patterns

### ❌ DON'T
1. **Duplicate across layers**
   - BAD: Copying project architecture to Auto Memory
   - GOOD: Reference Memory Bank from Auto Memory

2. **Store temporary info in permanent places**
   - BAD: Temporary debug notes in Memory Bank
   - GOOD: Temporary notes in Auto Memory, move if permanent

3. **Overwrite user preferences**
   - BAD: Assuming user wants verbose responses
   - GOOD: Read Auto Memory for communication preferences

4. **Ignore Memory Bank**
   - BAD: Asking user about project architecture (it's in Memory Bank!)
   - GOOD: Load Memory Bank, reference it

5. **Create giant MEMORY.md**
   - BAD: 1000-line Auto Memory file
   - GOOD: Concise Auto Memory, move stable info to right layer

## Success Metrics

### Healthy System
- ✅ Memory Bank updated within 3 days of major changes
- ✅ Auto Memory <200 lines
- ✅ Agent Global knowledge grows slowly and deliberately
- ✅ Minimal context re-explanation needed
- ✅ Cross-agent consistency (all agents see same Memory Bank)

### Unhealthy System
- ❌ Agents repeatedly asking same questions
- ❌ Contradictory information across layers
- ❌ Stale Memory Bank (>1 week old with active development)
- ❌ Giant Auto Memory files (>500 lines)
- ❌ Duplicate information across layers

## Maintenance

### Weekly
- Review Auto Memory for stale temporary context
- Check Memory Bank is current (via `mb-status`)

### Monthly
- Review Agent Global knowledge for obsolete patterns
- Prune unused recipes or outdated troubleshooting

### Quarterly
- Audit for duplication across layers
- Update this strategy document if patterns emerge

## Tools

### Shell Aliases
- `mbk` - Edit Memory Bank
- `mbc` - Quick edit context.md
- `mb-status` - Check Memory Bank freshness
- `ag-rules` - Edit Agent Global rules

### Scripts
- `~/.agent_global/bootstrap-project.sh` - Setup new project
- `~/.agent_global/sync-obsidian.sh` - Sync with Obsidian
- `~/.agent_global/hooks/post-commit-mb-reminder` - Update reminder

## Related Documentation
- Agent Global Hub: `~/.agent_global/README.md`
- Setup Guide: `~/.agent_global/SETUP.md`
- Memory Bank Protocol: `~/.claude/workflows/memory-bank-protocol.md`
- Auto Memory: `~/.claude/projects/-home-haint/memory/MEMORY.md`
