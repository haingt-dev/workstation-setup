#!/usr/bin/env python3
"""Generate every colour artefact of the rice from ONE source colour.

Dev-time tool — it is NOT run by ./setup.sh. Edit palette.toml, run
`bash scripts/desktop/gen-palette.sh`, review the diff, commit. The setup
stages only ever copy the generated files, so a machine being set up needs
neither this script nor its dependencies.

Dependencies (dev machine only):  python3-materialyoucolor  python3-pillow
    dnf install python3-materialyoucolor python3-pillow
    # or: pip install --user materialyoucolor pillow

What comes out (all next to this file):
    <Name>.colors        KDE colour scheme  -> ~/.local/share/color-schemes/
    <Name>.colorscheme   Konsole            -> ~/.local/share/konsole/
    <name>.kitty.conf    kitty colours      -> ~/.config/kitty/ (included)
    tokens.json          every M3 token + the 16 ANSI colours (machine-readable)
    tokens.sh            RICE_* shell vars  -> ~/.config/rice/tokens.sh
    Tokens.qml           QML singleton      -> copied into our plasmoids

The Material You maths comes from `materialyoucolor` (the Python port of
Google's material-color-utilities). The KDE section/key mapping follows
luisbocanegra's kde-material-you-colors, which is the reference for how M3
tokens land on Plasma's colour roles.
"""

from __future__ import annotations

import json
import os
import sys
import tomllib
from datetime import date

from materialyoucolor.blend import Blend
from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
from materialyoucolor.hct import Hct

HERE = os.path.dirname(os.path.abspath(__file__))

# --- scheme variants ---------------------------------------------------------
def _schemes():
    from materialyoucolor.scheme.scheme_tonal_spot import SchemeTonalSpot
    from materialyoucolor.scheme.scheme_expressive import SchemeExpressive
    from materialyoucolor.scheme.scheme_fidelity import SchemeFidelity
    from materialyoucolor.scheme.scheme_content import SchemeContent
    from materialyoucolor.scheme.scheme_vibrant import SchemeVibrant
    from materialyoucolor.scheme.scheme_neutral import SchemeNeutral
    from materialyoucolor.scheme.scheme_monochrome import SchemeMonochrome
    return {
        "tonal_spot": SchemeTonalSpot, "expressive": SchemeExpressive,
        "fidelity": SchemeFidelity, "content": SchemeContent,
        "vibrant": SchemeVibrant, "neutral": SchemeNeutral,
        "monochrome": SchemeMonochrome,
    }


# --- colour helpers ----------------------------------------------------------
def argb(hex_str: str) -> int:
    h = hex_str.lstrip("#")
    return 0xFF000000 | int(h, 16)


def hexs(a: int) -> str:
    return "#%06x" % (a & 0xFFFFFF)


def rgb(a: int) -> str:
    """KDE .colors wants decimal 'r,g,b'."""
    return "%d,%d,%d" % ((a >> 16) & 0xFF, (a >> 8) & 0xFF, a & 0xFF)


def tone_of(a: int, tone: float) -> int:
    """Same hue/chroma, forced lightness — how we hit a contrast target."""
    h = Hct.from_int(a)
    return Hct.from_hct(h.hue, h.chroma, tone).to_int()


# Material You tints the NEUTRALS with the source hue too, not just the accents.
# At a warm source that means the background, the body text and the greys all
# carry real chroma — and a terminal painted in them reads as if night-light is
# on (Hải, 2026-09-07: "terminal đang bị ám vàng kiểu night light mode"). These
# are the roles that come from the neutral / neutral-variant palettes; scaling
# their chroma keeps the hue (so the desktop still reads as one family) while
# taking the cast off.
NEUTRAL_ROLES = {
    "background", "onBackground", "surface", "surfaceDim", "surfaceBright",
    "surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer",
    "surfaceContainerHigh", "surfaceContainerHighest", "surfaceVariant",
    "onSurface", "onSurfaceVariant", "outline", "outlineVariant",
    "inverseSurface", "inverseOnSurface", "scrim", "shadow",
    "neutralPaletteKeyColor", "neutralVariantPaletteKeyColor",
}


def desaturate_neutrals(tokens: dict[str, int], keep: float) -> dict[str, int]:
    """Scale the chroma of the neutral roles to `keep` (1.0 = untouched)."""
    if keep >= 1.0:
        return tokens
    out = dict(tokens)
    for role in NEUTRAL_ROLES & set(out):
        h = Hct.from_int(out[role])
        out[role] = Hct.from_hct(h.hue, h.chroma * keep, h.tone).to_int()
    return out


def pick_source(cfg) -> int:
    """Explicit hex, or score the wallpaper's quantised colours."""
    src = str(cfg.get("source_color", "auto")).strip()
    if src.lower() != "auto":
        return argb(src)
    from PIL import Image
    from materialyoucolor.quantize import QuantizeCelebi
    from materialyoucolor.score.score import Score
    path = os.path.join(HERE, "..", "wallpapers", cfg["wallpaper"])
    im = Image.open(path).convert("RGB")
    im.thumbnail((256, 256))
    px = [[r, g, b, 255] for r, g, b in im.getdata()]
    return Score.score(QuantizeCelebi(px, 128))[0]


# --- ANSI ---------------------------------------------------------------------
# Six semantic anchors, harmonised toward the scheme's source colour so the
# terminal sits in the same tonal world as the desktop instead of shouting in
# stock RGB. Tones are fixed (not blended) so contrast against the dark
# background is predictable: 72 reads as "normal", 84 as "bright".
ANSI_ANCHORS = {
    "red": 0xFFE53935, "green": 0xFF43A047, "yellow": 0xFFFDD835,
    "blue": 0xFF1E88E5, "magenta": 0xFF8E24AA, "cyan": 0xFF00ACC1,
}
ANSI_ORDER = ["red", "green", "yellow", "blue", "magenta", "cyan"]


def build_ansi(source: int, t: dict[str, int]) -> dict[str, int]:
    """16 ANSI colours: 0/8 greys and 7/15 text from the scheme, 1-6 harmonised."""
    out = {
        0: t["surfaceContainerHigh"],      # "black" that is still visible on bg
        7: t["onSurfaceVariant"],
        8: t["outline"],
        15: t["onSurface"],
    }
    for i, name in enumerate(ANSI_ORDER, start=1):
        harmonised = Blend.harmonize(ANSI_ANCHORS[name], source)
        out[i] = tone_of(harmonised, 72)
        out[i + 8] = tone_of(harmonised, 84)
    return out


# --- writers ------------------------------------------------------------------
def kde_scheme(cfg, t, ansi) -> str:
    """Plasma colour scheme. Roles follow kde-material-you-colors' mapping."""
    link, visited = ansi[4], ansi[5]
    negative, neutral, positive = ansi[1], ansi[3], ansi[2]

    def fg_block(normal, active):
        return (
            f"ForegroundActive={rgb(active)}\n"
            f"ForegroundInactive={rgb(t['outline'])}\n"
            f"ForegroundLink={rgb(link)}\n"
            f"ForegroundNegative={rgb(negative)}\n"
            f"ForegroundNeutral={rgb(neutral)}\n"
            f"ForegroundNormal={rgb(normal)}\n"
            f"ForegroundPositive={rgb(positive)}\n"
            f"ForegroundVisited={rgb(visited)}\n"
        )

    def section(name, bg_alt, bg, normal, active, hover=None):
        return (
            f"[{name}]\n"
            f"BackgroundAlternate={rgb(bg_alt)}\n"
            f"BackgroundNormal={rgb(bg)}\n"
            f"DecorationFocus={rgb(t['primary'])}\n"
            f"DecorationHover={rgb(hover or t['primary'])}\n"
            + fg_block(normal, active) + "\n"
        )

    head = (
        "# Generated by assets/desktop/palette/gen-palette.py — do not edit by hand.\n"
        f"# Source colour {hexs(cfg['_source'])}, {cfg['variant']}, generated {date.today()}.\n\n"
        "[ColorEffects:Disabled]\n"
        f"Color={rgb(t['surfaceContainer'])}\n"
        "ColorAmount=0.5\nColorEffect=3\nContrastAmount=0\nContrastEffect=0\n"
        "IntensityAmount=0\nIntensityEffect=0\n\n"
        "[ColorEffects:Inactive]\n"
        "ChangeSelectionColor=true\n"
        f"Color={rgb(t['surfaceContainerLowest'])}\n"
        "ColorAmount=0.025\nColorEffect=0\nContrastAmount=0.1\nContrastEffect=0\n"
        "Enable=true\nIntensityAmount=0\nIntensityEffect=0\n\n"
    )

    body = (
        section("Colors:Button", t["surfaceVariant"], t["surfaceContainerHigh"],
                t["onSurface"], t["onSurface"])
        + section("Colors:Complementary", t["surface"], t["surfaceContainer"],
                  t["onSurfaceVariant"], t["inverseSurface"])
        + section("Colors:Header", t["surfaceContainer"], t["surfaceContainer"],
                  t["onSurfaceVariant"], t["inverseSurface"])
        + section("Colors:Header][Inactive", t["surfaceContainer"], t["surfaceContainer"],
                  t["onSurfaceVariant"], t["inverseSurface"])
        + section("Colors:Selection", t["primary"], t["primary"],
                  t["onPrimary"], t["onPrimary"], hover=t["secondary"])
        + section("Colors:Tooltip", t["surfaceVariant"], t["surfaceContainer"],
                  t["onSurface"], t["onSurface"])
        + section("Colors:View", t["surfaceContainer"], t["surfaceDim"],
                  t["onSurface"], t["inverseSurface"], hover=t["inversePrimary"])
        + section("Colors:Window", t["surfaceVariant"], t["surfaceContainer"],
                  t["onSurfaceVariant"], link)
    )

    tail = (
        "[General]\n"
        f"ColorScheme={cfg['name']}\n"
        f"Name={cfg['display_name']}\n"
        "shadeSortColumn=true\n\n"
        "[KDE]\n"
        "contrast=4\n"
        "frameContrast=0.2\n\n"
        "[WM]\n"
        f"activeBackground={rgb(t['surfaceContainerHighest'])}\n"
        "activeBlend=252,252,252\n"
        f"activeForeground={rgb(t['onSurface'])}\n"
        f"inactiveBackground={rgb(t['secondaryContainer'])}\n"
        "inactiveBlend=161,169,177\n"
        f"inactiveForeground={rgb(t['onSecondaryContainer'])}\n"
    )
    return head + body + tail


def konsole_scheme(cfg, t, ansi) -> str:
    """Konsole reads Faint/Intense per colour; we map them to our tone pairs."""
    out = [
        "# Generated by assets/desktop/palette/gen-palette.py — do not edit by hand.",
        "", "[Background]", f"Color={rgb(t['surface'])}", "",
        "[BackgroundFaint]", f"Color={rgb(t['surface'])}", "",
        "[BackgroundIntense]", f"Color={rgb(t['surfaceContainerLowest'])}", "",
    ]
    for i in range(8):
        out += [f"[Color{i}]", f"Color={rgb(ansi[i])}", ""]
        out += [f"[Color{i}Faint]", f"Color={rgb(tone_of(ansi[i], 55))}", ""]
        out += [f"[Color{i}Intense]", f"Color={rgb(ansi[i + 8])}", ""]
    out += [
        "[Foreground]", f"Color={rgb(t['onSurface'])}", "",
        "[ForegroundFaint]", f"Color={rgb(t['onSurfaceVariant'])}", "",
        "[ForegroundIntense]", f"Color={rgb(t['inverseSurface'])}", "",
        "[General]", f"Description={cfg['display_name']}", "Opacity=1",
        f"Wallpaper={cfg['wallpaper']}", "",
    ]
    return "\n".join(out)


def kitty_conf(cfg, t, ansi) -> str:
    lines = [
        "# Generated by assets/desktop/palette/gen-palette.py — do not edit by hand.",
        f"# {cfg['display_name']} — Material You from {hexs(cfg['_source'])}",
        "",
        f"foreground              {hexs(t['onSurface'])}",
        f"background              {hexs(t['surface'])}",
        f"selection_foreground    {hexs(t['onPrimary'])}",
        f"selection_background    {hexs(t['primary'])}",
        "",
        f"cursor                  {hexs(t['primary'])}",
        f"cursor_text_color       {hexs(t['onPrimary'])}",
        "",
        f"url_color               {hexs(ansi[4])}",
        f"active_border_color     {hexs(t['primary'])}",
        f"inactive_border_color   {hexs(t['outlineVariant'])}",
        f"bell_border_color       {hexs(t['error'])}",
        "",
        f"active_tab_foreground   {hexs(t['onPrimaryContainer'])}",
        f"active_tab_background   {hexs(t['primaryContainer'])}",
        f"inactive_tab_foreground {hexs(t['onSurfaceVariant'])}",
        f"inactive_tab_background {hexs(t['surfaceContainer'])}",
        "",
    ]
    for i in range(16):
        lines.append(f"color{i:<2}                  {hexs(ansi[i])}")

    # Backdrop: the crop of the wallpaper that 60-wallpaper.sh renders into the
    # wallpaper package. kitty resolves a leading ~ itself, so the path stays
    # portable across machines. `cscaled` keeps the aspect ratio; the crop is
    # already 16:9, so it fills without distorting.
    term = cfg.get("terminal")
    if term:
        img = f"~/.local/share/wallpapers/{cfg['name']}/contents/terminal/{cfg['name']}-terminal.jpg"
        lines += [
            "",
            "# Backdrop — rendered from the wallpaper by scripts/desktop/60-wallpaper.sh.",
            "# Crop/anchor/tint live in palette.toml [terminal]; kitty.conf keeps",
            "# background_opacity at 1 so nothing behind the window shows through.",
            f"background_image        {img}",
            "background_image_layout cscaled",
            "background_image_linear yes",
            f"background_tint         {float(term['tint'])}",
        ]
    return "\n".join(lines) + "\n"


# The terminal stack (tmux's theme plugin, the starship prompt) is written
# against CATPPUCCIN'S semantic colour names. Rather than rewrite either config,
# we hand them the same names filled with OUR colours — so their layout, which
# is fine, keeps working and only the palette changes.
def catppuccin_names(t: dict[str, int], ansi: dict[int, int]) -> dict[str, str]:
    m = {
        # Structural ladder, darkest to lightest. Deliberately starts at
        # `surface` and not `surfaceContainerLowest`: Material You makes that
        # one pure #000000 on a dark scheme, and a powerline prompt or a tmux
        # status bar painted in it reads as solid black blocks punched into a
        # translucent terminal. `base` — the main background for both — is the
        # same surfaceContainer the dock and the widget cards use.
        "crust":     t["surface"],
        "mantle":    t["surfaceContainerLow"],
        "base":      t["surfaceContainer"],
        "surface0":  t["surfaceContainerHigh"],
        "surface1":  t["surfaceContainerHighest"],
        "surface2":  t["surfaceBright"],
        "overlay0":  t["outlineVariant"],
        "overlay1":  t["outline"],
        "overlay2":  tone_of(t["outline"], 60),
        "subtext0":  t["onSurfaceVariant"],
        "subtext1":  tone_of(t["onSurfaceVariant"], 80),
        "text":      t["onSurface"],
        # accents: the ANSI set, which is already harmonised toward the source
        # hue and contrast-checked against a dark ground
        "red":       ansi[1],
        "maroon":    ansi[9],
        "peach":     t["primary"],
        "yellow":    ansi[3],
        "green":     ansi[2],
        "teal":      ansi[6],
        "sky":       ansi[14],
        "sapphire":  ansi[12],
        "blue":      ansi[4],
        "lavender":  tone_of(ansi[4], 82),
        "mauve":     ansi[5],
        "pink":      ansi[13],
        "flamingo":  tone_of(ansi[1], 82),
        "rosewater": tone_of(t["primary"], 88),
    }
    return {k: hexs(v) for k, v in m.items()}


def tmux_conf(cfg, names: dict[str, str]) -> str:
    """@thm_* overrides for catppuccin/tmux.

    The plugin sets its own values with `set -ogq` — the `o` means "only if
    unset" — so sourcing this BEFORE tpm runs leaves the plugin's layout intact
    and swaps just the colours. No fork, no patched plugin.
    """
    order = ["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
             "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"]
    lines = [
        "# Generated by assets/desktop/palette/gen-palette.py — do not edit by hand.",
        f"# {cfg['display_name']} palette for catppuccin/tmux.",
        "# MUST be sourced before tpm runs: the plugin uses `set -ogq`, which",
        "# skips any option that already has a value.",
        "",
        f'set -g @thm_bg "{names["base"]}"',
        f'set -g @thm_fg "{names["text"]}"',
        "",
    ]
    for n in order:
        lines.append(f'set -g @thm_{n} "{names[n]}"')
    lines.append("")
    for n in ["subtext_0", "subtext_1", "overlay_0", "overlay_1", "overlay_2",
              "surface_0", "surface_1", "surface_2", "mantle", "crust"]:
        lines.append(f'set -g @thm_{n} "{names[n.replace("_", "")]}"')
    return "\n".join(lines) + "\n"


def starship_palette(cfg, names: dict[str, str]) -> str:
    lines = ['[palettes.rice]']
    for k in ["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
              "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
              "text", "subtext1", "subtext0", "overlay2", "overlay1", "overlay0",
              "surface2", "surface1", "surface0", "base", "mantle", "crust"]:
        lines.append(f'{k} = "{names[k]}"')
    return "\n".join(lines) + "\n"


def splice_starship(cfg, names: dict[str, str]) -> str | None:
    """Rewrite the marked palette block inside the tracked starship.toml.

    Starship has no include mechanism, so the generated colours have to live in
    the same file as the hand-written module config. Markers keep the two apart:
    everything between them is ours, everything else is Hải's.
    """
    path = os.path.join(HERE, "..", "..", ".config", "starship", "starship.toml")
    path = os.path.normpath(path)
    if not os.path.exists(path):
        return None
    begin = "# >>> rice palette — generated by gen-palette.py, do not edit >>>"
    end = "# <<< rice palette <<<"
    block = begin + "\n" + starship_palette(cfg, names) + end
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if begin in text and end in text:
        head, _, rest = text.partition(begin)
        _, _, tail = rest.partition(end)
        text = head + block + tail
    else:
        text = text.rstrip("\n") + "\n\n" + block + "\n"
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return path


def tokens_sh(cfg, t, ansi) -> str:
    lines = [
        "# Generated by assets/desktop/palette/gen-palette.py — do not edit by hand.",
        "# Sourced by shell things that need the rice colours (statusline, stages).",
        "# Hex without '#', plus ready-made truecolour SGR escapes.",
        "",
        f"RICE_SCHEME_NAME='{cfg['name']}'",
    ]
    keys = ["primary", "onPrimary", "primaryContainer", "secondary", "tertiary",
            "error", "surface", "surfaceContainer", "surfaceContainerHigh",
            "onSurface", "onSurfaceVariant", "outline"]
    for k in keys:
        lines.append(f"RICE_{k.upper()}='{hexs(t[k])}'")
    lines.append("")
    lines.append("# SGR foreground escapes (printf '%b')")
    for k in keys:
        r, g, b = (t[k] >> 16) & 0xFF, (t[k] >> 8) & 0xFF, t[k] & 0xFF
        lines.append(f"RICE_FG_{k.upper()}='\\033[38;2;{r};{g};{b}m'")
    lines.append("RICE_FG_RESET='\\033[0m'")
    return "\n".join(lines) + "\n"


def qml_name(token: str) -> str:
    """Material's `onX` roles cannot keep their name in QML.

    A binding whose name is `on` + an uppercase letter is parsed as a SIGNAL
    HANDLER before anything is resolved, so `readonly property color onSurface:
    "#f5e2d2"` fails to compile with "Cannot assign a value to a signal", and
    every file importing the singleton then reports "Type Tokens unavailable".
    Found the hard way on 2026-09-07. `fg` = the foreground that goes ON that
    surface, which is what the M3 role means anyway.
    """
    if token.startswith("on") and len(token) > 2 and token[2].isupper():
        return "fg" + token[2:]
    return token


def tokens_qml(cfg, t, ansi, card_alpha) -> str:
    keys = ["primary", "onPrimary", "primaryContainer", "onPrimaryContainer",
            "secondary", "secondaryContainer", "tertiary", "onTertiary",
            "tertiaryContainer", "error", "onError", "surface", "surfaceDim",
            "surfaceBright", "surfaceContainerLowest", "surfaceContainerLow",
            "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest",
            "onSurface", "onSurfaceVariant", "outline", "outlineVariant",
            "inverseSurface"]
    props = "\n".join(
        f'    readonly property color {qml_name(k)}: "{hexs(t[k])}"' for k in keys)
    return f"""// Generated by assets/desktop/palette/gen-palette.py — do not edit by hand.
// {cfg['display_name']} — Material You ({cfg['variant']}) from {hexs(cfg['_source'])}.
pragma Singleton

import QtQuick

QtObject {{
{props}

    // How opaque our cards sit on the wallpaper.
    readonly property real cardAlpha: {card_alpha}
    readonly property color card: Qt.rgba(surfaceContainer.r, surfaceContainer.g,
                                          surfaceContainer.b, cardAlpha)
    readonly property color cardHigh: Qt.rgba(surfaceContainerHigh.r, surfaceContainerHigh.g,
                                              surfaceContainerHigh.b, cardAlpha)

    // Severity ramp, shared by every gauge/bar so "getting full" always looks
    // the same whether it is a disk or a Claude quota.
    readonly property color good: tertiary
    readonly property color warn: primary
    readonly property color high: "{hexs(tone_of(ANSI_ANCHORS['yellow'], 70))}"
    readonly property color crit: error

    function severityColor(percent) {{
        if (percent >= 95) return crit;
        if (percent >= 80) return high;
        if (percent >= 50) return warn;
        return good;
    }}
}}
"""


def main() -> int:
    with open(os.path.join(HERE, "palette.toml"), "rb") as fh:
        cfg = tomllib.load(fh)

    source = pick_source(cfg)
    cfg["_source"] = source
    variant = _schemes()[cfg["variant"]]
    scheme = variant(Hct.from_int(source), bool(cfg["dark"]), float(cfg["contrast"]))

    t = {n: getattr(MaterialDynamicColors, n).get_argb(scheme)
         for n in dir(MaterialDynamicColors)
         if not n.startswith("_") and hasattr(getattr(MaterialDynamicColors, n), "get_argb")}
    t = desaturate_neutrals(t, float(cfg.get("neutral_chroma", 1.0)))
    # ANSI is built AFTER the neutrals are calmed: colours 0/7/8/15 are taken
    # straight from them, so the terminal's own greys follow the same rule.
    ansi = build_ansi(source, t)

    name, low = cfg["name"], cfg["name"].lower()
    names = catppuccin_names(t, ansi)
    files = {
        "tmux-rice.conf": tmux_conf(cfg, names),
        f"{name}.colors": kde_scheme(cfg, t, ansi),
        f"{name}.colorscheme": konsole_scheme(cfg, t, ansi),
        f"{low}.kitty.conf": kitty_conf(cfg, t, ansi),
        "tokens.sh": tokens_sh(cfg, t, ansi),
        "Tokens.qml": tokens_qml(cfg, t, ansi, float(cfg["card_alpha"])),
        "tokens.json": json.dumps({
            "name": name,
            "displayName": cfg["display_name"],
            "source": hexs(source),
            "variant": cfg["variant"],
            "wallpaper": cfg["wallpaper"],
            "cardAlpha": cfg["card_alpha"],
            # Read by 60-wallpaper.sh to render the terminal crop.
            "terminal": cfg.get("terminal", {}),
            "tokens": {k: hexs(v) for k, v in sorted(t.items())},
            "ansi": {str(i): hexs(ansi[i]) for i in range(16)},
        }, indent=2) + "\n",
    }
    for fname, content in files.items():
        with open(os.path.join(HERE, fname), "w", encoding="utf-8") as fh:
            fh.write(content)
        print(f"  wrote {fname}")

    spliced = splice_starship(cfg, names)
    if spliced:
        print(f"  spliced palette into {os.path.relpath(spliced, HERE)}")

    print(f"\n  source {hexs(source)} · {cfg['variant']} · "
          f"surface {hexs(t['surface'])} · primary {hexs(t['primary'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
