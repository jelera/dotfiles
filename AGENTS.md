# AGENTS.md

Guidance for AI assistants (Claude Code, Copilot, etc.) working in this repository.

## Repository Overview

Modern dotfiles setup using **mise** for version management, **Zinit** for zsh plugins, with cross-platform support (macOS, Ubuntu/Kubuntu/Xubuntu 22.04/24.04 LTS).

**Repository**: https://github.com/jelera/dotfiles

### Key Technologies
- **mise**: All language runtime management (Ruby, Node, Python, Go, Erlang, Elixir)
- **Zinit**: Fast zsh plugin manager with lazy-loading
- **Homebrew**: Primary package manager (macOS + Linux)
- **Secrets**: Managed via `~/.env.local` (gitignored)

### Supported Platforms
- **macOS**: Latest 2 major versions (Ventura 13+, Sequoia 15+)
- **Ubuntu**: 22.04 LTS (Jammy), 24.04 LTS (Noble)
- **Kubuntu**: 22.04 LTS (Jammy), 24.04 LTS (Noble)
- **Xubuntu**: 22.04 LTS (Jammy), 24.04 LTS (Noble)

## Installation

```bash
# One-liner (requires gh CLI)
gh repo clone jelera/dotfiles ~/.config/dotfiles && ~/.config/dotfiles/install.sh

# Or manual
git clone https://github.com/jelera/dotfiles.git ~/.config/dotfiles
cd ~/.config/dotfiles
./install.sh

# Options available
./install.sh --help
```

### Safety Features

**Automatic Backups**: Existing dotfiles are automatically backed up before being replaced:
- Backup location: `~/.dotfiles.backup.YYYYMMDD_HHMMSS/`
- Each installation run creates a new timestamped backup directory
- To restore: `cp -r ~/.dotfiles.backup.YYYYMMDD_HHMMSS/. ~/`

**Installation Logs**: Warnings and errors are automatically logged:
- Log location: `~/.dotfiles-install-logs/install-YYYYMMDD_HHMMSS.log`
- Logs are only created when warnings or errors occur
- Check logs after installation if issues are reported

### Installation Modules
All scripts in `install/`:
- `common.sh` - Shared functions (logging, backups, symlinks)
- `detect-os.sh` - OS detection and validation
- `homebrew.sh` - Homebrew installation
- `mise.sh` - mise installation and language runtimes
- `packages.sh` - Package installation with fallback hierarchy
- `symlinks.sh` - Dotfile symlink management

## Architecture Decisions

### Version Management & Tool Installation
- **mise is the PRIMARY tool manager** for all CLI tools and language runtimes
- Global config: `mise/config.toml` (symlinked to `~/.config/mise/config.toml`)
- Local config: `.mise.toml` (for repo-specific development tools only)
- Uses `@latest` for all tools except Node (uses `lts`)
- All tools are installed globally via `mise use -g` for system-wide availability

**Benefits of mise-first approach:**
- Version pinning and reproducibility
- Cross-platform consistency (same tools on macOS and Linux)
- Declarative configuration
- No dependency on system package managers for CLI tools

### Package Installation Priority
1. **mise** - PRIMARY (language runtimes, CLI tools, dev utilities)
2. Homebrew - Fallback for tools not in mise
3. Maintained PPA repositories (Ubuntu only)
4. System apt packages (system libraries, build dependencies)
5. Flathub (GUI applications if needed)
6. Build from source (last resort)

**NO snap packages** - explicitly excluded

**What goes where:**
- mise: neovim, jq, fzf, ripgrep, bat, gh, lazygit, shellcheck, language servers
- System packages: git, curl, wget, build-essential, lib*-dev (system dependencies)
- Homebrew: Fallback for tools not available in mise

### Shell Configuration
- **Shared configs**: `shell/` (alias, functions, env)
- **Bash**: `bash/bashrc`, `bash/bash_profile`
- **Zsh**: `zsh/zshrc` with Zinit, `zsh/zshenv`
  - **Plugin documentation**: See `zsh/PLUGINS.md` for complete plugin list
  - **Development plugins**: Rails, Node.js, Docker, Bundler, npm, yarn
  - **Platform-specific**: Brew (macOS), Ubuntu (Linux)
- **Local overrides** (gitignored):
  - `~/.{bash,zsh}rc.local` - Shell-specific config
  - `~/.alias.local` - Custom aliases
  - `~/.functions.local` - Custom functions
  - `~/bin.local/` - Personal scripts (auto-added to PATH)

### Secrets Management
- Template: `shell/.env.local.example`
- Actual secrets: `~/.env.local` (gitignored)
- Sourced automatically by shell configs
- After installation: `cp shell/.env.local.example ~/.env.local && nvim ~/.env.local`

## Common Tasks

### Adding New Utility Script
1. Create in `bin/` with shebang `#!/usr/bin/env bash`
2. Make executable: `chmod +x bin/scriptname`
3. Add help text with `-h/--help` flag
4. Test on both macOS and Linux if possible

### Adding Shell Alias/Function
- **Aliases**: Add to `shell/alias` (shared) or `~/.alias.local` (personal)
- **Functions**: Add to `shell/functions` (shared) or `~/.functions.local` (personal)
- **Scripts**: Add to `bin/` (shared) or `~/bin.local/` (personal)
- **Env vars**: Add to `shell/env` (or `~/.env.local` if secret)

Note: Most utilities are shell functions (faster than scripts)

### Modifying Installation
1. Edit appropriate module in `install/`
2. Test changes: `./install.sh --no-languages -y`
3. Verify symlinks: `./install/symlinks.sh verify`

### Adding Language Runtime or CLI Tool
1. **First, check if mise supports it**: `mise ls-remote <tool>`
2. Add to `mise/config.toml` under `[tools]` (for global availability)
3. Install: `mise install <tool>@latest`
4. Set global: `mise use -g <tool>@latest`
5. Or add to `.mise.toml` for repo-specific development tools only

**For tools NOT in mise:**
1. Add to `install/packages.sh` in `install_essential_packages()`
2. Will automatically try: mise → Homebrew → apt → Flatpak → source

### GitHub Authentication

**Credential Helper Setup** (automatically configured during installation):

**Platform-specific helpers:**
- **macOS**: `osxkeychain` (built-in, uses macOS Keychain)
- **Ubuntu/Xubuntu**: `libsecret` (uses GNOME Keyring via Secret Service API)
- **Kubuntu**: `libsecret` (uses KWallet via Secret Service API)
- **GitHub-specific**: `gh auth git-credential` (uses GitHub CLI for github.com)

The install script automatically:
1. Installs `libsecret` libraries on all Ubuntu variants
2. Installs desktop-specific keyring (GNOME Keyring for Xubuntu, KWallet for Kubuntu)
3. Builds `git-credential-libsecret` helper if needed
4. Configures the appropriate helper in `~/.gitconfig.local`
5. Sets up GitHub-specific credential handling

**How keyring selection works:**
- **Ubuntu (GNOME)**: Uses GNOME Keyring (usually pre-installed)
- **Kubuntu (KDE)**: Uses KWallet (provides Secret Service API backend)
- **Xubuntu (XFCE)**: Uses GNOME Keyring (lighter alternative to KWallet)
- All use the same `libsecret` credential helper via Secret Service API

**To authenticate with GitHub:**
```bash
gh auth login
# Choose: GitHub.com → HTTPS → Login with browser or token → Authenticate
# Credentials are stored securely (Keychain on macOS, Secret Service on Linux)
```

**How it works:**
1. For **GitHub URLs** (`github.com`, `gist.github.com`): Uses `gh auth git-credential`
2. For **other Git hosts**: Uses platform-specific helper (osxkeychain or libsecret)
3. Empty `helper =` line clears defaults before setting GitHub-specific ones

**Configuration hierarchy:**
```gitconfig
# In git/gitconfig (version controlled)
[credential "https://github.com"]
	helper =
	helper = gh auth git-credential

# In ~/.gitconfig.local (machine-specific, not version controlled)
[credential]
	helper = osxkeychain          # macOS
	# OR
	helper = /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret  # Ubuntu
```

**Verify authentication:**
```bash
gh auth status                    # Check GitHub authentication
git config --get credential.helper # Check configured helper

# Test on macOS
git credential-osxkeychain

# Test on Ubuntu
/usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
```

**Troubleshooting credential storage:**

**On Ubuntu/Xubuntu/Kubuntu:**
```bash
# Check if libsecret is installed
dpkg -l | grep libsecret

# Check if keyring is running
ps aux | grep -E 'gnome-keyring|kwalletd'

# Manually build the credential helper
cd /usr/share/doc/git/contrib/credential/libsecret
sudo make

# Test it
./git-credential-libsecret

# Configure it
git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
```

**Desktop-specific checks:**
```bash
# Kubuntu (KDE) - Check KWallet
kwalletmanager5  # Open KWallet manager
qdbus org.kde.kwalletd5 /modules/kwalletd5 org.kde.KWallet.isEnabled

# Xubuntu (XFCE) - Check GNOME Keyring
gnome-keyring-daemon --version
echo $GNOME_KEYRING_CONTROL

# Ubuntu (GNOME) - Check GNOME Keyring
seahorse  # Open Passwords and Keys GUI
```

### Terminal Emulators

This dotfiles repository includes configurations for multiple terminal emulators:

#### iTerm2 (macOS only)

**Automatic Configuration**: The install script automatically configures iTerm2 to load preferences from the dotfiles directory.

**How it works:**
1. Your current iTerm2 settings are stored in `iterm2/com.googlecode.iterm2.plist`
2. During installation, iTerm2 is configured to load preferences from `~/.config/dotfiles/iterm2`
3. Changes made in iTerm2 are automatically saved back to the dotfiles directory

**Manual setup:**
```bash
# If you need to manually configure iTerm2
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "~/.config/dotfiles/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
```

**Update settings:**
```bash
# After making changes in iTerm2, commit them:
cd ~/.config/dotfiles
git add iterm2/com.googlecode.iterm2.plist
git commit -m "Update iTerm2 settings"
```

See `iterm2/README.md` for detailed instructions.

#### Ghostty (macOS and Linux)

**Installation:**

Ghostty is automatically installed during dotfiles setup on macOS.

```bash
# Automatic (via dotfiles install script)
./install.sh

# Manual installation if needed
brew install --cask ghostty              # macOS
# Linux - download from https://ghostty.org/
```

**Configuration**: Ghostty config is automatically symlinked during installation:
- Source: `config/ghostty/config`
- Target: `~/.config/ghostty/config`

**Features configured:**
- **Theme**: Catppuccin Mocha (customizable)
- **Font**: JetBrainsMono Nerd Font
- **Shell Integration**: Enabled for zsh with cursor, sudo, and title tracking
- **Keybindings**: macOS-style shortcuts for window/tab/split management
- **Performance**: GPU acceleration enabled

**Keybindings quick reference:**
- `⌘+D` / `⌘+Shift+D` - Split right/down
- `⌘+T` - New tab
- `⌘+1-9` - Go to tab
- `⌘+←→↑↓` - Navigate splits
- `⌘+Shift+R` - Reload config

**Customize:**
```bash
# Edit config
nvim ~/.config/dotfiles/config/ghostty/config

# In Ghostty, reload with: ⌘+Shift+R
```

See `config/ghostty/README.md` for detailed documentation, customization options, and troubleshooting.

### Keyboard Remapping (Linux)

**keyd** is a system-level keyboard remapping daemon for Linux that works with both X11 and Wayland.

**Installation:**

keyd must be installed separately before the dotfiles can configure it:

```bash
# Ubuntu 25.04+ (official repositories)
sudo apt update
sudo apt install keyd

# Ubuntu 24.04 and earlier (via PPA)
sudo add-apt-repository ppa:keyd-team/ppa
sudo apt update
sudo apt install keyd

# After installing keyd, run dotfiles installation to create symlinks
cd ~/.config/dotfiles
./install.sh
```

The install script automatically detects your Ubuntu version and provides the appropriate installation instructions if keyd is not found.

**Automatic Configuration**: The install script automatically configures keyd if it's installed:
- Configuration file: `config/keyd/default.conf`
- Symlinked to: `/etc/keyd/default.conf`
- Service is automatically restarted if running

**Current Remapping** (configured in `config/keyd/default.conf`):
- **Caps Lock (tap)**: Acts as ESC
- **Caps Lock (hold)**: Acts as Left Control

**Manual Setup** (if needed):
```bash
# Create symlink
sudo mkdir -p /etc/keyd
sudo ln -sf ~/.config/dotfiles/config/keyd/default.conf /etc/keyd/default.conf

# Enable and start service
sudo systemctl enable keyd
sudo systemctl start keyd

# Reload after config changes
sudo systemctl reload keyd
```

**Verify Configuration:**
```bash
# Check service status
sudo systemctl status keyd

# View logs
sudo journalctl -u keyd -n 20

# Verify symlink
readlink /etc/keyd/default.conf
```

**Note**: The install script recognizes both `keyd` (official packages) and `keyd.rvaiya` (PPA version).

See `config/keyd/README.md` for detailed documentation, advanced configuration examples, and troubleshooting.

### GPG Commit Signing

**Automatic Configuration**: GPG agent is automatically configured during installation:
- GPG agent config: `gnupg/gpg-agent.conf` → `~/.gnupg/gpg-agent.conf`
- Platform-specific pinentry paths are automatically detected
- GPG agent is restarted after configuration

**Requirements:**
- `pinentry` must be installed (automatically installed via `install/packages.sh`)
- `GPG_TTY` environment variable must be set (automatically configured in shell)

**How it works:**
1. Install script installs `pinentry` via package manager
2. Symlink script creates `~/.gnupg/gpg-agent.conf` with correct pinentry path
3. Shell configs (`shell/env.d/macos`, `shell/env.d/linux`) export `GPG_TTY=$(tty)`

**Platform-specific pinentry paths:**
- **macOS**: `/opt/homebrew/bin/pinentry-tty` (ARM) or `/usr/local/bin/pinentry-tty` (Intel)
- **Linux**: `/usr/bin/pinentry-tty` or `/usr/bin/pinentry-curses`

**Troubleshooting GPG signing errors:**

If you see `gpg: signing failed: Inappropriate ioctl for device`, the fix is:

```bash
# 1. Export GPG_TTY (required for passphrase prompts)
export GPG_TTY=$(tty)

# 2. Verify it's set
echo $GPG_TTY
# Should output something like: /dev/ttys001

# 3. Restart GPG agent
gpgconf --kill gpg-agent

# 4. Try committing again
git commit -m "Your message"
```

**For permanent fix:**
```bash
# Reload your shell configuration (already configured in dotfiles)
source ~/.zshrc  # or source ~/.bashrc

# Verify GPG_TTY is exported
echo $GPG_TTY

# Check GPG agent config
cat ~/.gnupg/gpg-agent.conf

# Verify pinentry is installed
which pinentry-tty  # macOS/Linux
```

**Check GPG configuration:**
```bash
# Check GPG agent status
gpgconf --list-dirs

# Check signing key
git config --get user.signingkey
git config --get commit.gpgsign

# Test GPG signing
echo "test" | gpg --clearsign
```

## Code Conventions

### Shell Scripts
- Use `#!/usr/bin/env bash` for portability
- Set `set -e` for error handling
- Source `install/common.sh` for shared functions
- Use logging functions: `log_info`, `log_success`, `log_warning`, `log_error`
  - `log_warning` and `log_error` automatically write to log file
  - Log file created only when first warning/error occurs
- Check command availability: `command_exists <cmd>`
- Backups are automatic via `backup_if_exists` or `create_symlink`

### Configuration Files
- Use absolute paths or `~` for portability
- Support local overrides (*.local files)
- Keep sensitive data in `~/.env.local`
- Comment complex configurations

## Testing

### Git Hooks (Lefthook)

Git hooks are automatically managed by **lefthook** for code quality and security.

**Automatic Installation**:
Lefthook is automatically installed during the dotfiles setup:
1. Installed via mise (see `mise/config.toml`)
2. Git hooks are automatically set up in `.git/hooks/` during `./install.sh`
3. No manual intervention required!

**Manual Installation** (if needed):
```bash
# Install lefthook
mise install lefthook@latest

# Set up git hooks in a repository
lefthook install
```

**Pre-commit hooks** (run before every commit):
- `shellcheck`: Lint all `.sh` files
- `shellcheck-no-ext`: Lint shell scripts without `.sh` extension (`bin/*`, `shell/functions`, `shell/env`)
- `gitleaks`: Check staged files for secrets/credentials
- `trailing-whitespace`: Check for trailing whitespace in code files

**Pre-push hooks** (run before pushing to remote):
- `gitleaks-full`: Full repository scan for secrets

**Manual testing**:
```bash
# Test pre-commit hooks
lefthook run pre-commit

# Test pre-push hooks
lefthook run pre-push

# Skip hooks for a commit
git commit --no-verify

# Skip hooks for a push
git push --no-verify
```

**Configuration**: Edit `lefthook.yml` to add or modify hooks.

### Shell Scripts

**Configuration**: Shell script linting rules are defined in `.shellcheckrc` and used everywhere:
- ✅ Local development (`shellcheck` command)
- ✅ Git pre-commit hooks (via lefthook)
- ✅ GitHub Actions CI pipeline

**Linting**:
```bash
# Lint all shell scripts (uses .shellcheckrc automatically)
shellcheck install.sh install/*.sh shell/functions.d/*.sh shell/functions shell/env bin/*

# Verify symlinks
./install/symlinks.sh verify

# Test shell syntax
bash -n bash/bashrc
zsh -n zsh/zshrc
bash -n install.sh
bash -n install/*.sh
```

**ShellCheck configuration** (`.shellcheckrc`):
- Target shell: bash (compatible with bash 3.2 on macOS)
- Severity: warnings and above
- Disabled: SC1091 (following sourced files)
- Enabled optional checks: default-case, nullary-conditions, unassigned-uppercase, etc.

## Troubleshooting

### mise Issues
```bash
mise doctor              # Check mise setup
mise list               # Show installed tools
mise current            # Show active versions
```

### Symlink Issues
```bash
./install/symlinks.sh verify    # Check all links
./install/symlinks.sh remove    # Remove all
./install/symlinks.sh create    # Recreate all
```

### Shell Not Loading Config
Check load order:
- Bash: `.bash_profile` → `.bashrc`
- Zsh: `.zshenv` → `.zshrc`

Verify sources:
```bash
grep -r "dotfiles" ~/.bashrc ~/.zshrc
```

## Platform-Specific Notes

### macOS
- Homebrew prefix: `/opt/homebrew` (ARM) or `/usr/local` (Intel)
- Uses `pbcopy` for clipboard (tmux, zsh)
- PostgreSQL via Postgres.app or Homebrew

### Ubuntu/Kubuntu/Xubuntu 22.04/24.04
- Homebrew installed to `/home/linuxbrew/.linuxbrew`
- Uses `xclip` for clipboard (all variants)
- Requires `build-essential` for compilation
- **Desktop-specific notes:**
  - **Ubuntu (GNOME)**: Full GNOME integration, gnome-keyring
  - **Kubuntu (KDE)**: KWallet for credential storage, KDE clipboard integration
  - **Xubuntu (XFCE)**: Lightweight, uses GNOME Keyring for credentials
- Credential storage via Secret Service API (works with all keyrings)

## File Naming Conventions

- **Scripts**: `lowercase-with-dashes.sh`
- **Configs**: match target (e.g., `bashrc`, `zshrc`)
- **Docs**: `UPPERCASE.md` for important docs
- **Hidden**: Prefix with `.` only for template examples

## Important: Keeping This File Updated

When making significant changes:
1. Update relevant section in this file
2. Keep README.md in sync (brief overview only)
3. Add troubleshooting notes for common issues

## Related Documentation

- `README.md` - Quick start and overview
- `CLAUDE.md` - Quick reference for Claude Code
- `install/common.sh` - Available helper functions
- `shell/.env.local.example` - Secrets template
