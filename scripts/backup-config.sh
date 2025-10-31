#!/bin/bash

# Backup existing Ghostty configuration
# Creates timestamped backup in ~/.config/ghostty/backups/

backup_config() {
    local CONFIG_DIR="${HOME}/.config/ghostty"
    local BACKUP_DIR="${CONFIG_DIR}/backups"
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_PATH="${BACKUP_DIR}/backup_${TIMESTAMP}"

    # Check if config directory exists
    if [ ! -d "$CONFIG_DIR" ]; then
        echo "No existing Ghostty configuration found. Skipping backup."
        return 0
    fi

    # Check if there are any files to backup
    if [ -z "$(ls -A $CONFIG_DIR 2>/dev/null | grep -v '^backups$')" ]; then
        echo "Ghostty config directory is empty. Skipping backup."
        return 0
    fi

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Create backup
    echo "Creating backup of existing Ghostty configuration..."
    mkdir -p "$BACKUP_PATH"

    # Copy all files except backups directory
    for item in "$CONFIG_DIR"/*; do
        if [ "$(basename "$item")" != "backups" ]; then
            cp -r "$item" "$BACKUP_PATH/"
        fi
    done

    echo "Backup created at: $BACKUP_PATH"

    # Keep only last 5 backups
    local BACKUP_COUNT=$(ls -1d ${BACKUP_DIR}/backup_* 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 5 ]; then
        echo "Cleaning old backups (keeping last 5)..."
        ls -1dt ${BACKUP_DIR}/backup_* | tail -n +6 | xargs rm -rf
    fi

    return 0
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    backup_config
fi
