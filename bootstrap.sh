#!/bin/bash

# Ghostty Bootstrap Script
# One-liner: curl -fsSL https://raw.githubusercontent.com/JussiHanski/ghostty/main/bootstrap.sh | bash

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
            PLATFORM="linux"
            ;;
        Darwin*)
            PLATFORM="macos"
            ;;
        *)
            log_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac

    log_info "Detected platform: $PLATFORM"
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

        log_success "Configuration deployed to $CONFIG_DIR"
    else
        log_info "Would deploy config to $CONFIG_DIR"
        log_info "  - config"
        log_info "  - keybindings.conf"
        log_info "  - themes/"
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
    log_warning "This will remove Ghostty configuration (binary will remain)"
    read -p "Continue? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        return 0
    fi

    if [ -d "$CONFIG_DIR" ]; then
        log_info "Backing up configuration before removal..."
        cd "$INSTALL_DIR" 2>/dev/null || true
        source scripts/backup-config.sh 2>/dev/null || true
        backup_config 2>/dev/null || true

        rm -rf "$CONFIG_DIR"
        log_success "Configuration removed from $CONFIG_DIR"
    fi

    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        log_success "Repository removed from $INSTALL_DIR"
    fi

    log_success "Uninstall complete"
}

print_next_steps() {
    echo
    log_success "Installation complete!"
    echo
    echo "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.bashrc (Linux) or source ~/.zprofile (macOS)"
    echo "  2. Launch Ghostty"
    echo "  3. Customize your config at: $CONFIG_DIR/config"
    echo
    echo "Configuration locations:"
    echo "  - Main config: $CONFIG_DIR/config"
    echo "  - Keybindings: $CONFIG_DIR/keybindings.conf"
    echo "  - Themes: $CONFIG_DIR/themes/"
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
