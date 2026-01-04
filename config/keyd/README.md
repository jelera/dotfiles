# keyd - Keyboard Remapping

Configuration for **keyd**, a modern keyboard remapping daemon for Linux.

## What is keyd?

keyd is a lightweight system-wide key remapping daemon that runs in userspace. It provides powerful keyboard customization capabilities with minimal overhead.

**Repository**: https://github.com/rvaiya/keyd

## Current Configuration

The default configuration (`default.conf`) remaps Caps Lock:
- **Tap** (press and release quickly): **ESC**
- **Hold** (press with other keys): **Left Control**

This is perfect for Vim users and those who prefer Control over Caps Lock.

## Installation

### Ubuntu 24.04+

```bash
sudo apt update
sudo apt install keyd
```

### Manual Installation (Ubuntu 22.04 or other distros)

```bash
git clone https://github.com/rvaiya/keyd
cd keyd
make
sudo make install
```

## Setup with Dotfiles

The configuration is automatically managed by the dotfiles installation:

1. **Install keyd** (see above)
2. **Run dotfiles install**:
   ```bash
   cd ~/.config/dotfiles
   ./install.sh
   ```
3. The install script will:
   - Symlink `config/keyd/default.conf` → `/etc/keyd/default.conf`
   - Restart keyd service if running

### Manual Setup

If you need to manually set up the configuration:

```bash
# Link the config
sudo mkdir -p /etc/keyd
sudo ln -sf ~/.config/dotfiles/config/keyd/default.conf /etc/keyd/default.conf

# Enable and start the service
sudo systemctl enable keyd
sudo systemctl start keyd

# Check status
sudo systemctl status keyd
```

## Usage

Once installed and configured, keyd runs automatically in the background.

### Testing

1. **Tap Caps Lock** - Should produce ESC
2. **Hold Caps Lock + C** - Should produce Ctrl+C (copy)
3. **Hold Caps Lock + V** - Should produce Ctrl+V (paste)

### Check Status

```bash
# Check if keyd is running
sudo systemctl status keyd

# View keyd logs
sudo journalctl -u keyd -f

# List active keyd devices
sudo keyd list-devices
```

## Customization

Edit `~/.config/dotfiles/config/keyd/default.conf` to customize your key mappings.

### Common Remappings

```ini
[main]
# Caps Lock as Escape/Control (current config)
capslock = overload(control, esc)

# Swap Escape and Caps Lock
esc = capslock
capslock = esc

# Make Caps Lock just Control (no tap-to-esc)
capslock = leftcontrol

# Disable Caps Lock entirely
capslock = noop
```

### Advanced Configuration

keyd supports layers, macros, and complex remappings. See the [official documentation](https://github.com/rvaiya/keyd/blob/master/docs/keyd.scdoc) for more.

**Example - Vim-like navigation layer**:
```ini
[main]
# Caps Lock activates navigation layer when held
capslock = layer(nav)

[nav]
# Vim-like navigation with Caps Lock held
h = left
j = down
k = up
l = right
```

## Reloading Configuration

After editing the configuration:

```bash
# Reload keyd to apply changes
sudo systemctl reload keyd

# Or restart if reload doesn't work
sudo systemctl restart keyd
```

## Troubleshooting

### keyd not starting

```bash
# Check service status
sudo systemctl status keyd

# View detailed logs
sudo journalctl -u keyd --no-pager

# Check if config is valid
sudo keyd -c /etc/keyd/default.conf
```

### Remapping not working

1. Verify keyd is running: `sudo systemctl status keyd`
2. Check config syntax: `sudo keyd -c /etc/keyd/default.conf`
3. Reload config: `sudo systemctl reload keyd`
4. Check logs: `sudo journalctl -u keyd -f`

### Conflict with X11 or Wayland settings

keyd works at a lower level than X11/Wayland, so it should override any desktop environment key settings. If you have conflicts:

1. Remove X11 key remappings (xmodmap, setxkbmap)
2. Remove desktop environment keyboard shortcuts for Caps Lock
3. Restart keyd: `sudo systemctl restart keyd`

## Uninstallation

To remove keyd:

```bash
# Stop and disable service
sudo systemctl stop keyd
sudo systemctl disable keyd

# Remove package (Ubuntu)
sudo apt remove keyd

# Or remove manual installation
cd keyd
sudo make uninstall
```

## Related Files

- Configuration: `config/keyd/default.conf`
- Symlink management: `install/symlinks.sh` (see `symlink_keyd_config()`)
- System config location: `/etc/keyd/default.conf` (symlinked)

## Platform Support

- **Linux**: Full support (Ubuntu, Fedora, Arch, etc.)
- **macOS**: Not supported (use Karabiner-Elements instead)
- **Wayland**: Full support
- **X11**: Full support

## Why keyd over alternatives?

- **Simple**: Easy configuration syntax
- **Fast**: Minimal overhead, runs in userspace
- **Modern**: Supports Wayland and X11
- **Powerful**: Layers, macros, and complex remappings
- **Reliable**: Stable and well-maintained

**Alternatives**:
- **xmodmap** (X11 only, deprecated)
- **xcape** (requires setxkbmap, more complex)
- **kmonad** (more powerful but heavier)
- **Karabiner-Elements** (macOS only)
