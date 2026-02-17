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

# shellcheck disable=SC2154
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

# Install Bash 4+ on macOS (required for optimized installation)
# Linux already has Bash 4+, so this only runs on macOS
# shellcheck disable=SC2154
install_bash_4_on_macos() {
    # Skip if not macOS
    if [[ "$OS" != "macos" ]]; then
        return 0
    fi

    log_step "Checking Bash version..."

    local current_version="${BASH_VERSINFO[0]:-3}"

    # Check if already running Bash 4+
    if [[ "$current_version" -ge 4 ]]; then
        log_info "Already running Bash ${current_version}.${BASH_VERSINFO[1]}"
        return 0
    fi

    log_warning "Detected Bash 3.x (${BASH_VERSION})"
    log_info "Installing Bash 4+ for optimized performance (20-30x faster)..."

    # Determine target bash path
    local new_bash_path
    if [[ "$ARCH" == "arm64" ]]; then
        new_bash_path="/opt/homebrew/bin/bash"
    else
        new_bash_path="/usr/local/bin/bash"
    fi

    # In dry-run mode, check if bash 4+ is already available
    # If so, exec to it so dry-run can continue properly
    if is_dry_run; then
        if [[ -x "$new_bash_path" ]]; then
            local existing_version
            # shellcheck disable=SC2016
            existing_version=$("$new_bash_path" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null)
            if [[ "$existing_version" -ge 4 ]]; then
                log_info "Bash 4+ already available at $new_bash_path"
                log_info "Re-executing with Bash 4+ for accurate dry-run..."
                echo ""
                exec "$new_bash_path" "$0" "$@"
            fi
        fi

        log_dry_run "Would install bash via Homebrew"
        log_dry_run "Would add bash to /etc/shells"
        log_dry_run "Would re-execute installer with Bash 4+"
        log_warning "Continuing with Bash 3.x - some features may not work in dry-run"
        return 0
    fi

    # Install bash via Homebrew
    if ! command_exists brew; then
        log_error "Homebrew not available - cannot install bash"
        return 1
    fi

    log_info "Installing bash via Homebrew..."
    if brew install bash; then
        log_success "Bash 4+ installed"
    else
        log_error "Failed to install bash via Homebrew"
        return 1
    fi

    # Determine new bash path
    local new_bash_path
    if [[ "$ARCH" == "arm64" ]]; then
        new_bash_path="/opt/homebrew/bin/bash"
    else
        new_bash_path="/usr/local/bin/bash"
    fi

    # Verify installation
    if [[ ! -x "$new_bash_path" ]]; then
        log_error "Bash not found at expected location: $new_bash_path"
        return 1
    fi

    local new_version
    new_version=$("$new_bash_path" --version | head -n1)
    log_success "Installed: $new_version"

    # Add to /etc/shells if not present
    if ! grep -qF "$new_bash_path" /etc/shells 2>/dev/null; then
        log_info "Adding $new_bash_path to /etc/shells..."
        echo "$new_bash_path" | sudo tee -a /etc/shells >/dev/null
    fi

    # Re-execute installer with new bash
    log_info "Re-executing installer with Bash 4+..."
    echo ""
    exec "$new_bash_path" "$0" "$@"

    # This line will never be reached if exec succeeds
    return 0
}

# shellcheck disable=SC2154
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

# shellcheck disable=SC2154
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
