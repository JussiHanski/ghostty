#!/bin/bash

# Ghostty installation script for macOS
# Uses Homebrew or builds from source

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/detect-platform.sh"
source "${SCRIPT_DIR}/scripts/install-log.sh"

check_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found."
        read -p "Install Homebrew? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Set environment variables to suppress Homebrew hints
            export HOMEBREW_NO_INSTALL_CLEANUP=1
            export HOMEBREW_NO_ENV_HINTS=1
            install_homebrew
            log_install "HOMEBREW_INSTALLED_BY_SCRIPT" "true"
        else
            echo "Homebrew is required for this installation method."
            echo "Visit https://brew.sh for manual installation."
            exit 1
        fi
    else
        echo "Homebrew is already installed."
        log_install "HOMEBREW_INSTALLED_BY_SCRIPT" "false"
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
        log_install "GHOSTTY_INSTALLED_BY_SCRIPT" "false"
    else
        brew install ghostty
        log_install "GHOSTTY_INSTALLED_BY_SCRIPT" "true"
    fi

    log_install "GHOSTTY_INSTALL_METHOD" "homebrew"
    log_install "GHOSTTY_BINARY_PATH" "$(which ghostty 2>/dev/null || echo '/Applications/Ghostty.app')"

    # Install chafa for welcome image display
    if ! command -v chafa &> /dev/null; then
        echo "Installing chafa for terminal graphics..."
        brew install chafa
        log_install "CHAFA_INSTALLED_BY_SCRIPT" "true"
    else
        log_install "CHAFA_INSTALLED_BY_SCRIPT" "false"
    fi

    echo "Ghostty installed via Homebrew!"
}

install_from_source() {
    echo "Installing Ghostty from source..."

    # Track chafa installation
    local chafa_was_installed=false
    if ! command -v chafa &> /dev/null; then
        chafa_was_installed=true
    fi

    # Install dependencies
    echo "Installing build dependencies..."
    brew install git zig pandoc chafa

    if [ "$chafa_was_installed" = true ]; then
        log_install "CHAFA_INSTALLED_BY_SCRIPT" "true"
    else
        log_install "CHAFA_INSTALLED_BY_SCRIPT" "false"
    fi

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

    # Install to Applications
    echo "Installing Ghostty to /Applications..."
    if [ -d "/Applications/Ghostty.app" ]; then
        rm -rf "/Applications/Ghostty.app"
    fi
    cp -r "zig-out/bin/Ghostty.app" /Applications/

    log_install "GHOSTTY_INSTALL_METHOD" "source"
    log_install "GHOSTTY_BINARY_PATH" "/Applications/Ghostty.app"

    echo "Ghostty installed successfully!"
}

ensure_dependencies() {
    # Always ensure chafa is installed (needed for welcome image)
    if ! command -v chafa &> /dev/null; then
        echo "Installing chafa for terminal graphics..."
        if command -v brew &> /dev/null; then
            brew install chafa
            log_install "CHAFA_INSTALLED_BY_SCRIPT" "true"
        else
            echo "Warning: Homebrew not found. Cannot install chafa."
            echo "Install it manually: brew install chafa"
        fi
    else
        # Only log if not already logged by install functions
        if [ -z "$(read_install_log CHAFA_INSTALLED_BY_SCRIPT)" ]; then
            log_install "CHAFA_INSTALLED_BY_SCRIPT" "false"
        fi
    fi
}

# Main installation flow
main() {
    echo "=== Ghostty macOS Installation ==="
    echo "OS: $OS"
    echo "Architecture: $ARCH"
    echo

    # Suppress Homebrew hints and cleanup messages
    export HOMEBREW_NO_INSTALL_CLEANUP=1
    export HOMEBREW_NO_ENV_HINTS=1

    # Initialize install log
    init_install_log
    log_install "PLATFORM" "macos"

    # Always ensure dependencies are installed
    check_homebrew
    ensure_dependencies

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
