# Claude Code — Systems Migration

## Project Values
- Be precise about system operations — always specify which distro/version a command targets
- Explain **why** before **how** when suggesting system changes
- **Idempotency** — Scripts must be safe to re-run. No destructive overwrites, use backups and conditionals
- **Caution with system operations** — This modifies the actual development environment. A broken config means lost productivity. Double-check before executing
- **Nobara/Fedora first** — All solutions should target Fedora-based systems. Don't assume Ubuntu/Debian conventions

### Boundaries
- Get explicit approval before `rm -rf` on system directories or dotfiles
- Explain consequences before modifying `/etc/` files
- Prefer `dnf` over manual installations. Prefer Flatpak for GUI apps when available
- Test scripts in dry-run mode when possible before live execution
