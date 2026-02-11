---
description: Triggers when starting any task that involves code changes, architecture decisions, or project context. Reads Memory Bank files to ground the agent in project context before proceeding.
---

# Memory Bank Protocol

## Read on Start
At the start of **EVERY** task, read the following files from `.agent/rules/memory-bank/` to ground yourself in the project context:
- `brief.md` — Project goals and scope
- `product.md` — Product context and constraints
- `context.md` — Current focus, active workstreams, recent changes
- `architecture.md` — System architecture and structure
- `tech.md` — Tech stack and tooling

## Initialization
If the Memory Bank directory (`.agent/rules/memory-bank/`) is missing or incomplete, proactively offer to initialize it for the user by creating the missing files with appropriate content based on what you can observe about the project.

## Source of Truth
When in doubt about project scope, architecture, or coding style, refer to the Memory Bank files. They are the authoritative source of project context shared between all agents (Kilo Code and Antigravity).
