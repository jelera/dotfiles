# iTerm2 to Ghostty Porting Notes

This document describes how your iTerm2 settings were ported to Ghostty.

## Successfully Ported Settings

### Font Configuration
- **Font**: CaskaydiaCove Nerd Font (exact match)
- **Font Size**: 16pt (exact match)
- **Ligatures**: Enabled (exact match)
- **Anti-aliasing**: Enabled by default in Ghostty

### Color Scheme: Gruvbox Dark
All colors successfully ported with exact RGB values:
- Background: `#1d1d1d`
- Foreground: `#e5d3a2`
- Cursor color: `#e5d3a2`
- Cursor text: `#1d1d1d`
- All 16 ANSI colors (0-15): Complete palette ported

### Cursor
- **Style**: Block cursor (exact match)
- **Blinking**: Disabled (exact match)

### Window Settings
- **Initial Size**: 80 columns x 25 rows (exact match)
- **Transparency**: 0.98 opacity (iTerm2 had 0.02 transparency = 98% opacity)

### Scrollback
- **Lines**: 1000 (exact match)

### macOS-Specific
- **Option Key**: Configured as Alt (matching iTerm2's mode 0)
- **Window Tabbing**: Manual mode preserved through Ghostty's keybindings

### Shell Integration
- Enabled for zsh with cursor, sudo, and title tracking

## Settings Not Directly Portable

### Window Blur
- **iTerm2**: Had blur disabled
- **Ghostty**: Does not have a blur effect feature
- **Impact**: None (blur was disabled in iTerm2)

### Non-ASCII Font
- **iTerm2**: Used Monaco 12 as fallback
- **Ghostty**: Uses the main font for all characters
- **Impact**: Minimal - modern Nerd Fonts include all necessary glyphs

### Custom Keybindings
- **iTerm2**: May have had custom keybindings in the profile
- **Ghostty**: Standard macOS-style keybindings configured
- **Note**: If you had custom iTerm2 keybindings, you may need to add them manually

### Advanced iTerm2 Features
The following iTerm2-specific features don't have direct Ghostty equivalents:
- **Triggers**: Text-based automation rules
- **Smart Selection**: Custom selection rules
- **Shell Integration Advanced Features**: Some iTerm2-specific shell integration features
- **Badges**: Window badges showing text
- **Instant Replay**: Terminal history playback
- **Captured Output**: Automatic output capture

## Ghostty-Specific Enhancements

Your Ghostty config now includes features not present in iTerm2:

### Enhanced Split Management
- Keyboard-based split navigation (⌘+arrows)
- Keyboard-based split resizing (⌘+Alt+arrows)
- Split creation shortcuts (⌘+D, ⌘+Shift+D)

### Modern Features
- GPU acceleration with auto-detection
- Clipboard paste protection
- Shell integration features

## Testing Your Configuration

1. **Install Ghostty** (if not already installed):
   ```bash
   brew install --cask ghostty
   ```

2. **Install the required font**:
   ```bash
   brew tap homebrew/cask-fonts
   brew install --cask font-caskaydia-cove-nerd-font
   ```

3. **Symlink the config** (done automatically by install script):
   ```bash
   ./install/symlinks.sh create
   ```

4. **Launch Ghostty** and verify:
   - Font renders correctly at 16pt
   - Gruvbox Dark colors match iTerm2
   - Window size is 80x25
   - Cursor is a non-blinking block

5. **Test keyboard shortcuts**:
   - ⌘+D to split right
   - ⌘+T to create new tab
   - ⌘+1-9 to switch between tabs

## Side-by-Side Comparison

| Setting | iTerm2 | Ghostty | Match |
|---------|--------|---------|-------|
| Font Family | CaskaydiaCove NF | CaskaydiaCove NF | ✅ |
| Font Size | 16pt | 16pt | ✅ |
| Ligatures | Yes | Yes | ✅ |
| Color Scheme | Gruvbox Dark | Gruvbox Dark | ✅ |
| Cursor Style | Block | Block | ✅ |
| Cursor Blink | No | No | ✅ |
| Window Size | 80x25 | 80x25 | ✅ |
| Transparency | 0.02 | 0.02 | ✅ |
| Scrollback | 1000 | 1000 | ✅ |
| Option as Meta | No | No | ✅ |
| Shell Integration | Yes | Yes | ✅ |

## Customization

To modify your ported settings:

```bash
# Edit Ghostty config
nvim ~/.config/ghostty/config

# Reload config in Ghostty
# Press: ⌘+Shift+R
```

## Further Reading

- [Ghostty Documentation](https://ghostty.org/docs)
- [Ghostty Config Reference](https://ghostty.org/docs/config)
- [Ghostty Keybindings](https://ghostty.org/docs/keybindings)
