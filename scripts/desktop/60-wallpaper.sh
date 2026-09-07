#!/bin/bash
# =============================================================================
# 60-wallpaper.sh - Static wallpaper (desktop + lock screen + login greeter)
# =============================================================================
# Round 6 replaced the video wallpaper with a still image. Reasons, in order:
#   1. Hải wanted a calmer desktop ("style nhất quán, tông suyệt tông") and the
#      wallpaper is now the SOURCE of the whole palette — see
#      assets/desktop/palette/palette.toml. A moving picture cannot be that.
#   2. It removes the single largest perf risk in the rice. The old setup had
#      to pause a video decoder on window state, keep an NVIDIA HW-decode env
#      drop-in, avoid AV1 (upstream #275 crashed plasmashell), strip audio
#      (#269 crashed WirePlumber) and dodge a suspend deadlock in the greeter
#      (#281). A JPEG has none of those failure modes and costs 0% GPU.
# The old video path is in git history (before round 6) if it is ever wanted.
#
# Four surfaces, one image:
#   desktop  -> org.kde.image via the PlasmaShell scripting API (applies live)
#   lock     -> the same image, darkened+blurred so the password field reads
#   greeter  -> plasmalogin, via a drop-in under /etc/plasmalogin.conf.d/
#   terminal -> a CROP of the same image, used as kitty's background_image
#               (crop parameters live in palette.toml [terminal])
#               (NEVER edit /etc/plasmalogin.conf — it carries [Autologin])
#
# The wallpaper is installed as a proper KDE wallpaper PACKAGE rather than a
# loose file so it shows up in the wallpaper picker and survives a GUI change.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 60: wallpaper (static)"

PALETTE_DIR="$PROJECT_ROOT/assets/desktop/palette"
read -r WP_NAME WP_FILE < <(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(d["name"], d["wallpaper"])' "$PALETTE_DIR/tokens.json")

SRC="$PROJECT_ROOT/assets/desktop/wallpapers/$WP_FILE"
[[ -f "$SRC" ]] || { log_error "Wallpaper missing: $SRC"; exit 1; }

PKG_DIR="$HOME/.local/share/wallpapers/$WP_NAME"
IMG_DIR="$PKG_DIR/contents/images"
DEST="$IMG_DIR/${WP_NAME}.jpg"
DIM="$PKG_DIR/contents/images_dark/${WP_NAME}-dim.jpg"
TERM_IMG="$PKG_DIR/contents/terminal/${WP_NAME}-terminal.jpg"

# --- 1. Install as a wallpaper package -----------------------------------------
ensure_dir "$IMG_DIR"
if cmp -s "$SRC" "$DEST"; then
    log_success "OK  wallpaper image up to date: $DEST"
else
    install -m 644 "$SRC" "$DEST"
    log_success "SET wallpaper image -> $DEST"
fi

if [[ ! -f "$PKG_DIR/metadata.json" ]] || ! grep -q "\"Id\": \"$WP_NAME\"" "$PKG_DIR/metadata.json"; then
    cat > "$PKG_DIR/metadata.json" <<EOF
{
    "KPlugin": {
        "Id": "$WP_NAME",
        "Name": "$WP_NAME",
        "License": "See assets/desktop/wallpapers.manifest",
        "Authors": [ { "Name": "workstation-setup" } ]
    },
    "KPackageStructure": "Wallpaper/Images"
}
EOF
    log_success "SET wallpaper package metadata"
else
    log_success "OK  wallpaper package metadata present"
fi

# --- 2. Darkened variant for lock screen / greeter -----------------------------
# The desktop can afford a bright picture (widgets sit on translucent cards);
# a login field cannot. Blur + a brightness cut keeps the same image reading as
# the same place without fighting the text on top of it.
ensure_dir "$(dirname "$DIM")"
if [[ -f "$DIM" ]] && [[ "$DIM" -nt "$DEST" ]]; then
    log_success "OK  darkened variant up to date"
elif check_command ffmpeg; then
    ffmpeg -loglevel error -y -i "$DEST" \
        -vf "scale=2560:-1,gblur=sigma=18,eq=brightness=-0.10:saturation=0.9" \
        -frames:v 1 -q:v 3 "$DIM"
    log_success "SET darkened variant -> $DIM"
else
    log_warn "ffmpeg missing — lock screen will use the plain image"
    DIM="$DEST"
fi
[[ -f "$DIM" ]] || DIM="$DEST"

# --- 2b. Terminal crop ---------------------------------------------------------
# kitty draws this instead of being translucent. A window that lets the desktop
# through sounds nicer than it looks here: this picture is nearly black, so the
# glass showed almost nothing, and any window underneath bled into the text
# (Hải, 2026-09-07). A fixed crop shows the sun, which is the one thing worth
# seeing, and never changes with what is behind the window.
#
# Pillow rather than ffmpeg: the crop is anchored on a point (the sun) that has
# to be able to land in a corner, which means padding the source when the frame
# runs off its edge — expressible in four lines of numpy, awkward in a filter
# graph. ffmpeg still does the lock-screen blur above, where no such maths is
# needed.
ensure_dir "$(dirname "$TERM_IMG")"
if [[ -f "$TERM_IMG" && "$TERM_IMG" -nt "$DEST" && "$TERM_IMG" -nt "$PALETTE_DIR/tokens.json" ]]; then
    log_success "OK  terminal crop up to date"
else
    python3 - "$DEST" "$TERM_IMG" "$PALETTE_DIR/tokens.json" <<'PY'
import json, sys
import numpy as np
from PIL import Image

src_path, out_path, tokens_path = sys.argv[1:4]
cfg = json.load(open(tokens_path)).get("terminal") or {}
if not cfg:
    print("no [terminal] block in palette.toml — skipping"); sys.exit(0)

W, H = 2560, 1440                      # the screen this rice is built for
zoom = float(cfg["zoom"])
fx, fy = (float(v) for v in cfg["focus"])
ax, ay = (float(v) for v in cfg["anchor"])

src = np.asarray(Image.open(src_path).convert("RGB"))
sh, sw = src.shape[:2]
cw, ch = int(sw / zoom), int(sh / zoom)
x0, y0 = int(fx * sw - ax * cw), int(fy * sh - ay * ch)

# The anchor can pull the frame past the top/left edge (it does for any focus
# point left of anchor*width). Mirror the source there rather than clamping:
# clamping would silently move the subject away from the corner it was placed in.
pad_l, pad_t = max(0, -x0), max(0, -y0)
pad_r, pad_b = max(0, x0 + cw - sw), max(0, y0 + ch - sh)
if pad_l or pad_t or pad_r or pad_b:
    src = np.pad(src, ((pad_t, pad_b), (pad_l, pad_r), (0, 0)), mode="reflect")
    x0 += pad_l
    y0 += pad_t

crop = Image.fromarray(src[y0:y0 + ch, x0:x0 + cw]).resize((W, H), Image.LANCZOS)
crop.save(out_path, "JPEG", quality=90, optimize=True)
print(f"{W}x{H} from {cw}x{ch} at ({x0},{y0})")
PY
    log_success "SET terminal crop -> $TERM_IMG"
fi

# --- 3. Desktop ----------------------------------------------------------------
CUR_PLUGIN="$(plasma_script 'print(desktops()[0].wallpaperPlugin);' 2>/dev/null | tr -d '\r\n')"
CUR_IMG="$(plasma_script '
const d = desktops()[0];
d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
print(d.readConfig("Image"));' 2>/dev/null | tr -d '\r\n')"

if [[ "$CUR_PLUGIN" == "org.kde.image" && "$CUR_IMG" == "file://$DEST" ]]; then
    log_success "OK  desktop wallpaper already $WP_NAME"
else
    plasma_script "
for (const d of desktops()) {
    d.wallpaperPlugin = 'org.kde.image';
    d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    d.writeConfig('Image', 'file://$DEST');
    d.writeConfig('FillMode', 2);          // 2 = scaled and cropped
}" >/dev/null
    log_success "SET desktop wallpaper -> $WP_NAME (was ${CUR_PLUGIN:-unset})"
fi

# Retire the video-wallpaper HW-decode environment drop-in from round 1-5.
OLD_ENV="$HOME/.config/environment.d/50-video-wallpaper.conf"
if [[ -f "$OLD_ENV" ]]; then
    rm -f "$OLD_ENV"
    log_success "Removed stale video-wallpaper env drop-in: $OLD_ENV"
fi

# --- 4. Lock screen ------------------------------------------------------------
kset kscreenlockerrc Greeter WallpaperPlugin org.kde.image
kset kscreenlockerrc "Greeter/Wallpaper/org.kde.image/General" Image "file://$DIM"

# --- 5. plasmalogin greeter (root; drop-in only) -------------------------------
if sudo -n true 2>/dev/null; then
    sudo install -Dm644 "$DIM" /usr/local/share/rice/login.jpg
    sudo install -Dm644 /dev/stdin /etc/plasmalogin.conf.d/50-rice.conf <<'EOF'
[Greeter]
WallpaperPluginId=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/local/share/rice/login.jpg
EOF
    log_success "plasmalogin greeter wallpaper -> /usr/local/share/rice/login.jpg"
else
    log_warn "sudo unavailable — skipping plasmalogin greeter wallpaper"
    log_info "Manual: sudo install -Dm644 $DIM /usr/local/share/rice/login.jpg"
    log_info "        then re-run this stage (it writes /etc/plasmalogin.conf.d/50-rice.conf)"
fi
