---
name: validate
description: Dry-run prerequisite check for system setup (read-only, no changes)
argument-hint: "[component name]"
---

Validate all prerequisites for system setup (READ-ONLY, no changes).

If `$ARGUMENTS` provided, check only that component (e.g., `terminal`, `godot`, `agent`).

1. **System ID:**
   ```
   cat /etc/os-release
   uname -r
   ```
   Verify Nobara/Fedora-based.

2. **Check prerequisites per component** (read `setup.sh` and `scripts/common.sh` first):

   - **Terminal**: zsh, git, curl installed?
   - **Agent**: claude CLI, `~/Projects/agent/` exists?
   - **Godot**: godot binary or flatpak, gdformat/gdlint?
   - **Apps**: dnf, flatpak available?
   - **DNS**: current `cat /etc/resolv.conf`

3. **Check assets:** Verify `assets/` has expected config files:
   ```
   find assets/ -type f | head -30
   ```

4. **Conflict check:** Existing configs that would be overwritten?

5. **Report checklist:**
   | Component | Prerequisites | Status | Notes |
   Mark: READY, MISSING_DEPS, or SKIP.
