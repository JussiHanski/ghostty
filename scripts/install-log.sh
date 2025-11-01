#!/bin/bash

# Install Log Management
# Tracks what was installed by the bootstrap script for clean uninstall

INSTALL_LOG="${HOME}/.config/ghostty/.install_log"

# Initialize install log
init_install_log() {
    mkdir -p "$(dirname "$INSTALL_LOG")"
    cat > "$INSTALL_LOG" <<EOF
# Ghostty Installation Log
# This file tracks what was installed by the bootstrap script
# Generated: $(date)

PLATFORM=
GHOSTTY_INSTALLED_BY_SCRIPT=false
GHOSTTY_INSTALL_METHOD=none
GHOSTTY_BINARY_PATH=
CHAFA_INSTALLED_BY_SCRIPT=false
HOMEBREW_INSTALLED_BY_SCRIPT=false
ZIG_INSTALLED_BY_SCRIPT=false
SHELL_PROFILE=
INSTALL_DATE=$(date +%Y%m%d_%H%M%S)
EOF
}

# Update a value in the install log
log_install() {
    local key="$1"
    local value="$2"

    if [ ! -f "$INSTALL_LOG" ]; then
        init_install_log
    fi

    # Update or add the key
    if grep -q "^${key}=" "$INSTALL_LOG" 2>/dev/null; then
        # Using | as delimiter to avoid conflicts with paths containing /
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$INSTALL_LOG"
        rm -f "${INSTALL_LOG}.bak"
    else
        echo "${key}=${value}" >> "$INSTALL_LOG"
    fi
}

# Read a value from the install log
read_install_log() {
    local key="$1"

    if [ ! -f "$INSTALL_LOG" ]; then
        echo ""
        return 1
    fi

    grep "^${key}=" "$INSTALL_LOG" 2>/dev/null | cut -d= -f2-
}

# Export functions for sourcing
export -f init_install_log
export -f log_install
export -f read_install_log
