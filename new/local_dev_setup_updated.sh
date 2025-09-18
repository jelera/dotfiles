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
    ln -sf "$dotfiles_dir/tools/tmux/tmux.conf" "$HOME/.tmux.conf"
    ln -sf "$dotfiles_dir/tools/git/gitignore_global" "$HOME/.gitignore_global"
    ln -sf "$dotfiles_dir/tools/ripgrep/ripgreprc" "$HOME/.ripgreprc"
    ln -sf "$dotfiles_dir/tools/mise/mise.toml" "$HOME/.mise.toml"
    ln -sf "$dotfiles_dir/tools/git/gitconfig" "$HOME/.gitconfig"
    # ln -sf "$dotfiles_dir/configs/nvim/init.vim" "$HOME/.config/nvim/init.vim"
    # ln -sf "$dotfiles_dir/configs/nvim/undodir" "$HOME/.config/nvim/undodir"

    log_success "Configuration files linked"
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
# => Install oh-my-zsh with useful plugins
# --------------------------------------------------------------------------- #
install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log_success "Oh My Zsh installed"
    else
        log_info "Oh My Zsh already installed"
    fi

    # Install useful plugins
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # zsh-autosuggestions
    if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions plugin..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    fi

    # zsh-syntax-highlighting
    if [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting plugin..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/plugins/zsh-syntax-highlighting"
    fi

    # fzf-tab (better tab completion with fzf)
    if [ ! -d "$zsh_custom/plugins/fzf-tab" ]; then
        log_info "Installing fzf-tab plugin..."
        git clone https://github.com/Aloxaf/fzf-tab "$zsh_custom/plugins/fzf-tab"
    fi
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
    eval "$(~/.local/bin/mise activate bash)"

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
    local homebrew_tools=("neovim" "git-delta" "lazygit")

    # Add macOS-specific tools
    if [ "$os" = "macos" ]; then
        homebrew_tools+=(
            "ripgrep"
            "fd"
            "fzf"
            "tmux"
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
    mise exec ruby@3.3 -- gem install bundler rails rubocop solargraph debug

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
    # log_info "  1. Copy git config: cp $dotfiles_dir/tools/git/gitconfig ~/.gitconfig"
    log_info "  2. Update with your name and email"
    log_info "  3. Restart your shell to load new configuration"
}

# Create development directories
create_dev_dirs() {
    log_info "Creating development directories..."

    mkdir -p "$HOME/dev"/{projects,learning,scripts,tools}
    mkdir -p "$HOME/.config/nvim/undodir"

    log_success "Development directories created in ~/dev/"
}

# Main system installation orchestrator
install_system_packages() {
    local os=$(detect_os)

    if [ "$os" = "ubuntu" ]; then
        setup_ubuntu_repos
        install_ubuntu_system_deps
    elif [ "$os" = "macos" ]; then
        install_macos_system_deps
    fi
}

# Cleanup/Uninstall function
cleanup_installation() {
    log_warning "This will remove all installed components. This action cannot be undone!"
    read -p "Are you sure you want to proceed? (type 'YES' to confirm): " confirm

    if [ "$confirm" != "YES" ]; then
        log_info "Cleanup cancelled"
        return
    fi

    log_info "Starting cleanup..."

    # Stop services
    log_info "Stopping services..."
    local os=$(detect_os)
    if [ "$os" = "ubuntu" ]; then
        sudo systemctl stop postgresql 2>/dev/null || true
        sudo systemctl stop docker 2>/dev/null || true
    elif [ "$os" = "macos" ]; then
        brew services stop postgresql@16 2>/dev/null || true
    fi

    # Remove mise and its tools
    if command_exists mise; then
        log_info "Removing mise and its tools..."
        rm -rf "$HOME/.local/share/mise"
        rm -rf "$HOME/.local/bin/mise"
        rm -f "$HOME/.mise.toml"
    fi

    # Remove Homebrew (this will remove all installed packages)
    if command_exists brew; then
        log_info "Removing Homebrew and all its packages..."
        read -p "This will remove ALL Homebrew packages. Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
        fi
    fi

    # Remove Oh My Zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log_info "Removing Oh My Zsh..."
        rm -rf "$HOME/.oh-my-zsh"
    fi

    # Remove dotfiles configuration
    if [ -d "$HOME/.config/dotfiles" ]; then
        log_info "Removing dotfiles configuration..."
        rm -rf "$HOME/.config/dotfiles"
        rm -f "$HOME/.tmux.conf"
        rm -f "$HOME/.gitignore_global"
        rm -f "$HOME/.ripgreprc"
    fi

    # Remove Nerd Fonts (Ubuntu only)
    if [ "$os" = "ubuntu" ] && [ -d "$HOME/.local/share/fonts" ]; then
        read -p "Remove installed Nerd Fonts? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.local/share/fonts"/{JetBrainsMono,FiraCode,Hack,SourceCodePro,CascadiaCode}
            fc-cache -fv
        fi
    fi

    # Remove development directories (with confirmation)
    read -p "Remove development directories in ~/dev? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/dev"
        log_info "Development directories removed"
    fi

    # Clean shell profiles
    log_info "Cleaning shell profiles..."
    local shell_profiles=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.zprofile")
    for profile in "${shell_profiles[@]}"; do
        if [ -f "$profile" ]; then
            # Remove lines added by this script
            sed -i.bak '/mise activate/d' "$profile" 2>/dev/null || true
            sed -i.bak '/load_dotfiles.sh/d' "$profile" 2>/dev/null || true
            sed -i.bak '/homebrew/d' "$profile" 2>/dev/null || true
            sed -i.bak '/Load.*dotfiles/d' "$profile" 2>/dev/null || true
            rm -f "${profile}.bak"
        fi
    done

    # Remove Node.js global directory
    rm -rf "$HOME/.npm-global"

    # Remove Neovim undo directory
    rm -rf "$HOME/.config/nvim/undodir"

    # Remove additional repositories (Ubuntu)
    if [ "$os" = "ubuntu" ]; then
        log_info "Removing added repositories..."
        sudo rm -f /etc/apt/sources.list.d/pgdg.list
        sudo rm -f /etc/apt/sources.list.d/docker.list
        sudo apt-key del ACCC4CF8 2>/dev/null || true
        sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
        sudo apt-get update
    fi

    log_success "Cleanup completed!"
    log_info "You may need to:"
    log_info "  1. Restart your terminal"
    log_info "  2. Manually remove any remaining configuration files"
    log_info "  3. Remove Docker group membership: sudo gpasswd -d $USER docker"
    log_info "  4. Remove any remaining PostgreSQL data directories"
}

# Verify installation
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
    # echo "   cp ~/.config/dotfiles/tools/git/gitconfig ~/.gitconfig"
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

            link_configuration_files
            install_system_packages
            install_mise
            install_homebrew_tools
            install_nerd_fonts
            install_oh_my_zsh
            install_languages_and_tools
            setup_dotfiles_config
            create_dev_dirs

            echo
            verify_installation

            echo
            print_post_install
            ;;
        "cleanup"|"uninstall")
            cleanup_installation
            ;;
        "verify")
            verify_installation
            ;;
        *)
            echo "Usage: $0 [install|cleanup|uninstall|verify]"
            echo
            echo "Commands:"
            echo "  install    - Install complete development environment (default)"
            echo "  cleanup    - Remove all installed components"
            echo "  uninstall  - Alias for cleanup"
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
