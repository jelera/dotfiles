#!/bin/bash

# Modern Development Environment Setup Script
# This script installs development tools using preferred package managers
# Ubuntu: apt -> mise -> homebrew
# macOS: mise -> homebrew
# Supports: Ubuntu 24.04+ LTS, macOS 13.0+

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS and validate support
detect_os() {
    case "$(uname -s)" in
        Linux*)     
            if grep -q "Ubuntu" /etc/os-release && grep -qE "24\.04|22\.04|20\.04" /etc/os-release; then
                OS="ubuntu"
            else
                log_error "Only Ubuntu 24.04+ LTS is supported"
                exit 1
            fi
            ;;
        Darwin*)    
            local macos_version=$(sw_vers -productVersion | cut -d. -f1,2)
            if (( $(echo "$macos_version >= 13.0" | bc -l) )); then
                OS="macos"
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
    echo $OS
}

# Add required PPAs and repositories for Ubuntu
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

# Install system dependencies on Ubuntu using apt
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

# Install macOS system dependencies
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

# Install Nerd Fonts
install_nerd_fonts() {
    local os=$(detect_os)
    log_info "Installing Nerd Fonts..."
    
    if [ "$os" = "ubuntu" ]; then
        # Create fonts directory
        mkdir -p ~/.local/share/fonts
        
        # Download and install popular Nerd Fonts
        local fonts=(
            "JetBrainsMono"
            "FiraCode" 
            "Hack"
            "SourceCodePro"
            "UbuntuMono"
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
            font-jetbrains-mono-nerd-font \
            font-fira-code-nerd-font \
            font-hack-nerd-font \
            font-source-code-pro \
            font-ubuntu-mono-nerd-font
    fi
    
    log_success "Nerd Fonts installed"
}

# Install Homebrew (fallback for tools not available via other methods)
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



# Install mise
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
    
    if ! grep -q 'mise activate' "$shell_profile"