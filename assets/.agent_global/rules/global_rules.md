# Global Rules

## Memory Bank Loading
**CRITICAL**: At the **start of every new task**, you **MUST** read the Memory Bank files in `.agent/rules/memory-bank/` before doing any work.

**Procedure**:
1. Read all available files in `.agent/rules/memory-bank/` (e.g., `brief.md`, `product.md`, `context.md`, `architecture.md`, `tech.md`).
2. Evaluate whether the loaded information is **relevant and useful** for the current task.
3. If the memory bank provides useful context, load it into your context window and display **`[memory bank active]`** at the beginning of your first response.
4. If the memory bank files are empty, missing, or not relevant to the current task, proceed normally without the indicator.

**Why**: This ensures continuity across sessions — you always start with the latest project knowledge rather than working from scratch.

## Memory Bank Maintenance
**CRITICAL**: After making significant architectural changes or completing major tasks, you **MUST** update the Memory Bank files in `.agent/rules/memory-bank/` (especially `context.md`) to reflect the current state. This ensures both Kilo Code and Antigravity agents stay synchronized.

**Location**: `.agent/rules/memory-bank`

**Files to maintain**:
- `brief.md` — Project goals and scope
- `product.md` — Product context and constraints
- `context.md` — Current focus, active workstreams, recent changes
- `architecture.md` — System architecture and structure
- `tech.md` — Tech stack and tooling

**When to update**:
- After completing a major task or feature
- After making architectural or structural changes
- After adding/modifying significant tooling or dependencies
- When `context.md` becomes stale or inaccurate
