#!/bin/bash
# =============================================================================
# input_setup.sh - Vietnamese input method support (ibus-bamboo)
# =============================================================================

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_not_root

log_section "Installing Vietnamese Input Method (ibus-bamboo)"

# =============================================================================
# Install ibus-bamboo
# =============================================================================
log_info "Installing ibus and ibus-bamboo..."

# Remove potentially corrupt repo file from previous runs to prevent dnf errors
sudo rm -f /etc/yum.repos.d/ibus-bamboo.repo

# Add OpenBuildService repo for ibus-bamboo if not already added
FEDORA_VERSION=$(rpm -E %fedora)
REPO_URL=""
FOUND_VERSION=""

# Function to check if a repo URL exists
check_repo_url() {
    local url="$1"
    if curl --output /dev/null --silent --head --fail "$url"; then
        return 0
    else
        return 1
    fi
}

# Try to find a valid repository in order of preference:
# 1. Exact match for current Fedora version
# 2. Fedora Rawhide (often works for bleeding edge)
# 3. Fedora 42 (known stable recent)
# 4. Fedora 41 (fallback)

# 1. Check exact version
URL_CANDIDATE="https://download.opensuse.org/repositories/home:/lamlng/Fedora_${FEDORA_VERSION}/home:lamlng.repo"
if check_repo_url "$URL_CANDIDATE"; then
    REPO_URL="$URL_CANDIDATE"
    FOUND_VERSION="$FEDORA_VERSION"
    log_info "Found repository for Fedora ${FEDORA_VERSION}."
else
    log_warn "Repository for Fedora ${FEDORA_VERSION} not found. Checking alternatives..."
    
    # 2. Check Rawhide
    URL_CANDIDATE="https://download.opensuse.org/repositories/home:/lamlng/Fedora_Rawhide/home:lamlng.repo"
    if check_repo_url "$URL_CANDIDATE"; then
        REPO_URL="$URL_CANDIDATE"
        FOUND_VERSION="Rawhide"
        log_info "Found repository for Fedora Rawhide."
    else
        # 3. Check Fedora 42
        URL_CANDIDATE="https://download.opensuse.org/repositories/home:/lamlng/Fedora_42/home:lamlng.repo"
        if check_repo_url "$URL_CANDIDATE"; then
            REPO_URL="$URL_CANDIDATE"
            FOUND_VERSION="42"
            log_info "Found repository for Fedora 42."
        else
            # 4. Check Fedora 41
            URL_CANDIDATE="https://download.opensuse.org/repositories/home:/lamlng/Fedora_41/home:lamlng.repo"
            if check_repo_url "$URL_CANDIDATE"; then
                REPO_URL="$URL_CANDIDATE"
                FOUND_VERSION="41"
                log_info "Found repository for Fedora 41."
            else
                log_error "Could not find a valid ibus-bamboo repository for Fedora ${FEDORA_VERSION}, Rawhide, 42, or 41."
                exit 1
            fi
        fi
    fi
fi

if [ ! -f /etc/yum.repos.d/ibus-bamboo.repo ]; then
    log_info "Downloading ibus-bamboo repository for Fedora ${FOUND_VERSION}..."
    # Use -f to fail silently on server errors (404) so we don't save HTML to the repo file
    if ! sudo curl -f -o /etc/yum.repos.d/ibus-bamboo.repo "$REPO_URL"; then
        log_error "Failed to download repository from $REPO_URL"
        exit 1
    fi

    # Verify the downloaded file is a valid repo file (not HTML)
    if ! grep -q "\[home_lamlng\]" /etc/yum.repos.d/ibus-bamboo.repo; then
        log_error "Downloaded file is not a valid repository file (likely HTML error page)."
        log_info "Removing invalid file..."
        sudo rm -f /etc/yum.repos.d/ibus-bamboo.repo
        exit 1
    fi
fi

dnf_install ibus ibus-bamboo

log_success "ibus-bamboo installed"

# =============================================================================
# Configure environment variables
# =============================================================================
log_section "Configuring input method environment..."

# Add IBus environment variables to .profile if not already present
PROFILE_FILE="$HOME/.profile"
if ! grep -q "GTK_IM_MODULE=ibus" "$PROFILE_FILE" 2>/dev/null; then
    cat >> "$PROFILE_FILE" << 'EOF'

# IBus input method configuration
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
EOF
    log_success "Added IBus environment variables to ~/.profile"
else
    log_info "IBus environment variables already configured in ~/.profile"
fi

# =============================================================================
# Configure input sources
# =============================================================================
log_section "Configuring input sources..."

# Preload IBus engines
env DCONF_PROFILE=ibus dconf write /desktop/ibus/general/preload-engines "['BambooUs', 'Bamboo']"

# Add English and Vietnamese (Bamboo) to input sources
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'Bamboo')]"

# Set Vietnamese as default (index 1)
gsettings set org.gnome.desktop.input-sources current 1

log_success "Input sources configured with Vietnamese (Bamboo) as default"

# =============================================================================
# Summary
# =============================================================================
log_section "Vietnamese Input Method Setup Complete!"
echo ""
echo "To complete setup:"
echo "  1. Log out and log back in (or reboot)"
echo "  2. The input sources are already configured with Vietnamese (Bamboo) as default"
echo ""
echo "Keyboard shortcut to switch input: Super+Space (default)"
echo ""
log_info "Typing method: Telex by default. Configure via ibus-bamboo settings."