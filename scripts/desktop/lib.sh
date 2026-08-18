#!/bin/bash
# =============================================================================
# lib.sh - Shared helpers for the desktop rice stages (scripts/desktop/*.sh)
# =============================================================================
# Sourced by every stage AFTER common.sh. Provides:
#   kset FILE GROUP[/SUBGROUP...] KEY VALUE [TYPE]
#       Idempotent kwriteconfig6: reads first, writes (with --notify) only when
#       the value differs. Group nesting via "/" (no KDE group here uses "/").
#   kdel FILE GROUP[/SUBGROUP...] KEY
#       Delete a key if present.
#   plasma_script "JS"
#       Run JS through plasmashell's scripting API (applies live, no restart).
#   qdbus_cmd
#       Resolved qdbus binary (qdbus vs qdbus6 across Fedora releases).
# =============================================================================

qdbus_cmd() {
    if command -v qdbus >/dev/null 2>&1; then echo qdbus
    elif command -v qdbus6 >/dev/null 2>&1; then echo qdbus6
    else return 1; fi
}

_kgroups() {
    # "$1" = slash-separated group path -> echoes --group args (one per line-safe array)
    local IFS='/'
    local -a parts
    read -ra parts <<< "$1"
    for g in "${parts[@]}"; do
        printf -- '--group\n%s\n' "$g"
    done
}

kset() {
    local file="$1" grouppath="$2" key="$3" value="$4" type="${5:-}"
    local -a gargs
    mapfile -t gargs < <(_kgroups "$grouppath")

    local cur
    cur="$(kreadconfig6 --file "$file" "${gargs[@]}" --key "$key" 2>/dev/null || true)"
    if [[ "$cur" == "$value" ]]; then
        log_success "OK  $file [$grouppath] $key = $value"
        return 0
    fi

    local -a targs=()
    [[ -n "$type" ]] && targs=(--type "$type")
    kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" "${targs[@]}" --notify "$value"
    log_success "SET $file [$grouppath] $key: '${cur:-<unset>}' -> '$value'"
}

kdel() {
    local file="$1" grouppath="$2" key="$3"
    local -a gargs
    mapfile -t gargs < <(_kgroups "$grouppath")
    local cur
    cur="$(kreadconfig6 --file "$file" "${gargs[@]}" --key "$key" 2>/dev/null || true)"
    if [[ -n "$cur" ]]; then
        kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" --delete
        log_success "DEL $file [$grouppath] $key (was '$cur')"
    fi
}

plasma_script() {
    local js="$1" qd
    qd="$(qdbus_cmd)" || { log_warn "qdbus not found — cannot reach plasmashell"; return 1; }
    "$qd" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js"
}

kwin_reconfigure() {
    local qd
    qd="$(qdbus_cmd)" || return 0
    "$qd" org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
}

# Restart plasmashell (flushes its config on TERM). The session USUALLY
# auto-respawns it, but not always (observed 2026-08-18 on a double restart)
# — so wait, then start it ourselves if it stayed dead.
plasma_restart() {
    local pid
    pid="$(pgrep -x plasmashell || true)"
    [[ -n "$pid" ]] && kill -TERM "$pid"
    for _ in {1..8}; do
        sleep 1
        if pgrep -x plasmashell >/dev/null; then return 0; fi
    done
    log_warn "plasmashell did not auto-respawn — starting it"
    (kstart plasmashell >/dev/null 2>&1 &)
    sleep 3
    pgrep -x plasmashell >/dev/null
}
