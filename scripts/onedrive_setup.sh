#!/bin/bash
# =============================================================================
# onedrive_setup.sh - Setup for OneDrive with multi-account support
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Setting up OneDrive"

# =============================================================================
# Install OneDrive Client
# =============================================================================
if ! check_command onedrive; then
    log_info "Installing OneDrive client..."
    dnf_install onedrive
    log_success "OneDrive client installed"
else
    log_info "OneDrive client is already installed"
fi

# =============================================================================
# Multi-Account Configuration Loop
# =============================================================================
echo ""
echo "This script can help you configure multiple OneDrive accounts."
echo "Each account will have its own configuration and sync directory."
echo ""

while true; do
    read -p "Do you want to configure a new OneDrive account? [y/N] " response
    if [[ ! "$response" =~ ^[yY]$ ]]; then
        break
    fi

    echo ""
    read -p "Enter a name for this account (e.g., 'personal', 'work'): " account_name
    
    if [[ -z "$account_name" ]]; then
        log_error "Account name cannot be empty."
        continue
    fi

    # Define paths
    config_dir="$HOME/.config/onedrive-${account_name}"
    sync_dir="$HOME/OneDrive/${account_name}"
    
    log_info "Creating configuration for '$account_name'..."
    
    # Create config directory
    ensure_dir "$config_dir"
    
    # Create sync directory
    ensure_dir "$sync_dir"
    
    # Create config file
    config_file="$config_dir/config"
    if [[ ! -f "$config_file" ]]; then
        echo "sync_dir = \"$sync_dir\"" > "$config_file"
        log_success "Created config file at: $config_file"
    else
        log_warn "Config file already exists at: $config_file"
    fi
    
    # Authentication
    echo ""
    log_section "Authentication for '$account_name'"
    echo "The OneDrive client will now run in interactive mode."
    echo "1. Open the URL displayed in your browser."
    echo "2. Log in with your '$account_name' Microsoft account."
    echo "3. Copy the response URL and paste it back into the terminal."
    echo ""
    read -p "Press Enter to start authentication..."
    
    # Run onedrive with the specific config directory
    # Using 'if' ensures the script doesn't exit if authentication fails (due to set -e)
    if onedrive --confdir="$config_dir" --reauth; then
        log_success "Authentication successful for '$account_name'"
        
        # Enable systemd service
        log_info "Enabling background service 'onedrive@${account_name}'..."
        systemctl --user enable --now "onedrive@${account_name}"
        log_success "Service started and enabled"
        
        # Initial sync (optional, running in background now)
        log_info "Initial sync started in background."
    else
        log_error "Authentication failed or was cancelled."
    fi
    
    echo ""
done

log_section "OneDrive Setup Complete"
echo "You can manage your services with:"
echo "  systemctl --user status onedrive@<name>"
echo "  systemctl --user stop onedrive@<name>"
echo "  systemctl --user restart onedrive@<name>"