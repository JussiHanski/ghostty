#!/bin/bash

# Ghostty installation script for Linux
# Detects distro and installs using appropriate method

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/detect-platform.sh"
source "${SCRIPT_DIR}/scripts/install-log.sh"

install_dependencies() {
    echo "Installing build dependencies for $DISTRO..."

    case "$DISTRO" in
        ubuntu|debian|pop)
            sudo apt-get update
            sudo apt-get install -y git build-essential libgtk-4-dev \
                libadwaita-1-dev pkg-config pandoc
            ;;
        fedora)
            sudo dnf install -y git gcc gcc-c++ gtk4-devel \
                libadwaita-devel pkgconfig pandoc
            ;;
        arch|manjaro)
            sudo pacman -Sy --needed --noconfirm git base-devel gtk4 \
                libadwaita pkgconf pandoc
            ;;
        *)
            echo "Warning: Unknown distribution. You may need to install dependencies manually."
            echo "Required: git, build tools, gtk4, libadwaita, pkg-config, pandoc"
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
}

check_zig() {
    local REQUIRED_ZIG_VERSION="0.15.2"

    version_lt() {
        [ "$1" != "$2" ] && [ "$1" = "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" ]
    }

    dev_satisfies_required() {
        local CURRENT="$1"
        local REQUIRED="$2"

        # Accept dev builds that are at least the required major.minor, regardless of patch
        if [[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\..*-dev ]]; then
            local CUR_MAJOR="${BASH_REMATCH[1]}"
            local CUR_MINOR="${BASH_REMATCH[2]}"

            if [[ "$REQUIRED" =~ ^([0-9]+)\.([0-9]+)\. ]]; then
                local REQ_MAJOR="${BASH_REMATCH[1]}"
                local REQ_MINOR="${BASH_REMATCH[2]}"

                if [[ "$CUR_MAJOR" -gt "$REQ_MAJOR" || ( "$CUR_MAJOR" -eq "$REQ_MAJOR" && "$CUR_MINOR" -ge "$REQ_MINOR" ) ]]; then
                    return 0
                fi
            fi
        fi

        return 1
    }

    try_snap_install_zig() {
        local REQUIRED="$1"
        local channels=("stable" "beta" "edge")

        if ! command -v snap &> /dev/null; then
            return 1
        fi

        for ch in "${channels[@]}"; do
            echo "Attempting to install Zig via snap (${ch} channel)..."
            if [ "$ch" = "stable" ]; then
                sudo snap install zig --classic || true
            else
                sudo snap install zig --classic --"$ch" || true
            fi

            if command -v zig &> /dev/null; then
                local SNAP_ZIG_VERSION
                SNAP_ZIG_VERSION="$(zig version 2>/dev/null || true)"
                if ! version_lt "$SNAP_ZIG_VERSION" "$REQUIRED" || dev_satisfies_required "$SNAP_ZIG_VERSION" "$REQUIRED"; then
                    echo "Zig ${SNAP_ZIG_VERSION} installed via snap (${ch})."
                    log_install "ZIG_INSTALLED_BY_SCRIPT" "true"
                    return 0
                else
                    echo "Snap Zig version ${SNAP_ZIG_VERSION} is below required ${REQUIRED}, trying next channel..."
                fi
            fi
        done

        return 1
    }

    if command -v zig &> /dev/null; then
        local CURRENT_ZIG_VERSION
        CURRENT_ZIG_VERSION="$(zig version 2>/dev/null || true)"

        if version_lt "$CURRENT_ZIG_VERSION" "$REQUIRED_ZIG_VERSION" && ! dev_satisfies_required "$CURRENT_ZIG_VERSION" "$REQUIRED_ZIG_VERSION"; then
            echo "Found Zig ${CURRENT_ZIG_VERSION:-unknown}, but >= ${REQUIRED_ZIG_VERSION} is required. Installing correct version..."
            install_zig "$REQUIRED_ZIG_VERSION"
        else
            echo "Zig is already installed: ${CURRENT_ZIG_VERSION}"
            log_install "ZIG_INSTALLED_BY_SCRIPT" "false"
        fi
    else
        echo "Zig compiler not found. Installing Zig ${REQUIRED_ZIG_VERSION}..."
        install_zig "$REQUIRED_ZIG_VERSION"
    fi
}

download_and_install_zig() {
    local URL="$1"
    local VERSION_LABEL="$2"
    local INSTALL_DIR="${HOME}/.local/zig"

    echo "Downloading Zig ${VERSION_LABEL}..."
    mkdir -p "${HOME}/.local"
    cd "${HOME}/.local"

    curl -fsSL "$URL" -o zig.tar.xz
    tar -xf zig.tar.xz
    rm zig.tar.xz

    # Extract folder name from tarball (matches trailing .tar.xz basename minus extension)
    local FOLDER_NAME
    FOLDER_NAME="$(basename "$URL" .tar.xz)"

    rm -rf zig
    mv "$FOLDER_NAME" zig

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        echo "Adding Zig to PATH..."
        echo 'export PATH="$HOME/.local/zig:$PATH"' >> "${HOME}/.bashrc"
        export PATH="${INSTALL_DIR}:$PATH"
    fi

    log_install "ZIG_INSTALLED_BY_SCRIPT" "true"
    echo "Zig installed successfully!"
}

install_zig() {
    local ZIG_VERSION="${1:-0.15.2}"
    # Only use snap as a source. If it fails, instruct the user to install manually.
    if try_snap_install_zig "$ZIG_VERSION"; then
        return
    fi

    echo "Error: Unable to install Zig via snap. Please install Zig >= ${ZIG_VERSION} manually and re-run the installer."
    exit 1
}

try_snap_install_ghostty() {
    if ! command -v snap &> /dev/null; then
        return 1
    fi

    echo "Attempting to install Ghostty via snap..."

    if snap list ghostty &> /dev/null; then
        sudo snap refresh ghostty --classic || true
    else
        sudo snap install ghostty --classic || true
    fi

    if command -v ghostty &> /dev/null; then
        local GHOSTTY_PATH
        GHOSTTY_PATH="$(command -v ghostty)"
        local GHOSTTY_VERSION
        GHOSTTY_VERSION="$(ghostty --version 2>/dev/null || echo 'unknown')"
        echo "Ghostty installed via snap at ${GHOSTTY_PATH} (version: ${GHOSTTY_VERSION})."
        log_install "GHOSTTY_INSTALLED_BY_SCRIPT" "true"
        log_install "GHOSTTY_INSTALL_METHOD" "snap"
        log_install "GHOSTTY_BINARY_PATH" "${GHOSTTY_PATH}"
        return 0
    fi

    echo "Snap installation of Ghostty did not succeed."
    return 1
}

install_ghostty() {
    echo "Installing Ghostty..."

    if try_snap_install_ghostty; then
        return
    fi

    echo "Snap installation unavailable or failed; building Ghostty from source..."

    check_zig

    local BUILD_DIR="${HOME}/.local/src/ghostty"

    # Clone or update repository
    if [ -d "$BUILD_DIR" ]; then
        echo "Ghostty source found. Updating..."
        cd "$BUILD_DIR"
        git pull
        log_install "GHOSTTY_INSTALLED_BY_SCRIPT" "false"
    else
        echo "Cloning Ghostty repository..."
        mkdir -p "${HOME}/.local/src"
        git clone https://github.com/ghostty-org/ghostty.git "$BUILD_DIR"
        cd "$BUILD_DIR"
        log_install "GHOSTTY_INSTALLED_BY_SCRIPT" "true"
    fi

    # Build
    echo "Building Ghostty... (this may take a few minutes)"
    zig build -Doptimize=ReleaseFast

    # Install
    echo "Installing Ghostty..."
    mkdir -p "${HOME}/.local/bin"
    cp "zig-out/bin/ghostty" "${HOME}/.local/bin/"

    log_install "GHOSTTY_INSTALL_METHOD" "source"
    log_install "GHOSTTY_BINARY_PATH" "${HOME}/.local/bin/ghostty"

    # Install desktop file
    mkdir -p "${HOME}/.local/share/applications"
    if [ -f "src/apprt/gtk/ghostty.desktop" ]; then
        cp "src/apprt/gtk/ghostty.desktop" "${HOME}/.local/share/applications/"
        sed -i "s|Exec=ghostty|Exec=${HOME}/.local/bin/ghostty|g" \
            "${HOME}/.local/share/applications/ghostty.desktop"
    fi

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
        echo "Adding ${HOME}/.local/bin to PATH..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
        export PATH="${HOME}/.local/bin:$PATH"
    fi

    echo "Ghostty installed successfully!"
}

# Main installation flow
main() {
    echo "=== Ghostty Linux Installation ==="
    echo "OS: $OS"
    echo "Distribution: $DISTRO"
    echo "Architecture: $ARCH"
    echo

    # Initialize install log
    init_install_log
    log_install "PLATFORM" "linux"

    # Check if Ghostty is already installed
    if command -v ghostty &> /dev/null; then
        echo "Ghostty is already installed: $(ghostty --version 2>&1 || echo 'version unknown')"

        # Only prompt if running interactively
        if [ -t 0 ]; then
            read -p "Reinstall/update? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Skipping Ghostty installation."
                log_install "GHOSTTY_INSTALLED_BY_SCRIPT" "false"
                log_install "GHOSTTY_INSTALL_METHOD" "pre-existing"
                return 0
            fi
        else
            echo "Non-interactive mode: Skipping Ghostty installation."
            log_install "GHOSTTY_INSTALLED_BY_SCRIPT" "false"
            log_install "GHOSTTY_INSTALL_METHOD" "pre-existing"
            return 0
        fi
    fi

    install_dependencies
    # Ghostty snap is self-contained; only build deps are needed when falling back to source.
    install_ghostty

    echo
    echo "Installation complete! You may need to restart your shell or run:"
    echo "  source ~/.bashrc"
}

main "$@"
