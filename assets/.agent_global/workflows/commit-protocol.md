---
description: Triggers when making code changes, file modifications, or any task that produces artifacts that should be version controlled. Ensures all changes are properly committed before task completion.
---

# Execution & Commit Protocol

**Restriction**: A task is **NOT** "done" until the code is safely committed.

## Workflow
1. **Verify**: Ensure changes are correct and tests pass.
2. **Stage**: `git add .`
3. **Commit**: `git commit -m "<type>(<scope>): <description>"`
4. **Retry**: If commit fails, FIX and RETRY immediately.

## Commit Message Format
`<type>(<scope>): <description>`

### Commit Types
| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, white-space |
| `refactor` | Code change (no fix/feat) |
| `perf` | Performance improvement |
| `test` | Adding/fixing tests |
| `chore` | Build/tools maintenance |

## Commit Recommendation
After completing changes, **commit to git** before using `attempt_completion` when the project has a git repository. If committing fails or the project is not git-tracked, note this to the user but do not block task completion.
