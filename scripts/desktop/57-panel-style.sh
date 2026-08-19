#!/bin/bash
# =============================================================================
# 57-panel-style.sh - Panel Colorizer: Dock preset, no state auto-switching
# =============================================================================
# Styles the vertical dock via Panel Colorizer (installed by 55-widgets.sh).
#
# Mechanism (read from the plasmoid source, config/main.xml + ui/main.qml):
#   - The whole style lives in ONE config key `globalSettings` (JSON string);
#     applying a preset = writing the preset's settings.json globalSettings
#     into that key + setting `lastPreset` to the preset DIRECTORY path.
#   - The widget reads/writes its config in group [Configuration][General] —
#     scripting MUST set currentConfigGroup = ["General"]. The first version
#     of this script wrote with currentConfigGroup = [] which lands in the
#     [Configuration] root: those keys are ignored by the widget at runtime
#     (stale copies may linger there; harmless).
#
# Chosen style (Hải 2026-08-19, revised same day):
#   preset "Dock" (patched: panel margin/padding off — see GLOBAL_JSON below),
#   presetAutoloading DISABLED.
#   History: v1 shipped Outline Accent + state-aware autoload (Solid on
#   maximized, Transparent on fullscreen). Hải then picked "Dock" in the GUI
#   and the autoloader kept clobbering it back on every window-state change —
#   that IS what autoload does, but it means the GUI preset choice never
#   sticks. Verdict: one preset always, GUI stays source of truth.
#
# CONVERGE POLICY: config is applied only when `lastPreset` is unset/foreign
# (fresh install or reset). After that the GUI (right-click panel -> Configure
# Panel Colorizer) is the source of truth for style tweaks — appletsrc is in
# backup Section 9a, so tweaks survive recovery. Run with FORCE_PANEL_STYLE=1
# to re-apply the declared style.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 57: panel style (Colorizer Dock preset)"

PC_ID="luisbocanegra.panel.colorizer"
PRESET_ROOT="$HOME/.local/share/plasma/plasmoids/$PC_ID/contents/ui/presets"
BASE_PRESET="$PRESET_ROOT/Dock"

[[ -d "$BASE_PRESET" ]] || { log_error "Preset missing: $BASE_PRESET (Panel Colorizer not installed?)"; exit 1; }

# Dock preset PATCHED: panel margin (4px) + padding (2px) disabled.
# In a vertical panel the clock auto-font fills the applet width; the theme
# SVG already eats ~16px of the 56px thickness, and Dock's own insets took
# another 12px, shrinking the clock to ~28px (unreadable — Hải 2026-08-19).
# Margins off -> clock gets 40px, matching how other presets render it.
# python handles the JS-string-literal escaping layer (double json.dumps).
GLOBAL_JSON="$(python3 -c '
import json,sys
with open(sys.argv[1]) as f: data=json.load(f)
g = data["globalSettings"]
g["panel"]["normal"]["margin"]["enabled"] = False
g["panel"]["normal"]["padding"]["enabled"] = False
print(json.dumps(json.dumps(g, separators=(",",":"))))
' "$BASE_PRESET/settings.json")"

RESULT="$(plasma_script '
const FORCE = '"${FORCE_PANEL_STYLE:-0}"' === 1;
var out = "no-colorizer";
for (const p of panels()) {
    const ws = p.widgets("luisbocanegra.panel.colorizer");
    if (ws.length === 0) continue;
    const w = ws[0];
    w.currentConfigGroup = ["General"];
    const cur = w.readConfig("lastPreset", "");
    if (!FORCE && cur !== "") { out = "already"; continue; }
    w.writeConfig("isEnabled", true);
    w.writeConfig("globalSettings", '"$GLOBAL_JSON"');
    w.writeConfig("lastPreset", "'"$BASE_PRESET"'");
    w.writeConfig("presetAutoloading", "{\"enabled\":false}");
    out = "applied";
}
print(out);
')"

case "$RESULT" in
    applied)      log_success "Panel style applied: Dock preset, autoload off" ;;
    already)      log_success "OK  panel has a preset (GUI is source of truth; FORCE_PANEL_STYLE=1 to reset to Dock)" ;;
    no-colorizer) log_warn "Panel Colorizer widget not found in any panel — run 55-widgets.sh first"; exit 1 ;;
    *)            log_warn "Unexpected result: $RESULT" ;;
esac
