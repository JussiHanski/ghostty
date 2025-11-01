# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ghostty terminal emulator configuration and auto-installer repository. The project provides automated installation and configuration management for Ghostty across Linux, macOS, and WSL (Windows Subsystem for Linux) environments, with pre-configured themes, keybindings, and a one-line installation experience.

## Repository Architecture

### Core Components

**bootstrap.sh** - Main entry point that orchestrates the entire installation flow:
- Parses command-line arguments (-v, -d, -s, --uninstall)
- Detects platform (Linux/macOS)
- Clones/updates the repository to `~/.ghostty-config`
- Delegates to platform-specific installers
- Backs up existing config before deployment
- Deploys configuration files to `~/.config/ghostty`
- Installs welcome script to `~/.local/bin/show-welcome.sh`
- Modifies `.bashrc` to add welcome message on terminal launch

**install/** - Platform-specific installation scripts:
- `linux.sh` - Builds Ghostty from source on Linux, installs Zig compiler, handles dependencies for Ubuntu/Debian, Fedora, and Arch
- `macos.sh` - Installs via Homebrew (preferred) or builds from source, handles Homebrew installation if missing
- `wsl.sh` - WSL-specific installer with WSL2/WSLg detection and validation, builds from source with Windows GUI integration

**config/** - Configuration files deployed to user's system:
- `config` - Main Ghostty configuration (font, theme, window settings, shell integration)
- `keybindings.conf` - Custom keybindings (vim-style splits, tab management)
- `themes/` - Theme files (currently Catppuccin Mocha)
- `wizard.png` - Welcome image displayed in terminal

**scripts/** - Utility scripts:
- `detect-platform.sh` - Platform/distro detection, sets OS, DISTRO, ARCH environment variables
- `detect-wsl.sh` - WSL detection and validation, sets IS_WSL, WSL_VERSION, HAS_WSLG variables
- `backup-config.sh` - Creates timestamped backups of existing config (keeps last 5)
- `show-welcome.sh` - Displays welcome message with wizard image in Ghostty terminals
- `install-log.sh` - Tracks what components were installed for safe uninstallation

### Design Patterns

1. **Platform Abstraction**: Platform-specific logic is isolated in `install/linux.sh`, `install/macos.sh`, and `install/wsl.sh`, sourced by bootstrap.sh based on detected OS

2. **WSL Detection**: Bootstrap detects WSL environments and uses WSL-specific installer that validates WSL2/WSLg requirements before installation

3. **Idempotency**: All scripts can be run multiple times safely - checks for existing installations, prompts for updates, backs up configs

4. **Dry-run Mode**: Bootstrap supports `--dry-run` flag to preview changes without modifying system

5. **Modular Configuration**: Main config imports keybindings via `config-file = keybindings.conf`, allowing separate management

6. **Install Tracking**: All installations are logged to allow safe, selective uninstallation (only removes script-installed components)

## Common Development Commands

### Testing Installation

```bash
# Preview what will be installed (no changes made)
./bootstrap.sh --dry-run

# Run installation with verbose output
./bootstrap.sh --verbose

# Deploy config only (skip Ghostty binary installation)
./bootstrap.sh --skip-install
```

### Testing Platform-Specific Installers

```bash
# Test Linux installer directly
bash install/linux.sh

# Test macOS installer directly
bash install/macos.sh
```

### Testing Utility Scripts

```bash
# Test platform detection
source scripts/detect-platform.sh
echo "OS: $OS, Distro: $DISTRO, Arch: $ARCH"

# Test backup functionality
bash scripts/backup-config.sh

# Test welcome script
bash scripts/show-welcome.sh
```

### Configuration Testing

```bash
# Validate Ghostty config syntax
ghostty --config-file config/config

# Test with local config without installing
ghostty --config-file="$(pwd)/config/config"
```

## Keybinding Conventions

The keybindings follow vim-style conventions where possible:
- **h/j/k/l** for directional navigation/resizing
- **Shift+Ctrl** prefix for navigation (goto_split)
- **Ctrl+Alt** prefix for creation (new_split)
- **Ctrl+Alt+Shift** prefix for resizing (resize_split)

Current resize amount is 100 pixels (recently increased from 10 → 25 → 100).

## Important Path Conventions

- **Installation directory**: `~/.ghostty-config` (cloned repo)
- **Config directory**: `~/.config/ghostty` (deployed config)
- **Install log**: `~/.config/ghostty/.install_log` (tracks installed components)
- **Backups**: `~/.config/ghostty/backups/backup_YYYYMMDD_HHMMSS/`
- **Linux binary**: `~/.local/bin/ghostty`
- **Linux source**: `~/.local/src/ghostty`
- **WSL binary**: `~/.local/bin/ghostty` (same as Linux)
- **WSL source**: `~/.local/src/ghostty` (same as Linux)
- **macOS binary**: `/Applications/Ghostty.app`

## Shell Integration Notes

The bootstrap modifies the appropriate shell profile based on platform:

**Linux** - modifies `.bashrc`:
1. Add `~/.local/bin` to PATH (via linux.sh installer)
2. Add `~/.local/zig` to PATH (if Zig installed)
3. Add welcome script hook (detects `$GHOSTTY_RESOURCES_DIR` environment variable)

**WSL (Windows Subsystem for Linux)** - modifies `.bashrc`:
1. Add `~/.local/bin` to PATH (via wsl.sh installer)
2. Add `~/.local/zig` to PATH (if Zig installed)
3. Add welcome script hook (detects `$GHOSTTY_RESOURCES_DIR` environment variable)
4. Update desktop database for Windows Start Menu integration

**macOS** - modifies `.zprofile`:
1. Add Homebrew to PATH (Apple Silicon only, via macos.sh installer)
2. Add welcome script hook (detects `$GHOSTTY_RESOURCES_DIR` environment variable)

All PATH modifications check if already present to avoid duplicates.

The welcome script requires `chafa` to display the wizard image - this is automatically installed by all platform installers.

## Configuration File Format

Ghostty config uses a simple `key = value` format:
- Theme switching via `theme = catppuccin-mocha`
- Keybindings via `keybind = modifier+key=action:args`
- Config imports via `config-file = keybindings.conf`

## Dependencies

**Linux Build Dependencies**:
- build-essential/gcc/base-devel (distro-specific)
- libgtk-4-dev, libadwaita-1-dev
- pkg-config
- pandoc
- chafa (for terminal graphics/welcome image display)
- Zig compiler (0.13.0, auto-installed to `~/.local/zig`)

**WSL Build Dependencies** (same as Linux, plus):
- WSL2 (required)
- WSLg (required for GUI support)
- Windows 11 OR Windows 10 Build 19044+ with latest updates
- All Linux dependencies above

**macOS Build Dependencies**:
- Homebrew
- Xcode Command Line Tools
- Zig (via brew)
- pandoc (via brew)
- chafa (via brew, for terminal graphics/welcome image display)

## WSL-Specific Notes

**WSL Detection**: The bootstrap automatically detects WSL by checking:
- `/proc/sys/kernel/osrelease` for "microsoft"
- `/proc/version` for "microsoft"
- `$WSL_DISTRO_NAME` environment variable

**WSL Version Detection**: Checks for "WSL2" or "microsoft-standard" in `/proc/version`

**WSLg Detection**: Checks for:
- `$WAYLAND_DISPLAY` or `$DISPLAY` environment variables
- `/mnt/wslg/` directory existence
- Wayland socket at `/mnt/wslg/runtime-dir/wayland-0`

**WSL Requirements Validation**: The WSL installer validates:
1. Running in WSL (not native Linux)
2. WSL2 (warns if WSL1)
3. WSLg support (warns if not available)
4. Provides upgrade instructions if requirements not met

**Windows Integration**:
- Ghostty appears in Windows Start Menu
- Can be launched from WSL terminal or Windows GUI
- Desktop file integration via `update-desktop-database`
- Opens as native Windows application window

**Known Limitations**:
- WSL support is experimental (official support on Ghostty roadmap)
- Some rendering or performance issues may occur
- Not actively fixed by Ghostty maintainers until official Windows support

## Modifying This Repository

To create a custom fork:
1. Fork the repository
2. Edit configuration files in `config/`
3. Update `REPO_URL` in `bootstrap.sh` line 16 to point to your fork
4. Update one-liner installation command in `bootstrap.sh` line 4 and README.md
