# Project Brief: Terminal Custom Setup

## Purpose

- Provide a reproducible, automated way to configure a personalized
  terminal and development environment on Nobara 42 and Fedora-based systems.
- Restore backed-up dotfiles, fonts, and GUI configuration for key tools
  such as Kitty, tmux, Starship, Atuin, and VS Code.
- Install and wire up supporting developer tools (containers, editors,
  vector DB, game engine, and productivity apps) that match the
  original workstation.

## Primary Goals

1. One-command bootstrap via [`setup.sh`](../../setup.sh:1) that can be run
   on a fresh Nobara/Fedora installation by a non-root user with sudo.
2. Core terminal experience is configured consistently using assets in
   [`assets/`](../../assets:1) and scripts in [`scripts/`](../../scripts:1).
3. Minimize interactive prompts during setup so the process can run mostly
   unattended.
4. Keep all customizations version-controlled so they can evolve safely
   over time.

## Scope

- Shell environment: Zsh, Starship, Atuin, plugins, history, and dotfiles.
- Terminal UX: Kitty configuration, Catppuccin themes, and tmux with TPM.
- Developer productivity: power tools (zoxide, eza, bat, fzf, ripgrep,
  fd-find, lazygit, yazi).
- Editor and tooling: VS Code (settings, extensions), Godot, Qdrant,
  container runtime (Podman), and selected desktop applications.
- Fonts: installation of Nerd Fonts and JetBrains Mono into the user
  font directory.

## Out of Scope

- Managing OS-level upgrades or distro changes beyond basic `dnf update`.
- Supporting non-Fedora-based distributions.
- Managing secrets, SSH keys, or cloud credentials.
- Opinionated application data (browser profiles, dotfiles not tracked
  in [`assets/`](../../assets:1)).

## Success Criteria

- A new Nobara/Fedora system can be brought to a working, familiar
  environment by running `./setup.sh` with minimal manual steps.
- Rerunning scripts is idempotent enough not to break an existing
  installation (safe backups and copy semantics).
- Configuration is centralized under this repository so future changes
  are made here and then applied via re-run or incremental scripts.