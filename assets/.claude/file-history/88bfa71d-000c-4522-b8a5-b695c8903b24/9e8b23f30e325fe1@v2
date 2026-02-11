# Claude Auto Memory Strategy

This file defines what should be stored in Claude's auto memory vs other knowledge systems.

## Three-Layer Knowledge Architecture

```
┌─────────────────────────────────────────────────┐
│  AUTO MEMORY (Session-Specific)                │
│  ~/.claude/projects/*/memory/MEMORY.md         │
│  • User preferences & communication style      │
│  • Cross-session debugging insights            │
│  • Temporary patterns & workarounds            │
└─────────────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────────────┐
│  MEMORY BANK (Project-Specific)                │
│  .agent/rules/memory-bank/*.md                 │
│  • Project architecture & structure            │
│  • Business logic & requirements               │
│  • Technical decisions & rationale             │
│  • Current workstreams & recent changes        │
└─────────────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────────────┐
│  AGENT GLOBAL (All Projects)                   │
│  ~/.agent_global/rules/ & workflows/           │
│  • Behavioral guidelines for all agents        │
│  • Workflows & protocols                       │
│  • Cross-project patterns & learnings          │
└─────────────────────────────────────────────────┘
```

## What Goes in Auto Memory (HERE)

### ✅ DO Store
1. **User Communication Preferences**
   - Preferred language (Vietnamese/English)
   - Response style preferences
   - Level of detail desired

2. **Cross-Session Insights**
   - Debugging patterns noticed across sessions
   - User's common workflows
   - Frequently used commands or approaches

3. **Temporary Context**
   - In-progress experiments
   - Temporary workarounds (before proper fix)
   - Session-specific notes

4. **Meta-Learnings**
   - What kind of explanations user finds helpful
   - Which approaches user prefers
   - Mistakes to avoid (session-specific)

### ❌ DO NOT Store
1. **Project-Specific Information** → Goes in Memory Bank instead
   - Architecture details
   - Business requirements
   - Current project status
   - Technical decisions

2. **Stable Patterns** → Goes in Agent Global Knowledge instead
   - Reusable code patterns
   - Troubleshooting guides
   - Best practices

3. **Duplicate Information**
   - Don't copy Memory Bank content
   - Don't copy Agent Global rules
   - Reference them instead

## Token Optimization Principles

### Principle 1: Single Source of Truth
- Memory Bank is authoritative for project context
- Agent Global is authoritative for workflows
- Auto Memory fills gaps, doesn't duplicate

### Principle 2: Decay by Relevance
- Auto Memory should fade out stale info
- Memory Bank is actively maintained
- Agent Global is curated knowledge

### Principle 3: Load Order
1. Load Agent Global rules (behavioral foundation)
2. Load project CLAUDE.md + Memory Bank (project context)
3. Apply Auto Memory insights (session personalization)

## Practical Guidelines

### When You Learn Something New
```
Is it specific to this project?
├─ Yes → Update Memory Bank (.agent/rules/memory-bank/)
│
└─ No → Is it reusable across projects?
   ├─ Yes → Add to Agent Global Knowledge
   └─ No → Keep in Auto Memory (session-specific insight)
```

### Example Scenarios

**Scenario**: User prefers terse responses
→ **Auto Memory**: "User prefers concise answers without lengthy explanations"

**Scenario**: Wildtide uses Godot 4.x with specific camera system
→ **Memory Bank**: Update `tech.md` and `architecture.md` in Wildtide project

**Scenario**: Discovered a pattern for optimizing Godot tile maps
→ **Agent Global**: Add to `~/.agent_global/knowledge/patterns/godot-tilemap-optimization.md`

**Scenario**: Working on temporary feature flag for testing
→ **Auto Memory**: "Feature flag EXPERIMENTAL_MULTIPLAYER active for testing"

**Scenario**: User always wants git commits after major changes
→ **Agent Global**: Already in `commit-protocol.md` workflow

## Monitoring & Maintenance

### Health Checks
- Auto Memory should be <200 lines (guideline)
- Review quarterly and prune stale info
- Check for duplication with Memory Bank

### Red Flags
⚠️ Auto Memory contains:
- Project architecture diagrams → Move to Memory Bank
- Stable code patterns → Move to Agent Global
- Old temporary workarounds → Delete (if not needed)

## Current User Preferences

**Communication**:
- Language: Vietnamese preferred, English OK
- Style: Direct and practical, focus on ROI
- Priorities: Token optimization, efficiency, utility

**Workflow**:
- Uses Obsidian extensively (PARA method)
- Multi-agent environment (Claude, Antigravity, Kilo)
- Prefers Claude for complex work
- Values automation and smart defaults

**System**:
- OS: Fedora/Nobara Linux
- Shell: zsh
- Editor: [To be determined based on usage]
- Container: Podman available

## Related Documentation
- Memory Bank Protocol: `~/.claude/workflows/memory-bank-protocol.md`
- Agent Global Rules: `~/.claude/rules/CLAUDE.md`
- Knowledge Base: `~/.agent_global/knowledge/`
