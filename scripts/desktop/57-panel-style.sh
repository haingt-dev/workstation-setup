#!/bin/bash
# =============================================================================
# 57-panel-style.sh - Panel Colorizer: one "Dock Slim" preset, no autoload
# =============================================================================
# Styles the vertical dock via Panel Colorizer (installed by 55-widgets.sh).
#
# Mechanism (read from the plasmoid source, config/main.xml + ui/main.qml):
#   - The whole style lives in ONE config key `globalSettings` (JSON string);
#     applying a preset = writing the preset's settings.json globalSettings
#     into that key + setting `lastPreset` to the preset DIRECTORY path.
#   - The widget reads/writes its config in group [Configuration][General] —
#     scripting MUST set currentConfigGroup = ["General"].
#   - User presets live in ~/.config/panel-colorizer/presets/<Name>/ (the same
#     dir the GUI reads and saves to — confirmed in configPresets.qml).
#   - The widget does not re-read its config while running: a change made
#     here needs a plasmashell restart to show.
#
# Chosen style: user preset "Dock Slim" = the shipped Dock preset with
# margin/padding OFF (the insets shrank the auto-fit clock — see 20-theme.sh).
# Translucent + blur, follows the colour scheme.
#
# History: v1 (2026-08-19) Outline Accent + autoload — autoload's `normal`
# differed from Hải's GUI pick, so every window-state flip clobbered it;
# v2 autoload OFF; v3 (08-20) autoload back ON with `normal` = Dock Slim and
# `maximized` = an opaque "Dock Solid" so the dock merged with maximized
# windows; v4 (2026-09-07, this) drops the flip entirely: nearly every window
# on this desktop is dark now, so Slim already reads as one surface next to
# them and the state machine bought nothing. Dock Solid is removed on sight.
#
# CONVERGE POLICY: the preset FILE is a declared artefact and always converges
# (tweak it via the GUI's save-preset, then sync the change back here). The
# live widget config (`presetAutoloading`, `globalSettings`, `lastPreset`) is
# applied only while it still points somewhere else (autoload on, or a
# different preset); after that the GUI is the source of truth (appletsrc is
# in backup Section 9a). FORCE_PANEL_STYLE=1 re-applies the declared config.
# =============================================================================

set -e
DESKTOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DESKTOP_DIR/../common.sh"
source "$DESKTOP_DIR/lib.sh"

log_section "Desktop 57: panel style (Dock Slim, no autoload)"

PC_ID="luisbocanegra.panel.colorizer"
BASE_PRESET="$HOME/.local/share/plasma/plasmoids/$PC_ID/contents/ui/presets/Dock"
USER_PRESETS="$HOME/.config/panel-colorizer/presets"
SLIM_DIR="$USER_PRESETS/Dock Slim"
SOLID_DIR="$USER_PRESETS/Dock Solid"   # retired v3 artefact, removed below

[[ -d "$BASE_PRESET" ]] || { log_error "Preset missing: $BASE_PRESET (Panel Colorizer not installed?)"; exit 1; }

# --- 1. Generate the user preset (always converge — declared file) -------------
ensure_dir "$SLIM_DIR"
PRESET_STATE="$(python3 - "$BASE_PRESET/settings.json" "$SLIM_DIR/settings.json" <<'PY'
import json, sys
base, slim_out = sys.argv[1:3]
with open(base) as f: data = json.load(f)

n = data["globalSettings"]["panel"]["normal"]
n["margin"]["enabled"] = False    # insets shrank the auto-fit clock
n["padding"]["enabled"] = False

txt = json.dumps(data, indent=2)
try:
    if open(slim_out).read() == txt:
        print("unchanged"); sys.exit(0)
except FileNotFoundError:
    pass
with open(slim_out, "w") as f: f.write(txt)
print("regenerated")
PY
)"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$SLIM_DIR/settings.json" \
    || { log_error "Generated preset JSON invalid"; exit 1; }
log_success "User preset converged: 'Dock Slim' ($PRESET_STATE)"

if [[ -d "$SOLID_DIR" ]]; then
    rm -rf "$SOLID_DIR"
    log_success "Removed retired preset 'Dock Solid' (v3 maximized flip)"
fi

# v1 wrote these with currentConfigGroup = [] , which lands in [Configuration]
# ROOT — a group the widget never reads. They sat there as dead keys ever since
# and are indistinguishable from live config to anything grepping appletsrc.
APPLETSRC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
DEAD="$(python3 - "$APPLETSRC" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
out = []
for m in re.finditer(r"^\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]\[Configuration\]$(.*?)(?=^\[|\Z)",
                     txt, re.M | re.S):
    if re.search(r"^(presetAutoloading|lastPreset)=", m.group(3), re.M):
        out.append(m.group(1) + " " + m.group(2))
print("\n".join(out))
PY
)"
if [[ -n "$DEAD" ]]; then
    while read -r ctn applet; do
        [[ -n "$applet" ]] || continue
        for key in presetAutoloading lastPreset; do
            kwriteconfig6 --file "$APPLETSRC" --group Containments --group "$ctn" \
                --group Applets --group "$applet" --group Configuration --key "$key" --delete
        done
        log_success "Cleared dead root-group Colorizer keys (containment $ctn, applet $applet)"
    done <<< "$DEAD"
fi

# --- 2. Point the widget at it (only while it points elsewhere) -----------------
GLOBAL_JSON="$(python3 -c '
import json,sys
print(json.dumps(json.dumps(json.load(open(sys.argv[1]))["globalSettings"], separators=(",",":"))))
' "$SLIM_DIR/settings.json")"

RESULT="$(plasma_script '
const FORCE = '"${FORCE_PANEL_STYLE:-0}"' === 1;
const SLIM = "'"$SLIM_DIR"'";
var out = "no-colorizer";
for (const p of panels()) {
    const ws = p.widgets("luisbocanegra.panel.colorizer");
    if (ws.length === 0) continue;
    const w = ws[0];
    w.currentConfigGroup = ["General"];
    var auto = {};
    try { auto = JSON.parse(w.readConfig("presetAutoloading", "{}")); } catch (e) {}
    const last = w.readConfig("lastPreset", "");
    if (!FORCE && auto.enabled !== true && last === SLIM) { out = "already"; continue; }
    w.writeConfig("isEnabled", true);
    w.writeConfig("globalSettings", '"$GLOBAL_JSON"');
    w.writeConfig("lastPreset", SLIM);
    w.writeConfig("presetAutoloading", JSON.stringify({enabled: false}));
    out = "applied";
}
print(out);
')"

case "$RESULT" in
    applied)
        log_success "Applied 'Dock Slim', autoload OFF — restarting plasmashell so the widget re-reads it"
        plasma_restart ;;
    already)      log_success "OK  'Dock Slim' active, autoload off (GUI is source of truth; FORCE_PANEL_STYLE=1 to reset)" ;;
    no-colorizer) log_warn "Panel Colorizer widget not found in any panel — run 55-widgets.sh first"; exit 1 ;;
    *)            log_warn "Unexpected result: $RESULT" ;;
esac
