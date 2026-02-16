#!/usr/bin/env bash
# Homebrew installation and configuration
# Installs on both macOS and Linux

# Get the directory of this script
# Use _INSTALL_SCRIPT_DIR to avoid overwriting parent's SCRIPT_DIR
_INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=install/common.sh
source "${_INSTALL_SCRIPT_DIR}/common.sh"

# Source OS detection
# shellcheck source=install/detect-os.sh
source "${_INSTALL_SCRIPT_DIR}/detect-os.sh"

install_homebrew() {
    log_step "Installing Homebrew..."

    if command_exists brew; then
        log_info "Homebrew already installed"
        local brew_version
        brew_version="$(brew --version | head -n1)"
        log_info "$brew_version"

        if is_dry_run; then
            log_dry_run "Would update Homebrew"
        else
            # Update Homebrew
            log_info "Updating Homebrew..."
            brew update
        fi

        return 0
    fi

    if is_dry_run; then
        log_dry_run "Would download and install Homebrew"
        log_dry_run "Would configure Homebrew in PATH"
        return 0
    fi

    # Install Homebrew
    log_info "Downloading and installing Homebrew..."

    if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        log_error "Homebrew installation failed"
        return 1
    fi

    log_success "Homebrew installed successfully"

    # Configure Homebrew in PATH
    configure_homebrew_path

    return 0
}

configure_homebrew_path() {
    log_step "Configuring Homebrew PATH..."

    local brew_path=""

    # shellcheck disable=SC2154
    if [[ "$OS" == "macos" ]]; then
        # shellcheck disable=SC2154
        if [[ "$ARCH" == "arm64" ]]; then
            # Apple Silicon
            brew_path="/opt/homebrew/bin/brew"
        else
            # Intel Mac
            brew_path="/usr/local/bin/brew"
        fi
    elif [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        # Linux
        brew_path="/home/linuxbrew/.linuxbrew/bin/brew"
    fi

    if [[ -f "$brew_path" ]]; then
        # Evaluate brew shellenv for current session
        eval "$("$brew_path" shellenv)"
        log_success "Homebrew configured for current session"

        # Add to shell configs
        add_brew_to_shell_configs "$brew_path"
    else
        log_warning "Homebrew binary not found at expected location: $brew_path"

        # Try to find it
        if command_exists brew; then
            log_info "Found brew in PATH: $(command -v brew)"
            return 0
        else
            log_error "Cannot configure Homebrew - brew command not found"
            return 1
        fi
    fi

    return 0
}

add_brew_to_shell_configs() {
    local brew_path="$1"
    local brew_init_line="eval \"\$($brew_path shellenv)\""

    log_info "Adding Homebrew to shell configurations..."

    # Add to bash
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "homebrew" "$HOME/.bashrc"; then
            {
                echo ""
                echo "# Homebrew"
                echo "$brew_init_line"
            } >> "$HOME/.bashrc"
            log_success "Added Homebrew to ~/.bashrc"
        fi
    fi

    if [[ -f "$HOME/.bash_profile" ]]; then
        if ! grep -q "homebrew" "$HOME/.bash_profile"; then
            {
                echo ""
                echo "# Homebrew"
                echo "$brew_init_line"
            } >> "$HOME/.bash_profile"
            log_success "Added Homebrew to ~/.bash_profile"
        fi
    fi

    # Add to zsh
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "homebrew" "$HOME/.zshrc"; then
            {
                echo ""
                echo "# Homebrew"
                echo "$brew_init_line"
            } >> "$HOME/.zshrc"
            log_success "Added Homebrew to ~/.zshrc"
        fi
    fi
}

install_homebrew_packages() {
    log_step "Installing essential packages via Homebrew..."

    if ! command_exists brew; then
        log_error "Homebrew not found. Please install it first."
        return 1
    fi

    local packages=(
        "git"           # Version control
        "curl"          # HTTP client
        "wget"          # Download utility
        "tmux"          # Terminal multiplexer
        "fzf"           # Fuzzy finder
        "ripgrep"       # Fast grep
        "fd"            # Fast find
        "bat"           # Cat with syntax highlighting
        "eza"           # Modern ls
        "jq"            # JSON processor
        "htop"          # Process viewer
        "tree"          # Directory tree
        "neovim"        # Text editor
        "shellcheck"    # Shell script linter
        "lefthook"      # Git hooks manager
        "gitleaks"      # Secrets detection
    )

    # macOS-specific packages
    if [[ "$OS" == "macos" ]]; then
        packages+=(
            "coreutils"     # GNU core utilities
            "gnu-sed"       # GNU sed
            "gnu-tar"       # GNU tar
            "grep"          # GNU grep
        )
    fi

    # Linux-specific packages
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        packages+=(
            "gcc"           # C compiler
            "build-essential" # Build tools (if available)
        )
    fi

    log_info "Installing ${#packages[@]} packages..."
    log_info "Installing: ${packages[*]}"

    # brew install is idempotent - it skips already installed packages
    if brew install "${packages[@]}" 2>/dev/null; then
        log_success "Homebrew packages installed successfully"
    else
        log_warning "Some packages may have failed to install"
    fi

    log_success "Homebrew packages installation complete"
    return 0
}

verify_homebrew() {
    log_step "Verifying Homebrew installation..."

    if ! command_exists brew; then
        log_error "Homebrew verification failed - brew command not found"
        return 1
    fi

    # Run brew doctor (non-fatal warnings)
    log_info "Running brew doctor..."
    if brew doctor; then
        log_success "Homebrew is configured correctly"
    else
        log_warning "Homebrew doctor reported some issues (may be non-critical)"
    fi

    # Show Homebrew info
    local brew_prefix
    brew_prefix="$(brew --prefix)"
    log_info "Homebrew prefix: $brew_prefix"

    return 0
}

# Main execution if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    require_non_root

    print_header "Homebrew Installation"

    # Detect OS first
    detect_os || exit 1

    # Install Homebrew
    install_homebrew || exit 1

    # Verify installation
    verify_homebrew || exit 1

    # Install essential packages
    if confirm "Install essential development packages via Homebrew?" "y"; then
        install_homebrew_packages || exit 1
    fi

    log_success "Homebrew setup complete!"
fi
