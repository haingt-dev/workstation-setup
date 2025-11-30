#!/bin/bash
# =============================================================================
# qdrant_setup.sh - Qdrant vector database setup with Podman
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

QDRANT_STORAGE="$HOME/qdrant_storage"

# =============================================================================
# Ensure Podman is installed
# =============================================================================
log_section "Checking Podman..."

if ! check_command podman; then
    log_info "Podman not found, installing..."
    dnf_install podman podman-compose
    log_success "Podman installed"
else
    log_success "Podman is already installed"
fi

# =============================================================================
# Create Storage Directory
# =============================================================================
log_section "Setting up Qdrant storage..."
ensure_dir "$QDRANT_STORAGE"
log_success "Qdrant storage directory: $QDRANT_STORAGE"

# =============================================================================
# Pull Qdrant Image
# =============================================================================
log_section "Pulling Qdrant image..."
podman pull qdrant/qdrant
log_success "Qdrant image pulled"

# =============================================================================
# Create Systemd User Service
# =============================================================================
log_section "Creating systemd user service for Qdrant..."

ensure_dir "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/qdrant.service" << EOF
[Unit]
Description=Qdrant Vector Database Container
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStartPre=-/usr/bin/podman stop -t 10 qdrant
ExecStartPre=-/usr/bin/podman rm qdrant
ExecStart=/usr/bin/podman run --rm --name qdrant \\
    -p 6333:6333 -p 6334:6334 \\
    -v $HOME/qdrant_storage:/qdrant/storage:Z \\
    qdrant/qdrant
ExecStop=/usr/bin/podman stop -t 10 qdrant

[Install]
WantedBy=default.target
EOF

log_success "Qdrant systemd service file created"

# =============================================================================
# Enable and Start Service
# =============================================================================
log_section "Enabling Qdrant service..."

# Reload systemd user daemon
systemctl --user daemon-reload
log_success "Systemd user daemon reloaded"

# Enable and start Qdrant service
systemctl --user enable --now qdrant
log_success "Qdrant service enabled and started"

# Enable lingering so service starts on boot without login
loginctl enable-linger "$USER"
log_success "User lingering enabled (Qdrant will start on boot)"

log_section "Qdrant setup complete!"
echo ""
log_info "Qdrant is running at: http://localhost:6333"
log_info "gRPC endpoint: localhost:6334"