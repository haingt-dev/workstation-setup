# Terminal Capabilities Guide

Kitty + Zsh development environment: a two-pane startup layout, power tools, and colours
that come from the same generated palette as the desktop.

---

## Startup Layout

Kitty opens maximized and splits into two panes (`assets/.config/kitty/startup.conf`):

```
┌──────────────────────────┬──────────────────────────┐
│  digital-identity        │                          │
│  claude --continue       │   Shell (~/Projects)     │
│  (falls back to a shell  │                          │
│   when the session ends) │                          │
└──────────────────────────┴──────────────────────────┘
```

Left pane resumes the Claude Code session in `~/Projects/digital-identity`; the right pane
is a plain shell in `~/Projects`. Splits are managed by kitty itself — `enabled_layouts
splits,stack`, `Ctrl+Shift+Z` zooms a pane.

> **Retired 2026-09-07**: this used to be a three-pane tmux dashboard (`main` session,
> fastfetch → btop, an auto-syncing lazygit pane), plus a `work` session that remote
> connections auto-attached to. tmux went out with the iPad remote stack — see the Awake
> guard section in `README.md`. `Ctrl+Shift+G` still opens lazygit as an overlay.

---

## Kitty

### Key Settings

| Setting | Value |
|:---|:---|
| Font | CaskaydiaCove Nerd Font 14pt, ligatures on |
| Background | opaque, drawing a crop of the wallpaper (`background_image`) |
| Colours | `firewatchdusk.kitty.conf`, generated from the wallpaper |
| Cursor | block, with trail |
| Startup | maximized, two panes (above) |
| Remote control | socket-only (`unix:/tmp/kitty`) |

The window is **not** translucent on purpose. It was, at 0.85 with blur — but the
wallpaper is nearly black, so the glass showed no picture and plenty of whatever window
happened to sit underneath. It now draws a fixed crop of that same wallpaper instead,
rendered by `scripts/desktop/60-wallpaper.sh` with the parameters in
`assets/desktop/palette/palette.toml` under `[terminal]`. `dynamic_background_opacity` is
still on, so `Ctrl+Shift+A` then `m`/`l`/`1`/`d` brings the glass back at any time.

### Keyboard Shortcuts

Modifier: `Ctrl+Shift` (referred to as `kitty_mod`)

| Action | Shortcut |
|:---|:---|
| Copy / Paste | `kitty_mod + c / v` |
| New window (cwd) | `kitty_mod + Enter` |
| New tab (cwd) | `kitty_mod + t` |
| Close window / tab | `kitty_mod + w / q` |
| Next/prev tab | `kitty_mod + Right / Left` |
| Navigate panes | `Alt + h/j/k/l` |
| Resize panes | `Alt+Shift + h/j/k/l`, reset `Alt+Shift+r` |
| Zoom pane (stack layout) | `kitty_mod + z` |
| Next layout | `kitty_mod + l` |
| Font size +/- / reset | `kitty_mod + = / -` / `Backspace` |
| Fullscreen / maximize | `kitty_mod + F11 / F10` |
| Scrollback buffer | `kitty_mod + h` |
| URL hints | `kitty_mod + e` |
| Path/line/word hints | `kitty_mod + p` then `f/l/w` |
| Open line in nvim | `kitty_mod + p` then `g` |
| Opacity +/- / opaque / default | `kitty_mod + a` then `m/l/1/d` |
| Unicode input | `kitty_mod + u` |
| Overlays: lazygit / yazi / btop | `kitty_mod + g / y / o` |
| Reload / edit config | `kitty_mod + F5 / F2` |

---

## Power Tools (CLI)

| Tool | Replaces | Alias | Description |
|:---|:---|:---|:---|
| zoxide | `cd` | `z <name>` | Smart directory jumping, learns from usage |
| eza | `ls` | `ls`, `ll`, `la`, `lt` | Icons, git status, tree view |
| bat | `cat` | `cat`, `catp` (paging) | Syntax highlighting |
| fzf | `find` | `Ctrl+T/R`, `Alt+C` | Fuzzy finder, fd backend |
| ripgrep | `grep` | `rg` | Fast regex search |
| fd-find | `find` | `fd` | Fast file finder |
| lazygit | git CLI | `lg` | Terminal UI for git |
| yazi | file managers | `y` | Terminal file manager (cd on exit) |

---

## Shell (Zsh)

### Plugins
- `zsh-autosuggestions` — grey inline suggestions (accept with Right Arrow)
- `zsh-syntax-highlighting` — command validation colors
- `zsh-autocomplete` — **disabled 2026-06-29** (segfaults on zsh 5.9)
- Starship prompt
- Atuin shell history (sync/search)

### Key Aliases

| Alias | Command |
|:---|:---|
| `gs` | `git status` |
| `ga` | `git add` |
| `gc` | `git commit` |
| `gp` | `git push` |
| `gl` | `git pull` |
| `gd` | `git diff` |
| `glog` | `git log --oneline --graph --decorate` |
| `..` / `...` / `....` | Navigate up 1/2/3 levels |
| `mkcd <dir>` | Create directory and cd into it |
| `extract <file>` | Auto-extract any archive format |

### FZF Shortcuts
- `Ctrl+T` — fuzzy file search (fd backend)
- `Ctrl+R` — fuzzy history search
- `Alt+C` — fuzzy directory navigation

---

## Theme

One palette, generated from the wallpaper — see `assets/desktop/palette/` and the *One
derived palette* bullet in `README.md`. Nothing in this stack carries its own colours:

- **Kitty**: `include firewatchdusk.kitty.conf` (generated), plus the backdrop crop
- **Starship**: a generated `[palettes.rice]` block spliced into `starship.toml`
- **Bat**: `BAT_THEME=ansi` — follows the terminal
- **FZF**: `FZF_DEFAULT_OPTS` uses ANSI indices and `-1`, so it follows too

Change the look in one place: edit `assets/desktop/palette/palette.toml`, run
`bash scripts/desktop/gen-palette.sh`, review the diff, commit.
