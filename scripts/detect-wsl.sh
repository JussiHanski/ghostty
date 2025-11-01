#!/bin/bash

# Detect if running in WSL and check WSLg support
# Usage: source detect-wsl.sh
# Sets: IS_WSL, WSL_VERSION, HAS_WSLG

detect_wsl() {
    IS_WSL=false
    WSL_VERSION="none"
    HAS_WSLG=false

    # Check if running in WSL
    if [ -f /proc/sys/kernel/osrelease ]; then
        if grep -qi microsoft /proc/sys/kernel/osrelease; then
            IS_WSL=true
        fi
    fi

    # Alternative check using /proc/version
    if [ "$IS_WSL" = false ] && [ -f /proc/version ]; then
        if grep -qi microsoft /proc/version; then
            IS_WSL=true
        fi
    fi

    # Check WSL_DISTRO_NAME environment variable (set by WSL)
    if [ -n "$WSL_DISTRO_NAME" ]; then
        IS_WSL=true
    fi

    if [ "$IS_WSL" = true ]; then
        # Detect WSL version
        if grep -qi "WSL2" /proc/version 2>/dev/null || grep -qi "microsoft-standard" /proc/version 2>/dev/null; then
            WSL_VERSION="2"
        else
            WSL_VERSION="1"
        fi

        # Check for WSLg support (GUI support)
        # WSLg is available in WSL2 on Windows 11 or Windows 10 with recent updates
        if [ "$WSL_VERSION" = "2" ]; then
            # Check if Wayland socket exists (indicates WSLg)
            if [ -n "$WAYLAND_DISPLAY" ] || [ -S "/mnt/wslg/runtime-dir/wayland-0" ] || [ -d "/mnt/wslg" ]; then
                HAS_WSLG=true
            fi

            # Check if X11 is available through WSLg
            if [ -n "$DISPLAY" ] && [[ "$DISPLAY" == *":0"* ]]; then
                HAS_WSLG=true
            fi
        fi
    fi
}

# Run detection
detect_wsl

# Export variables
export IS_WSL
export WSL_VERSION
export HAS_WSLG
