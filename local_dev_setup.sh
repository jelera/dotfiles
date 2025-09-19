#!/usr/bin/env bash

# Modern Development Environment Setup Script

# Last updated: 2024-06-20
#
# This script installs development tools using preferred package managers
#
# Installation strategy priority:
# Ubuntu: apt -> mise -> homebrew
# macOS: mise -> homebrew
#
# Supports:
#  - Ubuntu Linux
#    - 22.04 LTS
#    - 24.04 LTS
#  - macOS
#    - 13.0+

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "✅ ${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "⚠️ ${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "❌ ${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}


# --------------------------------------------------------------------------- #
# => Detect OS and validate support
# --------------------------------------------------------------------------- #
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -q "Ubuntu" /etc/os-release && grep -qE "24\.04|22\.04" /etc/os-release; then
                echo "ubuntu"
            else
                log_error "Only Ubuntu 22.04 or 24.04 LTS is supported"
                exit 1
            fi
            ;;
        Darwin*)
            # macOS version check (integer compare, works for 13.0+)
            macos_version=$(sw_vers -productVersion | cut -d. -f1,2)
            major=$(echo "$macos_version" | cut -d. -f1)
            minor=$(echo "$macos_version" | cut -d. -f2)
            if [ "$major" -gt 13 ] || { [ "$major" -eq 13 ] && [ "$minor" -ge 0 ]; }; then
                echo "macos"
            else
                log_error "Only macOS 13.0+ is supported"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported operating system. Only Ubuntu 24.04+ LTS and macOS 13.0+ are supported."
            exit 1
            ;;
    esac
}

# --------------------------------------------------------------------------- #
# Link configuration files
# --------------------------------------------------------------------------- #
link_configuration_files() {
    log_info "Linking configuration files..."

    local dotfiles_dir="$HOME/.config/dotfiles"

    # Ensure dotfiles directory exists
    if [ ! -d "$dotfiles_dir" ]; then
        log_error "Dotfiles directory $dotfiles_dir does not exist. Please clone your dotfiles there."
        exit 1
    fi

    # Link configuration files
    ln -sf "$dotfiles_dir/tools/ripgrep/ripgreprc" "$HOME/.ripgreprc"
    ln -sf "$dotfiles_dir/tools/mise/mise.toml" "$HOME/.mise.toml"
    # ln -sf "$dotfiles_dir/configs/nvim/init.vim" "$HOME/.config/nvim/init.vim"
    # ln -sf "$dotfiles_dir/configs/nvim/undodir" "$HOME/.config/nvim/undodir"

    log_success "Configuration files linked"
}

backup_existing_files() {
    log_info "Backing up existing configuration files..."

    local backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    local files_to_backup=(
        "$HOME/.ripgreprc"
        "$HOME/.mise.toml"
        "$HOME/.config/nvim/init.vim"
        "$HOME/.config/nvim/undodir"
    )

    for file in "${files_to_backup[@]}"; do
        if [ -e "$file" ] || [ -L "$file" ]; then
            mv "$file" "$backup_dir/"
            log_info "Backed up $file to $backup_dir/"
        fi
    done

    log_success "Backup completed. Backup directory: $backup_dir"
}

# --------------------------------------------------------------------------- #
#  => Add required PPAs and repositories for Ubuntu
# --------------------------------------------------------------------------- #
setup_ubuntu_repos() {
    log_info "Setting up Ubuntu repositories and PPAs..."

    # Update package list
    sudo apt-get update

    # Add PostgreSQL official repository
    if ! grep -q "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list 2>/dev/null; then
        log_info "Adding PostgreSQL official repository..."
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
        echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
    fi

    # Add Docker official repository
    if ! command_exists docker; then
        log_info "Adding Docker official repository..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    fi

    # Note: Neovim will be installed via Homebrew for latest version

    # Update after adding repositories
    sudo apt-get update

    log_success "Ubuntu repositories configured"
}

# --------------------------------------------------------------------------- #
# => Install system dependencies on Ubuntu using apt
# --------------------------------------------------------------------------- #
install_ubuntu_system_deps() {
    log_info "Installing Ubuntu system dependencies with apt..."

    # Essential build tools and libraries
    sudo apt-get install -y \
        curl \
        git \
        build-essential \
        unzip \
        gettext \
        cmake \
        pkg-config \
        libtool \
        libtool-bin \
        autoconf \
        automake \
        g++ \
        make \
        wget \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        tree \
        htop \
        jq \
        bc \
        zsh

    # Install development tools available in apt (excluding neovim - will use Homebrew)
    sudo apt-get install -y \
        ripgrep \
        fd-find \
        fzf \
        tmux \
        postgresql-16 \
        postgresql-client-16 \
        postgresql-contrib-16 \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-compose-plugin

    # Create symlinks for fd (Ubuntu packages it as fd-find)
    sudo ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true

    # Setup PostgreSQL
    log_info "Configuring PostgreSQL 16..."
    sudo systemctl enable postgresql
    sudo systemctl start postgresql

    # Setup Docker
    log_info "Configuring Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo groupadd -f docker
    sudo usermod -aG docker $USER

    log_success "Ubuntu system dependencies installed"
}

# --------------------------------------------------------------------------- #
# => Install macOS system dependencies
# --------------------------------------------------------------------------- #
install_macos_system_deps() {
    log_info "Installing basic macOS dependencies..."

    # Install basic tools that mise might need
    if ! command_exists brew; then
        log_info "Installing Homebrew for macOS dependencies..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # Install essential tools via Homebrew on macOS
    brew install git curl wget tree htop jq bc

    log_success "macOS basic dependencies installed"
}



# --------------------------------------------------------------------------- #
# => Install Nerd Fonts
# --------------------------------------------------------------------------- #
install_nerd_fonts() {
    local os=$(detect_os)
    log_info "Installing Nerd Fonts..."

    if [ "$os" = "ubuntu" ]; then
        # Create fonts directory
        mkdir -p ~/.local/share/fonts

        # Download and install popular Nerd Fonts
        local fonts=(
            "CascadiaCode"
            "JetBrainsMono"
            "FiraCode"
            "Hack"
            "SourceCodePro"
        )

        for font in "${fonts[@]}"; do
            if [ ! -d ~/.local/share/fonts/"$font" ]; then
                log_info "Installing $font Nerd Font..."
                wget -q "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.zip" -O /tmp/"$font".zip
                unzip -q /tmp/"$font".zip -d ~/.local/share/fonts/"$font"/
                rm /tmp/"$font".zip
            fi
        done

        # Refresh font cache
        fc-cache -fv ~/.local/share/fonts

    elif [ "$os" = "macos" ]; then
        # Use Homebrew to install Nerd Fonts on macOS
        brew tap homebrew/cask-fonts
        brew install --cask \
            font-caskaydia-mono-nerd-font \
            font-jetbrains-mono-nerd-font \
            font-fira-code-nerd-font \
            font-hack-nerd-font \
            font-source-code-pro
    fi

    log_success "Nerd Fonts installed"
}

# --------------------------------------------------------------------------- #
# => Install Homebrew (fallback for tools not available via other methods)
# --------------------------------------------------------------------------- #
install_homebrew() {
    if command_exists brew; then
        log_info "Homebrew already installed"
        return
    fi

    local os=$(detect_os)
    log_info "Installing Homebrew as fallback package manager..."

    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for current session and future sessions
    if [ "$os" = "ubuntu" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
    else
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi

    log_success "Homebrew installed"
}

# --------------------------------------------------------------------------- #
# => Install mise
# --------------------------------------------------------------------------- #
install_mise() {
    if command_exists mise; then
        log_info "mise already installed"
        return
    fi

    log_info "Installing mise..."
    curl https://mise.run | sh

    # Add mise to shell profile
    local shell_profile=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_profile="$HOME/.bashrc"
    else
        shell_profile="$HOME/.profile"
    fi

    if ! grep -q 'mise activate' "$shell_profile" 2>/dev/null; then
        echo 'eval "$(~/.local/bin/mise activate $(basename $SHELL))"' >> "$shell_profile"
        log_info "Added mise activation to $shell_profile"
    fi

    # Source mise for current session
    export PATH="$HOME/.local/bin:$PATH"

    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        eval "$(~/.local/bin/mise activate zsh)"
    elif [ -n "$BASH_VERSION" ]; then
        eval "$(~/.local/bin/mise activate bash)"
    else
        eval "$(~/.local/bin/mise activate bash)"
    fi

    log_success "mise installed"
}

# --------------------------------------------------------------------------- #
# => Install tools via Homebrew (including Neovim for consistency)
# --------------------------------------------------------------------------- #
install_homebrew_tools() {
    local os=$(detect_os)
    log_info "Installing additional tools via Homebrew..."

    # Ensure Homebrew is available
    if ! command_exists brew; then
        install_homebrew
    fi

    # Tools to install via Homebrew
    local homebrew_tools=(
        "neovim"
        "git-delta"  # A syntax-highlighting pager for git
        "lazygit"    # A simple terminal UI for git commands
        "tig"        # A text-mode interface for git
        "bat"        # A cat(1) clone with wings
    )

    # Add macOS-specific tools
    if [ "$os" = "macos" ]; then
        homebrew_tools+=(
            "ripgrep"   # A line-oriented search tool that recursively searches your current directory for a regex pattern
            "fd"        # A simple, fast and user-friendly alternative to 'find'
            "fzf"       # A general-purpose command-line fuzzy finder
            "tmux"      # A terminal multiplexer
            "postgresql@16"
            "docker"
            "docker-compose"
        )
    fi

    # Install tools
    for tool in "${homebrew_tools[@]}"; do
        if ! brew list "$tool" >/dev/null 2>&1; then
            log_info "Installing $tool via Homebrew..."
            brew install "$tool"
        fi
    done

    # Setup PostgreSQL on macOS
    if [ "$os" = "macos" ]; then
        log_info "Starting PostgreSQL service on macOS..."
        brew services start postgresql@16
    fi

    # Install iterm2 if on macOS
    if [ "$os" = "macos" ]; then
        if ! brew list --cask iterm2 >/dev/null 2>&1; then
            log_info "Installing iTerm2 via Homebrew Cask..."
            brew install --cask iterm2
        fi
    fi

    log_success "Homebrew tools installed"
}

# --------------------------------------------------------------------------- #
# => Install programming languages and tools with mise
# --------------------------------------------------------------------------- #
install_languages_and_tools() {
    log_info "Installing programming languages and tools with mise..."

    # Ensure mise is available
    if ! command_exists mise; then
        install_mise
    fi

    # Install tools from ~/.mise.toml
    mise install

    # Install additional Go tools
    log_info "Installing Go development tools..."
    mise exec go@latest -- go install golang.org/x/tools/gopls@latest
    mise exec go@latest -- go install github.com/go-delve/delve/cmd/dlv@latest
    mise exec go@latest -- go install honnef.co/go/tools/cmd/staticcheck@latest
    mise exec go@latest -- go install golang.org/x/tools/cmd/goimports@latest

    # Install additional Rust tools
    log_info "Installing Rust development tools..."
    mise exec rust@latest -- cargo install cargo-watch
    mise exec rust@latest -- cargo install cargo-edit
    mise exec rust@latest -- cargo install cargo-audit
    mise exec rust@latest -- rustup component add rust-analyzer

    # Install additional Python tools that might not work with pipx
    log_info "Installing additional Python tools..."
    mise exec python@3.12 -- pip install debugpy pylsp-mypy python-lsp-server

    # Install Ruby development tools
    log_info "Installing Ruby development tools..."
    mise exec ruby@3.3 -- gem install bundler rails rubocop solargraph debug pry

    # Install Elixir development tools
    log_info "Installing Elixir development tools..."
    mise exec elixir@1.16 -- mix local.hex --force
    mise exec elixir@1.16 -- mix local.rebar --force
    mise exec elixir@1.16 -- mix archive.install hex phx_new --force

    # Install and configure Node.js development environment
    log_info "Setting up Node.js development environment..."
    mise exec node@lts -- npm config set prefix ~/.npm-global

    log_success "Languages and tools installed"
}


# --------------------------------------------------------------------------- #
# => Setup modular dotfiles structure and configuration
# --------------------------------------------------------------------------- #
setup_dotfiles_config() {
    local dotfiles_dir="$HOME/.config/dotfiles"

    log_info "Setting up modular dotfiles configuration structure..."

    # Add loader to shell profiles
    local shell_profiles=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    for profile in "${shell_profiles[@]}"; do
        if [ -f "$profile" ]; then
            if ! grep -q "load_dotfiles.sh" "$profile"; then
                echo "" >> "$profile"
                echo "# Load modular dotfiles configuration" >> "$profile"
                echo "[ -f \"$dotfiles_dir/load_dotfiles.sh\" ] && source \"$dotfiles_dir/load_dotfiles.sh\"" >> "$profile"
            fi
        fi
    done

    log_success "Modular dotfiles configuration created at $dotfiles_dir"
    log_info "Configuration structure:"
    log_info "  ├── aliases/          - Command aliases by category"
    log_info "  ├── shells/           - Shell-specific configurations"
    log_info "  ├── environments/     - Environment variables by topic"
    log_info "  ├── scripts/          - Custom functions and helpers"
    log_info "  ├── tools/            - Tool-specific configurations"
    log_info "  └── configs/          - Application configurations"
    log_info ""
    log_info "Key features:"
    log_info "  - Modular organization for easy maintenance"
    log_info "  - Automatic loading via load_dotfiles.sh"
    log_info "  - Shell-agnostic compatibility"
    log_info "  - Project management functions"
    log_info "  - Enhanced FZF integration"
    log_info ""
    log_info "Don't forget to:"
    log_info "  1. Update with your name and email"
    log_info "  2. Restart your shell to load new configuration"
}

# --------------------------------------------------------------------------- #
# => Create development directories
# --------------------------------------------------------------------------- #
create_dev_dirs() {
    log_info "Creating development directories..."

    mkdir -p "$HOME/dev"
    mkdir -p "$HOME/.config/nvim"
    mkdir -p "$HOME/dev"/{projects,learning,scripts,tools}
    mkdir -p "$HOME/.config/nvim/undodir"

    log_success "Development directories created in ~/dev/"
}

# --------------------------------------------------------------------------- #
# => Install Visual Studio Code
# --------------------------------------------------------------------------- #
install_vscode() {
    local os=$(detect_os)
    log_info "Installing Visual Studio Code..."

    if [ "$os" = "ubuntu" ]; then
        # Install VSCode via apt
        if ! command_exists code; then
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
            sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
            sudo apt-get install -y apt-transport-https
            sudo apt-get update
            sudo apt-get install -y code
            rm packages.microsoft.gpg
        fi
    elif [ "$os" = "macos" ]; then
        # Install VSCode via Homebrew Cask
        if ! command_exists code; then
            brew install --cask visual-studio-code
        fi
    fi

    log_success "Visual Studio Code installed"
}

# --------------------------------------------------------------------------- #
# => Setup Tmux Plugin Manager
# --------------------------------------------------------------------------- #
setup_tmux_plugins() {
    log_info "Setting up Tmux Plugin Manager..."

    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi

    log_success "Tmux Plugin Manager set up"
}


# --------------------------------------------------------------------------- #
# Main system installation orchestrator
# --------------------------------------------------------------------------- #
install_system_packages() {
    local os=$(detect_os)

    if [ "$os" = "ubuntu" ]; then
        setup_ubuntu_repos
        install_ubuntu_system_deps
    elif [ "$os" = "macos" ]; then
        install_macos_system_deps
    fi
}


# --------------------------------------------------------------------------- #
# => Install terminfo entries for 256-color and italics support
# --------------------------------------------------------------------------- #
install_terminfo_entries() {
    local os=$(detect_os)
    local dotfiles_dir="$HOME/.config/dotfiles"

    log_info "Installing terminfo entries..."

    if [ "$os" = "ubuntu" ]; then
        # Install terminfo entries for 256-color and italics support
        sudo apt-get install -y ncurses-term
    elif [ "$os" = "macos" ]; then
        # macOS usually has good terminfo support, but we can add custom entries if needed
        if [ ! -f "$HOME/.terminfo/x/xterm-256color-italic" ]; then
            mkdir -p "$HOME/.terminfo/x"
            tic -x ${dotfiles_dir}/terminfo/xterm-256color-italic.terminfo
        fi
    fi

    # Support for tmux-256color-italic
    if [ ! -f "$HOME/.terminfo/t/screen-256color-italic" ]; then
        mkdir -p "$HOME/.terminfo/t"
        tic -x ${dotfiles_dir}/terminfo/screen-256color-italic.terminfo
    fi

    log_success "Terminfo entries installed"
}

# --------------------------------------------------------------------------- #
# => Verify installation
# --------------------------------------------------------------------------- #
verify_installation() {
    log_info "Verifying installation..."

    local failed=0
    local warnings=0

    # Check OS
    local os=$(detect_os)
    log_success "Operating System: $os"

    # Check package managers
    if [ "$os" = "ubuntu" ]; then
        if command_exists apt-get; then
            log_success "APT package manager: Available"
        else
            log_error "APT package manager not found"
            failed=1
        fi
    fi

    # Check Homebrew
    if command_exists brew; then
        local brew_version=$(brew --version | head -n1)
        log_success "Homebrew: $brew_version"
    else
        log_warning "Homebrew not found"
        warnings=1
    fi

    # Check mise
    if command_exists mise; then
        local mise_version=$(mise --version)
        log_success "mise: $mise_version"
    else
        log_error "mise not found"
        failed=1
    fi

    # Check Neovim
    if command_exists nvim; then
        local nvim_version=$(nvim --version | head -n1)
        log_success "Neovim: $nvim_version"
    else
        log_error "Neovim not found"
        failed=1
    fi

    # Check PostgreSQL
    if command_exists psql; then
        local pg_version=$(psql --version)
        log_success "PostgreSQL: $pg_version"

        # Check if PostgreSQL is running
        if [ "$os" = "ubuntu" ]; then
            if systemctl is-active --quiet postgresql; then
                log_success "PostgreSQL service: Running"
            else
                log_warning "PostgreSQL service: Not running (run 'pgstart' to start)"
                warnings=1
            fi
        elif [ "$os" = "macos" ]; then
            if brew services list | grep -q "postgresql.*started"; then
                log_success "PostgreSQL service: Running"
            else
                log_warning "PostgreSQL service: Not running (run 'pgstart' to start)"
                warnings=1
            fi
        fi
    else
        log_warning "PostgreSQL not found in PATH"
        warnings=1
    fi

    # Check Docker
    if command_exists docker; then
        local docker_version=$(docker --version)
        log_success "Docker: $docker_version"

        # Check if Docker is running
        if docker info >/dev/null 2>&1; then
            log_success "Docker service: Running"
        else
            log_warning "Docker service: Not running"
            warnings=1
        fi
    else
        log_warning "Docker not found"
    fi

    # Check Tmux
    if command_exists tmux; then
        local tmux_version=$(tmux -V)
        log_success "Tmux: $tmux_version"
    else
        log_warning "Tmux not found"
        warnings=1
    fi

    # Check development tools
    local tools=("git" "curl" "wget" "rg" "fd" "fzf" "tree" "htop" "jq")
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            log_success "$tool: Available"
        else
            log_warning "$tool: Not found in PATH"
            warnings=1
        fi
    done

    # Check programming languages (these might not be in PATH until shell restart)
    local languages=("node" "python" "go" "rustc" "lua" "ruby" "elixir")
    for lang in "${languages[@]}"; do
        if command_exists "$lang"; then
            local version=""
            case "$lang" in
                "node") version=$(node --version) ;;
                "python") version=$(python --version 2>&1) ;;
                "go") version=$(go version | cut -d' ' -f3) ;;
                "rustc") version=$(rustc --version | cut -d' ' -f2) ;;
                "lua") version=$(lua -v 2>&1 | head -n1) ;;
                "ruby") version=$(ruby --version | cut -d' ' -f2) ;;
                "elixir") version=$(elixir --version | grep Elixir | cut -d' ' -f2) ;;
            esac
            log_success "$lang: $version"
        else
            log_warning "$lang: Not found in PATH (may need shell restart or mise activation)"
            warnings=1
        fi
    done

    # Check Node.js tools
    local node_tools=("npm" "ng" "prettier" "eslint")
    for tool in "${node_tools[@]}"; do
        if command_exists "$tool"; then
            log_success "$tool: Available"
        else
            log_warning "$tool: Not found (may need shell restart)"
            warnings=1
        fi
    done

    # Check dotfiles structure
    if [ -d "$HOME/.config/dotfiles" ]; then
        log_success "Dotfiles structure: Created"
        if [ -f "$HOME/.config/dotfiles/load_dotfiles.sh" ]; then
            log_success "Dotfiles loader: Available"
        else
            log_error "Dotfiles loader: Missing"
            failed=1
        fi
    else
        log_error "Dotfiles structure: Not found"
        failed=1
    fi

    # Check key configuration files
    local config_files=("$HOME/.tmux.conf" "$HOME/.gitignore_global" "$HOME/.ripgreprc")
    for config in "${config_files[@]}"; do
        local filename=$(basename "$config")
        if [ -f "$config" ] || [ -L "$config" ]; then
            log_success "$filename: Configured"
        else
            log_warning "$filename: Not found"
            warnings=1
        fi
    done

    # Check fonts (Ubuntu only)
    if [ "$os" = "ubuntu" ]; then
        if [ -d "$HOME/.local/share/fonts/JetBrainsMono" ]; then
            log_success "Nerd Fonts: Installed"
        else
            log_warning "Nerd Fonts: Not found"
            warnings=1
        fi
    fi

    # Summary
    echo ""
    if [ $failed -eq 0 ]; then
        if [ $warnings -eq 0 ]; then
            log_success "🎉 Installation verification completed successfully!"
        else
            log_warning "⚠️  Installation completed with $warnings warnings"
            log_info "Most warnings are normal and will resolve after restarting your shell"
        fi
    else
        log_error "❌ Installation verification failed with $failed errors and $warnings warnings"
        return 1
    fi
}

# Print post-install instructions
print_post_install() {
    local os=$(detect_os)

    log_info "🚀 Installation completed! Next steps:"
    echo
    echo "1. Restart your terminal or run:"
    echo "   source ~/.$(basename $SHELL)rc"
    echo
    echo "2. Configure Git with your information:"
    echo "   git config --global user.name \"Your Name\""
    echo "   git config --global user.email \"your.email@example.com\""
    echo
    echo "3. Start development services:"
    echo "   pgstart    # Start PostgreSQL"
    if [ "$os" = "ubuntu" ]; then
        echo "   sudo systemctl start docker  # Start Docker (if not auto-started)"
    fi
    echo
    echo "🛠  Useful commands:"
    echo "   mise list          - Show installed tools"
    echo "   mise install       - Install tools from .mise.toml"
    echo "   mise upgrade       - Update all tools"
    echo "   pgstart/pgstop     - Manage PostgreSQL"
    echo "   dcleanup           - Clean Docker resources"
    echo "   gclone <repo>      - Clone repo to projects directory"
    echo "   proj <name>        - Navigate to project"
    echo "   projlist           - List all projects"
    echo "   ta [session]       - Attach/create tmux session"
    echo "   tproject <name>    - Create tmux session for project"
    echo "   sysinfo            - Show system and tool info"
    echo "   devservices        - Show running development services"
    echo
    echo "🎨 FZF shortcuts (Ctrl+):"
    echo "   Ctrl+R             - Command history"
    echo "   Ctrl+T             - File finder"
    echo "   Alt+C              - Directory navigation"
    echo "   Ctrl+G Ctrl+L      - Git log browser"
    echo "   Ctrl+G Ctrl+B      - Git branch selector"
    echo
    echo "📂 Directory structure:"
    echo "   ~/dev/projects/     - Your projects"
    echo "   ~/dev/learning/     - Learning materials"
    echo "   ~/dev/scripts/      - Personal scripts"
    echo "   ~/.config/dotfiles/ - Configuration files"
    echo
    if [ "$os" = "ubuntu" ]; then
        echo "⚠️  Ubuntu specific notes:"
        echo "   - Log out and back in for Docker group membership"
        echo "   - Nerd Fonts installed to ~/.local/share/fonts"
    fi
    echo "Happy coding! 🎉"
}

# Main installation function
main() {
    case "${1:-install}" in
        "install")
            log_info "🚀 Starting modern development environment setup..."
            echo

            # Detect and validate OS
            local os=$(detect_os)
            log_info "Detected OS: $os"

            # Confirmation
            read -p "This will install development tools using system packages, mise, and Homebrew. Continue? (Y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                log_info "Installation cancelled"
                exit 0
            fi

            # Run installation steps in order
            log_info "Installation order: system packages → mise → homebrew → fonts → shell → tools → dotfiles"
            echo

            backup_existing_files
            link_configuration_files
            install_system_packages
            install_mise
            install_homebrew_tools
            install_nerd_fonts
            install_languages_and_tools
            setup_dotfiles_config
            setup_tmux_plugins
            install_vscode
            install_terminfo_entries
            create_dev_dirs

            echo
            verify_installation

            echo
            print_post_install
            ;;
        "verify")
            verify_installation
            ;;
        *)
            echo "Usage: $0 [install|uninstall|verify]"
            echo
            echo "Commands:"
            echo "  install    - Install complete development environment (default)"
            echo "  verify     - Verify installation and show status"
            echo
            echo "This script creates a modern development environment with:"
            echo "  • Package management: apt (Ubuntu) → mise → homebrew"
            echo "  • Languages: Node.js, Python, Go, Rust, Ruby, Elixir, Lua"
            echo "  • Tools: Neovim, PostgreSQL 16, Docker, Tmux, Git, FZF"
            echo "  • Fonts: JetBrains Mono, Fira Code, Hack (Nerd Fonts)"
            echo "  • Shell: Oh My Zsh with plugins and enhancements"
            echo "  • Dotfiles: Modular configuration system"
            exit 1
            ;;
    esac
}

main "$@"
