# Memory Bank Pattern

**Category**: Project Organization
**Tags**: #documentation #context #agents

## Problem
AI agents lose context between sessions, leading to:
- Repeated questions about project goals
- Re-explaining architecture decisions
- Inconsistent coding patterns
- Wasted tokens on re-establishing context

## Solution
Maintain a structured Memory Bank in `.agent/rules/memory-bank/` with:
- `brief.md` - Project goals and scope
- `product.md` - User needs and requirements
- `context.md` - Current state and recent changes
- `architecture.md` - System structure and patterns
- `tech.md` - Stack and tooling decisions

## Implementation
1. Bootstrap with templates:
   ```bash
   bootstrap /path/to/project
   ```

2. Load at start of every session (agent responsibility)

3. Update after significant changes:
   - Architecture refactoring
   - Major feature completion
   - Technology changes
   - Scope adjustments

## Benefits
- ✅ Agents maintain context across sessions
- ✅ Faster onboarding for new contributors
- ✅ Consistent understanding across multiple agents
- ✅ Token-efficient (load once vs re-explain repeatedly)

## When to Use
- Any project that will be worked on by AI agents
- Projects with multiple contributors
- Long-running projects (>1 week)
- Projects that need cross-agent consistency

## Related
- See: `~/.agent_global/templates/memory-bank/`
- Used in: All current projects (Wildtide, chimera-protocol, etc.)
