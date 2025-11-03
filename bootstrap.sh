#!/bin/bash

# Ghostty Bootstrap Script
# One-liner: curl -fsSL https://raw.githubusercontent.com/JussiHanski/ghostty/refs/heads/main/bootstrap.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/JussiHanski/ghostty.git"
INSTALL_DIR="${HOME}/.ghostty-config"
CONFIG_DIR="${HOME}/.config/ghostty"

# Flags
DRY_RUN=false
VERBOSE=false
SKIP_INSTALL=false

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Ghostty Bootstrap Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -d, --dry-run       Show what would be done without making changes
    -s, --skip-install  Skip Ghostty installation, only deploy config
    --uninstall         Remove Ghostty configuration (keeps Ghostty binary)

Examples:
    # Standard installation
    $0

    # Dry run to see what would happen
    $0 --dry-run

    # Only deploy configuration (Ghostty already installed)
    $0 --skip-install

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log_warning "Dry run mode enabled - no changes will be made"
                shift
                ;;
            -s|--skip-install)
                SKIP_INSTALL=true
                shift
                ;;
            --uninstall)
                uninstall_config
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

detect_platform() {
    case "$(uname -s)" in
        Linux*)
            # Check if running in WSL
            if [ -f "${INSTALL_DIR}/scripts/detect-wsl.sh" ]; then
                source "${INSTALL_DIR}/scripts/detect-wsl.sh"
                if [ "$IS_WSL" = "true" ]; then
                    PLATFORM="wsl"
                    log_info "Detected platform: WSL (Windows Subsystem for Linux)"
                    log_info "  WSL Version: $WSL_VERSION"
                    [ "$HAS_WSLG" = "true" ] && log_info "  WSLg: Available (GUI support enabled)"
                else
                    PLATFORM="linux"
                    log_info "Detected platform: Linux"
                fi
            else
                PLATFORM="linux"
                log_info "Detected platform: Linux"
            fi
            ;;
        Darwin*)
            PLATFORM="macos"
            log_info "Detected platform: macOS"
            ;;
        *)
            log_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
}

clone_or_update_repo() {
    if [ -d "$INSTALL_DIR" ]; then
        log_info "Repository already exists. Updating..."
        if [ "$DRY_RUN" = false ]; then
            cd "$INSTALL_DIR"
            git pull --quiet
        fi
    else
        log_info "Cloning repository..."
        if [ "$DRY_RUN" = false ]; then
            git clone --quiet "$REPO_URL" "$INSTALL_DIR"
        fi
    fi
    log_success "Repository ready at $INSTALL_DIR"

    # Source install log functions after repo is available
    if [ -f "${INSTALL_DIR}/scripts/install-log.sh" ]; then
        source "${INSTALL_DIR}/scripts/install-log.sh"
    fi
}

run_installer() {
    if [ "$SKIP_INSTALL" = true ]; then
        log_info "Skipping Ghostty installation (--skip-install flag)"
        return 0
    fi

    log_info "Running Ghostty installation for $PLATFORM..."

    if [ "$DRY_RUN" = false ]; then
        cd "$INSTALL_DIR"
        bash "install/${PLATFORM}.sh"
    else
        log_info "Would run: install/${PLATFORM}.sh"
    fi
}

backup_existing_config() {
    if [ ! -d "$CONFIG_DIR" ]; then
        log_info "No existing configuration found. Skipping backup."
        return 0
    fi

    if [ "$DRY_RUN" = false ]; then
        cd "$INSTALL_DIR"
        source scripts/backup-config.sh
        backup_config
    else
        log_info "Would backup existing config"
    fi
}

deploy_config() {
    log_info "Deploying Ghostty configuration..."

    if [ "$DRY_RUN" = false ]; then
        # Create config directory
        mkdir -p "$CONFIG_DIR"

        # Copy main config files
        cp "$INSTALL_DIR/config/config" "$CONFIG_DIR/"
        cp "$INSTALL_DIR/config/keybindings.conf" "$CONFIG_DIR/"

        # Copy themes
        mkdir -p "$CONFIG_DIR/themes"
        cp -r "$INSTALL_DIR/config/themes/"* "$CONFIG_DIR/themes/"

        # Copy welcome image
        if [ -f "$INSTALL_DIR/config/wizard.png" ]; then
            cp "$INSTALL_DIR/config/wizard.png" "$CONFIG_DIR/"
        fi

        # Copy welcome script
        mkdir -p "$HOME/.local/bin"
        if [ -f "$INSTALL_DIR/scripts/show-welcome.sh" ]; then
            cp "$INSTALL_DIR/scripts/show-welcome.sh" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/show-welcome.sh"
        fi

        # Add welcome script to shell profile (platform-specific)
        if [ "$PLATFORM" = "macos" ]; then
            SHELL_PROFILE="$HOME/.zprofile"
        elif [ "$PLATFORM" = "wsl" ] || [ "$PLATFORM" = "linux" ]; then
            SHELL_PROFILE="$HOME/.bashrc"
        else
            SHELL_PROFILE="$HOME/.bashrc"
        fi

        # Create shell profile if it doesn't exist
        touch "$SHELL_PROFILE"

        # Log shell profile (only if function is available)
        if type log_install &>/dev/null; then
            log_install "SHELL_PROFILE" "$SHELL_PROFILE"
        fi

        # Add welcome script if not already present
        if ! grep -q "show-welcome.sh" "$SHELL_PROFILE"; then
            echo "" >> "$SHELL_PROFILE"
            echo "# Ghostty welcome message" >> "$SHELL_PROFILE"
            echo 'if [ -n "$GHOSTTY_RESOURCES_DIR" ] && [ -f "$HOME/.local/bin/show-welcome.sh" ]; then' >> "$SHELL_PROFILE"
            echo '    "$HOME/.local/bin/show-welcome.sh"' >> "$SHELL_PROFILE"
            echo 'fi' >> "$SHELL_PROFILE"
            log_success "Added welcome message to $(basename $SHELL_PROFILE)"
        fi

        log_success "Configuration deployed to $CONFIG_DIR"
    else
        log_info "Would deploy config to $CONFIG_DIR"
        log_info "  - config"
        log_info "  - keybindings.conf"
        log_info "  - themes/"
        log_info "  - wizard.png"
        log_info "  - show-welcome.sh -> ~/.local/bin/"
        if [ "$PLATFORM" = "macos" ]; then
            log_info "  - Add welcome to .zprofile"
        elif [ "$PLATFORM" = "wsl" ]; then
            log_info "  - Add welcome to .bashrc (WSL)"
        else
            log_info "  - Add welcome to .bashrc"
        fi
    fi
}

verify_installation() {
    log_info "Verifying installation..."

    if command -v ghostty &> /dev/null; then
        local version=$(ghostty --version 2>&1 || echo "unknown")
        log_success "Ghostty is installed: $version"
    elif [ -d "/Applications/Ghostty.app" ]; then
        log_success "Ghostty is installed at /Applications/Ghostty.app"
    else
        log_warning "Ghostty binary not found in PATH"
        log_info "You may need to restart your shell or add it to PATH"
    fi

    if [ -f "$CONFIG_DIR/config" ]; then
        log_success "Configuration file exists"
    else
        log_error "Configuration file not found!"
        return 1
    fi
}

uninstall_config() {
    local INSTALL_LOG="${CONFIG_DIR}/.install_log"

    echo
    log_warning "=== Ghostty Complete Uninstall ==="
    echo
    echo "This will remove:"
    echo "  - Ghostty configuration"
    echo "  - Components installed by this script (based on install log)"
    echo "  - Shell profile modifications"
    echo

    if [ -f "$INSTALL_LOG" ]; then
        echo "Install log found. The following will be checked for removal:"

        # Source the log functions if not already loaded
        if [ -f "${INSTALL_DIR}/scripts/install-log.sh" ]; then
            source "${INSTALL_DIR}/scripts/install-log.sh"
        fi

        local platform=$(read_install_log "PLATFORM")
        local ghostty_installed=$(read_install_log "GHOSTTY_INSTALLED_BY_SCRIPT")
        local ghostty_method=$(read_install_log "GHOSTTY_INSTALL_METHOD")
        local chafa_installed=$(read_install_log "CHAFA_INSTALLED_BY_SCRIPT")
        local lazygit_installed=$(read_install_log "LAZYGIT_INSTALLED_BY_SCRIPT")
        local lazygit_ppa_added=$(read_install_log "LAZYGIT_PPA_ADDED")
        local homebrew_installed=$(read_install_log "HOMEBREW_INSTALLED_BY_SCRIPT")
        local zig_installed=$(read_install_log "ZIG_INSTALLED_BY_SCRIPT")

        echo "  - Platform: ${platform}"
        [ "$ghostty_installed" = "true" ] && echo "  - Ghostty (installed via ${ghostty_method})"
        [ "$chafa_installed" = "true" ] && echo "  - Chafa"
        [ "$lazygit_installed" = "true" ] && echo "  - Lazygit"
        [ "$homebrew_installed" = "true" ] && echo "  - Homebrew"
        [ "$zig_installed" = "true" ] && echo "  - Zig compiler"
        echo
    else
        log_warning "No install log found. Only configuration will be removed."
    fi

    read -p "Continue with uninstall? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        return 0
    fi

    # Backup configuration before removal
    if [ -d "$CONFIG_DIR" ]; then
        log_info "Backing up configuration before removal..."
        cd "$INSTALL_DIR" 2>/dev/null || true
        source scripts/backup-config.sh 2>/dev/null || true
        backup_config 2>/dev/null || true
    fi

    # Remove based on install log
    if [ -f "$INSTALL_LOG" ]; then
        source "${INSTALL_DIR}/scripts/install-log.sh"

        local platform=$(read_install_log "PLATFORM")
        local ghostty_installed=$(read_install_log "GHOSTTY_INSTALLED_BY_SCRIPT")
        local ghostty_method=$(read_install_log "GHOSTTY_INSTALL_METHOD")
        local ghostty_binary=$(read_install_log "GHOSTTY_BINARY_PATH")
        local chafa_installed=$(read_install_log "CHAFA_INSTALLED_BY_SCRIPT")
        local lazygit_installed=$(read_install_log "LAZYGIT_INSTALLED_BY_SCRIPT")
        local lazygit_ppa_added=$(read_install_log "LAZYGIT_PPA_ADDED")
        local homebrew_installed=$(read_install_log "HOMEBREW_INSTALLED_BY_SCRIPT")
        local zig_installed=$(read_install_log "ZIG_INSTALLED_BY_SCRIPT")
        local shell_profile=$(read_install_log "SHELL_PROFILE")

        # Remove Ghostty if we installed it
        if [ "$ghostty_installed" = "true" ]; then
            log_info "Removing Ghostty..."

            if [ "$platform" = "macos" ]; then
                if [ "$ghostty_method" = "homebrew" ]; then
                    if command -v brew &> /dev/null; then
                        brew uninstall ghostty 2>/dev/null || true
                        brew untap ghostty-org/ghostty 2>/dev/null || true
                    fi
                elif [ "$ghostty_method" = "source" ]; then
                    rm -rf "/Applications/Ghostty.app"
                    rm -rf "${HOME}/.local/src/ghostty"
                fi
            else
                # Linux
                rm -f "${HOME}/.local/bin/ghostty"
                rm -f "${HOME}/.local/share/applications/ghostty.desktop"
                rm -rf "${HOME}/.local/src/ghostty"
            fi

            log_success "Ghostty removed"
        fi

        # Remove chafa if we installed it
        if [ "$chafa_installed" = "true" ]; then
            log_info "Removing chafa..."

            if [ "$platform" = "macos" ]; then
                if command -v brew &> /dev/null; then
                    brew uninstall chafa 2>/dev/null || true
                fi
            else
                # Linux - note this requires manual intervention as we don't want to force uninstall
                log_warning "Chafa was installed. You may want to remove it manually:"
                log_info "  Ubuntu/Debian: sudo apt-get remove chafa"
                log_info "  Fedora: sudo dnf remove chafa"
                log_info "  Arch: sudo pacman -R chafa"
            fi

            log_success "Chafa removal complete"
        fi

        # Remove lazygit if we installed it
        if [ "$lazygit_installed" = "true" ]; then
            log_info "Removing lazygit..."

            if [ "$platform" = "macos" ]; then
                if command -v brew &> /dev/null; then
                    brew uninstall lazygit 2>/dev/null || true
                fi
            else
                # Linux
                if [ "$lazygit_ppa_added" = "true" ]; then
                    # Remove via apt and PPA
                    log_info "Removing lazygit and PPA..."
                    sudo apt-get remove -y lazygit 2>/dev/null || true
                    sudo add-apt-repository --remove ppa:lazygit-team/release -y 2>/dev/null || true
                else
                    # Installed via package manager (Fedora/Arch) or manual binary
                    log_warning "Lazygit was installed. You may want to remove it manually:"
                    log_info "  Ubuntu/Debian: sudo apt-get remove lazygit (or remove /usr/local/bin/lazygit if installed manually)"
                    log_info "  Fedora: sudo dnf remove lazygit"
                    log_info "  Arch: sudo pacman -R lazygit"
                    # Try to remove manual binary install
                    if [ -f "/usr/local/bin/lazygit" ]; then
                        sudo rm -f /usr/local/bin/lazygit 2>/dev/null || true
                    fi
                fi
            fi

            log_success "Lazygit removal complete"
        fi

        # Remove Zig if we installed it (Linux only)
        if [ "$zig_installed" = "true" ]; then
            log_info "Removing Zig compiler..."
            rm -rf "${HOME}/.local/zig"
            log_success "Zig removed"
        fi

        # Remove Homebrew if we installed it
        if [ "$homebrew_installed" = "true" ]; then
            log_warning "Homebrew was installed by this script."
            read -p "Remove Homebrew? This may affect other applications. (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Removing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
                log_success "Homebrew removed"
            fi
        fi

        # Remove shell profile modifications
        if [ -n "$shell_profile" ] && [ -f "$shell_profile" ]; then
            log_info "Removing shell profile modifications..."

            # Remove Ghostty welcome message section
            sed -i.ghostty-backup '/# Ghostty welcome message/,/^fi$/d' "$shell_profile" 2>/dev/null || \
                sed -i '.ghostty-backup' '/# Ghostty welcome message/,/^fi$/d' "$shell_profile"

            # Remove Zig PATH (Linux)
            if [ "$platform" = "linux" ]; then
                sed -i.ghostty-backup '/export PATH="\$HOME\/.local\/zig:\$PATH"/d' "$shell_profile" 2>/dev/null || \
                    sed -i '.ghostty-backup' '/export PATH="\$HOME\/.local\/zig:\$PATH"/d' "$shell_profile"
                sed -i.ghostty-backup '/export PATH="\$HOME\/.local\/bin:\$PATH"/d' "$shell_profile" 2>/dev/null || \
                    sed -i '.ghostty-backup' '/export PATH="\$HOME\/.local\/bin:\$PATH"/d' "$shell_profile"
            fi

            # Remove Homebrew PATH (macOS)
            if [ "$platform" = "macos" ]; then
                sed -i.ghostty-backup '/eval "\$(.\/opt\/homebrew\/bin\/brew shellenv)"/d' "$shell_profile" 2>/dev/null || \
                    sed -i '.ghostty-backup' '/eval "\$(.\/opt\/homebrew\/bin\/brew shellenv)"/d' "$shell_profile"
            fi

            rm -f "${shell_profile}.ghostty-backup"
            log_success "Shell profile cleaned"
        fi
    fi

    # Remove welcome script
    if [ -f "${HOME}/.local/bin/show-welcome.sh" ]; then
        rm -f "${HOME}/.local/bin/show-welcome.sh"
        log_success "Welcome script removed"
    fi

    # Remove configuration directory
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        log_success "Configuration removed from $CONFIG_DIR"
    fi

    # Remove repository
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        log_success "Repository removed from $INSTALL_DIR"
    fi

    echo
    log_success "Uninstall complete!"
    echo
    echo "You may want to:"
    echo "  1. Restart your shell or run: source ~/"$(basename ${shell_profile:-".bashrc"})
    echo "  2. Check for any remaining files in ~/.local/bin or ~/.local/src"
    echo "  3. Review your shell profile for any remaining modifications"
}

print_next_steps() {
    echo
    log_success "Installation complete!"
    echo

    # Platform-specific shell profile
    if [ "$PLATFORM" = "macos" ]; then
        SHELL_PROFILE_NAME=".zprofile"
    else
        SHELL_PROFILE_NAME=".bashrc"
    fi

    echo "Next steps:"
    echo "  1. Restart your terminal or run: source ~/$SHELL_PROFILE_NAME"
    echo "  2. Launch Ghostty"

    if [ "$PLATFORM" = "wsl" ]; then
        echo "     - From WSL terminal: ghostty"
        echo "     - From Windows Start Menu: Search for 'Ghostty'"
    fi

    echo "  3. Customize your config at: $CONFIG_DIR/config"
    echo
    echo "Configuration locations:"
    echo "  - Main config: $CONFIG_DIR/config"
    echo "  - Keybindings: $CONFIG_DIR/keybindings.conf"
    echo "  - Themes: $CONFIG_DIR/themes/"

    if [ "$PLATFORM" = "wsl" ]; then
        echo
        echo "WSL Notes:"
        echo "  - Ghostty will open as a Windows GUI application"
        echo "  - Requires WSL2 with WSLg for best experience"
        echo "  - WSL support is experimental (official support coming)"
    fi

    echo
    echo "To update in the future, run this script again!"
}

# Main execution
main() {
    echo "=== Ghostty Bootstrap ==="
    echo

    parse_args "$@"
    detect_platform
    clone_or_update_repo
    run_installer
    backup_existing_config
    deploy_config
    verify_installation
    print_next_steps
}

# Run main function
main "$@"
