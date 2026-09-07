#!/bin/bash
# =============================================================================
# awake-guard.sh — block auto-suspend while Claude Code is being used
# =============================================================================
#
# Why: Plasma 6 PowerDevil suspends after 15 min without LOCAL input. Reading a
# long answer, thinking between prompts, or driving a session from the phone via
# Claude Code's Remote Control all look like an idle machine to it — the host
# sleeps mid-conversation and the session goes offline.
#
# Division of labor (each layer covers a distinct gap):
#   - The Claude Code inhibit hooks (~/.claude/hooks/claude-inhibit-*.sh) hold a
#     sleep inhibitor while a turn RUNS. They cover the loud part.
#   - THIS guard holds one while a session is merely IN USE — the quiet part:
#     between turns, while you read, while the phone is in your hand.
#
# Detection is by TRANSCRIPT MTIME: Claude Code appends to
# ~/.claude/projects/<project>/<session>.jsonl on every message and tool result,
# so a file touched in the last WINDOW_MIN minutes means a live session. `find
# -print -quit` stops at the first hit — 3ms across 2200 files, cheap enough to
# poll. Nothing else on this box writes there.
#
# Accepted side effect: the machine stays awake for up to WINDOW_MIN minutes
# after the last Claude activity, and while the lock is held a MANUAL suspend
# (KDE menu / systemctl suspend) is refused too. Escape hatch:
# `systemctl --user stop awake-guard`.
#
# PowerDevil honors systemd inhibitors with mode=block ONLY: PolicyAgent imports
# logind inhibitors, skipping anything where mode != "block" — 'sleep' lock →
# InterruptSession policy (Plasma/6.6 source, daemon/powerdevilpolicyagent.cpp,
# checkLogindInhibitions). block-weak would be ignored.
#
# History: v1-v3 (2026-07) watched for remote mosh/SSH sessions, because the box
# was driven from an iPad over Tailscale. That stack was retired 2026-09-07 —
# Claude Code's own Remote Control replaced it — so the signal moved to the
# thing that is actually in use. The old who(1) trap is gone with it: v2 read
# logind sessions and never saw mosh at all (Fedora 43 coreutils >=9.4 dropped
# utmp), which is how it slept the host mid-session on 2026-07-10.
#
# Runs as a systemd user service (awake-guard.service, Restart=on-failure).
# Fail direction: if the guard dies, the machine may sleep (fail-open) — the
# unit restarts it within seconds; a stuck inhibitor can't outlive the unit
# (default cgroup kill on stop).
# =============================================================================

POLL_SEC=30
WINDOW_MIN=20
CLAUDE_PROJECTS="$HOME/.claude/projects"
INHIBIT_PID=""

claude_active() {
    [[ -d "$CLAUDE_PROJECTS" ]] || return 1
    [[ -n "$(find "$CLAUDE_PROJECTS" -name '*.jsonl' -mmin "-$WINDOW_MIN" -print -quit 2>/dev/null)" ]]
}

release() {
    if [[ -n "$INHIBIT_PID" ]]; then
        kill "$INHIBIT_PID" 2>/dev/null
        wait "$INHIBIT_PID" 2>/dev/null
        INHIBIT_PID=""
        echo "inhibit OFF (no Claude activity for ${WINDOW_MIN}m)"
    fi
}

trap 'release; exit 0' TERM INT

while true; do
    if claude_active; then
        if [[ -z "$INHIBIT_PID" ]] || ! kill -0 "$INHIBIT_PID" 2>/dev/null; then
            systemd-inhibit --what=sleep --mode=block \
                --who="awake-guard" \
                --why="Claude Code session in use" \
                sleep infinity &
            INHIBIT_PID=$!
            echo "inhibit ON (claude activity within ${WINDOW_MIN}m)"
        fi
    else
        release
    fi
    sleep "$POLL_SEC"
done
