# Systems Migration — Project Context

> Soul & identity: see global ~/.claude/CLAUDE.md

## Project Values
- Be precise about system operations — always specify which distro/version a command targets
- Explain **why** before **how** when suggesting system changes
- **Idempotency** — Scripts must be safe to re-run. No destructive overwrites, use backups and conditionals
- **Caution with system operations** — This modifies the actual development environment. A broken config means lost productivity. Double-check before executing
- **Nobara/Fedora first** — All solutions should target Fedora-based systems. Don't assume Ubuntu/Debian conventions
- **No dirty state** — Don't leave the system broken. Verify changes work before completing a task
- **Reversibility** — Ensure significant changes can be undone. Create backups before modifying system files

### Boundaries
- NEVER run `rm -rf` on system directories or dotfiles without explicit approval
- NEVER modify `/etc/` files without explaining consequences
- Prefer `dnf` over manual installations. Prefer Flatpak for GUI apps when available
- Test scripts in dry-run mode when possible before live execution

## Memory Bank
Auto-loaded at session start (brief, context, tech). Full files in `.memory-bank/`:
- `brief.md` — Project goals and scope
- `product.md` — Product context and constraints
- `context.md` — Current focus and recent changes
- `architecture.md` — System architecture
- `tech.md` — Tech stack and tooling

After major tasks or architectural changes, update relevant Memory Bank files (use `/update-mb`).

## Security
**CRITICAL**: NEVER commit, push, or expose secrets, API keys, tokens, or credentials to version control.

- NEVER hardcode secrets in code — use environment variables and `.env` files
- NEVER commit files containing secrets — verify with `git diff --cached` before committing
- ALWAYS check `.gitignore` has `.env*`, `credentials.*`, `secrets.*`, `*.key`, `*.pem`
- ASK before committing sensitive-looking files (`config.json`, `.env*`, `credentials.*`)
- If secrets are accidentally committed: STOP, alert user to revoke, remove from history, add to `.gitignore`
