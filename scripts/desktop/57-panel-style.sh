#!/bin/bash
# =============================================================================
# 57-panel-style.sh - Panel Colorizer: accent islands + state-aware presets
# =============================================================================
# Styles the vertical dock via Panel Colorizer (installed by 55-widgets.sh).
#
# Mechanism (read from the plasmoid source, config/main.xml + ui/main.qml):
#   - The whole style lives in ONE config key `globalSettings` (JSON string);
#     applying a preset = writing the preset's settings.json globalSettings
#     into that key + setting `lastPreset` to the preset DIRECTORY path.
#   - `presetAutoloading` (JSON string) switches presets by panel state; keys
#     (priority order in code/utils.js): fullscreenWindow, maximized,
#     touchingWindow, activeWindow, visibleWindows, floating, activity,
#     normal. Values = preset directory paths.
#
# Chosen style (Hải 2026-08-19, deep-research vòng 3):
#   normal      -> "Outline Accent" — accent-outlined widget islands; the
#                  accent IS Mocha Mauve (kdeglobals), so it theme-syncs free
#   maximized   -> "Solid" — calm readable bar while a window is maximized
#   fullscreen  -> "Transparent" — panel is covered anyway; zero visual noise
#
# CONVERGE POLICY: config is applied only when `lastPreset` is unset/foreign
# (fresh install or reset). After that the GUI (right-click panel -> Configure
# Panel Colorizer) is the source of truth for style tweaks — appletsrc is in
# backup Section 9a, so tweaks survive recovery. Delete the `lastPreset` key
# (or run with FORCE_PANEL_STYLE=1) to re-apply the declared style.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 57: panel style (Colorizer islands)"

PC_ID="luisbocanegra.panel.colorizer"
PRESET_ROOT="$HOME/.local/share/plasma/plasmoids/$PC_ID/contents/ui/presets"
BASE_PRESET="$PRESET_ROOT/Outline Accent"
MAX_PRESET="$PRESET_ROOT/Solid"
FS_PRESET="$PRESET_ROOT/Transparent"

for d in "$BASE_PRESET" "$MAX_PRESET" "$FS_PRESET"; do
    [[ -d "$d" ]] || { log_error "Preset missing: $d (Panel Colorizer not installed?)"; exit 1; }
done

# Compact JSON payloads (python handles the JS-string-literal escaping layer).
# PATCH over the stock preset (Hải 2026-08-19: stock "Outline Accent" disables
# the native panel background -> the vertical bar went washed-white over the
# bright wallpaper): keep the accent widget islands, but paint the panel a
# dark Mocha translucent glass (custom #1e1e2e @ 0.85) with blur behind.
GLOBAL_JSON="$(python3 -c '
import json,sys
with open(sys.argv[1]) as f: data=json.load(f)
g = data["globalSettings"]
p = g["panel"]["normal"]
p["enabled"] = True
p["blurBehind"] = True
bc = p["backgroundColor"]
bc.update({"enabled": True, "sourceType": 0, "custom": "#1e1e2e", "alpha": 0.85})
print(json.dumps(json.dumps(g, separators=(",",":"))))
' "$BASE_PRESET/settings.json")"

AUTOLOAD_JSON="$(python3 -c '
import json,sys
cfg={"enabled":True,"normal":sys.argv[1],"maximized":sys.argv[2],"fullscreenWindow":sys.argv[3]}
print(json.dumps(json.dumps(cfg, separators=(",",":"))))
' "$BASE_PRESET" "$MAX_PRESET" "$FS_PRESET")"

RESULT="$(plasma_script '
const FORCE = '"${FORCE_PANEL_STYLE:-0}"' === 1;
var out = "no-colorizer";
for (const p of panels()) {
    const ws = p.widgets("luisbocanegra.panel.colorizer");
    if (ws.length === 0) continue;
    const w = ws[0];
    w.currentConfigGroup = [];
    const cur = w.readConfig("lastPreset", "");
    if (!FORCE && cur === "'"$BASE_PRESET"'") { out = "already"; continue; }
    w.writeConfig("isEnabled", true);
    w.writeConfig("globalSettings", '"$GLOBAL_JSON"');
    w.writeConfig("lastPreset", "'"$BASE_PRESET"'");
    w.writeConfig("presetAutoloading", '"$AUTOLOAD_JSON"');
    out = "applied";
}
print(out);
')"

case "$RESULT" in
    applied)      log_success "Panel style applied: Outline Accent + state-aware autoload (Solid/Transparent)" ;;
    already)      log_success "OK  panel style already applied (GUI is source of truth for tweaks)" ;;
    no-colorizer) log_warn "Panel Colorizer widget not found in any panel — run 55-widgets.sh first"; exit 1 ;;
    *)            log_warn "Unexpected result: $RESULT" ;;
esac
