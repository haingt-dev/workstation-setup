#!/bin/bash
# =============================================================================
# awake-guard.sh — block auto-suspend while remote (mosh/SSH) sessions exist
# =============================================================================
#
# Why: Plasma 6 PowerDevil suspends after 15 min without LOCAL input — remote
# SSH/mosh activity does NOT reset the idle timer, so the host sleeps under
# your fingers mid-iPad-session and drops off the tailnet (looks identical to
# a crash from Termius). Bit three times: 2026-07-07 + 2026-07-08, then
# 2026-07-10 AGAIN because v1 of this guard detected sessions via who(1) and
# went blind to mosh (see Detection below).
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
# Detection is PROCESS-based: a live mosh-server = an open mosh session; an
# OpenSSH >=9.8 "sshd-session: user [priv]" monitor = a live SSH connection.
# Do NOT detect via who(1)/utmp: on Fedora 43 `who` (coreutils >=9.4, Y2038
# utmp deprecation) reads logind sessions instead of /run/utmp — a mosh
# session NEVER appears there (its SSH bootstrap logind session is TTY-less
# and goes State=closing the moment mosh-server is spawned; the mosh pty
# lives only in deprecated utmp). Plain SSH *does* show up in who, which is
# how the who-based v1 passed its ssh-only E2E test yet suspended the host
# mid-mosh on 2026-07-10 14:07.
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
REMOTE_KIND=""

remote_active() {
    # mosh: a live mosh-server IS an open session. MOSH_SERVER_NETWORK_TMOUT
    # (assets/.zshenv) reaps abandoned servers, so this signal self-clears.
    if pgrep -x mosh-server >/dev/null 2>&1; then
        REMOTE_KIND="mosh"
        return 0
    fi
    # ssh: OpenSSH >=9.8 keeps one root "sshd-session: <user> [priv]" monitor
    # per live connection — incl. exec-channel (scp/rsync), which spawns NO
    # "user@..." titled process (verified on 10.0p1). Interactive sessions
    # add "sshd-session: user@pts/N"; match either. Pre-auth probes title as
    # "unknown [priv]" and can false-positive for ≤LoginGraceTime — accepted:
    # port 22 is tailnet/LAN-only and the guard fails toward staying awake.
    if pgrep -f '^sshd-session: .* \[priv\]' >/dev/null 2>&1 \
        || pgrep -f '^sshd-session: .*@' >/dev/null 2>&1; then
        REMOTE_KIND="ssh"
        return 0
    fi
    return 1
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
            echo "inhibit ON ($REMOTE_KIND session detected)"
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
