#!/bin/bash

# Ghostty installation script for macOS
# Uses Homebrew or builds from source

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/detect-platform.sh"

check_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found."
        read -p "Install Homebrew? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_homebrew
        else
            echo "Homebrew is required for this installation method."
            echo "Visit https://brew.sh for manual installation."
            exit 1
        fi
    else
        echo "Homebrew is already installed."
    fi
}

install_homebrew() {
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH (for Apple Silicon Macs)
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${HOME}/.zprofile"
    fi
}

install_ghostty_homebrew() {
    echo "Installing Ghostty via Homebrew..."

    # Check if tap exists
    if brew tap | grep -q "ghostty-org/tap"; then
        echo "Ghostty tap already added."
    else
        echo "Adding Ghostty tap..."
        brew tap ghostty-org/ghostty
    fi

    # Install or upgrade
    if brew list ghostty &> /dev/null; then
        echo "Ghostty is already installed. Upgrading..."
        brew upgrade ghostty
    else
        brew install ghostty
    fi

    echo "Ghostty installed via Homebrew!"
}

install_from_source() {
    echo "Installing Ghostty from source..."

    # Install dependencies
    echo "Installing build dependencies..."
    brew install git zig pandoc

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

    # Install to Applications
    echo "Installing Ghostty to /Applications..."
    if [ -d "/Applications/Ghostty.app" ]; then
        rm -rf "/Applications/Ghostty.app"
    fi
    cp -r "zig-out/bin/Ghostty.app" /Applications/

    echo "Ghostty installed successfully!"
}

# Main installation flow
main() {
    echo "=== Ghostty macOS Installation ==="
    echo "OS: $OS"
    echo "Architecture: $ARCH"
    echo

    # Check if Ghostty is already installed
    if command -v ghostty &> /dev/null || [ -d "/Applications/Ghostty.app" ]; then
        echo "Ghostty appears to be already installed."
        if command -v ghostty &> /dev/null; then
            echo "Version: $(ghostty --version 2>&1 || echo 'version unknown')"
        fi

        # Only prompt if running interactively
        if [ -t 0 ]; then
            read -p "Reinstall/update? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Skipping installation."
                return 0
            fi
        else
            echo "Non-interactive mode: Skipping installation."
            return 0
        fi
    fi

    check_homebrew

    # Prefer Homebrew installation
    echo
    echo "Installation method:"
    echo "1) Homebrew (recommended)"
    echo "2) Build from source"
    read -p "Choose [1-2]: " -n 1 -r
    echo

    case $REPLY in
        1)
            install_ghostty_homebrew
            ;;
        2)
            install_from_source
            ;;
        *)
            echo "Invalid choice. Using Homebrew (default)..."
            install_ghostty_homebrew
            ;;
    esac

    echo
    echo "Installation complete!"
}

main "$@"
