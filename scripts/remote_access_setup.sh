#!/bin/bash
# =============================================================================
# remote_access_setup.sh - Remote access for iPad/mobile workstation
# =============================================================================
#
# Installs and configures:
# - Tailscale (mesh VPN)
# - OpenSSH server (enabled + started)
# - Mosh (resilient UDP shell for iPad/Termius — survives roaming/sleep/IP change)
# - Wake-on-LAN via ethtool (for Realtek 2.5G LAN)
# - awake-guard: blocks auto-suspend ONLY while remote sessions are open
#   (KDE default suspend stays; the claude-inhibit hooks guard running tasks)
#
# Hardware: ASUS TUF B650M-E WIFI (Realtek 2.5G Ethernet)
# BIOS manual step: Delete → Advanced → APM Configuration →
#   - Restore AC Power Loss = Power On (for smart plug boot)
#   - Power On By PCI-E = Enabled (for WoL)
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Remote Access Setup"

# =============================================================================
# 1. OpenSSH Server
# =============================================================================
log_info "Setting up OpenSSH server..."

if ! rpm -q openssh-server &>/dev/null; then
    dnf_install openssh-server
else
    log_success "openssh-server already installed"
fi

run_sudo systemctl enable --now sshd
log_success "SSH server enabled and started"

# Mosh — resilient mobile shell (survives roaming / sleep-wake / IP change).
# Without mosh-server installed, Termius/iPad clients with "Mosh" enabled
# authenticate over SSH then drop the session instantly. UDP 60000-61000 is
# already covered by the tailscale0 trusted zone (all tailnet traffic allowed).
if ! rpm -q mosh &>/dev/null; then
    dnf_install mosh
    log_success "mosh installed (mosh-server available)"
else
    log_success "mosh already installed"
fi

# =============================================================================
# 2. Tailscale
# =============================================================================
log_info "Setting up Tailscale..."

if ! check_command tailscale; then
    # Official Tailscale install for Fedora/Nobara
    run_sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    dnf_install tailscale
    log_success "Tailscale installed"
else
    log_success "Tailscale already installed"
fi

run_sudo systemctl enable --now tailscaled
if systemctl is-active --quiet tailscaled; then
    log_success "Tailscale daemon enabled and running"
else
    log_warn "Tailscale daemon enabled but not yet active — check: systemctl status tailscaled"
fi

# Add tailscale0 to trusted firewall zone (allow all tailnet traffic)
if check_command firewall-cmd; then
    if ! run_sudo firewall-cmd --zone=trusted --list-interfaces 2>/dev/null | grep -q tailscale0; then
        run_sudo firewall-cmd --zone=trusted --add-interface=tailscale0 --permanent
        run_sudo firewall-cmd --reload
        log_success "Firewall: tailscale0 added to trusted zone"
    else
        log_success "Firewall: tailscale0 already in trusted zone"
    fi
fi

# Check if already authenticated
if tailscale status &>/dev/null; then
    log_success "Tailscale already authenticated"
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
    log_info "Tailscale IP: $TAILSCALE_IP"
else
    log_warn "Tailscale not authenticated yet"
    log_info "Run: sudo tailscale up"
    log_info "Then authenticate in browser"
fi

# =============================================================================
# 3. Wake-on-LAN (ethtool)
# =============================================================================
log_info "Setting up Wake-on-LAN..."

if ! check_command ethtool; then
    dnf_install ethtool
else
    log_success "ethtool already installed"
fi

# Find primary ethernet interface
ETH_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^en' | head -1)

if [[ -n "$ETH_IFACE" ]]; then
    # Enable WoL on the interface
    run_sudo ethtool -s "$ETH_IFACE" wol g 2>/dev/null && \
        log_success "WoL enabled on $ETH_IFACE (magic packet)" || \
        log_warn "Could not enable WoL on $ETH_IFACE (check BIOS: Power On By PCI-E = Enabled)"

    # Make WoL persistent via NetworkManager
    NM_CON=$(nmcli -t -f NAME,DEVICE con show --active | grep "$ETH_IFACE" | cut -d: -f1)
    if [[ -n "$NM_CON" ]]; then
        nmcli con modify "$NM_CON" 802-3-ethernet.wake-on-lan magic
        log_success "WoL persistent via NetworkManager on '$NM_CON'"
    fi

    # Show MAC address for WoL packet
    MAC=$(ip link show "$ETH_IFACE" | awk '/ether/ {print $2}')
    log_info "MAC address ($ETH_IFACE): $MAC — save this for WoL apps"
else
    log_warn "No ethernet interface found — WoL requires wired connection"
fi

# =============================================================================
# 4. Awake guard — conditional suspend blocking (remote sessions)
# =============================================================================
# Plasma 6 default: suspend after 15 min without LOCAL input. Remote activity
# (SSH/mosh) does NOT reset the idle timer, so a locally-started session
# suspends mid-iPad-session and drops off the tailnet — from Termius it looks
# identical to a crash. Bit three times: 2026-07-07 17:45 + 2026-07-08 23:17
# + 2026-07-10 14:07 — the third AFTER guard v1 shipped, because who(1)-based
# detection is blind to mosh on Fedora 43 (see awake-guard.sh header).
# (journal: 'systemd-logind: The system will suspend now!').
#
# Design: auto-suspend stays at the KDE DEFAULT (PC sleeps normally at home).
# Three conditional layers keep it awake only when there's a reason:
#   1. The Claude Code inhibit hooks (~/.claude/hooks/claude-inhibit-*.sh)
#      hold a sleep inhibitor while a task runs.
#   2. awake-guard.service holds one while a remote mosh/SSH session is open
#      (human reading/thinking on iPad — shell idle, but suspend would be rude);
#      detection is by live processes (mosh-server / sshd-session), NOT
#      who/utmp — blind to mosh on Fedora 43 (see awake-guard.sh header);
#      assets/.zshrc kicks it (USR1) on remote login for an instant poll.
#   3. MOSH_SERVER_NETWORK_TMOUT (assets/.zshenv) reaps stale mosh-servers so
#      a force-killed Termius can't hold the guard's inhibitor forever.
# PowerDevil honors systemd block inhibitors (PolicyAgent imports logind
# inhibitors — verified in Plasma/6.6 source, powerdevilpolicyagent.cpp).
# NOTE: this box autologs into Plasma on every boot (plasmalogin-autologin —
# no idle-safe greeter), so a remotely-booted host suspends ~15 min after
# power-on unless a remote session connects first. Connect promptly.
log_info "Setting up awake-guard (conditional suspend blocking)..."

# Migrate away the interim global fix (2026-07-09): default suspend is desired.
if check_command kwriteconfig6; then
    OLD_SUSPEND=$(kreadconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction 2>/dev/null || true)
    if [[ "$OLD_SUSPEND" == "0" ]]; then
        kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction --delete
        systemctl --user restart plasma-powerdevil.service 2>/dev/null || true
        log_success "Migrated: removed interim global auto-suspend disable (back to KDE default)"
    fi
fi

# link_file returns 1 on a missing asset — guard the chain so `set -e` can't
# silently abort the script mid-section, and don't enable a unit whose script
# failed to link.
if link_file ".local/bin/awake-guard.sh" ~/.local/bin/awake-guard.sh \
    && link_file ".config/systemd/user/awake-guard.service" ~/.config/systemd/user/awake-guard.service \
    && link_file ".zshenv" ~/.zshenv; then
    if systemctl --user daemon-reload 2>/dev/null \
        && systemctl --user enable --now awake-guard.service 2>/dev/null; then
        if systemctl --user is-active --quiet awake-guard.service; then
            log_success "awake-guard running (inhibits sleep only while remote sessions exist)"
        else
            log_warn "awake-guard enabled but not active — check: systemctl --user status awake-guard"
        fi
    else
        log_warn "systemd user manager unavailable — run later: systemctl --user enable --now awake-guard"
    fi
else
    log_warn "awake-guard assets missing — section skipped (incomplete checkout?)"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "Remote Access Setup Complete"
echo ""
log_info "Services:"
echo "  SSH:       $(systemctl is-active sshd) (port 22)"
echo "  Tailscale: $(systemctl is-active tailscaled)"
echo "  Mosh:      $(command -v mosh-server >/dev/null 2>&1 && echo installed || echo 'MISSING (dnf install mosh)')"
echo "  Session:   tmux 'work' — auto-attaches on connect (assets/.zshrc); manual: tmux new -s work"
echo "  Awake:     $(systemctl --user is-active awake-guard.service 2>/dev/null || echo inactive) — suspend blocked only while remote sessions exist"
echo ""

if ! tailscale status &>/dev/null; then
    log_warn "NEXT STEP: Authenticate Tailscale"
    echo "  sudo tailscale up"
    echo "  → Open the URL in browser to authenticate"
    echo ""
fi

log_info "BIOS steps (manual, one-time):"
echo "  1. Reboot → Delete key → Advanced → APM Configuration"
echo "  2. Set 'Restore AC Power Loss' = Power On"
echo "  3. Set 'Power On By PCI-E' = Enabled"
echo "  4. F10 → Save & Exit"
echo ""
log_info "iPad setup:"
echo "  1. Install Tailscale → login same account (keep it ON — a node that"
echo "     goes offline ~months drops off the tailnet and won't route)"
echo "  2. Install Termius → host = <tailscale-ip>, user = $(whoami)"
echo "     → enable Mosh in the host entry (survives 4G↔wifi, sleep, drops)"
echo "  3. Connect → auto-attaches to tmux session 'work' (assets/.zshrc)"
echo "  4. Detach: Ctrl-a d · reconnecting re-attaches automatically"
echo ""
if [[ -n "$MAC" ]]; then
    log_info "WoL MAC: $MAC"
fi
