# Desktop Rice — Wallpaper Videos

Video wallpapers live in **`~/Videos/wallpapers/`** — never in this repo (a 4K
60s loop is 20–150 MB; git would be ruined). `wallpapers.manifest` records the
source of every video so disaster recovery can re-download them, then re-run
`bash scripts/desktop/60-wallpaper.sh`.

## Hard rules for video files

- **Codec: H.264 or VP9 ONLY. Never AV1** — AV1/libdav1d leaks memory and
  hard-crashes plasmashell (plugin issue #275). Check: `ffprobe -v quiet
  -show_streams file.webm | grep codec_name`.
- **No audio track** — the plugin's PipeWire audio nodes can crash WirePlumber
  and kill system audio (issue #269). Strip on download:
  `ffmpeg -i in.mp4 -c:v copy -an out.mp4`
- Convert an AV1 download:
  `ffmpeg -i in.webm -c:v libx264 -crf 20 -preset slow -an out.mp4`

## Sources

- https://moewalls.com — per-resolution MP4/WebM downloads
- https://www.desktophut.com
- Self-generated loops (see manifest for the ffmpeg command).

## Plugin version pin

Nobara ships `plasma-smart-video-wallpaper-reborn` **2.9.0** (upstream is
2.14.0, 2026-08). Accepted drift — the pause-on-fullscreen feature is stable
since 1.x. Do **not** install the KDE-Store/upstream copy alongside: it shadows
`/usr/share` from `~/.local/share` and dnf updates silently become no-ops.
Re-check the gap when Nobara rebases.

Known landmines on 2.9.0 + NVIDIA Wayland (details in `scripts/desktop/60-wallpaper.sh`):
video on lock screen / plasmalogin = broken or suspend-deadlock (#281, #291) —
both intentionally get still images; if suspend ever hangs with the desktop
video running, set `QT_FFMPEG_DECODING_HW_DEVICE_TYPES=,` in
`~/.config/environment.d/50-video-wallpaper.conf` (software decode).
