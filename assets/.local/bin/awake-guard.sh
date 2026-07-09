#!/bin/bash
# =============================================================================
# awake-guard.sh — block auto-suspend while remote (mosh/SSH) sessions exist
# =============================================================================
#
# Why: Plasma 6 PowerDevil suspends after 15 min without LOCAL input — remote
# SSH/mosh activity does NOT reset the idle timer, so the host sleeps under
# your fingers mid-iPad-session and drops off the tailnet (looks identical to
# a crash from Termius). Bit twice: 2026-07-07 + 2026-07-08.
#
# Division of labor (each layer covers a distinct gap):
#   - The Claude Code inhibit hooks (~/.claude/hooks/claude-inhibit-*.sh) hold
#     a sleep inhibitor while a task RUNS.
#   - THIS guard holds one while a remote session is OPEN (reading/thinking/
#     between prompts — shell idle but human active).
#   - MOSH_SERVER_NETWORK_TMOUT (assets/.zshenv) reaps stale mosh-servers so
#     a force-killed Termius can't hold the inhibitor forever.
# When neither applies, the PC auto-suspends normally (desired at home).
#
# Detection: mosh-server registers utmp as "mosh [pid]"; plain SSH shows the
# client IP (v4 or v6). Local sessions (:0, tty, tmux panes) never match.
# Poll is 15s; on remote login assets/.zshrc sends USR1 for an instant poll,
# closing the race where PowerDevil's idle deadline falls inside the nap.
#
# PowerDevil honors systemd inhibitors with mode=block ONLY: PolicyAgent
# imports logind inhibitors, skipping anything where mode != "block" —
# 'sleep' lock → InterruptSession policy (Plasma/6.6 source,
# daemon/powerdevilpolicyagent.cpp, checkLogindInhibitions). So --mode=block
# is required here; block-weak would be ignored. Side effect (accepted):
# while the lock is held, a MANUAL suspend (KDE menu / systemctl suspend) is
# also refused. Escape hatch: close the remote session, or
# `systemctl --user stop awake-guard`.
#
# Runs as a systemd user service (awake-guard.service, Restart=on-failure).
# Fail direction: if the guard dies, the machine may sleep (fail-open) — the
# unit restarts it within seconds; a stuck inhibitor can't outlive the unit
# (default cgroup kill on stop).
# =============================================================================

POLL_SEC=15
INHIBIT_PID=""

remote_active() {
    # who(1) host column: "(mosh [1234])", "(<ipv4>" or "(<ipv6>". The IPv6
    # branch requires a leading hex group so local display entries like "(:0)"
    # never match; tmux panes "(tmux(3150).%0)" match nothing either.
    who | grep -qE '\(mosh \[|\([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|\([0-9a-fA-F]{1,4}:[0-9a-fA-F:]+'
}

release() {
    if [[ -n "$INHIBIT_PID" ]]; then
        kill "$INHIBIT_PID" 2>/dev/null
        wait "$INHIBIT_PID" 2>/dev/null
        INHIBIT_PID=""
        echo "inhibit OFF (no remote sessions)"
    fi
}

trap 'release; exit 0' TERM INT
trap 'true' USR1   # login kick from assets/.zshrc: interrupt the nap, poll now

while true; do
    if remote_active; then
        if [[ -z "$INHIBIT_PID" ]] || ! kill -0 "$INHIBIT_PID" 2>/dev/null; then
            systemd-inhibit --what=sleep --mode=block \
                --who="awake-guard" \
                --why="Remote session (mosh/SSH) active" \
                sleep infinity &
            INHIBIT_PID=$!
            echo "inhibit ON ($(who | grep -oE '\(mosh \[[0-9]+\]|\([0-9.]+|\([0-9a-fA-F:]+' | tr '\n' ' '))"
        fi
    else
        release
    fi
    # Interruptible nap: USR1 (or any trapped signal) cuts it short so a fresh
    # remote login is noticed immediately instead of after up to POLL_SEC.
    sleep "$POLL_SEC" &
    NAP_PID=$!
    wait "$NAP_PID" 2>/dev/null || { kill "$NAP_PID"; wait "$NAP_PID"; } 2>/dev/null
done
