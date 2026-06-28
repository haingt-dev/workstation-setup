#!/bin/bash
# =============================================================================
# nvidia-dp-edid.sleep.sh — systemd-sleep hook (Layer 3 auto-recovery)
# Installed to: /usr/lib/systemd/system-sleep/nvidia-dp-edid
# =============================================================================
#
# Recovers from the NVIDIA DisplayPort stub-EDID bug (desktop collapses to
# 640x480 after resume; /sys/.../edid goes empty). See brain 4db7e40bc653.
#
# systemd calls this as:  <script> pre  suspend     (before sleeping)
#                         <script> post suspend     (after resuming)
#
# pre  : write the known-good EDID into the connector's debugfs edid_override,
#        so it is already in place BEFORE the resume probe (preventive — works
#        IF nvidia-drm honours the override on probe).
# post : if the EDID still came back broken, nudge KWin (disable+enable the
#        output) to force a re-read (reactive). Only acts when ALREADY broken,
#        so it can never make a healthy display worse. Everything is logged.
#
# Notes: drm.edid_firmware / video= / 'echo detect' are confirmed no-ops on
# nvidia-drm — debugfs edid_override is the one injection path that has a hook.
# =============================================================================

PHASE="$1"   # pre | post
LOG=/var/log/nvidia-dp-edid.log
EDID_FILE=""
for c in /usr/local/share/nvidia-dp-edid/dp3-good.bin /home/haint/.local/share/edid/dp3-good.bin; do
    [ -r "$c" ] && { EDID_FILE="$c"; break; }
done
DESKTOP_USER=haint

log() { echo "$(date '+%F %T') [${PHASE}] $*" >> "$LOG" 2>/dev/null; }

# --- locate the connected DisplayPort connector + its debugfs override path ---
find_connector() {
    SYS_CONN="" CONN_NAME="" DBG_OVERRIDE=""
    local s d
    for s in /sys/class/drm/card*-DP-*/status; do
        [ -r "$s" ] || continue
        [ "$(cat "$s" 2>/dev/null)" = "connected" ] || continue
        SYS_CONN="$(dirname "$s")"
        CONN_NAME="$(basename "$SYS_CONN")"; CONN_NAME="${CONN_NAME#card*-}"   # -> DP-3
        break
    done
    [ -n "$CONN_NAME" ] || return 1
    for d in /sys/kernel/debug/dri/*/"$CONN_NAME"/edid_override; do
        [ -e "$d" ] && { DBG_OVERRIDE="$d"; break; }
    done
    return 0
}

edid_size() { cat "$1/edid" 2>/dev/null | wc -c; }

case "$PHASE" in
  pre)
    find_connector || { log "no connected DP connector"; exit 0; }
    if [ -n "$DBG_OVERRIDE" ] && [ -n "$EDID_FILE" ]; then
        if cat "$EDID_FILE" > "$DBG_OVERRIDE" 2>/dev/null; then
            log "override pre-set on $CONN_NAME from $EDID_FILE"
        else
            log "FAILED to write override on $CONN_NAME"
        fi
    else
        log "skip pre-set (override path='$DBG_OVERRIDE' edid='$EDID_FILE')"
    fi
    ;;

  post)
    # Run the recovery detached so we never delay resume completion.
    (
        sleep 3
        find_connector || { log "no connected DP connector"; exit 0; }
        BEFORE="$(edid_size "$SYS_CONN")"

        if [ "${BEFORE:-0}" -ge 128 ]; then
            log "healthy on resume (${BEFORE}B) on $CONN_NAME — no action"
            exit 0
        fi

        log "BROKEN on resume (${BEFORE}B) on $CONN_NAME — re-asserting override + nudging KWin"
        [ -n "$DBG_OVERRIDE" ] && [ -n "$EDID_FILE" ] && cat "$EDID_FILE" > "$DBG_OVERRIDE" 2>/dev/null

        # Nudge KWin in the user's Wayland session to force a re-read/modeset.
        UID_N="$(id -u "$DESKTOP_USER" 2>/dev/null)"
        RT="/run/user/${UID_N}"
        WL="$(ls "$RT" 2>/dev/null | grep -m1 '^wayland-[0-9]$')"
        if [ -n "$UID_N" ] && [ -n "$WL" ]; then
            RUN=(sudo -u "$DESKTOP_USER" env XDG_RUNTIME_DIR="$RT" WAYLAND_DISPLAY="$WL" \
                 DBUS_SESSION_BUS_ADDRESS="unix:path=${RT}/bus")
            "${RUN[@]}" kscreen-doctor "output.$CONN_NAME.disable" >>"$LOG" 2>&1
            sleep 1
            "${RUN[@]}" kscreen-doctor "output.$CONN_NAME.enable"  >>"$LOG" 2>&1
            sleep 2
            AFTER="$(edid_size "$SYS_CONN")"
            MODES="$("${RUN[@]}" kscreen-doctor -o 2>/dev/null | grep -oc '@')"
            log "after nudge on $CONN_NAME: edid=${AFTER}B modes=${MODES}"
            [ "${AFTER:-0}" -lt 128 ] && log "STILL BROKEN — power-cycle the monitor (debugfs override not honoured)"
        else
            log "could not reach user session (uid='$UID_N' wl='$WL') — skipped KWin nudge"
        fi
    ) >/dev/null 2>&1 &
    ;;
esac

exit 0
