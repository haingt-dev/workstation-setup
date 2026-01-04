#!/bin/bash

# Source common variables and functions
source "$(dirname "$0")/common.sh"

log_section "Antigravity Setup"

# Define source and target
SOURCE_FILE="${BACKUP_DIR}/.gemini/GEMINI.md"
TARGET_DIR="${HOME}/.gemini"
TARGET_FILE="${TARGET_DIR}/GEMINI.md"

# Verify source exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    log_file_action "MISSING" "$SOURCE_FILE"
    log_error "Antigravity rules file not found in assets!"
    exit 1
fi

# Ensure target directory exists
ensure_dir "$TARGET_DIR"

# Copy the file
log_info "Deploying Global Antigravity Rules..."
copy_file "$SOURCE_FILE" "$TARGET_FILE"

# Deploy Git Hook
HOOK_SOURCE="${BACKUP_DIR}/hooks/commit-msg"
HOOK_TARGET="${PROJECT_ROOT}/.git/hooks/commit-msg"

if [[ -f "$HOOK_SOURCE" ]]; then
    log_info "Deploying commit-msg hook..."
    ensure_dir "$(dirname "$HOOK_TARGET")"
    copy_file "$HOOK_SOURCE" "$HOOK_TARGET"
    chmod +x "$HOOK_TARGET"
    log_success "Git hook installed."
else
    log_warn "Git hook not found in assets. Skipping."
fi


# Success message
log_success "Antigravity Rules deployed successfully."
log_info "  Location: $TARGET_FILE"
log_info "  Rule: Read this file at start of every task."
