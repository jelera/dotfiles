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

# Preview installation
./install.sh --dry-run       # Preview with dev profile (59 packages)
./install.sh --minimal --dry-run  # Preview minimal profile (6 packages)
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
- `packages-manifest.sh` - Manifest-based package orchestration (default)
- `symlinks.sh` - Dotfile symlink management
- `lib/manifest-parser.sh` - YAML manifest parser
- `lib/backend-*.sh` - Package manager backends: apt, homebrew, ppa, mise
- `manifests/{common,ubuntu,macos}.yaml` - Multi-manifest package definitions

**Note**: This dotfiles installation uses a manifest-based system with declarative package management and 184 passing tests. Packages are defined in `install/manifests/{common,ubuntu,macos}.yaml` and installed based on profiles (minimal, dev, full, remote). See [Manifest-Based Installation Refactor](#manifest-based-installation-refactor) for details.

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

## Manifest-Based Installation Refactor

**Status**: Complete! (All 3 Phases ✅)

### Overview

The installation system is being refactored from hardcoded shell scripts to a YAML manifest-driven architecture. This provides:

- **Declarative package definitions**: All packages defined in multi-manifest structure (`install/manifests/{common,ubuntu,macos}.yaml`)
- **Installation profiles**: `remote`, `minimal`, `dev`, `full` for different use cases
- **Granular control**: Per-package priority chains, platform filters, category-based organization
- **Test-driven development**: Comprehensive test coverage using BATS framework
- **Dual-mode support**: Legacy and manifest modes during migration

### Architecture

```
install/
├── lib/                           # Shared libraries
│   ├── manifest-parser.sh         # YAML querying library (Phase 1 ✅)
│   ├── backend-apt.sh             # APT backend (Phase 2 ⏳)
│   ├── backend-homebrew.sh        # Homebrew backend (Phase 2 ⏳)
│   ├── backend-ppa.sh             # PPA backend (Phase 2 ⏳)
│   └── backend-mise.sh            # mise backend (Phase 2 ⏳)
├── manifests/
│   ├── common.yaml                # Cross-platform packages
│   ├── ubuntu.yaml                # Ubuntu-specific packages
│   └── macos.yaml                 # macOS-specific packages
├── schemas/
│   └── package-manifest.schema.json
├── tests/                         # Test suite (184 tests ✅)
│   ├── fixtures/
│   │   └── test-packages.yaml     # Test data
│   ├── test-helper.bash           # Test utilities
│   └── test-*.bats                # Parser, backend, integration tests
├── install.sh                     # Main installer
└── packages-manifest.sh           # Manifest-based installer ✅
```

### Phase 1: Foundation ✅ COMPLETE

**Implementation**: Manifest parser with full YAML querying capabilities

**Files**:
- `install/lib/manifest-parser.sh` - Parser library with schema validation
- `install/manifests/{common,ubuntu,macos}.yaml` - Multi-manifest package definitions
- `install/schemas/package-manifest.schema.json` - JSON Schema definition
- `install/tests/test-manifest-parser.bats` - 36 passing tests
- `install/tests/test-schema-validation.bats` - 24 passing tests

**Functions available**:
```bash
parse_manifest <file>                          # Parse YAML to JSON
validate_manifest <file>                       # Basic validation (yq-based)
validate_manifest_schema <file>                # Full JSON Schema validation
get_packages_by_category <file> <category>    # Filter by category
get_package_priority <file> <package>         # Get priority chain
get_packages_for_platform <file> <platform>   # Filter by platform
get_packages_for_profile <file> <profile>     # Filter by profile
is_managed_by_mise <file> <package>           # Check mise management
get_package_manager_config <file> <pkg> <mgr> # Get manager config
```

**Test results**: All 49 tests passing (22 parser + 27 schema validation)
```bash
make -f test.mk test         # Run all tests
make -f test.mk test-parser  # Run parser tests only
```

**Schema validation** (requires `check-jsonschema`):
```bash
# Install validator
mise install pipx:check-jsonschema@latest

# Validate manifest
validate_manifest_schema install/manifests/packages.yaml

# Or use directly
check-jsonschema --schemafile install/schemas/package-manifest.schema.json \
  install/manifests/packages.yaml
```

### Phase 2: Backend Modules ✅ COMPLETE

**Status**: All 4 backends implemented with 94/94 tests passing

Each backend provides:
- Manifest querying for package configuration
- Installation status checking
- Dry-run mode for testing
- Comprehensive error handling
- Bulk installation support

**Backends implemented**:
1. ✅ `backend-apt.sh` - APT/dpkg package installation (22 tests)
2. ✅ `backend-homebrew.sh` - Homebrew formulas and casks (27 tests)
3. ✅ `backend-ppa.sh` - Ubuntu PPA management (23 tests)
4. ✅ `backend-mise.sh` - mise tool installation (22 tests)

**Files created**:
- `install/lib/backend-apt.sh` - APT backend implementation
- `install/lib/backend-homebrew.sh` - Homebrew backend implementation
- `install/lib/backend-ppa.sh` - PPA backend implementation
- `install/lib/backend-mise.sh` - mise backend implementation
- `install/tests/test-backend-apt.bats` - APT backend tests
- `install/tests/test-backend-homebrew.bats` - Homebrew backend tests
- `install/tests/test-backend-ppa.bats` - PPA backend tests
- `install/tests/test-backend-mise.bats` - mise backend tests

**TDD methodology**: All backends developed using strict Red-Green-Refactor cycle

### Phase 3: Integration Layer ✅ COMPLETE

**Status**: Fully implemented with 30/30 tests passing

Complete manifest-driven package installation orchestration with CLI interface.

**New file**: `install/packages-manifest.sh`
- Reads selected profile from CLI args
- Queries manifest for package list
- Orchestrates backend modules
- Maintains compatibility with existing flags

**Migration strategy**:
1. Dual-mode support: `--use-manifest` flag to opt-in
2. Validation: Both modes install same packages
3. Gradual migration: Test thoroughly before switching default
4. Legacy support: Keep `packages.sh` as fallback during migration

**TDD approach**: Write tests in `install/tests/test-integration.bats`

### Manifest Schema

The manifest (`install/manifests/packages.yaml`) follows a strict JSON Schema (`install/schemas/package-manifest.schema.json`) that validates:

- **Required fields**: version, profiles, categories, packages
- **Version format**: String "1.0" or number 1.0
- **Profile constraints**: Must use either `packages` OR `includes`/`excludes`, not both
- **Category requirements**: Must have description and priority array
- **Package requirements**: Must have category and description
- **Platform values**: Must be one of: macos, ubuntu, kubuntu, xubuntu
- **Priority values**: Must be one of: mise, apt, ppa, homebrew, homebrew-cask, flatpak, source
- **PPA repositories**: Must start with "ppa:" prefix
- **Bulk groups**: Must have enabled and packages fields

The manifest uses this structure:

**Quick Reference**:

| Profile | Use Case | Includes |
|---------|----------|----------|
| `full` | Complete dev environment | All categories |
| `dev` | Headless dev environment | All except GUI apps |
| `minimal` | Essential CLI only | git, curl, wget, tmux, tree, pinentry |
| `remote` | Lightweight remote server | git, curl, wget, tmux, htop, tree, pinentry, build-essential |

| Category | Purpose | Default Priority |
|----------|---------|------------------|
| `language_runtimes` | Ruby, Python, Node, Go, etc. | ppa → homebrew → mise |
| `general_tools` | CLI utilities | apt → ppa → homebrew → mise |
| `system_libraries` | Build dependencies | apt only |
| `gui_applications` | Desktop apps | homebrew-cask → flatpak |

#### Profiles

Installation profiles for different use cases:

```yaml
profiles:
  full:
    description: "Complete development environment with all tools"
    includes: [system_libraries, general_tools, language_runtimes, gui_applications]

  dev:
    description: "Developer tools without GUI applications"
    includes: [system_libraries, general_tools, language_runtimes]
    excludes: [gui_applications]

  minimal:
    description: "Essential CLI tools only"
    packages: [git, curl, wget, tmux, tree, pinentry]

  remote:
    description: "Lightweight remote server setup"
    packages: [git, curl, wget, tmux, htop, tree, pinentry, build-essential]
```

**Profile types**:
- **Category-based**: Use `includes`/`excludes` (e.g., `full`, `dev`)
- **Explicit**: Use `packages` array (e.g., `minimal`, `remote`)

#### Categories

Organize packages by purpose with default priority chains:

```yaml
categories:
  language_runtimes:
    description: "Language interpreters and compilers"
    priority: ["ppa", "homebrew", "mise"]

  general_tools:
    description: "CLI utilities and development tools"
    priority: ["apt", "ppa", "homebrew", "mise"]

  system_libraries:
    description: "System-level libraries and build dependencies"
    priority: ["apt"]

  gui_applications:
    description: "Desktop applications"
    priority: ["homebrew-cask", "flatpak"]
```

#### Packages

Individual package definitions:

```yaml
packages:
  git:
    category: general_tools
    description: "Version control system"
    priority: ["apt", "homebrew"]  # Override category default
    apt:
      package: git
    homebrew:
      package: git

  build-essential:
    category: system_libraries
    description: "GCC, make, and essential build tools"
    platforms: ["ubuntu"]  # Only install on Ubuntu
    apt:
      package: build-essential

  ruby:
    category: language_runtimes
    description: "Ruby language runtime"
    managed_by: mise  # Installed via mise, not package managers

  ghostty:
    category: gui_applications
    description: "Modern terminal emulator"
    platforms: ["macos"]
    homebrew:
      cask: true  # Install as cask
      package: ghostty
```

**Package fields**:
- `category` (required): Package category
- `description`: Human-readable description
- `priority`: Custom priority chain (overrides category default)
- `platforms`: Array of platforms (`ubuntu`, `macos`)
- `desktop_env`: Array of desktop environments (`GNOME`, `KDE`, `XFCE`)
- `managed_by`: Special handler (`mise` for mise-managed tools)
- `apt`, `homebrew`, `ppa`: Package manager specific config

#### Bulk Install Groups

Optimize installation by grouping packages:

```yaml
bulk_install_groups:
  system_essentials:
    description: "Core system tools"
    enabled: true
    packages: [git, curl, wget, tree]

  ubuntu_build_tools:
    description: "Build dependencies for Ubuntu"
    enabled: true
    platforms: ["ubuntu"]
    packages: [build-essential, pkg-config, libssl-dev]
```

### Testing

**Framework**: BATS (Bash Automated Testing System)

**Running tests**:
```bash
# Show available test commands
make -f test.mk help

# Run all tests
make -f test.mk test

# Run specific test suites
make -f test.mk test-parser        # Manifest parser tests (22/22 ✅)
make -f test.mk test-backends      # Backend tests (Phase 2 ⏳)
make -f test.mk test-integration   # Integration tests (Phase 3 ⏳)

# Watch mode (re-run on changes)
make -f test.mk test-watch

# Verbose output
make -f test.mk test-verbose

# Coverage summary
make -f test.mk test-coverage
```

**Test structure**:
```
install/tests/
├── fixtures/              # Test data
│   └── test-packages.yaml # Sample manifest
├── test-helper.bash       # Common utilities, setup/teardown
└── test-*.bats           # Test files (BATS format)
```

**TDD workflow**:
1. **Red**: Write a failing test first
2. **Green**: Implement code to make the test pass
3. **Refactor**: Improve code while keeping tests passing

**Current coverage**:
- ✅ Phase 1 - Foundation:
  - Manifest parser: 22/22 tests passing
  - Schema validation: 27/27 tests passing
  - **Total: 49/49 tests passing**
- ✅ Phase 2 - Backend modules:
  - APT backend: 22/22 tests passing
  - Homebrew backend: 27/27 tests passing
  - PPA backend: 23/23 tests passing
  - mise backend: 22/22 tests passing
  - **Total: 94/94 tests passing**
- ✅ Phase 3 - Integration:
  - Integration tests: 30/30 tests passing
  - **Total: 30/30 tests passing**

**🎉 Grand Total: 173/173 tests passing**

**✨ Manifest-based installation system is COMPLETE!**

### Adding New Packages

**Method 1: Add to manifest** (preferred for Phase 2+)

1. Edit `install/manifests/packages.yaml`
2. Add package definition:
   ```yaml
   packages:
     mypackage:
       category: general_tools
       description: "My awesome tool"
       priority: ["apt", "homebrew"]  # Optional, uses category default if omitted
       apt:
         package: mypackage
       homebrew:
         package: mypackage
   ```
3. Optionally add to a profile:
   ```yaml
   profiles:
     dev:
       includes: [general_tools]  # mypackage will be included
   ```
4. Run tests to verify: `make -f test.mk test`

**Method 2: Add to mise** (for CLI tools and runtimes)

1. Check availability: `mise ls-remote <tool>`
2. Add to `mise/config.toml`:
   ```toml
   [tools]
   mypackage = "latest"
   ```
3. Add to manifest with `managed_by: mise`:
   ```yaml
   packages:
     mypackage:
       category: general_tools
       description: "My CLI tool"
       managed_by: mise
   ```
4. Install: `mise install mypackage@latest`

**Method 3: Legacy mode** (temporary, until Phase 3)

1. Edit `install/packages.sh`
2. Add to appropriate function
3. Follow existing patterns in the file

### Adding New Profiles

Edit `install/manifests/packages.yaml`:

**Category-based profile**:
```yaml
profiles:
  myprofile:
    description: "My custom setup"
    includes: [general_tools, system_libraries]
    excludes: [gui_applications]
```

**Explicit package list**:
```yaml
profiles:
  myprofile:
    description: "My minimal setup"
    packages: [git, curl, tmux, neovim]
```

**Test the profile**:
```bash
# Query packages in profile
source install/lib/manifest-parser.sh
get_packages_for_profile install/manifests/packages.yaml myprofile
```

### Migration Notes

**Current state**: Phase 1 complete, using legacy install scripts

**Testing manifest queries**:
```bash
# Source the parser
source install/lib/manifest-parser.sh

# Test queries
get_packages_for_profile install/manifests/packages.yaml minimal
get_packages_for_platform install/manifests/packages.yaml ubuntu
get_package_priority install/manifests/packages.yaml git
```

**When Phase 2 completes**:
- Backend modules will be available for testing
- Can test individual package installations via manifest

**When Phase 3 completes**:
- Full manifest-driven installation available
- Use `--use-manifest` flag to opt-in
- Default remains legacy mode until validated

**Final migration**:
- Switch default to manifest mode
- Keep legacy mode with `--use-legacy` flag
- Eventually deprecate legacy scripts

### Related Files

- `install/manifests/packages.yaml` - Main package manifest
- `install/schemas/package-manifest.schema.json` - JSON Schema definition
- `install/lib/manifest-parser.sh` - Parser library with validation
- `install/tests/test-manifest-parser.bats` - Parser tests (22 tests)
- `install/tests/test-schema-validation.bats` - Schema tests (27 tests)
- `test.mk` - Test runner
- `mise/config.toml` - mise-managed tools (referenced by manifest)

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

### Uninstalling

The `uninstall.sh` script provides safe, granular removal of dotfiles with multiple safety levels:

**Safety Levels:**
- **Safe**: `--symlinks`, `--logs`
- **Moderate**: `--configs`, `--local-files`, `--git-hooks`
- **Risky**: `--mise-tools`, `--mise`
- **Dangerous**: `--homebrew` (may break other applications!)

**Basic Usage:**

```bash
# Remove symlinks only (safest - keeps all tools)
./uninstall.sh --symlinks

# Remove symlinks and config directories
./uninstall.sh --symlinks --configs

# Remove symlinks, configs, and logs (keeps mise/tools)
./uninstall.sh --symlinks --configs --logs

# Dry run to see what would be removed (RECOMMENDED FIRST!)
./uninstall.sh --all --dry-run

# Skip confirmation prompts
./uninstall.sh --symlinks --yes
```

**Advanced Usage:**

```bash
# Remove mise-managed tools (50+ packages)
./uninstall.sh --mise-tools

# Remove mise binary and data directories
./uninstall.sh --mise

# Remove local configuration files (contains secrets!)
./uninstall.sh --local-files

# Remove git hooks
./uninstall.sh --git-hooks

# Remove installation logs
./uninstall.sh --logs

# Nuclear option - remove EVERYTHING including Homebrew
./uninstall.sh --all

# Everything except Homebrew (recommended)
./uninstall.sh --symlinks --configs --mise-tools --mise --local-files --logs --git-hooks
```

**What each flag removes:**
- `--symlinks`: Dotfile symlinks (.bashrc, .zshrc, .gitconfig, etc.) + resets iTerm2 preferences
- `--configs`: Config directories (~/.config/mise, ~/.config/ghostty)
- `--local-files`: Local config files (~/.env.local, ~/.gitconfig.local) - contains YOUR data!
- `--logs`: Installation log directory (~/.dotfiles-install-logs)
- `--git-hooks`: Git hooks installed by lefthook
- `--mise-tools`: All mise-installed tools (languages, CLI utilities)
- `--mise`: mise binary, ~/.local/share/mise, ~/.local/state/mise, ~/.cache/mise
- `--homebrew`: **DANGEROUS** - Uninstalls Homebrew and ALL its packages (may break other apps!)
- `--all`: Everything above (nuclear option)

**Safety features:**
- Creates timestamped backup: `~/.dotfiles.backup.uninstall.YYYYMMDD_HHMMSS/`
- Restores original shell configs when removing symlinks
- Interactive confirmations for destructive operations (skip with `--yes`)
- Extra warnings for dangerous operations (Homebrew removal)
- Dry-run mode to preview changes (`--dry-run`)
- Backups created before deletion

**Restore from backup:**
```bash
# After uninstall, backups are saved in timestamped directory
cp -r ~/.dotfiles.backup.uninstall.YYYYMMDD_HHMMSS/. ~/
```

**Implementation:**
- Script: `uninstall.sh`
- Uses existing `remove_symlinks()` from `install/symlinks.sh`
- Queries mise for installed tools before removal
- Downloads official Homebrew uninstall script if requested
- Handles iTerm2 preference reset on macOS
- Removes keyd config via sudo if needed

### Adding Language Runtime or CLI Tool

**Note**: See [Manifest-Based Installation Refactor > Adding New Packages](#adding-new-packages) for the preferred manifest-based approach (Phase 2+).

**Current method (legacy)**:
1. **First, check if mise supports it**: `mise ls-remote <tool>`
2. Add to `mise/config.toml` under `[tools]` (for global availability)
3. Install: `mise install <tool>@latest`
4. Set global: `mise use -g <tool>@latest`
5. Or add to `.mise.toml` for repo-specific development tools only

**For tools NOT in mise:**
1. Add to `install/packages.sh` in `install_essential_packages()`
2. Will automatically try: mise → Homebrew → apt → Flatpak → source

**Recommended**: Also add to `install/manifests/packages.yaml` to prepare for manifest-based installation

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
