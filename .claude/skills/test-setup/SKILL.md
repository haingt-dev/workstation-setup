---
name: test-setup
description: Trace setup.sh execution without running it — dry-run analysis
argument-hint: "[--terminal|--godot|component]"
---

Trace setup.sh execution without running it — dry-run analysis.

If `$ARGUMENTS` provided (e.g., `--terminal`, `--godot`), focus on that component only.

1. **Read the scripts:**
   - `setup.sh` (orchestrator)
   - `scripts/common.sh` (shared utilities)
   - Each component script that would execute

2. **Trace execution path:** Determine:
   - Which component scripts run, in what order
   - Files copied/created/modified (source -> destination)
   - Packages installed
   - Commands executed

3. **Check for issues:**
   - Missing source files (every `cp`/`ln` target exists in `assets/`?)
   - Permission needs (sudo operations?)
   - Existing file conflicts (destination already exists?)
   - Package availability (`dnf info <pkg>` without installing)
   - Idempotency issues (`mkdir` without `-p`, `ln` without `-f`)

4. **Report per component:**
   - What it installs/configures
   - Source -> Destination file mappings
   - Dependencies satisfied?
   - Risk level (safe / caution / risky)

5. **Overall GO / NO-GO recommendation.**
