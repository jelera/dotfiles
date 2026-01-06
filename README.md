# Dotfiles

Modern, modular dotfiles with [mise](https://mise.jdx.dev/) version management.

## Features

- **mise** for version management (Ruby, Node, Python, Go, Erlang, Elixir)
- **Zinit** for fast zsh plugin loading
- **Homebrew** with smart fallbacks (PPA → Apt → Flathub → Source)
- **Secure secrets** management (`.env.local` with gitignore)
- **Cross-platform** (macOS, Ubuntu/Kubuntu/Xubuntu 22.04/24.04 LTS)

## Quick Start

```bash
# One-liner install (requires gh CLI)
gh repo clone jelera/dotfiles ~/.config/dotfiles && ~/.config/dotfiles/install.sh

# Or manual clone
git clone https://github.com/jelera/dotfiles.git ~/.config/dotfiles
cd ~/.config/dotfiles
./install.sh

# Minimal (no languages)
./install.sh --minimal

# Symlinks only
./install.sh --symlinks-only
```

## What Gets Installed

- **Core**: git, curl, tmux, neovim, fzf, ripgrep, bat, eza, jq, tree
- **Dev Tools**: shellcheck, lefthook, gitleaks (linting & security)
- **Languages**: Ruby, Node (LTS), Python, Go, Erlang, Elixir (optional)
- **Configs**: bash, zsh, git, tmux
- **Git Hooks**: Pre-commit linting and secrets detection

## Structure

```
dotfiles/
├── bash/           # Bash configuration
├── zsh/            # Zsh with Zinit
├── git/            # Git config, aliases, ignore patterns
├── tmux/           # Tmux with TPM plugins
├── shell/          # Shared (alias, functions, env)
├── bin/            # Utility scripts
├── install/        # Modular installation scripts
└── mise/           # mise version management config
```

## Post-Installation

```bash
# 1. Reload shell
source ~/.zshrc  # or ~/.bashrc

# 2. Configure secrets
cp shell/.env.local.example ~/.env.local
nvim ~/.env.local

# 3. Configure zsh prompt (optional)
p10k configure

# 4. Install tmux plugins
# In tmux: Ctrl-a + I

# Git hooks are automatically installed (shellcheck + gitleaks)
```

## Updates

```bash
# Update dotfiles
cd ~/.config/dotfiles && git pull

# Update tools
brew upgrade              # Homebrew packages
mise upgrade              # Language runtimes
zinit update --all        # Zsh plugins (in zsh)
```

## Uninstall

```bash
# Remove symlinks only (safest, keeps all tools)
./uninstall.sh --symlinks

# Remove symlinks and configs
./uninstall.sh --symlinks --configs

# Remove everything (symlinks, configs, mise, all tools)
./uninstall.sh --all

# Dry run to see what would be removed
./uninstall.sh --all --dry-run

# See all options
./uninstall.sh --help
```

**Note**: Uninstall creates backups in `~/.dotfiles.backup.uninstall.*` for safety.

## Documentation

- `AGENTS.md` - Detailed guidance for AI assistants working in this repository
- `CLAUDE.md` - Quick reference for Claude Code
- Secrets template: `shell/.env.local.example` (copy to `~/.env.local`)

## Customization

### Local Overrides (gitignored)
Add machine-specific config to these files:
- `~/.bashrc.local` - Bash-specific config
- `~/.zshrc.local` - Zsh-specific config
- `~/.gitconfig.local` - Git config (name, email, etc.)
- `~/.env.local` - Secrets and environment variables
- `~/.alias.local` - Custom aliases
- `~/.functions.local` - Custom shell functions
- `~/bin.local/` - Personal scripts (auto-added to PATH)

### Shell Functions
All bin/ scripts are available as shell functions. Examples:
```bash
branches              # Show recent git branches
coauthor "john doe"   # Find git co-authors
get_localip           # Get local IP address
videoconvert in.mov out.mp4  # Convert video
```

## License

MIT
