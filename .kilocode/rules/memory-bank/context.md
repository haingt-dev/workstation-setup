# Context

## Current Work Focus

- Initializing the Memory Bank for the `terminal-custom` project.
- Capturing high-level product intent, architecture, and technologies so future tasks can start with `[Memory Bank: Active]`.

## Recent Changes

- Created project brief describing goals, scope, and success criteria in [`brief.md`](./brief.md:1).
- Documented product-level behavior and UX flow in [`product.md`](./product.md:1).
- Confirmed core behavior and structure from:
  - [`README.md`](../../README.md:1)
  - [`setup.sh`](../../setup.sh:1)
  - Core scripts under [`scripts/`](../../scripts:1) and configuration under [`assets/`](../../assets:1).
- Added Vietnamese input support (`ibus-bamboo`) via `scripts/input_setup.sh` and updated `setup.sh` with `--vietnamese` flag.

## Next Steps

- Add architecture overview in [`architecture.md`](./architecture.md:1) describing:
  - Role of `setup.sh` as orchestrator.
  - Responsibilities of scripts in [`scripts/`](../../scripts:1).
  - Use of configuration and assets under [`assets/`](../../assets:1).
- Add technology summary in [`tech.md`](./tech.md:1) listing:
  - Languages (Bash), tools (dnf, Podman, VS Code, Godot, Qdrant, etc.).
  - Target platform (Nobara 42 / Fedora-based distros).
- Verify Memory Bank files for accuracy against current repository state.
- Commit Memory Bank initialization to version control as the new baseline.