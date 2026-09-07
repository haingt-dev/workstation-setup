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

# -----------------------------------------------------------------------------
# install_own_plasmoid ID
#   Install/update one of OUR plasmoids (assets/desktop/plasmoids/<ID>) and
#   echo "installed" | "updated" | "current".
#
# The package in the repo is deliberately INCOMPLETE: the colour tokens and the
# fullscreen/game guard are shared artefacts (assets/desktop/palette/Tokens.qml
# and assets/desktop/plasmoids/shared/GameGuard.qml) and would otherwise have to
# be duplicated into every package and kept in sync by hand. So the package is
# assembled into a staging directory first, and THAT is what kpackagetool6 sees.
#
# Idempotency uses `kpackagetool6 --hash`, which hashes the package CONTENT —
# no version bookkeeping, and an edit to any file (including the generated
# tokens) triggers exactly one update.
# -----------------------------------------------------------------------------
install_own_plasmoid() {
    local id="$1"
    local src="$PROJECT_ROOT/assets/desktop/plasmoids/$id"
    local shared="$PROJECT_ROOT/assets/desktop/plasmoids/shared"
    local tokens="$PROJECT_ROOT/assets/desktop/palette/Tokens.qml"
    local stage="$HOME/.cache/workstation-setup/plasmoid-build/$id"
    local installed="$HOME/.local/share/plasma/plasmoids/$id"

    [[ -d "$src" ]] || { log_error "Package source missing: $src"; return 1; }
    [[ -f "$tokens" ]] || { log_error "Missing $tokens — run scripts/desktop/gen-palette.sh"; return 1; }

    rm -rf "$stage"
    mkdir -p "$stage"
    cp -a "$src/." "$stage/"
    install -m 644 "$tokens" "$stage/contents/ui/Tokens.qml"
    install -m 644 "$shared/GameGuard.qml" "$stage/contents/ui/GameGuard.qml"

    local hash_src hash_dst
    hash_src="$(kpackagetool6 -t Plasma/Applet --hash "$stage" 2>/dev/null | grep -oE '[0-9a-f]{40}' || true)"
    hash_dst=""
    [[ -d "$installed" ]] && hash_dst="$(kpackagetool6 -t Plasma/Applet --hash "$installed" 2>/dev/null | grep -oE '[0-9a-f]{40}' || true)"

    if ! kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$id"; then
        kpackagetool6 -t Plasma/Applet -i "$stage" >/dev/null
        echo "installed"
    elif [[ -n "$hash_src" && "$hash_src" == "$hash_dst" ]]; then
        echo "current"
    else
        # -u refuses in some kpackagetool versions when the version string is
        # unchanged, so fall back to a clean remove+install.
        if ! kpackagetool6 -t Plasma/Applet -u "$stage" >/dev/null 2>&1; then
            kpackagetool6 -t Plasma/Applet -r "$id" >/dev/null 2>&1 || true
            kpackagetool6 -t Plasma/Applet -i "$stage" >/dev/null
        fi
        echo "updated"
    fi
}
