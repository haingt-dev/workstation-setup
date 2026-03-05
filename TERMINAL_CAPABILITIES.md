# Terminal Capabilities Guide

Kitty + tmux + Zsh development environment with auto-dashboard layout, Catppuccin theming, and power tools.

---

## Dashboard Layout

Kitty launches maximized and auto-creates a tmux session `main` with a 3-pane dashboard:

```
┌─────────────────────┬───────────────────────┐
│  fastfetch → btop   │                       │
│  (system monitor)   │    Shell (focused)     │
├─────────────────────┤                       │
│  lazygit-pane       │                       │
│  (auto cwd sync)    │                       │
└─────────────────────┴───────────────────────┘
```

- **Top-left** (pane 1.1): fastfetch system info, then transitions to btop
- **Bottom-left** (pane 1.2): lazygit-pane — auto-restarts and follows shell's cwd
- **Right** (pane 1.3): Interactive shell (default focus)

### lazygit-pane

Wrapper script at `~/.local/bin/lazygit-pane`:
- Reads target directory from `/tmp/tmux-main-cwd` (written by zsh `chpwd` hook)
- When lazygit quits (`q`), re-reads the file and restarts in the new directory
- If not in a git repo, displays a waiting message and polls for directory change
- Trigger manual resync: `prefix + g` (sends `q` to lazygit pane, causing restart)

### Fastfetch Profiles

Three configs under `~/.config/fastfetch/`:

| Config | Usage | Logo |
|:---|:---|:---|
| `kitty.jsonc` | Direct kitty launch (no tmux) | Image (jedi.png via kitty protocol) |
| `tmux.jsonc` | Dashboard pane (inside tmux) | Text (Jedi builtin) |
| `generic.jsonc` | Other terminals | Text (Jedi builtin) |

---

## Tmux

**Prefix**: `Ctrl+a` (not default `Ctrl+b`)

### Pane & Window Management

| Action | Shortcut |
|:---|:---|
| Split vertical | `prefix + \|` |
| Split horizontal | `prefix + -` |
| Navigate panes | `prefix + h/j/k/l` |
| Resize panes | `prefix + H/J/K/L` (hold shift) |
| Zoom pane | `prefix + z` |
| Kill pane | `prefix + x` |
| Kill window | `prefix + X` |
| New window | `prefix + c` |
| Next/prev window | `prefix + Ctrl+l / Ctrl+h` |
| Swap window left/right | `prefix + < / >` |
| Last window | `prefix + Space` |
| Sync panes (toggle) | `prefix + S` |

### Session & Navigation Popups

| Action | Shortcut |
|:---|:---|
| Switch session (fzf popup) | `prefix + s` |
| Switch window (fzf popup) | `prefix + w` |
| Yazi file manager (popup) | `prefix + y` |
| Resync lazygit pane | `prefix + g` |
| New session | `prefix + N` |

### Copy Mode (Vi-style)

| Action | Shortcut |
|:---|:---|
| Enter copy mode | `prefix + [` |
| Begin selection | `v` |
| Rectangle selection | `Ctrl+v` |
| Yank (copy) | `y` |
| Paste | `prefix + ]` |
| Cancel | `Escape` |

### Plugins (TPM)

- `tmux-sensible` — sensible defaults
- `catppuccin/tmux` v2.1.0 — Mocha theme
- `tmux-resurrect` — save/restore sessions
- `tmux-continuum` — auto-save every 15min (auto-restore **off** — .zshrc handles layout)
- `tmux-yank` — system clipboard integration

Install plugins: `prefix + I` | Save: `prefix + Ctrl+s` | Restore: `prefix + Ctrl+r`

### Technical Settings

- `allow-passthrough on` — enables kitty graphics protocol in tmux (fastfetch image logo)
- `extended-keys always` + `csi-u` format — configured for extended key support
- Note: Ctrl+Enter forwarding is configured but **not functional in practice**. Use Alt+Enter for newline in applications that need it.

---

## Kitty

GPU-accelerated terminal emulator with Catppuccin Mocha theme.

### Key Settings

- Font: CaskaydiaCove Nerd Font 14pt with ligatures
- Background: 85% opacity with 32px blur
- Cursor: Block with trail effect
- Startup: Maximized via `startup.conf`, launches zsh
- Remote control: socket-only (`unix:/tmp/kitty`)

### Keyboard Shortcuts

Modifier: `Ctrl+Shift` (referred to as `kitty_mod`)

| Action | Shortcut |
|:---|:---|
| Copy / Paste | `kitty_mod + c / v` |
| New window (cwd) | `kitty_mod + Enter` |
| New tab (cwd) | `kitty_mod + t` |
| Close window / tab | `kitty_mod + w / q` |
| Next/prev tab | `kitty_mod + Right / Left` |
| Font size +/- | `kitty_mod + = / -` |
| Reset font | `kitty_mod + Backspace` |
| Fullscreen | `kitty_mod + F11` |
| Scrollback buffer | `kitty_mod + h` |
| URL hints | `kitty_mod + e` |
| Path/line/word hints | `kitty_mod + p` then `f/l/w` |
| Opacity +/- | `kitty_mod + a` then `m/l` |
| Unicode input | `kitty_mod + u` |
| Open line in nvim | `Ctrl+Shift + g` |
| Ctrl+Enter (CSI-u) | `Ctrl+Enter` → sends `\x1b[13;5u` |

---

## Power Tools (CLI)

| Tool | Replaces | Alias | Description |
|:---|:---|:---|:---|
| zoxide | `cd` | `z <name>` | Smart directory jumping, learns from usage |
| eza | `ls` | `ls`, `ll`, `la`, `lt` | Icons, git status, tree view |
| bat | `cat` | `cat`, `catp` (paging) | Syntax highlighting, Catppuccin theme |
| fzf | `find` | `Ctrl+T/R`, `Alt+C` | Fuzzy finder with Catppuccin theme, fd backend |
| ripgrep | `grep` | `rg` | Fast regex search |
| fd-find | `find` | `fd` | Fast file finder |
| lazygit | git CLI | `lg` | Terminal UI for git |
| yazi | file managers | `y` | Terminal file manager (cd on exit) |

---

## Shell (Zsh)

### Plugins
- `zsh-autosuggestions` — grey inline suggestions (accept with Right Arrow)
- `zsh-syntax-highlighting` — command validation colors
- `zsh-autocomplete` — real-time completion menu
- Starship prompt (Gruvbox theme)
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

### Tmux cwd Sync
When inside tmux, a `chpwd` hook writes `$PWD` to `/tmp/tmux-main-cwd` on every directory change. The lazygit-pane reads this file to stay in sync.

---

## Theme

Catppuccin Mocha across the stack:
- **Kitty**: `catppuccin-mocha.conf` include
- **Tmux**: `catppuccin/tmux` plugin, Mocha flavor
- **FZF**: Custom color scheme via `FZF_DEFAULT_OPTS`
- **Bat**: `BAT_THEME="Catppuccin-mocha"`
- **Starship**: Gruvbox Dark theme (intentional contrast with Catppuccin terminal)
