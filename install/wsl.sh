#!/bin/bash

# Ghostty installation script for WSL (Windows Subsystem for Linux)
# Requires WSL2 with WSLg for GUI support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/detect-platform.sh"
source "${SCRIPT_DIR}/scripts/detect-wsl.sh"
source "${SCRIPT_DIR}/scripts/install-log.sh"

check_wsl_requirements() {
    echo "=== Checking WSL Requirements ==="
    echo

    if [ "$IS_WSL" != "true" ]; then
        echo "Error: This script is for WSL only."
        echo "You appear to be running on native Linux."
        echo "Use the regular Linux installer instead."
        exit 1
    fi

    echo "✓ Running in WSL"
    echo "  WSL Version: $WSL_VERSION"

    if [ "$WSL_VERSION" != "2" ]; then
        echo
        echo "⚠️  WARNING: WSL1 detected"
        echo
        echo "Ghostty requires WSL2 for best performance and GUI support."
        echo
        echo "To upgrade to WSL2:"
        echo "  1. Open PowerShell as Administrator (in Windows)"
        echo "  2. Run: wsl --set-version $WSL_DISTRO_NAME 2"
        echo "  3. Wait for conversion to complete"
        echo "  4. Re-run this installer"
        echo
        read -p "Continue anyway? (not recommended) (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "✓ WSL2 detected"
    fi

    if [ "$HAS_WSLG" != "true" ]; then
        echo
        echo "⚠️  WARNING: WSLg not detected"
        echo
        echo "Ghostty is a GUI application and requires WSLg (GUI support)."
        echo
        echo "WSLg Requirements:"
        echo "  - Windows 11, OR"
        echo "  - Windows 10 Build 19044+ with latest updates"
        echo
        echo "To enable WSLg:"
        echo "  1. Update Windows to latest version"
        echo "  2. Open PowerShell as Administrator"
        echo "  3. Run: wsl --update"
        echo "  4. Run: wsl --shutdown"
        echo "  5. Restart WSL and re-run this installer"
        echo
        echo "Without WSLg, Ghostty may not display correctly."
        echo
        read -p "Continue anyway? (not recommended) (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "✓ WSLg detected (GUI support available)"
        echo "  DISPLAY: $DISPLAY"
        [ -n "$WAYLAND_DISPLAY" ] && echo "  WAYLAND_DISPLAY: $WAYLAND_DISPLAY"
    fi

    echo
    echo "All requirements satisfied!"
    echo
}

cleanup_broken_ppas() {
    # Remove broken lazygit PPA if it exists (doesn't support all Ubuntu versions)
    if [ -f /etc/apt/sources.list.d/lazygit-team-ubuntu-release-*.list ]; then
        echo "Removing broken lazygit PPA from previous installation attempt..."
        sudo add-apt-repository --remove ppa:lazygit-team/release -y 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/lazygit-team-ubuntu-release-*.list 2>/dev/null || true
    fi
}

install_dependencies() {
    echo "Installing build dependencies for WSL ($DISTRO)..."

    case "$DISTRO" in
        ubuntu|debian|pop)
            cleanup_broken_ppas
            sudo apt-get update
            sudo apt-get install -y libgtk-4-dev libadwaita-1-dev blueprint-compiler
            ;;
        fedora)
            sudo dnf install -y git gcc gcc-c++ gtk4-devel \
                libadwaita-devel pkgconfig pandoc chafa lazygit
            ;;
        arch|manjaro)
            sudo pacman -Sy --needed --noconfirm git base-devel gtk4 \
                libadwaita pkgconf pandoc chafa lazygit
            ;;
        *)
            echo "Warning: Unknown distribution: $DISTRO"
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
        log_install "ZIG_INSTALLED_BY_SCRIPT" "false"
    fi
}

install_zig() {
    echo "Installing Zig via snap..."
    sudo snap install --beta zig --classic
    log_install "ZIG_INSTALLED_BY_SCRIPT" "true"
    log_install "ZIG_INSTALL_METHOD" "snap"
    echo "Zig installed successfully!"
}

install_ghostty() {
    echo "Installing Ghostty from source..."

    local BUILD_DIR="${HOME}/.local/src/ghostty"
    # Build from main branch

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

    # Build and install
    echo "Building and installing Ghostty... (this may take a few minutes)"
    sudo zig build -p /usr -Doptimize=ReleaseFast

    log_install "GHOSTTY_INSTALL_METHOD" "source"
    log_install "GHOSTTY_BINARY_PATH" "/usr/bin/ghostty"

    # Desktop file is installed by zig build -p /usr automatically
    # Update desktop database for WSLg
    if command -v update-desktop-database &> /dev/null; then
        sudo update-desktop-database /usr/share/applications 2>/dev/null || true
    fi

    echo "Ghostty installed successfully!"
}

ensure_user_dependencies() {
    # Always ensure chafa is installed (needed for welcome image)
    if ! command -v chafa &> /dev/null; then
        echo "Installing chafa for terminal graphics..."
        case "$DISTRO" in
            ubuntu|debian|pop)
                sudo apt-get install -y chafa
                log_install "CHAFA_INSTALLED_BY_SCRIPT" "true"
                ;;
            fedora)
                sudo dnf install -y chafa
                log_install "CHAFA_INSTALLED_BY_SCRIPT" "true"
                ;;
            arch|manjaro)
                sudo pacman -S --needed --noconfirm chafa
                log_install "CHAFA_INSTALLED_BY_SCRIPT" "true"
                ;;
            *)
                echo "Warning: Unknown distribution. Cannot auto-install chafa."
                echo "Please install it manually for the welcome image to display."
                log_install "CHAFA_INSTALLED_BY_SCRIPT" "false"
                ;;
        esac
    else
        if [ -z "$(read_install_log CHAFA_INSTALLED_BY_SCRIPT)" ]; then
            log_install "CHAFA_INSTALLED_BY_SCRIPT" "false"
        fi
    fi

    # Always ensure lazygit is installed
    if ! command -v lazygit &> /dev/null; then
        echo "Installing lazygit..."
        case "$DISTRO" in
            ubuntu|debian|pop)
                # Install from GitHub releases (PPA doesn't support all Ubuntu versions)
                LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
                curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
                tar xf lazygit.tar.gz lazygit
                sudo install lazygit /usr/local/bin
                rm lazygit lazygit.tar.gz
                log_install "LAZYGIT_INSTALLED_BY_SCRIPT" "true"
                ;;
            fedora)
                sudo dnf install -y lazygit
                log_install "LAZYGIT_INSTALLED_BY_SCRIPT" "true"
                ;;
            arch|manjaro)
                sudo pacman -S --needed --noconfirm lazygit
                log_install "LAZYGIT_INSTALLED_BY_SCRIPT" "true"
                ;;
            *)
                echo "Warning: Unknown distribution. Cannot auto-install lazygit."
                echo "Please install it manually from: https://github.com/jesseduffield/lazygit"
                log_install "LAZYGIT_INSTALLED_BY_SCRIPT" "false"
                ;;
        esac
    else
        if [ -z "$(read_install_log LAZYGIT_INSTALLED_BY_SCRIPT)" ]; then
            log_install "LAZYGIT_INSTALLED_BY_SCRIPT" "false"
        fi
    fi
}

print_wsl_info() {
    echo
    echo "=== WSL-Specific Information ==="
    echo
    echo "Ghostty is now installed and should work with WSLg."
    echo
    echo "Launching Ghostty:"
    echo "  - From WSL terminal: ghostty"
    echo "  - From Windows Start Menu: Search for 'Ghostty'"
    echo "  - Ghostty will open as a Windows GUI application"
    echo
    echo "Known Issues:"
    echo "  - Ghostty in WSL is experimental (official support coming later)"
    echo "  - Some rendering or performance issues may occur"
    echo "  - Report issues at: https://github.com/ghostty-org/ghostty/issues"
    echo
    echo "Windows Integration:"
    echo "  - You can pin Ghostty to Windows taskbar"
    echo "  - Desktop entry available in WSL app menu"
    echo
}

# Main installation flow
main() {
    echo "=== Ghostty WSL Installation ==="
    echo "OS: $OS"
    echo "Distribution: $DISTRO"
    echo "Architecture: $ARCH"
    echo

    # Initialize install log
    init_install_log
    log_install "PLATFORM" "wsl"
    log_install "WSL_VERSION" "$WSL_VERSION"
    log_install "HAS_WSLG" "$HAS_WSLG"

    # Check WSL requirements first
    check_wsl_requirements

    # Always ensure user dependencies are installed (chafa, lazygit, etc.)
    ensure_user_dependencies

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
    check_zig
    install_ghostty
    print_wsl_info

    echo
    echo "Installation complete! You may need to restart your shell or run:"
    echo "  source ~/.bashrc"
}

main "$@"
