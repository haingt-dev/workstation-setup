#!/bin/bash
# =============================================================================
# display_setup.sh - NVIDIA + DisplayPort EDID-loss mitigation
# =============================================================================
#
# THE BUG (diagnosed 2026-06-28, brain discovery 4db7e40bc653):
#   On NVIDIA + DisplayPort + Wayland, when the monitor wakes (from DPMS idle
#   blank OR system resume) it asserts Hot-Plug-Detect BEFORE its DDC/I²C bus is
#   ready. The NVIDIA driver reads DDC immediately, gets nothing, caches a fake
#   stub EDID (manufacturer "NVD", year 1990, ONLY 640x480) and never retries.
#   Result: the desktop collapses to 640x480 with no other mode until a physical
#   hot-plug (power-cycle the monitor / replug the DP cable). Confirmed unpatched
#   NVIDIA regression across the 590.x–595.x driver series (forum thread 370243,
#   exact match: Fedora + driver 595.71.05). NOT a config error, NOT Nobara.
#
# DEAD ENDS on nvidia-drm (do NOT chase — confirmed ignored by the driver):
#   drm.edid_firmware=...  /  video=DP-3:e  /  echo detect > .../status
#   Adding nvidia-suspend/resume systemd services would be HARMFUL (Nobara uses
#   kernel suspend notifiers — NVreg_UseKernelSuspendNotifiers=1).
#
# WHAT THIS SCRIPT DOES (the two zero-risk layers that kill the frequent case):
#   Layer 1 (hardware — REMINDER only, cannot be scripted): monitor OSD
#           "Auto Power OFF: OFF" so the panel keeps its DDC bus alive.
#   Layer 2 (automated): KDE "turn off screen" -> never, so the display is never
#           DPMS-blanked on idle -> the wake race never fires.
#   Layer 3 (needs root): a systemd-sleep hook that pre-sets the connector's
#         debugfs edid_override before sleep and nudges KWin on resume if the
#         EDID still came back broken — for the system-suspend case. Source:
#         scripts/display/nvidia-dp-edid.sleep.sh. The debugfs edid_override is
#         the one injection path that has a hook on nvidia-drm (drm.edid_firmware
#         is a no-op there). Efficacy self-logs to /var/log/nvidia-dp-edid.log.
#
# Idempotent. Layers 1-2 + EDID need no sudo; Layer 3 install uses sudo if
# available (skipped with manual instructions otherwise).
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

# Effectively-never idle time, in seconds (~3.17 years). The KDE GUI shows this
# as a large minute value; to make it read literally "Never", toggle once in
# System Settings -> Power Management -> Energy Saving -> Turn off screen.
NEVER_IDLE=100000000
EDID_REPO="$BACKUP_DIR/edid/dp3-gigabyte-m27q.bin"   # committed known-good EDID
EDID_RUNTIME="$HOME/.local/share/edid/dp3-good.bin"  # where a future Layer 3 reads

log_section "Display Setup (NVIDIA DisplayPort EDID-loss mitigation)"

# -----------------------------------------------------------------------------
# Applicability guard — this fix targets NVIDIA GPUs only.
# -----------------------------------------------------------------------------
if ! lspci -nnk 2>/dev/null | grep -qiE 'vga|3d|display' || ! lspci -nnk 2>/dev/null | grep -iA3 -E 'vga|3d|display' | grep -qi nvidia; then
    log_info "No NVIDIA GPU detected — the EDID-loss bug is NVIDIA-specific. Skipping."
    exit 0
fi
log_info "NVIDIA GPU detected — applying DisplayPort EDID-loss mitigation."

# -----------------------------------------------------------------------------
# Layer 2 — KDE: never DPMS-blank the screen (AC profile). Idempotent.
# -----------------------------------------------------------------------------
if check_command kwriteconfig6; then
    PM_FILE="powermanagementprofilesrc"
    CUR="$(kreadconfig6 --file "$PM_FILE" --group AC --group DPMSControl --key idleTime 2>/dev/null || echo "")"

    if [[ "$CUR" == "$NEVER_IDLE" ]]; then
        log_success "KDE screen-blank already disabled (idleTime=$CUR)"
    else
        # Back up the live config once before mutating it.
        LIVE="$HOME/.config/$PM_FILE"
        if [[ -f "$LIVE" ]]; then
            cp -f "$LIVE" "$LIVE.pre-display-setup.$(date +%Y%m%d-%H%M%S).bak"
            log_info "Backed up $PM_FILE (was idleTime='${CUR:-default}')"
        fi
        kwriteconfig6 --file "$PM_FILE" --group AC --group DPMSControl --key idleTime "$NEVER_IDLE"
        log_success "KDE 'turn off screen' set to never (idleTime=$NEVER_IDLE)"

        # Apply live without a re-login if powerdevil is running.
        if check_command qdbus && qdbus org.kde.Solid.PowerManagement >/dev/null 2>&1; then
            qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement \
                org.kde.Solid.PowerManagement.reparseConfiguration >/dev/null 2>&1 || true
            log_success "powerdevil reloaded (applied live)"
        else
            log_info "powerdevil not reachable — change applies on next login"
        fi
    fi
else
    log_warn "kwriteconfig6 not found — not a KDE session? Skipping Layer 2."
fi

# -----------------------------------------------------------------------------
# EDID stewardship — keep a known-good EDID on disk for a future Layer 3.
# -----------------------------------------------------------------------------
# Find the currently-connected DisplayPort connector + its live EDID size.
LIVE_DP=""
LIVE_EDID_SIZE=0
for s in /sys/class/drm/card*-DP-*/status; do
    [[ -r "$s" ]] || continue
    if [[ "$(cat "$s" 2>/dev/null)" == "connected" ]]; then
        d="$(dirname "$s")"
        LIVE_DP="$(basename "$d")"
        LIVE_EDID_SIZE="$(wc -c < "$d/edid" 2>/dev/null || echo 0)"
        break
    fi
done

if [[ -f "$EDID_REPO" ]]; then
    ensure_dir "$(dirname "$EDID_RUNTIME")"
    cp -f "$EDID_REPO" "$EDID_RUNTIME"
    log_success "Known-good EDID staged: $EDID_RUNTIME ($(stat -c%s "$EDID_RUNTIME") bytes)"
elif [[ -n "$LIVE_DP" && "$LIVE_EDID_SIZE" -ge 128 ]]; then
    # No committed EDID yet, but the live one is healthy — capture it so the repo
    # carries it going forward. (Commit assets/edid/ afterwards.)
    ensure_dir "$(dirname "$EDID_REPO")"
    cp -f "/sys/class/drm/$LIVE_DP/edid" "$EDID_REPO"
    log_success "Captured live EDID from $LIVE_DP -> $EDID_REPO ($(stat -c%s "$EDID_REPO") bytes) — commit it"
else
    log_warn "No committed EDID and no healthy live EDID to capture (skip)"
fi

# -----------------------------------------------------------------------------
# Layer 3 — auto-recovery for the system-suspend case (needs root).
# Installs the known-good EDID + a systemd-sleep hook (pre: set edid_override;
# post: nudge KWin if EDID came back broken). Self-logs to /var/log.
# -----------------------------------------------------------------------------
HOOK_SRC="$SCRIPT_DIR/display/nvidia-dp-edid.sleep.sh"
if sudo -n true 2>/dev/null; then
    if [[ -f "$EDID_REPO" ]]; then
        sudo install -D -m644 "$EDID_REPO" /usr/local/share/nvidia-dp-edid/dp3-good.bin
        log_success "Installed known-good EDID -> /usr/local/share/nvidia-dp-edid/dp3-good.bin"
    else
        log_warn "No committed EDID — Layer 3 hook will fall back to ~/.local/share/edid/"
    fi
    if [[ -f "$HOOK_SRC" ]]; then
        sudo install -m755 "$HOOK_SRC" /usr/lib/systemd/system-sleep/nvidia-dp-edid
        log_success "Installed systemd-sleep hook -> /usr/lib/systemd/system-sleep/nvidia-dp-edid"
        log_info "Layer 3 active on next suspend. Log: /var/log/nvidia-dp-edid.log"
    else
        log_warn "Hook source missing: $HOOK_SRC (skip Layer 3)"
    fi
else
    log_warn "sudo not available non-interactively — skipping Layer 3 auto-install."
    log_info "Install Layer 3 manually:"
    log_info "  sudo install -D -m644 $EDID_REPO /usr/local/share/nvidia-dp-edid/dp3-good.bin"
    log_info "  sudo install -m755 $HOOK_SRC /usr/lib/systemd/system-sleep/nvidia-dp-edid"
fi

# -----------------------------------------------------------------------------
# Layer 1 — hardware reminder (cannot be automated).
# -----------------------------------------------------------------------------
log_section "Display Setup complete"
echo ""
echo "  ┌─ MANUAL STEP (one-time, per monitor) ──────────────────────────────┐"
echo "  │ On the monitor's OSD menu, set 'Auto Power OFF' / 'DP Deep Sleep' / │"
echo "  │ 'Standby' to OFF. This keeps the DDC bus alive so the NVIDIA driver │"
echo "  │ can re-read EDID on wake. (Gigabyte M27Q: System -> Auto Power OFF) │"
echo "  └────────────────────────────────────────────────────────────────────┘"
echo ""
log_info "If the screen ever drops to 640x480: power-cycle the monitor (or replug DP)."
log_info "Health check:  wc -c < /sys/class/drm/${LIVE_DP:-card1-DP-3}/edid   # 384=healthy, 0=bug hit"
log_info "Layer 3 auto-recovery log: /var/log/nvidia-dp-edid.log  (design: brain 4db7e40bc653)"
