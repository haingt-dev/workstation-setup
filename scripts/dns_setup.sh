#!/bin/bash
# =============================================================================
# dns_setup.sh - Configure DNS to Cloudflare Block Malware
# =============================================================================

# Source common utilities
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# Main Logic
# =============================================================================

log_section "Configuring DNS (Cloudflare Block Malware)..."

# Check if nmcli is available
if ! check_command nmcli; then
    log_error "nmcli not found. Cannot configure DNS."
    exit 1
fi

# Get active connection
# We use -t (terse) and -f (fields) to get just the name
ACTIVE_CONN=$(nmcli -t -f NAME connection show --active | head -1)

if [[ -z "$ACTIVE_CONN" ]]; then
    log_error "No active network connection found."
    exit 1
fi

log_info "Active connection: $ACTIVE_CONN"

# Configure IPv4 DNS (1.1.1.2, 1.0.0.2)
log_info "Setting IPv4 DNS..."
if run_sudo nmcli connection modify "$ACTIVE_CONN" ipv4.dns "1.1.1.2 1.0.0.2" ipv4.ignore-auto-dns yes; then
    log_success "IPv4 DNS configured."
else
    log_error "Failed to configure IPv4 DNS."
    exit 1
fi

# Configure IPv6 DNS (2606:4700:4700::1112, 2606:4700:4700::1002)
log_info "Setting IPv6 DNS..."
if run_sudo nmcli connection modify "$ACTIVE_CONN" ipv6.dns "2606:4700:4700::1112 2606:4700:4700::1002" ipv6.ignore-auto-dns yes; then
    log_success "IPv6 DNS configured."
else
    log_error "Failed to configure IPv6 DNS."
    exit 1
fi

# Restart connection to apply changes
log_info "Restarting connection to apply changes..."
if run_sudo nmcli connection down "$ACTIVE_CONN" && run_sudo nmcli connection up "$ACTIVE_CONN"; then
    log_success "Connection restarted successfully."
    log_success "DNS setup complete!"
else
    log_error "Failed to restart connection."
    exit 1
fi