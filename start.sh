#!/usr/bin/env bash

# --------------------------------------------------------------------------- #
# Dotfiles Setup Script
# --------------------------------------------------------------------------- #
# Last updated: 2025-09-18
# Author: Jose Elera
# --------------------------------------------------------------------------- #
#
# Lightweight configuration for remote servers and light local environments with
# optional development setup
#
# Features:
# - Essential shell configuration
# - Useful aliases and functions for remote environments
# - Tmux and Git configuration
# - Optional development environment setup
#
# --------------------------------------------------------------------------- #

set -e  # Exit on any error

# Determine dotfiles directory (where this script is located)
# Likely "$HOME/.config/dotfiles"
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "✅ ${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "⚠️ ${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "❌ ${RED}[ERROR]${NC} $1"; }

# Check if command exists
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Detect OS - simplified for remote servers
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if [ -f /etc/os-release ]; then
                if grep -q "Ubuntu\|Debian" /etc/os-release; then
                    echo "debian-based"
                elif grep -q "CentOS\|Red Hat\|Fedora" /etc/os-release; then
                    echo "redhat-based"
                else
                    echo "linux-other"
                fi
            else
                echo "linux-other"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# --------------------------------------------------------------------------- #
# => Install basic packages based on OS
# --------------------------------------------------------------------------- #
install_basic_packages() {
    local os=$(detect_os)
    log_info "Installing basic packages for $os..."

    case "$os" in
        debian-based)
            sudo apt-get update
            sudo apt-get install -y git curl wget tmux vim zsh htop ripgrep fd-find fzf
            # Create symlink for fd (Ubuntu packages it as fd-find)
            if command_exists fdfind && ! command_exists fd; then
                sudo ln -sf $(which fdfind) /usr/local/bin/fd
            fi
            ;;
        redhat-based)
            sudo yum install -y git curl wget tmux vim zsh htop
            log_warning "Additional repos might be needed for ripgrep, fd, and fzf"
            ;;
        macos)
            if ! command_exists brew; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            brew install git curl wget tmux vim zsh htop ripgrep fd fzf
            ;;
        *)
            log_warning "Unknown OS - skipping package installation"
            ;;
    esac

    log_success "Basic packages installed"
}

# Install Oh My Zsh with plugins
install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log_success "Oh My Zsh installed"
    else
        log_info "Oh My Zsh already installed"
    fi

    # Install pliugins
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

    log_success "Zsh plugins installed"
}

# Setup dotfiles directory structure
setup_dotfiles() {
    log_info "Setting up dotfiles structure..."

    # Add loader to shell profiles
    local shell_profiles=("$HOME/.bashrc" "$HOME/.zshrc")
    for profile in "${shell_profiles[@]}"; do
        if [ -f "$profile" ]; then
            if ! grep -q "load_dotfiles.sh" "$profile"; then
                echo "" >> "$profile"
                echo "# Load modular dotfiles configuration" >> "$profile"
                echo "[ -f \"$DOTFILES_DIR/load_dotfiles.sh\" ] && source \"$DOTFILES_DIR/load_dotfiles.sh\"" >> "$profile"
            fi
        fi
    done

    log_success "Basic dotfiles structure created at $DOTFILES_DIR"
}

# --------------------------------------------------------------------------- #
# => Link configuration files
# --------------------------------------------------------------------------- #
link_configuration_files() {
    log_info "Linking configuration files..."

    # Ensure dotfiles directory exists
    if [ ! -d "$DOTFILES_DIR" ]; then
        log_error "Dotfiles directory $DOTFILES_DIR does not exist. Please clone your dotfiles there."
        exit 1
    fi

    # Link configuration files
    ln -sf "$DOTFILES_DIR/shells/zsh/zshrc.sh" "$HOME/.zshrc"
    ln -sf "$DOTFILES_DIR/shells/bash/bashrc.sh" "$HOME/.bashrc"
    ln -sf "$DOTFILES_DIR/tools/tmux/tmux.conf" "$HOME/.tmux.conf"
    ln -sf "$DOTFILES_DIR/tools/git/gitignore_global" "$HOME/.gitignore_global"
    ln -sf "$DOTFILES_DIR/tools/git/gitconfig" "$HOME/.gitconfig"

    log_success "Configuration files linked"
}

# --------------------------------------------------------------------------- #
# => Setup development environment (optional)
# --------------------------------------------------------------------------- #
setup_dev_environment() {
    log_info "Setting up development environment..."
    local local_dev_script="$HOME/.config/dotfiles/local_dev_setup.sh"

    # If we have the full setup script, use it
    if [ -f "$local_dev_script" ]; then
        bash "$local_dev_script"
        return
    fi

    # Otherwise, do a minimal dev setup
    log_info "Full setup script not found. Performing minimal dev setup..."

    local os=$(detect_os)

    # Install development tools
    case "$os" in
        debian-based)
            sudo apt-get install -y \
                build-essential \
                git \
                python3 \
                python3-pip \
                nodejs \
                npm
            ;;
        redhat-based)
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y \
                git \
                python3 \
                python3-pip
            # Additional steps for Node.js on CentOS/RHEL
            ;;
        macos)
            brew install \
                git \
                python@3 \
                node
            ;;
    esac

    # Create development directories
    mkdir -p "$HOME/dev"/{projects,scripts}

    log_success "Minimal development environment set up"
    log_info "For a full development setup, consider running the complete setup script"
}

# --------------------------------------------------------------------------- #
# => Set zsh as default shell if not already
# --------------------------------------------------------------------------- #
set_default_shell_to_zsh() {
    if [ "$SHELL" != "$(which zsh)" ]; then
        if command_exists chsh; then
            log_info "Changing default shell to zsh..."
            chsh -s "$(which zsh)"
            log_success "Default shell changed to zsh. Please restart your terminal."
        else
            log_warning "chsh command not found. Please change your default shell to zsh manually."
        fi
    else
        log_info "zsh is already the default shell"
    fi
}

# --------------------------------------------------------------------------- #
# => Print instructions
# --------------------------------------------------------------------------- #
print_instructions() {
    log_success "🚀 Setup completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Restart your shell or run: source ~/.$(basename $SHELL)rc"
    if [ "$SHELL" != "$(which zsh)" ]; then
        echo "2. To change your default shell to zsh: chsh -s $(which zsh)"
        echo "   (You may need to log out and log back in for the shell change to take effect)"
    fi
    echo
    echo "Useful commands:"
    echo "  tm                - Start a tmux session with a server-friendly layout"
    echo "  monitor           - Display system resource usage"
    echo "  sysinfo           - Show system information"
    echo "  find_large [dir]  - Find largest files/directories"
    echo "  find_text <text>  - Search for text in files"
    echo "  extract <file>    - Extract compressed files"
    echo "  serve [port]      - Start a simple HTTP server"
    echo
    echo "FZF shortcuts:"
    echo "  fgl               - Git log browser"
    echo "  fgb               - Git branch selector"
    echo "  fcd               - Interactive directory navigation"
    echo "  fe                - Interactive file selection"
    echo
    echo "Happy server administration! 🎉"
}

# --------------------------------------------------------------------------- #
# => Main function
# --------------------------------------------------------------------------- #
main() {
    log_info "🖥️  Minimal Dotfiles Setup"

    # Parse command line arguments
    local install_dev=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --dev|--development)
                install_dev=1
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--dev|--development] [--help|-h]"
                echo
                echo "Options:"
                echo "  --dev, --development  Install development environment"
                echo "  --help, -h            Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Try '$0 --help' for more information."
                exit 1
                ;;
        esac
    done

    # Confirm installation
    echo "This script will set up a minimal dotfiles configuration for remote servers or light local development."
    if [ "$install_dev" -eq 1 ]; then
        echo "It will also install development tools."
    fi
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled"
        exit 0
    fi

    # Run installation steps
    link_configuration_files
    install_basic_packages
    install_oh_my_zsh
    setup_dotfiles
    set_default_shell_to_zsh

    # Install development environment if requested
    if [ "$install_dev" -eq 1 ]; then
        setup_dev_environment
    fi

    print_instructions
}

main "$@"
