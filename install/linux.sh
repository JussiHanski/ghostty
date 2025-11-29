#!/bin/bash

# Ghostty installation script for Linux
# Detects distro and installs using appropriate method

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/detect-platform.sh"
source "${SCRIPT_DIR}/scripts/install-log.sh"

version_lt() {
    [ "$1" != "$2" ] && [ "$1" = "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" ]
}

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
            echo "Required: git, build tools, gtk4, libadwaita, pkg-config, pandoc, blueprint-compiler (>=0.16)"
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

            # If already installed, try refreshing to the channel; otherwise install fresh.
            if snap list zig &> /dev/null; then
                sudo snap refresh zig --classic --"$ch" || true
            else
                sudo snap install zig --classic --"$ch" || true
            fi

            local SNAP_BIN="/snap/bin/zig"
            local SNAP_ZIG_VERSION=""
            if [ -x "$SNAP_BIN" ]; then
                SNAP_ZIG_VERSION="$("$SNAP_BIN" version 2>/dev/null || true)"
            fi
            if [ -z "$SNAP_ZIG_VERSION" ] && command -v zig &> /dev/null; then
                SNAP_ZIG_VERSION="$(zig version 2>/dev/null || true)"
            fi

            if [ -n "$SNAP_ZIG_VERSION" ] && { ! version_lt "$SNAP_ZIG_VERSION" "$REQUIRED" || dev_satisfies_required "$SNAP_ZIG_VERSION" "$REQUIRED"; }; then
                echo "Zig ${SNAP_ZIG_VERSION} installed via snap (${ch})."
                # Prefer snap zig on PATH for subsequent commands
                if [[ ":$PATH:" != *":/snap/bin:"* ]]; then
                    export PATH="/snap/bin:$PATH"
                fi
                log_install "ZIG_INSTALLED_BY_SCRIPT" "true"
                return 0
            else
                echo "Snap Zig version ${SNAP_ZIG_VERSION:-unknown} is below required ${REQUIRED}, trying next channel..."
            fi
        done

        # Last resort: remove and reinstall on edge
        echo "Attempting fresh install of Zig via snap (edge channel)..."
        sudo snap remove zig || true
        sudo snap install zig --classic --edge || true

        local SNAP_BIN="/snap/bin/zig"
        local SNAP_ZIG_VERSION=""
        if [ -x "$SNAP_BIN" ]; then
            SNAP_ZIG_VERSION="$("$SNAP_BIN" version 2>/dev/null || true)"
        fi
        if [ -z "$SNAP_ZIG_VERSION" ] && command -v zig &> /dev/null; then
            SNAP_ZIG_VERSION="$(zig version 2>/dev/null || true)"
        fi
        if [ -n "$SNAP_ZIG_VERSION" ] && { ! version_lt "$SNAP_ZIG_VERSION" "$REQUIRED" || dev_satisfies_required "$SNAP_ZIG_VERSION" "$REQUIRED"; }; then
            echo "Zig ${SNAP_ZIG_VERSION} installed via snap (edge)."
            if [[ ":$PATH:" != *":/snap/bin:"* ]]; then
                export PATH="/snap/bin:$PATH"
            fi
            log_install "ZIG_INSTALLED_BY_SCRIPT" "true"
            return 0
        fi

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

check_blueprint() {
    local REQUIRED_BLUEPRINT_VERSION="0.16.0"
    local CURRENT_BLUEPRINT_VERSION=""

    if command -v blueprint-compiler &> /dev/null; then
        CURRENT_BLUEPRINT_VERSION="$(blueprint-compiler --version 2>/dev/null | awk '{print $NF}')"
    fi

    if [ -z "$CURRENT_BLUEPRINT_VERSION" ] || version_lt "$CURRENT_BLUEPRINT_VERSION" "$REQUIRED_BLUEPRINT_VERSION"; then
        echo "Installing blueprint-compiler (>= ${REQUIRED_BLUEPRINT_VERSION})..."
        case "$DISTRO" in
            ubuntu|debian|pop)
                if ! sudo apt-get install -y blueprint-compiler; then
                    echo "Error: failed to install blueprint-compiler via apt. Please install version >= ${REQUIRED_BLUEPRINT_VERSION} manually."
                    exit 1
                fi
                ;;
            fedora)
                if ! sudo dnf install -y blueprint-compiler; then
                    echo "Error: failed to install blueprint-compiler via dnf. Please install version >= ${REQUIRED_BLUEPRINT_VERSION} manually."
                    exit 1
                fi
                ;;
            arch|manjaro)
                if ! sudo pacman -Sy --needed --noconfirm blueprint-compiler; then
                    echo "Error: failed to install blueprint-compiler via pacman. Please install version >= ${REQUIRED_BLUEPRINT_VERSION} manually."
                    exit 1
                fi
                ;;
            *)
                echo "Error: blueprint-compiler >= ${REQUIRED_BLUEPRINT_VERSION} is required. Please install it manually and re-run the installer."
                exit 1
                ;;
        esac

        if command -v blueprint-compiler &> /dev/null; then
            CURRENT_BLUEPRINT_VERSION="$(blueprint-compiler --version 2>/dev/null | awk '{print $NF}')"
        fi
    fi

    if [ -z "$CURRENT_BLUEPRINT_VERSION" ] || version_lt "$CURRENT_BLUEPRINT_VERSION" "$REQUIRED_BLUEPRINT_VERSION"; then
        echo "Error: blueprint-compiler >= ${REQUIRED_BLUEPRINT_VERSION} is required but version ${CURRENT_BLUEPRINT_VERSION:-unknown} was found."
        echo "Please install a newer version (see https://ghostty.org/docs/install/build) and try again."
        exit 1
    else
        echo "blueprint-compiler is available: ${CURRENT_BLUEPRINT_VERSION}"
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

install_ghostty() {
    echo "Installing Ghostty from source..."

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
    check_blueprint
    check_zig
    install_ghostty

    echo
    echo "Installation complete! You may need to restart your shell or run:"
    echo "  source ~/.bashrc"
}

main "$@"
