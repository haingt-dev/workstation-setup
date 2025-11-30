# 🚀 New Terminal Capabilities Guide

You have successfully enhanced your terminal! This guide outlines the new "power tools," shortcuts, and features now available to you. Your environment is designed to be faster, prettier, and more efficient.

---

## ⚡ Power Tools (CLI Enhancements)

These modern replacements for classic Unix commands are installed and aliased automatically.

| Tool | Replaces | Description | New Command / Alias |
| :--- | :--- | :--- | :--- |
| **Zoxide** | `cd` | **Smarter navigation.** Remembers directories you visit. Jump to them by typing a partial name. | `z <partial_name>` (e.g., `z pro` might jump to `~/Projects`) |
| **Eza** | `ls` | **Modern file listing.** Adds colors, icons, and git status integration. | `ls` (standard), `ll` (detailed), `lt` (tree view) |
| **Bat** | `cat` | **Better file viewing.** Adds syntax highlighting, line numbers, and git integration. | `cat <file>` (aliased to bat), `catp` (with paging) |
| **Lazygit** | `git` CLI | **Terminal UI for Git.** Manage repositories, commits, and diffs with a visual interface. | `lg` |
| **Yazi** | `rm`/`cp` | **Terminal File Manager.** Blazing fast file navigation with image previews. | `y` (changes directory on exit) |
| **FZF** | `find` | **Fuzzy Finder.** Search for files, history, and directories instantly. | `Ctrl+T` (files), `Ctrl+R` (history), `Alt+C` (cd) |
| **Ripgrep** | `grep` | **Faster Search.** Searches text within files much faster than grep. | `rg <pattern>` |

---

## 🐚 Shell Enhancements (Zsh)

Your shell is now powered by **Starship** (prompt) and **Zsh** with auto-suggestions and syntax highlighting.

### ⌨️ Key Shortcuts
- **Auto-suggestion**: Type a command, and if you see a grey suggestion, press `Right Arrow` or `End` to accept it.
- **History Search**: Type part of a command and use `Up/Down Arrow` to cycle through matching history.

### 🛠️ Useful Aliases
- **Navigation**: `..` (up 1 level), `...` (up 2 levels), `....` (up 3 levels).
- **Safety**: `rm`, `cp`, and `mv` now ask for confirmation (`-i`).
- **Git**:
    - `gs` → `git status`
    - `ga` → `git add`
    - `gc` → `git commit`
    - `gp` → `git push`
    - `gl` → `git pull`
    - `gd` → `git diff`
    - `glog` → `git log --oneline --graph`

---

## 🧩 Terminal Multiplexer (Tmux)

Tmux allows you to manage multiple windows and panes within a single terminal window.
**Prefix Key:** `Ctrl + a` (Changed from default `Ctrl + b`)

### 🪟 Window & Pane Management
| Action | Shortcut |
| :--- | :--- |
| **Split Vertical** | `Ctrl+a` then `|` |
| **Split Horizontal** | `Ctrl+a` then `-` |
| **New Window** | `Ctrl+a` then `c` |
| **Close Pane** | `Ctrl+a` then `x` |
| **Navigate Panes** | `Ctrl+a` then `h` `j` `k` `l` (Vim keys) |
| **Resize Panes** | `Ctrl+a` then `H` `J` `K` `L` (Hold Shift) |
| **Next/Prev Window** | `Ctrl+a` then `Ctrl+l` / `Ctrl+h` |
| **Zoom Pane** | `Ctrl+a` then `z` |

### 🔌 Plugins (TPM)
- **Install Plugins**: `Ctrl+a` then `I` (Capital i) - *Run this first to install themes!*
- **Save Session**: `Ctrl+a` then `Ctrl+s`
- **Restore Session**: `Ctrl+a` then `Ctrl+r`

---

## 🐱 Terminal Emulator (Kitty)

Kitty is your GPU-accelerated terminal emulator. It handles the actual window rendering.

### ⌨️ Shortcuts (Use `Ctrl+Shift` as modifier)
- **New Window**: `Ctrl+Shift+Enter` (Opens in current directory)
- **New Tab**: `Ctrl+Shift+t`
- **Close Tab/Window**: `Ctrl+Shift+q` / `Ctrl+Shift+w`
- **Next/Prev Tab**: `Ctrl+Shift+Right` / `Ctrl+Shift+Left`
- **Font Size**: `Ctrl+Shift+Equal` (+) / `Ctrl+Shift+Minus` (-)
- **Scrollback**: `Ctrl+Shift+h` (Show scrollback buffer)

---

## 📝 Quick Start Checklist

1.  **Restart Terminal**: Ensure all changes are loaded.
2.  **Install Tmux Plugins**: Open tmux (`tmux`), press `Ctrl+a` then `I`.
3.  **Try Zoxide**: Type `z <folder>` instead of `cd`.
4.  **Try Lazygit**: Go to a git repo and type `lg`.
5.  **Explore**: Use `ll` to see your new file listing icons.