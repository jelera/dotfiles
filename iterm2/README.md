# iTerm2 Configuration

This directory contains your iTerm2 preferences.

## Files

- `com.googlecode.iterm2.plist` - Complete iTerm2 preferences

## Automatic Setup

iTerm2 preferences are automatically configured during dotfiles installation to load from this directory.

## Manual Import Settings

### Option 1: Manual Import via iTerm2 UI

1. Open iTerm2
2. Go to **Preferences** → **General** → **Preferences**
3. Check "Load preferences from a custom folder or URL"
4. Click "Browse" and select: `~/.config/dotfiles/iterm2`
5. Restart iTerm2

### Option 2: Command Line

```bash
# Set iTerm2 to load preferences from this directory
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "~/.config/dotfiles/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
```

## Export Updated Settings

If you make changes in iTerm2 and want to update the dotfiles:

```bash
# Copy current settings back to dotfiles
cp ~/Library/Preferences/com.googlecode.iterm2.plist ~/.config/dotfiles/iterm2/
cd ~/.config/dotfiles
git add iterm2/com.googlecode.iterm2.plist
git commit -m "Update iTerm2 settings"
```

## Notes

- iTerm2 will automatically save changes to the custom folder once configured
- Changes are immediately reflected in the plist file
- Remember to commit changes to keep your dotfiles in sync
