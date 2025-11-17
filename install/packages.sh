#!/usr/bin/env bash
# Package installation with priority hierarchy
# Priority: mise > Homebrew > Maintained PPA > System Apt > Flathub > Build from Source
# NO SNAP SUPPORT
#
# PHILOSOPHY: Use mise as the PRIMARY tool manager for all CLI tools and language runtimes
# Only fall back to other package managers if mise doesn't support the tool

# Get the directory of this script
# Use _INSTALL_SCRIPT_DIR to avoid overwriting parent's SCRIPT_DIR
_INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=install/common.sh
source "${_INSTALL_SCRIPT_DIR}/common.sh"

# Source OS detection
# shellcheck source=install/detect-os.sh
source "${_INSTALL_SCRIPT_DIR}/detect-os.sh"

# Track installation methods (Bash 3.2 compatible - using newline-separated "package:method" pairs)
PACKAGE_INSTALL_METHOD=""

# Helper: Add package installation method
add_install_method() {
    local package="$1"
    local method="$2"
    PACKAGE_INSTALL_METHOD="${PACKAGE_INSTALL_METHOD}${package}:${method}"$'\n'
}

# Helper: Get all package names
get_package_names() {
    echo "$PACKAGE_INSTALL_METHOD" | grep -v '^$' | cut -d: -f1
}

# Helper: Get method for package
get_package_method() {
    local package="$1"
    echo "$PACKAGE_INSTALL_METHOD" | grep "^${package}:" | cut -d: -f2
}

# Helper: Get all methods
get_all_methods() {
    echo "$PACKAGE_INSTALL_METHOD" | grep -v '^$' | cut -d: -f2
}

# Helper: Count entries
count_install_methods() {
    echo "$PACKAGE_INSTALL_METHOD" | grep -c -v '^$'
}

# Check if package is installed (any method)
is_package_installed() {
    local package="$1"

    # Check mise first
    if command_exists mise && mise list 2>/dev/null | grep -q "^${package}"; then
        return 0
    fi

    # Check Homebrew
    if command_exists brew && brew list "$package" &>/dev/null; then
        return 0
    fi

    # Check system package manager
    if command_exists dpkg && dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
        return 0
    fi

    # Check command
    if command_exists "$package"; then
        return 0
    fi

    # Check flatpak
    if command_exists flatpak && flatpak list | grep -q "$package"; then
        return 0
    fi

    return 1
}

# Install via mise (Priority 0 - HIGHEST)
install_via_mise() {
    local package="$1"

    if ! command_exists mise; then
        return 1
    fi

    log_info "Trying mise for $package..."

    # Check if already installed via mise
    if mise list 2>/dev/null | grep -q "^${package}"; then
        log_info "✓ $package (already installed via mise)"
        add_install_method "$package" "mise"
        return 0
    fi

    # Check if package is available in mise registry
    if ! mise ls-remote "$package" &>/dev/null; then
        log_info "  Package not available in mise registry"
        return 1
    fi

    if is_dry_run; then
        log_dry_run "Would install $package@latest via mise"
        add_install_method "$package" "mise"
        return 0
    fi

    # Install via mise and set globally
    if mise install "$package@latest" && mise use -g "$package@latest"; then
        log_success "✓ $package (installed via mise)"
        add_install_method "$package" "mise"
        return 0
    fi

    log_info "  Failed to install via mise"
    return 1
}

# Install via Homebrew (Priority 1)
install_via_homebrew() {
    local package="$1"

    if ! command_exists brew; then
        return 1
    fi

    log_info "Trying Homebrew for $package..."

    if brew list "$package" &>/dev/null; then
        log_info "✓ $package (already installed via Homebrew)"
        add_install_method "$package" "homebrew"
        return 0
    fi

    if is_dry_run; then
        # Check if package exists in homebrew
        if brew info "$package" &>/dev/null; then
            log_dry_run "Would install $package via Homebrew"
            add_install_method "$package" "homebrew"
            return 0
        else
            log_info "  Package not available in Homebrew"
            return 1
        fi
    fi

    if brew install "$package" 2>/dev/null; then
        log_success "✓ $package (installed via Homebrew)"
        add_install_method "$package" "homebrew"
        return 0
    fi

    log_info "  Package not available in Homebrew"
    return 1
}

# Install via Homebrew Cask (Priority 1b - GUI applications)
install_via_homebrew_cask() {
    local package="$1"

    if ! command_exists brew; then
        return 1
    fi

    log_info "Trying Homebrew Cask for $package..."

    # Check if already installed via cask
    if brew list --cask "$package" &>/dev/null; then
        log_info "✓ $package (already installed via Homebrew Cask)"
        add_install_method "$package" "homebrew-cask"
        return 0
    fi

    if is_dry_run; then
        # Check if cask exists
        if brew info --cask "$package" &>/dev/null; then
            log_dry_run "Would install $package via Homebrew Cask"
            add_install_method "$package" "homebrew-cask"
            return 0
        else
            log_info "  Cask not available in Homebrew"
            return 1
        fi
    fi

    if brew install --cask "$package" 2>/dev/null; then
        log_success "✓ $package (installed via Homebrew Cask)"
        add_install_method "$package" "homebrew-cask"
        return 0
    fi

    log_info "  Cask not available in Homebrew"
    return 1
}

# Install via maintained PPA (Priority 2 - Ubuntu only)
install_via_ppa() {
    local package="$1"
    local ppa_repo="${2:-}"  # Optional PPA repository

    # shellcheck disable=SC2154
    if [[ "$OS" != "ubuntu" ]]; then
        return 1
    fi

    if [[ -z "$ppa_repo" ]]; then
        return 1
    fi

    log_info "Trying PPA for $package..."

    # Add PPA repository
    if ! grep -q "$ppa_repo" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log_info "Adding PPA: $ppa_repo"
        if sudo add-apt-repository -y "$ppa_repo"; then
            sudo apt-get update -qq
        else
            log_warning "Failed to add PPA: $ppa_repo"
            return 1
        fi
    fi

    # Install package
    if sudo apt-get install -y "$package" 2>/dev/null; then
        log_success "✓ $package (installed via PPA)"
        add_install_method "$package" "ppa"
        return 0
    fi

    return 1
}

# Install via system apt (Priority 3)
install_via_apt() {
    local package="$1"

    if ! command_exists apt-get; then
        return 1
    fi

    log_info "Trying system apt for $package..."

    # Check if package exists in repos
    if ! apt-cache show "$package" &>/dev/null; then
        log_info "  Package not available in apt repos"
        return 1
    fi

    # Install package
    if sudo apt-get install -y "$package" 2>/dev/null; then
        log_success "✓ $package (installed via apt)"
        add_install_method "$package" "apt"
        return 0
    fi

    return 1
}

# Install via Flathub (Priority 4)
install_via_flatpak() {
    local package="$1"
    local flatpak_id="${2:-}"  # Full flatpak ID (e.g., com.example.App)

    if ! command_exists flatpak; then
        return 1
    fi

    if [[ -z "$flatpak_id" ]]; then
        return 1
    fi

    log_info "Trying Flathub for $package..."

    # Check if already installed
    if flatpak list | grep -q "$flatpak_id"; then
        log_info "✓ $package (already installed via Flatpak)"
        add_install_method "$package" "flatpak"
        return 0
    fi

    # Install from Flathub
    if flatpak install -y flathub "$flatpak_id" 2>/dev/null; then
        log_success "✓ $package (installed via Flatpak)"
        add_install_method "$package" "flatpak"
        return 0
    fi

    return 1
}

# Build from source (Priority 5 - last resort)
build_from_source() {
    local package="$1"
    local source_url="${2:-}"
    local build_script="${3:-}"

    if [[ -z "$source_url" ]]; then
        return 1
    fi

    log_info "Building $package from source..."
    log_warning "This may take a while..."

    local build_dir="/tmp/build-${package}-$$"
    mkdir -p "$build_dir"

    cd "$build_dir" || return 1

    # Download source
    if ! download_file "$source_url" "source.tar.gz"; then
        log_error "Failed to download source for $package"
        rm -rf "$build_dir"
        return 1
    fi

    # Extract
    tar -xzf source.tar.gz
    cd "$(find . -maxdepth 1 -type d | tail -n1)" || return 1

    # Build
    if [[ -n "$build_script" ]]; then
        # Use custom build script
        if eval "$build_script"; then
            log_success "✓ $package (built from source)"
            add_install_method "$package" "source"
            cd - >/dev/null || true
            rm -rf "$build_dir"
            return 0
        fi
    else
        # Standard build process
        if ./configure && make && sudo make install; then
            log_success "✓ $package (built from source)"
            add_install_method "$package" "source"
            cd - >/dev/null || true
            rm -rf "$build_dir"
            return 0
        fi
    fi

    cd - >/dev/null || true
    rm -rf "$build_dir"
    return 1
}

# Install package with hierarchy
install_package() {
    local package="$1"
    shift
    local options=("$@")  # Additional options: ppa_repo, flatpak_id, source_url, build_script, cask

    log_step "Installing: $package"

    # Check if already installed
    if is_package_installed "$package"; then
        log_info "✓ $package (already installed)"
        return 0
    fi

    # Check for cask option (GUI application)
    local is_cask=false
    for opt in "${options[@]}"; do
        if [[ "$opt" == "cask" ]]; then
            is_cask=true
            break
        fi
    done

    # Priority 0: mise (HIGHEST - try first for all CLI tools, skip for casks)
    if [[ "$is_cask" == false ]]; then
        if install_via_mise "$package"; then
            return 0
        fi
    fi

    # Priority 1: Homebrew (or Homebrew Cask for GUI apps)
    if [[ "$is_cask" == true ]]; then
        if install_via_homebrew_cask "$package"; then
            return 0
        fi
    else
        if install_via_homebrew "$package"; then
            return 0
        fi
    fi

    # Priority 2: PPA (Ubuntu only)
    if [[ "${options[0]:-}" == ppa:* ]]; then
        local ppa_repo="${options[0]#ppa:}"
        if install_via_ppa "$package" "$ppa_repo"; then
            return 0
        fi
    fi

    # Priority 3: System apt
    if install_via_apt "$package"; then
        return 0
    fi

    # Priority 4: Flatpak
    for opt in "${options[@]}"; do
        if [[ "$opt" == flatpak:* ]]; then
            local flatpak_id="${opt#flatpak:}"
            if install_via_flatpak "$package" "$flatpak_id"; then
                return 0
            fi
        fi
    done

    # Priority 5: Build from source
    for opt in "${options[@]}"; do
        if [[ "$opt" == source:* ]]; then
            local source_url="${opt#source:}"
            local build_script=""

            # Check for build script
            for bopt in "${options[@]}"; do
                if [[ "$bopt" == build:* ]]; then
                    build_script="${bopt#build:}"
                    break
                fi
            done

            if build_from_source "$package" "$source_url" "$build_script"; then
                return 0
            fi
        fi
    done

    log_error "✗ $package (all installation methods failed)"
    return 1
}

# Install multiple packages
install_packages() {
    local packages=("$@")

    log_step "Installing ${#packages[@]} packages..."

    local failed_packages=()

    for package_spec in "${packages[@]}"; do
        # Parse package spec (format: "package" or "package:option1:option2")
        IFS=':' read -ra parts <<< "$package_spec"
        local package="${parts[0]}"
        local options=("${parts[@]:1}")

        if ! install_package "$package" "${options[@]}"; then
            failed_packages+=("$package")
        fi
    done

    if (( ${#failed_packages[@]} > 0 )); then
        log_warning "Failed to install: ${failed_packages[*]}"
        return 1
    fi

    log_success "All packages installed successfully"
    return 0
}

# Setup Flatpak (if needed)
setup_flatpak() {
    if command_exists flatpak; then
        log_info "Flatpak already installed"
        return 0
    fi

    # shellcheck disable=SC2154
    if [[ "$OS" != "ubuntu" ]]; then
        return 0
    fi

    log_step "Setting up Flatpak..."

    # Install flatpak
    if ! sudo apt-get install -y flatpak; then
        log_warning "Failed to install Flatpak"
        return 1
    fi

    # Add Flathub repository
    if ! flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
        log_warning "Failed to add Flathub repository"
        return 1
    fi

    log_success "Flatpak configured with Flathub repository"
    return 0
}

# Install essential development packages
install_essential_packages() {
    log_step "Installing essential development packages..."

    # Note: Most CLI tools (jq, fzf, ripgrep, neovim, bat, gh, lazygit, etc.)
    # are now managed by mise. See mise/config.toml for the full list.
    # Only include packages here that:
    # 1. Are not available in mise registry
    # 2. Are system-level dependencies (libraries, build tools)

    local packages=(
        "git"           # Version control (mise doesn't handle git well)
        "curl"          # HTTP client (system dependency)
        "wget"          # Download utility (system dependency)
        "tmux"          # Terminal multiplexer (check if in mise, fallback to brew/apt)
        "htop"          # System monitor (check if in mise, fallback to brew/apt)
        "tree"          # Directory tree viewer (small utility, either mise or system)
        "pinentry"      # GPG passphrase entry (required for commit signing)
    )

    # Add OS-specific build tools (these MUST come from system package manager)
    # shellcheck disable=SC2154
    if [[ "$OS" == "ubuntu" ]]; then
        packages+=(
            "build-essential"  # GCC, make, etc. (required for compiling)
            "pkg-config"       # Build system helper
            "libssl-dev"       # SSL library headers
            "libreadline-dev"  # Readline library headers
            "zlib1g-dev"       # Compression library headers
            "autoconf"         # Build tool
            "automake"         # Build tool
            "libtool"          # Build tool
            "libsecret-1-0"    # Library for secure credential storage
            "libsecret-1-dev"  # Development headers for libsecret
        )

        # Add desktop-specific packages for credential/keyring support
        # shellcheck disable=SC2154
        case "${DESKTOP_ENV:-}" in
            KDE)
                # Kubuntu - KWallet provides Secret Service API
                packages+=("kwalletmanager")
                log_info "Adding KDE credential storage (KWallet)"
                ;;
            XFCE)
                # Xubuntu - Use GNOME Keyring for Secret Service
                packages+=("gnome-keyring")
                log_info "Adding XFCE credential storage (GNOME Keyring)"
                ;;
            LXQt|LXDE)
                # Lubuntu - Use GNOME Keyring
                packages+=("gnome-keyring")
                log_info "Adding LXQt credential storage (GNOME Keyring)"
                ;;
            GNOME|*)
                # Ubuntu (GNOME) or unknown - Use GNOME Keyring (usually pre-installed)
                packages+=("gnome-keyring")
                log_info "Adding credential storage (GNOME Keyring)"
                ;;
        esac

        # Add clipboard utility (works for all Ubuntu variants)
        packages+=("xclip")
    fi

    # Note: These are now in mise/config.toml:
    # - neovim
    # - ripgrep
    # - fzf
    # - jq
    # - bat
    # - gh
    # - lazygit
    # - shellcheck

    install_packages "${packages[@]}"
}

# Install GUI applications (terminal emulators, etc.)
install_gui_applications() {
    log_step "Installing GUI applications..."

    # Terminal emulators
    local gui_apps=()

    # Ghostty (macOS - Homebrew Cask, Linux - manual)
    # shellcheck disable=SC2154
    if [[ "$OS" == "macos" ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        gui_apps+=("ghostty:cask")
    else
        log_info "Ghostty: Install manually from https://ghostty.org/ (not in package managers yet)"
    fi

    if (( ${#gui_apps[@]} > 0 )); then
        install_packages "${gui_apps[@]}"
    else
        log_info "No GUI applications to install on this platform"
    fi

    return 0
}

# Print installation summary
print_installation_summary() {
    log_step "Installation Summary"

    local count
    count=$(count_install_methods)
    if [[ "$count" -eq 0 ]]; then
        log_info "No packages were installed"
        return
    fi

    echo ""
    printf "%-20s %-15s\n" "Package" "Method"
    print_separator

    # Iterate through all packages
    local package method
    while IFS=: read -r package method; do
        if [[ -n "$package" ]]; then
            printf "%-20s %-15s\n" "$package" "$method"
        fi
    done < <(echo "$PACKAGE_INSTALL_METHOD")

    echo ""

    # Count by method
    local mise_count=0
    local homebrew_count=0
    local homebrew_cask_count=0
    local ppa_count=0
    local apt_count=0
    local flatpak_count=0
    local source_count=0

    while read -r method; do
        if [[ -n "$method" ]]; then
            case "$method" in
                mise) ((mise_count++)) ;;
                homebrew) ((homebrew_count++)) ;;
                homebrew-cask) ((homebrew_cask_count++)) ;;
                ppa) ((ppa_count++)) ;;
                apt) ((apt_count++)) ;;
                flatpak) ((flatpak_count++)) ;;
                source) ((source_count++)) ;;
                *) log_warning "Unknown installation method: $method" ;;
            esac
        fi
    done < <(get_all_methods)

    log_info "Installation methods used:"
    [[ $mise_count -gt 0 ]] && echo "  mise: $mise_count packages"
    [[ $homebrew_count -gt 0 ]] && echo "  Homebrew: $homebrew_count packages"
    [[ $homebrew_cask_count -gt 0 ]] && echo "  Homebrew Cask: $homebrew_cask_count packages"
    [[ $ppa_count -gt 0 ]] && echo "  PPA: $ppa_count packages"
    [[ $apt_count -gt 0 ]] && echo "  Apt: $apt_count packages"
    [[ $flatpak_count -gt 0 ]] && echo "  Flatpak: $flatpak_count packages"
    [[ $source_count -gt 0 ]] && echo "  Source: $source_count packages"
    echo ""
}

# Main execution if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    require_non_root

    print_header "Package Installation"

    # Detect OS
    detect_os || exit 1

    # Setup Flatpak if on Linux
    if [[ "$OS" == "ubuntu" ]]; then
        setup_flatpak
    fi

    # Install essential packages
    install_essential_packages

    # Install GUI applications (terminal emulators, etc.)
    install_gui_applications

    # Print summary
    print_installation_summary

    log_success "Package installation complete!"
fi
