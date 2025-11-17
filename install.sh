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
DRY_RUN=false

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
  --dry-run              Show what would be done without making changes
  -y, --yes              Skip confirmation prompts
  -h, --help             Show this help message

Examples:
  $0                     # Full installation
  $0 --minimal           # Core tools only
  $0 --symlinks-only     # Just link dotfiles
  $0 --no-languages -y   # Everything except languages, no prompts
  $0 --dry-run           # Preview what will be installed

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
        --dry-run)
            DRY_RUN=true
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
# => HELPER FUNCTIONS
#----------------------------------------------------------------------------//

# Setup local environment file from example
setup_local_env() {
    log_step "Setting up local environment file..."

    local env_local="${HOME}/.env.local"
    local env_example="${SCRIPT_DIR}/shell/.env.local.example"

    if is_dry_run; then
        if [[ ! -f "$env_local" ]]; then
            log_dry_run "Would create ${env_local} from ${env_example}"
        else
            log_dry_run "Would skip creating ${env_local} (already exists)"
        fi
        return 0
    fi

    # Only create if it doesn't exist
    if [[ ! -f "$env_local" ]]; then
        if [[ -f "$env_example" ]]; then
            cp "$env_example" "$env_local"
            log_success "Created ${env_local} from example"
            log_info "Edit ${env_local} to add your secrets and configuration"
        else
            log_warning "Example file not found: ${env_example}"
        fi
    else
        log_info "${env_local} already exists, skipping"
    fi
}

# Configure Git credential helper based on OS
configure_git_credentials() {
    log_step "Configuring Git credential helper..."

    local gitconfig_local="${HOME}/.gitconfig.local"

    if is_dry_run; then
        log_dry_run "Would configure Git credential helper in ${gitconfig_local}"
        return 0
    fi

    # Create or update .gitconfig.local
    if [[ ! -f "$gitconfig_local" ]]; then
        touch "$gitconfig_local"
        log_info "Created ${gitconfig_local}"
    fi

    # Remove any existing credential.helper settings from local config
    git config --file="$gitconfig_local" --unset-all credential.helper 2>/dev/null || true

    # shellcheck disable=SC2154
    if [[ "$OS" == "macos" ]]; then
        # macOS: Use built-in osxkeychain
        git config --file="$gitconfig_local" credential.helper osxkeychain
        log_success "Configured osxkeychain credential helper for macOS"
    elif [[ "$OS" == "ubuntu" ]]; then
        # Ubuntu/Kubuntu/Xubuntu: Use libsecret with Secret Service API
        # Works with GNOME Keyring, KWallet, and other Secret Service providers
        if command_exists git-credential-libsecret || [[ -f /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret ]]; then
            # Try to find or build the credential helper
            local helper_path="/usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret"

            if [[ ! -x "$helper_path" ]] && [[ -d "$(dirname "$helper_path")" ]]; then
                log_info "Building git-credential-libsecret for ${OS_NAME}..."
                (cd "$(dirname "$helper_path")" && sudo make) || log_warning "Failed to build libsecret helper"
            fi

            if [[ -x "$helper_path" ]]; then
                git config --file="$gitconfig_local" credential.helper "$helper_path"
                # shellcheck disable=SC2154
                case "${DESKTOP_ENV:-}" in
                    KDE)
                        log_success "Configured libsecret credential helper for Kubuntu (KWallet)"
                        ;;
                    XFCE)
                        log_success "Configured libsecret credential helper for Xubuntu (GNOME Keyring)"
                        ;;
                    *)
                        log_success "Configured libsecret credential helper for Ubuntu"
                        ;;
                esac
            else
                log_warning "libsecret helper not available, using cache as fallback"
                git config --file="$gitconfig_local" credential.helper "cache --timeout=7200"
            fi
        else
            log_warning "libsecret not installed, using cache as fallback"
            git config --file="$gitconfig_local" credential.helper "cache --timeout=7200"
        fi
    else
        log_warning "Unknown OS, using cache credential helper"
        git config --file="$gitconfig_local" credential.helper "cache --timeout=7200"
    fi

    log_info "Git credential helper configured in ${gitconfig_local}"
}

#----------------------------------------------------------------------------//
# => PRE-FLIGHT CHECKS
#----------------------------------------------------------------------------//
main() {
    require_non_root

    # Export DRY_RUN for use in subscripts
    export DRY_RUN

    if [[ "$DRY_RUN" == "true" ]]; then
        print_header "Dotfiles Installation (DRY RUN)"
        log_warning "DRY RUN MODE: No changes will be made"
        echo ""
    else
        print_header "Dotfiles Installation"
    fi

    # Detect OS
    detect_os || exit 1

    # Check prerequisites
    check_prerequisites || exit 1

    # Print installation plan
    print_installation_plan

    # Confirm installation
    if [[ "$SKIP_CONFIRMATION" != "true" && "$DRY_RUN" != "true" ]]; then
        echo ""
        if ! confirm "Proceed with installation?" "y"; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi

    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        log_step "Preview of installation steps (DRY RUN)..."
    else
        log_step "Starting installation..."
    fi

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

    # Step 6: Setup local environment file
    setup_local_env

    # Step 7: Configure Git credential helper
    configure_git_credentials

    # Step 8: Setup git hooks
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

    # Show log file location if warnings/errors occurred
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        echo ""
        log_warning "Some warnings or errors occurred during installation"
        log_info "Check the log file for details: $LOG_FILE"
        echo ""
    fi

    # Print next steps
    log_step "Next Steps"
    echo ""
    echo "1. Restart your shell or run:"
    echo "   source ~/.zshrc  (or ~/.bashrc)"
    echo ""
    echo "2. Configure your secrets in ~/.env.local:"
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
