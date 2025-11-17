#!/usr/bin/env bash
###############################################################################
#
# Dotfiles Installation Script
# Modern, modular dotfiles setup with mise version manager
#
# Usage: ./install.sh [options]
#
###############################################################################

set -e  # Exit on error

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=./install/common.sh
source "${SCRIPT_DIR}/install/common.sh"

# Source OS detection
# shellcheck source=./install/detect-os.sh
source "${SCRIPT_DIR}/install/detect-os.sh"

#----------------------------------------------------------------------------//
# => DEFAULT OPTIONS
#----------------------------------------------------------------------------//
INSTALL_HOMEBREW=true
INSTALL_PACKAGES=true
INSTALL_MISE=true
INSTALL_LANGUAGES=true
CREATE_SYMLINKS=true
SKIP_CONFIRMATION=false

#----------------------------------------------------------------------------//
# => PARSE ARGUMENTS
#----------------------------------------------------------------------------//
display_usage() {
    cat <<EOF
Dotfiles Installation Script

Usage: $0 [options]

Options:
  --minimal              Install only core tools (no languages)
  --no-homebrew          Skip Homebrew installation
  --no-packages          Skip package installation
  --no-mise              Skip mise installation
  --no-languages         Skip language runtime installation
  --no-symlinks          Skip symlinking dotfiles
  --symlinks-only        Only create symlinks (skip everything else)
  -y, --yes              Skip confirmation prompts
  -h, --help             Show this help message

Examples:
  $0                     # Full installation
  $0 --minimal           # Core tools only
  $0 --symlinks-only     # Just link dotfiles
  $0 --no-languages -y   # Everything except languages, no prompts

Supported Platforms:
  - macOS (latest 2 versions)
  - Ubuntu 22.04 LTS
  - Ubuntu 24.04 LTS
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal)
            INSTALL_LANGUAGES=false
            shift
            ;;
        --no-homebrew)
            INSTALL_HOMEBREW=false
            shift
            ;;
        --no-packages)
            INSTALL_PACKAGES=false
            shift
            ;;
        --no-mise)
            INSTALL_MISE=false
            INSTALL_LANGUAGES=false
            shift
            ;;
        --no-languages)
            INSTALL_LANGUAGES=false
            shift
            ;;
        --no-symlinks)
            CREATE_SYMLINKS=false
            shift
            ;;
        --symlinks-only)
            INSTALL_HOMEBREW=false
            INSTALL_PACKAGES=false
            INSTALL_MISE=false
            INSTALL_LANGUAGES=false
            CREATE_SYMLINKS=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        -h|--help)
            display_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            display_usage
            exit 1
            ;;
    esac
done

#----------------------------------------------------------------------------//
# => PRE-FLIGHT CHECKS
#----------------------------------------------------------------------------//
main() {
    require_non_root

    print_header "Dotfiles Installation"

    # Detect OS
    detect_os || exit 1

    # Check prerequisites
    check_prerequisites || exit 1

    # Print installation plan
    print_installation_plan

    # Confirm installation
    if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
        echo ""
        if ! confirm "Proceed with installation?" "y"; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi

    echo ""
    log_step "Starting installation..."

    #------------------------------------------------------------------------//
    # => INSTALLATION STEPS
    #------------------------------------------------------------------------//

    # Step 1: Install Homebrew
    if [[ "$INSTALL_HOMEBREW" == "true" ]]; then
        source "${SCRIPT_DIR}/install/homebrew.sh"
        install_homebrew || log_warning "Homebrew installation had issues (continuing)"
    else
        log_info "Skipping Homebrew installation"
    fi

    # Step 2: Install packages
    if [[ "$INSTALL_PACKAGES" == "true" ]]; then
        source "${SCRIPT_DIR}/install/packages.sh"
        install_essential_packages || log_warning "Some packages failed to install (continuing)"
    else
        log_info "Skipping package installation"
    fi

    # Step 3: Install mise
    if [[ "$INSTALL_MISE" == "true" ]]; then
        source "${SCRIPT_DIR}/install/mise.sh"
        install_mise || log_warning "mise installation had issues (continuing)"
        configure_mise_shell_integration || log_warning "mise shell integration had issues (continuing)"
        setup_mise_config || true
    else
        log_info "Skipping mise installation"
    fi

    # Step 4: Install language runtimes
    if [[ "$INSTALL_LANGUAGES" == "true" ]]; then
        if command_exists mise; then
            if confirm "Install language runtimes? (This takes 10-30 minutes)" "y"; then
                install_mise_tools || install_language_runtimes_fallback
            else
                log_info "Skipping language runtime installation"
            fi
        else
            log_warning "mise not available, skipping language installation"
        fi
    else
        log_info "Skipping language runtime installation"
    fi

    # Step 5: Create symlinks
    if [[ "$CREATE_SYMLINKS" == "true" ]]; then
        source "${SCRIPT_DIR}/install/symlinks.sh"
        create_all_symlinks || log_warning "Some symlinks failed to create"
    else
        log_info "Skipping symlink creation"
    fi

    # Step 6: Setup git hooks
    if command_exists lefthook; then
        log_step "Setting up git hooks with lefthook..."
        if [[ -f "${SCRIPT_DIR}/lefthook.yml" ]]; then
            cd "${SCRIPT_DIR}" && lefthook install
            log_success "Git hooks installed (shellcheck, gitleaks)"
        fi
    else
        log_info "Skipping git hooks (lefthook not installed)"
    fi

    #------------------------------------------------------------------------//
    # => POST-INSTALLATION
    #------------------------------------------------------------------------//

    print_header "Installation Complete!"

    # Print next steps
    log_step "Next Steps"
    echo ""
    echo "1. Restart your shell or run:"
    echo "   source ~/.zshrc  (or ~/.bashrc)"
    echo ""
    echo "2. Configure your secrets:"
    echo "   cp shell/.env.local.example ~/.env.local"
    echo "   nvim ~/.env.local"
    echo ""
    echo "3. Configure Powerlevel10k prompt (zsh only):"
    echo "   p10k configure"
    echo ""
    echo "4. Install Tmux plugins:"
    echo "   tmux source ~/.tmux.conf"
    echo "   Press: Ctrl-a + I  (capital I)"
    echo ""
    echo "5. Git hooks are installed (shellcheck + gitleaks)"
    echo "   Run on demand: lefthook run pre-commit"
    echo ""

    if [[ "$INSTALL_LANGUAGES" == "true" ]] && command_exists mise; then
        echo "5. Verify installed tools:"
        echo "   mise list"
        echo "   ruby --version"
        echo "   node --version"
        echo "   python --version"
        echo ""
    fi

    log_info "Documentation:"
    echo "  README.md               - Overview and usage"
    echo "  docs/SECRETS.md         - Secrets management guide"
    echo "  docs/MISE.md            - mise usage guide (if exists)"
    echo "  MIGRATION_PLAN.md       - Migration details"
    echo ""

    log_success "Happy coding! 🚀"
}

# Run main function
main "$@"
