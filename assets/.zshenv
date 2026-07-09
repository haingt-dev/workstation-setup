# Sourced by EVERY zsh invocation (login, interactive, and the non-interactive
# `zsh -c` that sshd uses to launch mosh-server). Keep tiny: no output, nothing slow.

# mosh-server self-exits after 1h without client contact (force-killed Termius,
# iPad offline). Without this, a stale mosh-server keeps its utmp entry forever,
# awake-guard keeps holding the sleep inhibitor, and the PC never auto-suspends
# again. A running Claude task stays protected past the 1h reap by Claude Code's
# own inhibitor; tmux session `work` survives regardless — reconnecting re-attaches.
export MOSH_SERVER_NETWORK_TMOUT=3600
