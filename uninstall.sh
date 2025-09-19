#!/usr/bin/env bash

# Development Environment Cleanup Script
#
# This script removes all components installed by the local_dev_setup.sh script
# It can be run independently to clean up your development environment
#
# Usage: ./uninstall.sh

set -e  # Exit on any error

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

# Detect OS function
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
            log_error "Unsupported operating system. Only Ubuntu 22.04+ LTS and macOS 13.0+ are supported."
            exit 1
            ;;
    esac
}

# Main cleanup function
cleanup_installation() {
    log_warning "This will remove all installed components. This action cannot be undone!"
    read -p "Are you sure you want to proceed? (type 'YES' to confirm): " confirm

    if [ "$confirm" != "YES" ]; then
        log_info "Cleanup cancelled"
        return 1
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
        read -p "Remove dotfiles configuration? This will remove your custom configurations. Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.config/dotfiles"
            rm -f "$HOME/.tmux.conf"
            rm -f "$HOME/.gitignore_global"
            rm -f "$HOME/.ripgreprc"
        fi
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

# Print usage information
print_usage() {
    echo "Development Environment Cleanup Script"
    echo ""
    echo "This script removes all components installed by the local_dev_setup.sh script."
    echo "It safely removes development tools, languages, configurations and services."
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -f, --force    Skip confirmation (dangerous!)"
    echo ""
    echo "This script will:"
    echo "  - Stop services (PostgreSQL, Docker)"
    echo "  - Remove mise and its tools"
    echo "  - Remove Homebrew (optional)"
    echo "  - Remove Oh My Zsh"
    echo "  - Remove dotfiles (optional)"
    echo "  - Remove development directories (optional)"
    echo "  - Clean shell profiles"
    echo "  - Remove repositories and package sources"
    echo ""
    echo "Each destructive action will require confirmation unless --force is specified."
}

# Main function
main() {
    # Parse command-line arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -f|--force)
                FORCE_CLEANUP=1
                shift
                ;;
            *)
                log_error "Unknown parameter: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # If force flag is set, skip confirmation
    if [ "${FORCE_CLEANUP:-0}" -eq 1 ]; then
        log_warning "Forcing cleanup without confirmation!"
        confirm="YES"
    fi

    # Run the cleanup function
    cleanup_installation
}

# Execute main function
main "$@"
