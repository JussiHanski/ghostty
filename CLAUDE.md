# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ghostty terminal emulator configuration and auto-installer repository. The project provides automated installation and configuration management for Ghostty across Linux and macOS environments, with pre-configured themes, keybindings, and a one-line installation experience.

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

**config/** - Configuration files deployed to user's system:
- `config` - Main Ghostty configuration (font, theme, window settings, shell integration)
- `keybindings.conf` - Custom keybindings (vim-style splits, tab management)
- `themes/` - Theme files (currently Catppuccin Mocha)
- `wizard.png` - Welcome image displayed in terminal

**scripts/** - Utility scripts:
- `detect-platform.sh` - Platform/distro detection, sets OS, DISTRO, ARCH environment variables
- `backup-config.sh` - Creates timestamped backups of existing config (keeps last 5)
- `show-welcome.sh` - Displays welcome message with wizard image in Ghostty terminals

### Design Patterns

1. **Platform Abstraction**: Platform-specific logic is isolated in `install/linux.sh` and `install/macos.sh`, sourced by bootstrap.sh based on detected OS

2. **Idempotency**: All scripts can be run multiple times safely - checks for existing installations, prompts for updates, backs up configs

3. **Dry-run Mode**: Bootstrap supports `--dry-run` flag to preview changes without modifying system

4. **Modular Configuration**: Main config imports keybindings via `config-file = keybindings.conf`, allowing separate management

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
- **Backups**: `~/.config/ghostty/backups/backup_YYYYMMDD_HHMMSS/`
- **Linux binary**: `~/.local/bin/ghostty`
- **Linux source**: `~/.local/src/ghostty`
- **macOS binary**: `/Applications/Ghostty.app`

## Shell Integration Notes

The bootstrap modifies the appropriate shell profile based on platform:

**Linux** - modifies `.bashrc`:
1. Add `~/.local/bin` to PATH (via linux.sh installer)
2. Add `~/.local/zig` to PATH (if Zig installed)
3. Add welcome script hook (detects `$GHOSTTY_RESOURCES_DIR` environment variable)

**macOS** - modifies `.zprofile`:
1. Add Homebrew to PATH (Apple Silicon only, via macos.sh installer)
2. Add welcome script hook (detects `$GHOSTTY_RESOURCES_DIR` environment variable)

All PATH modifications check if already present to avoid duplicates.

The welcome script requires `chafa` to display the wizard image - this is automatically installed by both platform installers.

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

**macOS Build Dependencies**:
- Homebrew
- Xcode Command Line Tools
- Zig (via brew)
- pandoc (via brew)
- chafa (via brew, for terminal graphics/welcome image display)

## Modifying This Repository

To create a custom fork:
1. Fork the repository
2. Edit configuration files in `config/`
3. Update `REPO_URL` in `bootstrap.sh` line 16 to point to your fork
4. Update one-liner installation command in `bootstrap.sh` line 4 and README.md
