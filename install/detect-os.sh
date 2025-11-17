#!/usr/bin/env bash
# OS Detection for dotfiles installation
# Detects operating system and version

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

detect_os() {
    log_step "Detecting operating system..."

    # Detect OS type
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_VERSION="$(sw_vers -productVersion)"
        OS_VERSION_MAJOR="$(echo "$OS_VERSION" | cut -d. -f1)"
        OS_NAME="macOS"

        log_info "Detected: $OS_NAME $OS_VERSION"

        # Check for supported macOS versions (last 2 major versions)
        if (( OS_VERSION_MAJOR < 13 )); then
            log_warning "macOS version $OS_VERSION may not be fully supported"
            log_warning "Recommended: macOS 13+ (Ventura or later)"
        fi

    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ ! -f /etc/os-release ]]; then
            log_error "Cannot detect Linux distribution"
            log_error "/etc/os-release file not found"
            return 1
        fi

        # shellcheck source=/dev/null
        source /etc/os-release

        if [[ "$ID" == "ubuntu" ]]; then
            OS="ubuntu"
            OS_VERSION="$VERSION_ID"
            OS_NAME="Ubuntu"

            log_info "Detected: $OS_NAME $OS_VERSION"

            # Check for supported Ubuntu LTS versions
            case "$OS_VERSION" in
                "24.04")
                    log_success "Ubuntu 24.04 LTS (Noble Numbat) - Fully supported"
                    OS_CODENAME="noble"
                    ;;
                "22.04")
                    log_success "Ubuntu 22.04 LTS (Jammy Jellyfish) - Fully supported"
                    OS_CODENAME="jammy"
                    ;;
                "20.04")
                    log_warning "Ubuntu 20.04 LTS (Focal Fossa) - Limited support"
                    OS_CODENAME="focal"
                    ;;
                *)
                    log_warning "Ubuntu $OS_VERSION - May not be fully supported"
                    log_warning "Recommended: Ubuntu 22.04 LTS or 24.04 LTS"
                    OS_CODENAME="${VERSION_CODENAME:-unknown}"
                    ;;
            esac

        elif [[ "$ID" == "debian" ]]; then
            OS="debian"
            OS_VERSION="$VERSION_ID"
            OS_NAME="Debian"
            OS_CODENAME="${VERSION_CODENAME:-unknown}"

            log_info "Detected: $OS_NAME $OS_VERSION"
            log_warning "Debian support is experimental"
            log_warning "Some packages may need manual installation"

        else
            log_error "Unsupported Linux distribution: $ID"
            log_error "This script supports: Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, macOS"
            return 1
        fi

    else
        log_error "Unsupported operating system: $OSTYPE"
        log_error "This script supports: macOS, Ubuntu Linux"
        return 1
    fi

    # Detect architecture
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)
            ARCH_NAME="x86_64 (Intel/AMD 64-bit)"
            ;;
        arm64|aarch64)
            ARCH_NAME="ARM64 (Apple Silicon / ARM 64-bit)"
            ;;
        *)
            log_warning "Unusual architecture detected: $ARCH"
            ARCH_NAME="$ARCH"
            ;;
    esac
    log_info "Architecture: $ARCH_NAME"

    # Export variables for use by other scripts
    export OS
    export OS_NAME
    export OS_VERSION
    export OS_VERSION_MAJOR
    export OS_CODENAME
    export ARCH

    # Create a summary
    echo ""
    log_step "System Summary"
    echo "  OS:           $OS_NAME"
    echo "  Version:      $OS_VERSION"
    if [[ -n "${OS_CODENAME:-}" ]]; then
        echo "  Codename:     $OS_CODENAME"
    fi
    echo "  Architecture: $ARCH_NAME"
    echo ""

    return 0
}

# Check for required system tools
check_prerequisites() {
    log_step "Checking prerequisites..."

    local missing_tools=()

    # Essential tools
    if ! command_exists bash; then
        missing_tools+=("bash")
    fi

    if ! command_exists git; then
        missing_tools+=("git")
    fi

    if ! command_exists curl && ! command_exists wget; then
        missing_tools+=("curl or wget")
    fi

    if (( ${#missing_tools[@]} > 0 )); then
        log_error "Missing required tools: ${missing_tools[*]}"

        if [[ "$OS" == "macos" ]]; then
            log_info "Install Xcode Command Line Tools:"
            log_info "  xcode-select --install"
        elif [[ "$OS" == "ubuntu" ]]; then
            log_info "Install required tools:"
            log_info "  sudo apt-get update"
            log_info "  sudo apt-get install -y git curl"
        fi

        return 1
    fi

    log_success "All prerequisites found"
    return 0
}

# Print installation plan
print_installation_plan() {
    log_step "Installation Plan"
    echo ""
    echo "The following will be installed/configured:"
    echo ""
    echo "  1. Package Manager (Homebrew)"
    echo "  2. Version Manager (mise)"
    echo "  3. Development Tools (tmux, fzf, ripgrep, etc.)"
    echo "  4. Language Runtimes:"
    echo "     - Ruby (latest)"
    echo "     - Node.js (LTS)"
    echo "     - Python (latest)"
    echo "     - Go (latest)"
    echo "     - Erlang (latest)"
    echo "     - Elixir (latest)"
    echo "  5. Dotfiles (bash, zsh, git, tmux, etc.)"
    echo ""

    if [[ "$OS" == "ubuntu" ]]; then
        echo "Package installation priority:"
        echo "  1. Homebrew (if available)"
        echo "  2. Maintained PPAs"
        echo "  3. System apt packages"
        echo "  4. Flathub"
        echo "  5. Build from source"
        echo ""
        echo "Note: Snap packages will NOT be used"
        echo ""
    fi
}

# Main execution if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_header "Dotfiles OS Detection"
    detect_os || exit 1
    check_prerequisites || exit 1
    print_installation_plan
fi
