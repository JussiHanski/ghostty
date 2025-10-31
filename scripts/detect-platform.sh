#!/bin/bash

# Detect platform and distribution
# Usage: source detect-platform.sh
# Sets: OS, DISTRO, ARCH

detect_platform() {
    # Detect OS
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            ;;
        Darwin*)
            OS="macos"
            ;;
        *)
            echo "Error: Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac

    # Detect architecture
    ARCH="$(uname -m)"

    # Detect Linux distribution
    if [ "$OS" = "linux" ]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO="$ID"
            DISTRO_VERSION="$VERSION_ID"
        elif [ -f /etc/lsb-release ]; then
            . /etc/lsb-release
            DISTRO="$(echo $DISTRIB_ID | tr '[:upper:]' '[:lower:]')"
            DISTRO_VERSION="$DISTRIB_RELEASE"
        else
            DISTRO="unknown"
            DISTRO_VERSION="unknown"
        fi
    fi
}

# Run detection
detect_platform

# Export variables
export OS
export DISTRO
export DISTRO_VERSION
export ARCH
