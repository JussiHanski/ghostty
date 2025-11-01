#!/bin/bash

# Ghostty installation script for Linux
# Detects distro and installs using appropriate method

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/detect-platform.sh"

install_dependencies() {
    echo "Installing build dependencies for $DISTRO..."

    case "$DISTRO" in
        ubuntu|debian|pop)
            sudo apt-get update
            sudo apt-get install -y git build-essential libgtk-4-dev \
                libadwaita-1-dev pkg-config pandoc chafa
            ;;
        fedora)
            sudo dnf install -y git gcc gcc-c++ gtk4-devel \
                libadwaita-devel pkgconfig pandoc chafa
            ;;
        arch|manjaro)
            sudo pacman -Sy --needed --noconfirm git base-devel gtk4 \
                libadwaita pkgconf pandoc chafa
            ;;
        *)
            echo "Warning: Unknown distribution. You may need to install dependencies manually."
            echo "Required: git, build tools, gtk4, libadwaita, pkg-config, pandoc, chafa"
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
}

check_zig() {
    if ! command -v zig &> /dev/null; then
        echo "Zig compiler not found. Installing Zig..."
        install_zig
    else
        echo "Zig is already installed: $(zig version)"
    fi
}

install_zig() {
    local ZIG_VERSION="0.13.0"
    local ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ARCH}-${ZIG_VERSION}.tar.xz"
    local INSTALL_DIR="${HOME}/.local/zig"

    echo "Downloading Zig ${ZIG_VERSION}..."
    mkdir -p "${HOME}/.local"
    cd "${HOME}/.local"

    curl -fsSL "$ZIG_URL" -o zig.tar.xz
    tar -xf zig.tar.xz
    rm zig.tar.xz
    mv "zig-linux-${ARCH}-${ZIG_VERSION}" zig

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        echo "Adding Zig to PATH..."
        echo 'export PATH="$HOME/.local/zig:$PATH"' >> "${HOME}/.bashrc"
        export PATH="${INSTALL_DIR}:$PATH"
    fi

    echo "Zig installed successfully!"
}

install_ghostty() {
    echo "Installing Ghostty from source..."

    local BUILD_DIR="${HOME}/.local/src/ghostty"

    # Clone or update repository
    if [ -d "$BUILD_DIR" ]; then
        echo "Ghostty source found. Updating..."
        cd "$BUILD_DIR"
        git pull
    else
        echo "Cloning Ghostty repository..."
        mkdir -p "${HOME}/.local/src"
        git clone https://github.com/ghostty-org/ghostty.git "$BUILD_DIR"
        cd "$BUILD_DIR"
    fi

    # Build
    echo "Building Ghostty... (this may take a few minutes)"
    zig build -Doptimize=ReleaseFast

    # Install
    echo "Installing Ghostty..."
    mkdir -p "${HOME}/.local/bin"
    cp "zig-out/bin/ghostty" "${HOME}/.local/bin/"

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

ensure_dependencies() {
    # Always ensure chafa is installed (needed for welcome image)
    if ! command -v chafa &> /dev/null; then
        echo "Installing chafa for terminal graphics..."
        case "$DISTRO" in
            ubuntu|debian|pop)
                sudo apt-get install -y chafa
                ;;
            fedora)
                sudo dnf install -y chafa
                ;;
            arch|manjaro)
                sudo pacman -S --needed --noconfirm chafa
                ;;
            *)
                echo "Warning: Unknown distribution. Cannot auto-install chafa."
                echo "Please install it manually for the welcome image to display."
                ;;
        esac
    fi
}

# Main installation flow
main() {
    echo "=== Ghostty Linux Installation ==="
    echo "OS: $OS"
    echo "Distribution: $DISTRO"
    echo "Architecture: $ARCH"
    echo

    # Always ensure chafa is installed
    ensure_dependencies

    # Check if Ghostty is already installed
    if command -v ghostty &> /dev/null; then
        echo "Ghostty is already installed: $(ghostty --version 2>&1 || echo 'version unknown')"

        # Only prompt if running interactively
        if [ -t 0 ]; then
            read -p "Reinstall/update? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Skipping Ghostty installation."
                return 0
            fi
        else
            echo "Non-interactive mode: Skipping Ghostty installation."
            return 0
        fi
    fi

    install_dependencies
    check_zig
    install_ghostty

    echo
    echo "Installation complete! You may need to restart your shell or run:"
    echo "  source ~/.bashrc"
}

main "$@"
