# AGENTS.md

Guidance for AI assistants (Claude Code, Copilot, etc.) working in this repository.

## Repository Overview

Modern dotfiles setup using **mise** for version management, **Zinit** for zsh plugins, with cross-platform support (macOS, Ubuntu 22.04/24.04).

**Repository**: https://github.com/jelera/dotfiles

### Key Technologies
- **mise**: All language runtime management (Ruby, Node, Python, Go, Erlang, Elixir)
- **Zinit**: Fast zsh plugin manager with lazy-loading
- **Homebrew**: Primary package manager (macOS + Linux)
- **Secrets**: Managed via `~/.env.local` (gitignored)

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
- **Local overrides** (gitignored):
  - `~/.{bash,zsh}rc.local` - Shell-specific config
  - `~/.alias.local` - Custom aliases
  - `~/.functions.local` - Custom functions
  - `~/bin.local/` - Personal scripts (auto-added to PATH)

### Secrets Management
- Template: `shell/.env.local.example`
- Actual secrets: `~/.env.local` (gitignored)
- Sourced automatically by shell configs
- Full guide: `docs/SECRETS.md`

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

## Code Conventions

### Shell Scripts
- Use `#!/usr/bin/env bash` for portability
- Set `set -e` for error handling
- Source `install/common.sh` for shared functions
- Use logging functions: `log_info`, `log_success`, `log_warning`, `log_error`
- Check command availability: `command_exists <cmd>`

### Configuration Files
- Use absolute paths or `~` for portability
- Support local overrides (*.local files)
- Keep sensitive data in `~/.env.local`
- Comment complex configurations

## Testing

```bash
# Verify symlinks
./install/symlinks.sh verify

# Test shell syntax
bash -n bash/bashrc
zsh -n zsh/zshrc

# Test scripts
bash -n install.sh
bash -n install/*.sh
```

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

### Ubuntu 22.04/24.04
- Homebrew installed to `/home/linuxbrew/.linuxbrew`
- Uses `xclip` for clipboard
- Requires `build-essential` for compilation

## File Naming Conventions

- **Scripts**: `lowercase-with-dashes.sh`
- **Configs**: match target (e.g., `bashrc`, `zshrc`)
- **Docs**: `UPPERCASE.md` for important docs
- **Hidden**: Prefix with `.` only for template examples

## Important: Keeping This File Updated

When making significant changes:
1. Update relevant section in this file
2. Keep README.md in sync (brief overview only)
3. Update MIGRATION_PLAN.md if architecture changes
4. Add troubleshooting notes for common issues

## Related Documentation

- `README.md` - Quick start and overview
- `docs/TOOLS_REFERENCE.md` - Complete guide to all CLI tools, aliases, and functions
- `docs/SECRETS.md` - Detailed secrets management
- `MIGRATION_PLAN.md` - Original migration plan
- `install/common.sh` - Available helper functions
