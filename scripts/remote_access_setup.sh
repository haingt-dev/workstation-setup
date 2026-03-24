#!/bin/bash
# =============================================================================
# remote_access_setup.sh - Remote access for iPad/mobile workstation
# =============================================================================
#
# Installs and configures:
# - Tailscale (mesh VPN)
# - OpenSSH server (enabled + started)
# - Wake-on-LAN via ethtool (for Realtek 2.5G LAN)
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

sudo systemctl enable --now sshd
log_success "SSH server enabled and started"

# =============================================================================
# 2. Tailscale
# =============================================================================
log_info "Setting up Tailscale..."

if ! check_command tailscale; then
    # Official Tailscale install for Fedora/Nobara
    sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    dnf_install tailscale
    log_success "Tailscale installed"
else
    log_success "Tailscale already installed"
fi

sudo systemctl enable --now tailscaled
log_success "Tailscale daemon enabled and started"

# Add tailscale0 to trusted firewall zone (allow all tailnet traffic)
if check_command firewall-cmd; then
    if ! sudo firewall-cmd --zone=trusted --list-interfaces 2>/dev/null | grep -q tailscale0; then
        sudo firewall-cmd --zone=trusted --add-interface=tailscale0 --permanent
        sudo firewall-cmd --reload
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
    sudo ethtool -s "$ETH_IFACE" wol g 2>/dev/null && \
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
# Summary
# =============================================================================
echo ""
log_section "Remote Access Setup Complete"
echo ""
log_info "Services:"
echo "  SSH:       $(systemctl is-active sshd) (port 22)"
echo "  Tailscale: $(systemctl is-active tailscaled)"
echo "  Session:   tmux (use 'tmux new -s work' for persistent sessions)"
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
echo "  1. Install Tailscale → login same account"
echo "  2. Install Termius (free) → connect: ssh $(whoami)@<tailscale-ip>"
echo "  3. Start persistent session: tmux new -s work"
echo "  4. Reconnect after drop: tmux attach -t work"
echo ""
if [[ -n "$MAC" ]]; then
    log_info "WoL MAC: $MAC"
fi
