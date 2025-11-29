# Ghostty Configuration & Auto-Installer

Automated installation and configuration management for [Ghostty](https://ghostty.org) terminal emulator across Linux, macOS, and WSL environments.

## Features

- 🚀 **One-line installation** via curl
- 🐧 **Multi-distro Linux support** (Ubuntu, Debian, Fedora, Arch)
- 🍎 **macOS support** (Homebrew or build from source)
- 🪟 **WSL support** (Windows Subsystem for Linux with WSLg)
- 🎨 **Pre-configured themes** (Catppuccin Mocha/Latte)
- ⌨️ **Sensible keybindings** out of the box
- 💾 **Automatic backups** of existing configs
- 🔄 **Idempotent** - safe to run multiple times
- 🛡️ **Dry-run mode** for testing
- 🗑️ **Complete uninstall** - tracks and removes only script-installed components

## Quick Start

### One-liner Installation

```bash
curl -fsSL https://raw.githubusercontent.com/JussiHanski/ghostty/refs/heads/main/bootstrap.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/JussiHanski/ghostty.git ~/.ghostty-config
cd ~/.ghostty-config
./bootstrap.sh
```

## Usage

### Options

```bash
./bootstrap.sh [OPTIONS]

Options:
  -h, --help          Show help message
  -v, --verbose       Enable verbose output
  -d, --dry-run       Preview changes without applying
  -s, --skip-install  Deploy config only (skip Ghostty installation)
  --uninstall         Remove configuration (keeps Ghostty binary)
```

### Examples

```bash
# Preview what will be installed
./bootstrap.sh --dry-run

# Install configuration only (if Ghostty already installed)
./bootstrap.sh --skip-install

# Update configuration (re-run the bootstrap)
./bootstrap.sh
```

## Configuration

### File Locations

After installation, configuration files are located at:

```
~/.config/ghostty/
├── config              # Main configuration
├── keybindings.conf    # Keybinding customizations
└── themes/             # Theme files
    ├── catppuccin-mocha.conf
    └── catppuccin-latte.conf
```

### Customization

Edit the main config file:

```bash
$EDITOR ~/.config/ghostty/config
```

Changes take effect immediately - just open a new Ghostty window/tab.

## Default Configuration

### Theme

- **Dark mode**: Catppuccin Mocha
- **Light mode**: Catppuccin Latte
- Automatically switches based on system theme

### Font

- **Default**: JetBrains Mono, 12pt
- Font thickening enabled for better readability

### Key Bindings

#### Tabs
- `Ctrl+Shift+T` - New tab
- `Ctrl+Shift+W` - Close tab
- `Ctrl+Tab` / `Ctrl+Shift+Tab` - Navigate tabs
- `Ctrl+Shift+1-9` - Jump to tab 1-9

#### Splits
- `Ctrl+Shift+D` - Split right
- `Ctrl+Shift+Shift+D` - Split down
- `Ctrl+Shift+H/J/K/L` - Navigate splits (vim-style)

#### Font Size
- `Ctrl++` - Increase font size
- `Ctrl+-` - Decrease font size
- `Ctrl+0` - Reset font size

#### Other
- `Ctrl+Shift+C/V` - Copy/paste
- `Ctrl+Shift+F` - Quick terminal
- `Ctrl+Shift+K` - Clear screen

## Platform-Specific Details

### Linux

**Supported Distributions:**
- Ubuntu / Debian / Pop!_OS
- Fedora
- Arch / Manjaro

**Installation method:**
- Builds Ghostty from source
- Installs Zig compiler if needed
- Places binary in `~/.local/bin/`
- Adds desktop entry

**Dependencies installed:**
- Build tools (gcc, make)
- GTK4, libadwaita, GTK4 layer shell
- Zig compiler
- blueprint-compiler (>=0.16)
- gettext/msgfmt, libxml2/xmllint
- Pandoc
- chafa (for welcome image)

### macOS

**Installation methods:**
1. **Homebrew** (recommended)
   - Fastest installation
   - Automatic updates via `brew upgrade`

2. **Build from source**
   - Latest development version
   - Installs to `/Applications/Ghostty.app`

**Requirements:**
- Homebrew (will be installed if missing)
- Xcode Command Line Tools

### WSL (Windows Subsystem for Linux)

**Requirements:**
- **WSL2** (required)
- **WSLg** (GUI support) - included in Windows 11 or Windows 10 Build 19044+
- Ubuntu, Debian, Fedora, or Arch distribution

**Installation method:**
- Automatically detects WSL environment
- Validates WSL2 and WSLg requirements
- Builds from source (same as Linux)
- Integrates with Windows Start Menu

**Features:**
- Opens as native Windows GUI application
- Appears in Windows Start Menu
- Can launch from WSL terminal or Windows GUI
- Full desktop integration via WSLg

**Important Notes:**
- WSL support is **experimental** (official Windows support on roadmap)
- Requires `wsl --update` to ensure WSLg is available
- Some rendering/performance issues may occur

**Check your WSL version:**
```bash
wsl --version  # In PowerShell/CMD
```

**Upgrade to WSL2 if needed:**
```powershell
# In PowerShell as Administrator
wsl --set-version Ubuntu 2  # Replace 'Ubuntu' with your distro name
wsl --update
wsl --shutdown
# Restart WSL and run the installer
```

## Repository Structure

```
.
├── bootstrap.sh           # Main entry point
├── README.md             # This file
├── install/
│   ├── linux.sh         # Linux installation logic
│   └── macos.sh         # macOS installation logic
├── config/
│   ├── config           # Main Ghostty config
│   ├── keybindings.conf # Keybindings
│   └── themes/          # Theme files
└── scripts/
    ├── detect-platform.sh  # Platform detection
    └── backup-config.sh    # Config backup utility
```

## Backup & Recovery

### Automatic Backups

The bootstrap script automatically backs up your existing configuration before making changes.

Backups are stored in: `~/.config/ghostty/backups/backup_YYYYMMDD_HHMMSS/`

Only the last 5 backups are kept to save disk space.

### Manual Backup

```bash
~/.ghostty-config/scripts/backup-config.sh
```

### Restore from Backup

```bash
# List available backups
ls ~/.config/ghostty/backups/

# Restore a specific backup
cp -r ~/.config/ghostty/backups/backup_20241031_123456/* ~/.config/ghostty/
```

## Updating

To update Ghostty and/or the configuration, simply re-run the bootstrap script:

```bash
curl -fsSL https://raw.githubusercontent.com/JussiHanski/ghostty/refs/heads/main/bootstrap.sh | bash
```

Or if you have the repo cloned:

```bash
cd ~/.ghostty-config
git pull
./bootstrap.sh
```

## Uninstalling

### Complete Automated Uninstall (Recommended)

The bootstrap script tracks everything it installs and can remove it all automatically:

```bash
~/.ghostty-config/bootstrap.sh --uninstall
```

This will:
- Show you what was installed by the script (based on install log)
- Remove only components that were installed by the script
- Clean up shell profile modifications
- Create a backup of your configuration before removal
- Optionally remove Homebrew if it was installed by the script

**What gets removed:**
- Ghostty (if installed by script)
- Chafa (if installed by script)
- Zig compiler (Linux, if installed by script)
- Homebrew (macOS, with confirmation, if installed by script)
- Configuration files
- Shell profile modifications
- Welcome script

**What stays:**
- Pre-existing installations of Ghostty, chafa, or other tools
- Unrelated Homebrew packages (on macOS)
- Other modifications to your system

### Install Log

The installer creates a log at `~/.config/ghostty/.install_log` that tracks:
- What components were installed vs. already existing
- Installation methods used
- Paths to installed binaries
- Shell profile modifications

This ensures the uninstaller only removes what it installed, keeping your system clean.

## Troubleshooting

### Ghostty not in PATH

**Linux:**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**macOS:**
```bash
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile
```

### Config not loading

1. Check config syntax:
   ```bash
   ghostty --config-file ~/.config/ghostty/config
   ```

2. Verify file permissions:
   ```bash
   ls -la ~/.config/ghostty/
   ```

3. Check Ghostty logs (platform-specific location)

### Build failures on Linux

Ensure all dependencies are installed:

```bash
# Ubuntu/Debian
sudo apt-get install build-essential libgtk-4-dev libadwaita-1-dev pkg-config pandoc

# Fedora
sudo dnf install gcc gcc-c++ gtk4-devel libadwaita-devel pkgconfig pandoc

# Arch
sudo pacman -S base-devel gtk4 libadwaita pkgconf pandoc
```

## Contributing

Feel free to customize this repository for your own use!

To modify:
1. Fork this repository
2. Edit configs in `config/`
3. Update `REPO_URL` in `bootstrap.sh` to point to your fork
4. Push changes and use your own one-liner

## Resources

- [Ghostty Official Site](https://ghostty.org)
- [Ghostty Documentation](https://ghostty.org/docs)
- [Catppuccin Theme](https://github.com/catppuccin/catppuccin)

## License

This configuration repository is provided as-is for personal use. Ghostty is developed by Mitchell Hashimoto and the Ghostty team.
