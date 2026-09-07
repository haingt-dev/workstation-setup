#!/bin/bash
# =============================================================================
# retire_remote_stack.sh - Remove the iPad remote-access stack (one-shot)
# =============================================================================
#
# Context: from 2026-07 this machine was reachable from an iPad — Tailscale for
# the network, sshd + mosh for the shell, tmux for session persistence,
# Wake-on-LAN + a smart plug for power. Claude Code's own Remote Control
# (`/rc`, session driven from claude.ai or the phone app) replaced all of it,
# and the iPad had been offline on the tailnet for ~7 weeks. Hải's call
# 2026-09-07: remove the whole stack, and reconsider from scratch if remote
# access is ever needed again.
#
# This script removes the MACHINE state. The repo side (scripts, dotfiles, the
# --remote flag, the docs) is already gone — see the commit that added this
# file. Safe to re-run: every step checks first and reports SKIP.
#
# WHAT YOU LOSE, deliberately:
#   - No SSH into this box, from anywhere, including the LAN (scp/rsync in).
#     Outbound ssh still works: openssh-clients is untouched, so git over SSH
#     is fine.
#   - No Tailscale. The tailnet node disappears; nothing else on this box used
#     it (home-server binds to localhost).
#   - No Wake-on-LAN. The NIC stops arming the magic packet; the BIOS settings
#     are left alone (harmless, and changing them needs a reboot).
#
# Needs sudo. Run it yourself:  bash scripts/retire_remote_stack.sh
# =============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Retiring the iPad remote-access stack"

# --- 1. Services ---------------------------------------------------------------
if command -v tailscale >/dev/null 2>&1 && tailscale status &>/dev/null; then
    sudo tailscale down || true
    log_success "Tailscale disconnected from the tailnet"
fi

for unit in tailscaled sshd; do
    if systemctl list-unit-files "$unit.service" &>/dev/null \
        && systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        sudo systemctl disable --now "$unit"
        log_success "Disabled and stopped $unit"
    else
        log_info "SKIP $unit (not enabled)"
    fi
done

# --- 2. Firewall ---------------------------------------------------------------
# The trusted zone allowed ALL tailnet traffic (that is how mosh's UDP range
# was reachable). With no tailscale0 interface the rule is dead weight.
if command -v firewall-cmd >/dev/null 2>&1 \
    && sudo firewall-cmd --zone=trusted --list-interfaces 2>/dev/null | grep -q tailscale0; then
    sudo firewall-cmd --zone=trusted --remove-interface=tailscale0 --permanent
    sudo firewall-cmd --reload
    log_success "Firewall: tailscale0 removed from the trusted zone"
else
    log_info "SKIP firewall (tailscale0 not in the trusted zone)"
fi

# --- 3. Packages ---------------------------------------------------------------
# openssh-CLIENTS is not in this list on purpose — git pushes over SSH.
TO_REMOVE=()
for pkg in tailscale mosh tmux openssh-server; do
    rpm -q "$pkg" &>/dev/null && TO_REMOVE+=("$pkg")
done
if [[ ${#TO_REMOVE[@]} -gt 0 ]]; then
    log_info "Removing: ${TO_REMOVE[*]}"
    sudo dnf remove -y "${TO_REMOVE[@]}"
    log_success "Removed ${#TO_REMOVE[@]} package(s)"
else
    log_info "SKIP packages (none installed)"
fi

if [[ -f /etc/yum.repos.d/tailscale.repo ]]; then
    sudo rm -f /etc/yum.repos.d/tailscale.repo
    log_success "Removed the Tailscale dnf repo"
fi

# --- 4. Wake-on-LAN ------------------------------------------------------------
ETH_IFACE="$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^en' | head -1 || true)"
if [[ -n "$ETH_IFACE" ]]; then
    NM_CON="$(nmcli -t -f NAME,DEVICE con show --active | grep ":$ETH_IFACE\$" | cut -d: -f1 || true)"
    if [[ -n "$NM_CON" ]]; then
        CUR="$(nmcli -g 802-3-ethernet.wake-on-lan con show "$NM_CON" 2>/dev/null || true)"
        if [[ "$CUR" == "default" ]]; then
            log_info "SKIP Wake-on-LAN (already default on '$NM_CON')"
        else
            nmcli con modify "$NM_CON" 802-3-ethernet.wake-on-lan default
            log_success "Wake-on-LAN reset to the driver default on '$NM_CON'"
        fi
    fi
fi

# --- 5. User-level leftovers ---------------------------------------------------
# Only removes what this repo put there: symlinks pointing into the repo, plus
# TPM's plugin checkout. A real file someone wrote by hand is left alone.
for f in "$HOME/.config/tmux/tmux.conf" "$HOME/.config/tmux/tmux-rice.conf" \
         "$HOME/.zshenv" "$HOME/.config/starship-remote.toml" \
         "$HOME/.config/kitty/catppuccin-mocha.conf" "$HOME/.config/kitty/background.jpg" \
         "$HOME/.config/fastfetch/tmux.jsonc"; do
    if [[ -L "$f" ]]; then
        rm -f "$f"
        log_success "Removed dangling symlink: ${f/#$HOME/\~}"
    fi
done

for d in "$HOME/.tmux" "$HOME/.config/tmux"; do
    if [[ -d "$d" ]]; then
        rm -rf "$d"
        log_success "Removed ${d/#$HOME/\~} (TPM plugins / tmux config)"
    fi
done

if [[ -d "$HOME/.config/bat/themes" ]] && ls "$HOME/.config/bat/themes"/Catppuccin* &>/dev/null; then
    rm -f "$HOME/.config/bat/themes"/Catppuccin*
    bat cache --build &>/dev/null || true
    log_success "Removed the Catppuccin bat theme (BAT_THEME=ansi now)"
fi

# --- 6. Awake guard ------------------------------------------------------------
# v4 watches Claude Code transcripts instead of remote sessions; a guard still
# running the old script would keep looking for mosh that no longer exists.
if systemctl --user is-active --quiet awake-guard.service 2>/dev/null; then
    systemctl --user restart awake-guard.service
    log_success "awake-guard restarted on the new (Claude-activity) script"
fi

echo ""
log_section "Done"
log_info "Remote access from another device is now: run Claude Code here, then /rc"
log_info "Verify: rpm -q tmux mosh tailscale openssh-server  ·  systemctl --user status awake-guard"
