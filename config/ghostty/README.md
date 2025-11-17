# Ghostty Terminal Configuration

[Ghostty](https://ghostty.org/) is a fast, feature-rich, cross-platform terminal emulator.

**Note**: This configuration has been ported from your iTerm2 settings, including your Gruvbox Dark color scheme, CaskaydiaCove Nerd Font, and all visual preferences. See `PORTING_NOTES.md` for details.

## Installation

Ghostty is installed automatically by the dotfiles install script on macOS.

**Automatic installation (recommended):**
```bash
# Run the full dotfiles installation
./install.sh

# Or install just GUI applications
cd ~/.config/dotfiles
source install/common.sh
source install/detect-os.sh
source install/packages.sh
install_gui_applications
```

**Manual installation:**
```bash
# macOS
brew install --cask ghostty

# Linux - download from official site
# https://ghostty.org/
```

## Configuration

The config file will be automatically symlinked during dotfiles installation:

```
~/.config/dotfiles/config/ghostty/config → ~/.config/ghostty/config
```

## Features Configured

### Basic Settings
- **Theme**: Catppuccin Mocha (customizable)
- **Font**: JetBrainsMono Nerd Font at 14pt
- **GPU Acceleration**: Enabled (auto-detect driver)
- **Scrollback**: 10,000 lines

### Shell Integration
- Enabled for zsh
- Features: cursor, sudo, title tracking
- Automatic directory tracking in window title

### Keybindings

#### Window/Tab Management
- `⌘+N` - New window
- `⌘+W` - Close window/split
- `⌘+T` - New tab
- `⌘+Shift+T` - Reopen closed tab
- `⌘+1-9` - Go to tab 1-9
- `⌘+Shift+[` / `⌘+Shift+]` - Previous/next tab

#### Split Management
- `⌘+D` - New split (right)
- `⌘+Shift+D` - New split (down)
- `⌘+←→↑↓` - Navigate between splits
- `⌘+Alt+←→↑↓` - Resize splits

#### Text Operations
- `⌘+C` / `⌘+V` - Copy/paste
- `⌘+F` - Search
- `⌘+K` - Clear screen
- `⌘++` / `⌘+-` - Increase/decrease font size
- `⌘+0` - Reset font size

#### Utilities
- `⌘+,` - Open config editor
- `⌘+Shift+R` - Reload config
- `⌘+Shift+I` - Toggle inspector

## Customization

Edit `~/.config/dotfiles/config/ghostty/config` and reload:

```bash
# In Ghostty, press:
# ⌘+Shift+R
```

### Popular Themes

Available themes (change `theme =` line):
- `catppuccin-mocha`
- `catppuccin-macchiato`
- `tokyo-night`
- `dracula`
- `nord`
- `gruvbox-dark`
- `solarized-dark`
- `one-dark`

### Font Options

Popular terminal fonts (requires installation):
- JetBrainsMono Nerd Font (current)
- FiraCode Nerd Font
- Hack Nerd Font
- Inconsolata Nerd Font
- MesloLGS Nerd Font

Install Nerd Fonts:
```bash
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font
```

## Shell Integration Setup

Ghostty automatically handles shell integration when `shell-integration = zsh` is set.

For manual setup or troubleshooting:

```bash
# The integration is automatic, but you can verify:
echo $GHOSTTY_RESOURCES_DIR

# Integration provides:
# - Current directory in window title
# - Sudo password prompts in terminal
# - Cursor position tracking
```

## Documentation

- Official docs: https://ghostty.org/docs
- Config reference: https://ghostty.org/docs/config
- Keybindings: https://ghostty.org/docs/keybindings

## Troubleshooting

### Config not loading
```bash
# Check config location
ls -la ~/.config/ghostty/config

# Test config syntax
ghostty --config-check

# View effective config
ghostty --config-dump
```

### Font not found
```bash
# List available fonts
fc-list | grep -i "jetbrains"

# Install JetBrainsMono Nerd Font
brew install --cask font-jetbrains-mono-nerd-font
```

### Shell integration not working
```bash
# Verify GHOSTTY_RESOURCES_DIR is set
echo $GHOSTTY_RESOURCES_DIR

# Check shell integration setting in config
grep shell-integration ~/.config/ghostty/config

# Restart shell
exec zsh
```
