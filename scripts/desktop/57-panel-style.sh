#!/bin/bash
# =============================================================================
# 57-panel-style.sh - Panel Colorizer: Dock preset + solid-on-maximized
# =============================================================================
# Styles the vertical dock via Panel Colorizer (installed by 55-widgets.sh).
#
# Mechanism (read from the plasmoid source, config/main.xml + ui/main.qml):
#   - The whole style lives in ONE config key `globalSettings` (JSON string);
#     applying a preset = writing the preset's settings.json globalSettings
#     into that key + setting `lastPreset` to the preset DIRECTORY path.
#   - The widget reads/writes its config in group [Configuration][General] —
#     scripting MUST set currentConfigGroup = ["General"].
#   - Preset autoloading (utils.js getPresetName): on every panel-state change
#     it picks a preset by priority fullscreenWindow > maximized >
#     touchingWindow > ... > normal and RE-READS settings.json from the preset
#     DIRECTORY. Two consequences: (a) any state we autoload must exist as a
#     preset on disk — runtime-patched globalSettings would be lost on the
#     first state flip; (b) the `normal` entry must BE the look Hải wants,
#     otherwise autoload "clobbers" his choice (the v1 bug).
#   - User presets live in ~/.config/panel-colorizer/presets/<Name>/ (the same
#     dir the GUI reads and saves to — confirmed in configPresets.qml).
#
# Chosen style (Hải 2026-08-19/20, 3rd revision):
#   normal    -> user preset "Dock Slim"  = shipped Dock + margin/padding off
#                (the margins shrank the auto-fit clock — see 20-theme.sh)
#   maximized -> user preset "Dock Solid" = Dock Slim + opaque Mocha base
#                (#1e1e2e custom hex, alpha 1, radius off, blur off) so the
#                dock visually merges with maximized windows instead of
#                showing the wallpaper next to them.
#   Custom hex instead of "follow system colors" on purpose: that follow
#   feature broke on the Plasma 6.3.4 update (colorizer issue #212) and this
#   rice hardcodes Catppuccin anyway. True window-color sampling does not
#   exist on Plasma 6/Wayland (KWin scripting exposes no window pixels) —
#   deep-research 2026-08-20, wf_128e6a0d.
#   History: v1 = Outline Accent + autoload (clobbered Hải's GUI pick because
#   autoload `normal` differed from it); v2 = Dock patched + autoload OFF;
#   v3 (this) = autoload back ON but `normal` IS the chosen look, so nothing
#   clobbers. Fullscreen windows cover the panel entirely — no entry needed.
#
# CONVERGE POLICY: the two preset FILES are declared artefacts of this script
# and always converge (Hải: tweak them via the GUI's save-preset, then sync
# the change back here — or Save As a new name and re-point autoloading).
# The live widget config (`presetAutoloading`, `globalSettings`, `lastPreset`)
# is applied only when autoloading is still unset/disabled; after that the
# GUI is the source of truth (appletsrc is in backup Section 9a). Run with
# FORCE_PANEL_STYLE=1 to re-apply the declared config.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 57: panel style (Dock Slim / Dock Solid + autoload)"

PC_ID="luisbocanegra.panel.colorizer"
BASE_PRESET="$HOME/.local/share/plasma/plasmoids/$PC_ID/contents/ui/presets/Dock"
USER_PRESETS="$HOME/.config/panel-colorizer/presets"
SLIM_DIR="$USER_PRESETS/Dock Slim"
SOLID_DIR="$USER_PRESETS/Dock Solid"
SOLID_HEX="#1e1e2e"   # Catppuccin Mocha base — matches themed window bodies

[[ -d "$BASE_PRESET" ]] || { log_error "Preset missing: $BASE_PRESET (Panel Colorizer not installed?)"; exit 1; }

# --- 1. Generate the two user presets (always converge — declared files) ------
ensure_dir "$SLIM_DIR"
ensure_dir "$SOLID_DIR"
python3 - "$BASE_PRESET/settings.json" "$SLIM_DIR/settings.json" "$SOLID_DIR/settings.json" "$SOLID_HEX" <<'EOF'
import json, sys
base, slim_out, solid_out, hex_color = sys.argv[1:5]
with open(base) as f: data = json.load(f)

def write_if_changed(path, obj):
    txt = json.dumps(obj, indent=2)
    try:
        if open(path).read() == txt: return False
    except FileNotFoundError:
        pass
    with open(path, "w") as f: f.write(txt)
    return True

n = data["globalSettings"]["panel"]["normal"]
n["margin"]["enabled"] = False    # insets shrank the auto-fit clock
n["padding"]["enabled"] = False
slim_changed = write_if_changed(slim_out, data)

bc = n["backgroundColor"]
bc["sourceType"] = 0              # 0 = custom color (preset "Black" reference)
bc["custom"] = hex_color
bc["alpha"] = 1
n["blurBehind"] = False           # opaque — blur is dead weight
n["radius"]["enabled"] = False    # square corners: flush strip next to window
solid_changed = write_if_changed(solid_out, data)

print(("regenerated" if slim_changed or solid_changed else "unchanged"))
EOF
PRESET_STATE="$(python3 -c "
import json,sys
for p in ['$SLIM_DIR/settings.json','$SOLID_DIR/settings.json']:
    json.load(open(p))
print('ok')" 2>/dev/null || echo bad)"
[[ "$PRESET_STATE" == "ok" ]] || { log_error "Generated preset JSON invalid"; exit 1; }
log_success "User presets converged: 'Dock Slim' + 'Dock Solid' ($SOLID_HEX)"

# --- 2. Point the widget at them (only when autoload still unset/disabled) ----
GLOBAL_JSON="$(python3 -c '
import json,sys
print(json.dumps(json.dumps(json.load(open(sys.argv[1]))["globalSettings"], separators=(",",":"))))
' "$SLIM_DIR/settings.json")"

AUTOLOAD_JSON="$(python3 -c "
import json
print(json.dumps(json.dumps({'enabled': True,
    'normal': '$SLIM_DIR',
    'maximized': '$SOLID_DIR'}, separators=(',',':'))))")"

RESULT="$(plasma_script '
const FORCE = '"${FORCE_PANEL_STYLE:-0}"' === 1;
var out = "no-colorizer";
for (const p of panels()) {
    const ws = p.widgets("luisbocanegra.panel.colorizer");
    if (ws.length === 0) continue;
    const w = ws[0];
    w.currentConfigGroup = ["General"];
    var auto = {};
    try { auto = JSON.parse(w.readConfig("presetAutoloading", "{}")); } catch (e) {}
    if (!FORCE && auto.enabled === true) { out = "already"; continue; }
    w.writeConfig("isEnabled", true);
    w.writeConfig("globalSettings", '"$GLOBAL_JSON"');
    w.writeConfig("lastPreset", "'"$SLIM_DIR"'");
    w.writeConfig("presetAutoloading", '"$AUTOLOAD_JSON"');
    out = "applied";
}
print(out);
')"

case "$RESULT" in
    applied)      log_success "Autoload set: normal='Dock Slim', maximized='Dock Solid' (needs plasmashell restart to pick up)" ;;
    already)      log_success "OK  autoloading already enabled (GUI is source of truth; FORCE_PANEL_STYLE=1 to reset)" ;;
    no-colorizer) log_warn "Panel Colorizer widget not found in any panel — run 55-widgets.sh first"; exit 1 ;;
    *)            log_warn "Unexpected result: $RESULT" ;;
esac
