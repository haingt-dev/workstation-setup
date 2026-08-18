#!/bin/bash
# =============================================================================
# 60-wallpaper.sh - Video wallpaper (Smart Video Wallpaper Reborn)
# =============================================================================
# The point of the whole rice: animated wallpaper with ZERO perf cost while
# gaming. PauseMode=0 (MaximizedOrFullScreen) is the hard requirement.
#
# Facts this script encodes (verified 2026-08-18, plugin 2.9.0 / Plasma 6.7):
#   - Plugin id: luisbocanegra.smart.video.wallpaper.reborn (nobara repo pkg)
#   - Enums from upstream code/enum.js:
#       PauseMode: 0=MaximizedOrFullScreen 1=ActiveWindowPresent 2=WindowVisible 3=Never
#       MuteMode:  5=Always     BlurMode: 5=Never
#   - VideoUrls = JSON array of {filename:"file://...",enabled,duration,...}
#   - AV1 videos CRASH plasmashell (upstream #275) -> H.264/VP9 only, enforced
#     by assets/desktop/README.md. Audio stripped at source (#269: the plugin's
#     PipeWire nodes can crash WirePlumber).
#   - ScreenOffPausesVideo stays false: its ScreenStateCmd default is an Intel
#     laptop path and the comparison format is unverified; PauseMode=0 suffices.
#   - Lock screen gets a STILL image, never the video plugin: upstream #281
#     (OPEN) = NVIDIA UVM suspend deadlock with HW decode inside the greeter.
#   - plasmalogin: wallpaper only (still image, org.kde.image). Video on the
#     greeter is broken on 2.9.0 (#291). Config via /etc/plasmalogin.conf.d/,
#     never by editing /etc/plasmalogin.conf (carries [Autologin]).
#
# Empty/missing ~/Videos/wallpapers -> the plugin switch is SKIPPED entirely
# (org.kde.image stays), so a fresh machine never gets a broken black desktop.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 60: video wallpaper"

VIDEO_DIR="$HOME/Videos/wallpapers"
STILL_DIR="$HOME/Pictures/wallpapers"
STILL_IMG="$STILL_DIR/catppuccin-still.png"
PLUGIN_ID="luisbocanegra.smart.video.wallpaper.reborn"

# --- HW decode environment (picked up by plasmashell at next login) -----------
# CUDA_DISABLE_PERF_BOOST=1: without it nvidia-vaapi-driver clocks the GPU up
# and burns MORE power than CPU decode (needs driver >=580.105; box has 595.91).
# Escape hatch if suspend ever hangs (upstream #281 on desktop too):
#   QT_FFMPEG_DECODING_HW_DEVICE_TYPES=,   (forces software decode)
ENV_FILE="$HOME/.config/environment.d/50-video-wallpaper.conf"
ensure_dir "$(dirname "$ENV_FILE")"
DESIRED_ENV='QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi,cuda,vdpau
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
CUDA_DISABLE_PERF_BOOST=1'
if [[ -f "$ENV_FILE" ]] && [[ "$(cat "$ENV_FILE")" == "$DESIRED_ENV" ]]; then
    log_success "OK  HW-decode env already in place: $ENV_FILE"
else
    printf '%s\n' "$DESIRED_ENV" > "$ENV_FILE"
    log_success "SET HW-decode env: $ENV_FILE (takes effect at next login)"
fi

# --- Still image (lock screen + plasmalogin fallback) --------------------------
# Generated Catppuccin Mocha gradient (base #1e1e2e -> surface0 #313244).
ensure_dir "$STILL_DIR"
if [[ ! -f "$STILL_IMG" ]]; then
    if check_command ffmpeg; then
        ffmpeg -loglevel error -y -f lavfi \
            -i "gradients=s=2560x1440:c0=#1e1e2e:c1=#313244:x0=0:y0=0:x1=2560:y1=1440:n=2" \
            -frames:v 1 "$STILL_IMG"
        log_success "Generated Catppuccin still image: $STILL_IMG"
    else
        log_warn "ffmpeg missing — no still image for lock screen (skip)"
    fi
else
    log_success "OK  still image exists: $STILL_IMG"
fi

# --- Lock screen: still image, keep Nobara's no-autolock behavior --------------
if [[ -f "$STILL_IMG" ]]; then
    kset kscreenlockerrc Greeter WallpaperPlugin org.kde.image
    kset kscreenlockerrc "Greeter/Wallpaper/org.kde.image/General" Image "file://$STILL_IMG"
fi

# --- plasmalogin greeter wallpaper (needs root; drop-in, never the main conf) --
if [[ -f "$STILL_IMG" ]] && sudo -n true 2>/dev/null; then
    sudo install -Dm644 "$STILL_IMG" /usr/local/share/rice/login.png
    sudo install -Dm644 /dev/stdin /etc/plasmalogin.conf.d/50-rice.conf <<'EOF'
[Greeter]
WallpaperPluginId=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/local/share/rice/login.png
EOF
    log_success "plasmalogin greeter wallpaper -> /usr/local/share/rice/login.png"
else
    log_warn "sudo unavailable or no still image — skipping plasmalogin wallpaper"
    log_info "Manual: sudo install -Dm644 $STILL_IMG /usr/local/share/rice/login.png"
    log_info "        + drop-in /etc/plasmalogin.conf.d/50-rice.conf (see this script)"
fi

# --- Desktop video wallpaper ---------------------------------------------------
ensure_dir "$VIDEO_DIR"
shopt -s nullglob
VIDEOS=("$VIDEO_DIR"/*.mp4 "$VIDEO_DIR"/*.webm)
shopt -u nullglob

if [[ ${#VIDEOS[@]} -eq 0 ]]; then
    log_warn "No videos in $VIDEO_DIR — keeping current (static) wallpaper."
    log_info "Add H.264/VP9 loops (NEVER AV1 — crashes plasmashell) then re-run:"
    log_info "  bash scripts/desktop/60-wallpaper.sh   # sources: see assets/desktop/README.md"
    exit 0
fi

# Build the VideoUrls JSON (a String config holding a JSON array) and embed it
# as a JS string literal — python handles both layers of escaping.
JS="$(python3 - "$VIDEO_DIR" <<'PY'
import json, sys, glob, os
d = sys.argv[1]
files = sorted(glob.glob(os.path.join(d, "*.mp4")) + glob.glob(os.path.join(d, "*.webm")))
urls = json.dumps([{"filename": "file://" + f, "enabled": True, "duration": 0,
                    "customDuration": 0, "playbackRate": 0.0,
                    "alternativePlaybackRate": 0.0, "loop": True} for f in files])
print("""
for (const d of desktops()) {
    d.wallpaperPlugin = 'luisbocanegra.smart.video.wallpaper.reborn';
    d.currentConfigGroup = ['Wallpaper','luisbocanegra.smart.video.wallpaper.reborn','General'];
    d.writeConfig('VideoUrls', %s);
    d.writeConfig('PauseMode', 0);
    d.writeConfig('MuteMode', 5);
    d.writeConfig('BlurMode', 5);
    d.writeConfig('Volume', 0);
    d.writeConfig('ScreenOffPausesVideo', false);
    d.writeConfig('BatteryPausesVideo', true);
    d.writeConfig('CheckWindowsActiveScreen', true);
    d.writeConfig('CrossfadeEnabled', false);
    d.writeConfig('DebugEnabled', false);
    d.writeConfig('EffectsPauseVideo', 'overview,windowview,showdesktop');
}""" % json.dumps(urls))
PY
)"

plasma_script "$JS" >/dev/null
log_success "Video wallpaper active: ${#VIDEOS[@]} video(s), PauseMode=MaximizedOrFullScreen"
log_info "Perf check: nvidia-smi --query-gpu=utilization.decoder --format=csv -l 1"
log_info "  (decoder >0% on idle desktop, MUST drop to 0% when a window is maximized)"
