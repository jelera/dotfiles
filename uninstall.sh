#!/usr/bin/env bash
# Uninstall dotfiles and optionally remove installed packages
# Usage: ./uninstall.sh [options]

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=install/common.sh
source "${SCRIPT_DIR}/install/common.sh"

# Get dotfiles directory
# shellcheck disable=SC2034
DOTFILES_DIR="$(get_dotfiles_dir)"

#------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------

# What to uninstall (set via command line flags)
REMOVE_SYMLINKS=false
REMOVE_MISE_TOOLS=false
REMOVE_MISE=false
REMOVE_CONFIGS=false
REMOVE_LOCAL_FILES=false
REMOVE_LOGS=false
REMOVE_GIT_HOOKS=false
REMOVE_HOMEBREW=false
DRY_RUN=false
INTERACTIVE=true

# Backup directory with timestamp
BACKUP_DIR="${HOME}/.dotfiles.backup.uninstall.$(date +%Y%m%d_%H%M%S)"

#------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------

print_usage() {
    cat <<EOF
Usage: $0 [options]

Uninstall dotfiles and optionally remove installed packages.

Options:
    --all                   Remove everything (nuclear option)
    --symlinks              Remove dotfile symlinks only (default if no options)
    --mise-tools            Uninstall mise-managed tools (50+ packages)
    --mise                  Remove mise binary and data directories
    --configs               Remove config directories (~/.config/mise, ~/.config/ghostty)
    --local-files           Remove local files (~/.env.local, ~/.gitconfig.local)
    --logs                  Remove installation log directory (~/.dotfiles-install-logs)
    --git-hooks             Remove git hooks (lefthook)
    --homebrew              Remove Homebrew (USE WITH CAUTION!)
    --dry-run, -n           Show what would be removed without doing it
    --yes, -y               Skip confirmation prompts
    --help, -h              Show this help message

Safety Levels:
    Safe:      --symlinks, --logs
    Moderate:  --configs, --local-files, --git-hooks
    Risky:     --mise-tools, --mise
    Dangerous: --homebrew (may break other applications!)

Examples:
    # Remove only symlinks (safest)
    $0 --symlinks

    # Remove symlinks and local files
    $0 --symlinks --local-files

    # Remove symlinks, configs, and logs (keeps mise/tools)
    $0 --symlinks --configs --logs

    # Remove everything except Homebrew
    $0 --symlinks --configs --mise-tools --mise --local-files --logs --git-hooks

    # Nuclear option - remove EVERYTHING including Homebrew
    $0 --all

    # Dry run to see what would be removed (recommended first!)
    $0 --all --dry-run

EOF
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$INTERACTIVE" == "false" ]]; then
        return 0
    fi

    local response
    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n]: " response
        response="${response:-y}"
    else
        read -rp "$prompt [y/N]: " response
        response="${response:-n}"
    fi

    [[ "$response" =~ ^[Yy] ]]
}

create_backup() {
    local file="$1"

    if [[ ! -e "$file" && ! -L "$file" ]]; then
        return 0
    fi

    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi

    local name
    name="$(basename "$file")"

    if is_dry_run; then
        log_dry_run "Would backup: $file -> ${BACKUP_DIR}/${name}"
    else
        cp -r "$file" "${BACKUP_DIR}/${name}" 2>/dev/null || true
        log_info "Backed up: $name"
    fi
}

#------------------------------------------------------------------------
# Uninstall Functions
#------------------------------------------------------------------------

remove_symlinks() {
    log_step "Removing dotfile symlinks..."

    # Source the symlinks script for its remove function
    # shellcheck source=install/symlinks.sh
    source "${SCRIPT_DIR}/install/symlinks.sh"

    # Use the existing remove_symlinks function
    if is_dry_run; then
        log_dry_run "Would remove all dotfile symlinks"
        log_info "See install/symlinks.sh:352 for full list"
    else
        # The function is already defined from sourcing symlinks.sh
        remove_symlinks
    fi
}

remove_mise_tools() {
    log_step "Removing mise-managed tools..."

    if ! command -v mise >/dev/null 2>&1; then
        log_info "mise not installed, skipping tool removal"
        return 0
    fi

    # Get list of installed tools
    local installed_tools
    installed_tools=$(mise list 2>/dev/null | awk '{print $1}' | sort -u)

    if [[ -z "$installed_tools" ]]; then
        log_info "No mise tools installed"
        return 0
    fi

    log_info "Found mise tools:"
    echo "$installed_tools" | while IFS= read -r tool; do
        echo "  - $tool"
    done

    if ! confirm "Remove all mise-managed tools?" "n"; then
        log_info "Skipping mise tool removal"
        return 0
    fi

    echo "$installed_tools" | while IFS= read -r tool; do
        if is_dry_run; then
            log_dry_run "Would uninstall: $tool"
        else
            log_info "Uninstalling: $tool"
            mise uninstall "$tool" --all || log_warning "Failed to uninstall: $tool"
        fi
    done

    log_success "Mise tools removed"
}

remove_mise_binary() {
    log_step "Removing mise..."

    if ! command -v mise >/dev/null 2>&1; then
        log_info "mise not installed"
        return 0
    fi

    local mise_path
    mise_path=$(command -v mise)

    log_info "Found mise at: $mise_path"

    if ! confirm "Remove mise binary?" "n"; then
        log_info "Keeping mise"
        return 0
    fi

    if is_dry_run; then
        log_dry_run "Would remove: $mise_path"
        log_dry_run "Would remove: ~/.local/share/mise"
        log_dry_run "Would remove: ~/.local/state/mise"
        log_dry_run "Would remove: ~/.cache/mise"
    else
        # Backup mise binary
        create_backup "$mise_path"

        # Remove mise binary
        rm -f "$mise_path"
        log_success "Removed mise binary"

        # Remove mise directories
        if [[ -d "${HOME}/.local/share/mise" ]]; then
            create_backup "${HOME}/.local/share/mise"
            rm -rf "${HOME}/.local/share/mise"
            log_success "Removed ~/.local/share/mise"
        fi

        if [[ -d "${HOME}/.local/state/mise" ]]; then
            create_backup "${HOME}/.local/state/mise"
            rm -rf "${HOME}/.local/state/mise"
            log_success "Removed ~/.local/state/mise"
        fi

        if [[ -d "${HOME}/.cache/mise" ]]; then
            rm -rf "${HOME}/.cache/mise"
            log_success "Removed ~/.cache/mise"
        fi
    fi
}

remove_config_directories() {
    log_step "Removing config directories..."

    local configs=(
        "${HOME}/.config/mise"
        "${HOME}/.config/ghostty"
    )

    for config in "${configs[@]}"; do
        if [[ -e "$config" || -L "$config" ]]; then
            if is_dry_run; then
                log_dry_run "Would remove: $config"
            else
                create_backup "$config"
                rm -rf "$config"
                log_success "Removed: $config"
            fi
        fi
    done
}

remove_local_files() {
    log_step "Removing local configuration files..."

    local files=(
        "${HOME}/.env.local"
        "${HOME}/.gitconfig.local"
    )

    log_warning "These files may contain your personal settings and secrets!"

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            if is_dry_run; then
                log_dry_run "Would remove: $file"
            else
                if confirm "Remove $file?" "n"; then
                    create_backup "$file"
                    rm -f "$file"
                    log_success "Removed: $file"
                else
                    log_info "Keeping: $file"
                fi
            fi
        fi
    done
}

remove_install_logs() {
    log_step "Removing installation logs..."

    if [[ -d "${HOME}/.dotfiles-install-logs" ]]; then
        if is_dry_run; then
            log_dry_run "Would remove: ~/.dotfiles-install-logs"
        else
            rm -rf "${HOME}/.dotfiles-install-logs"
            log_success "Removed: ~/.dotfiles-install-logs"
        fi
    else
        log_info "No installation logs found"
    fi
}

remove_git_hooks() {
    log_step "Removing git hooks..."

    if [[ ! -d "${SCRIPT_DIR}/.git/hooks" ]]; then
        log_info "Not a git repository or no hooks installed"
        return 0
    fi

    if ! command -v lefthook >/dev/null 2>&1; then
        log_info "lefthook not installed, skipping"
        return 0
    fi

    if is_dry_run; then
        log_dry_run "Would run: lefthook uninstall"
    else
        cd "${SCRIPT_DIR}" && lefthook uninstall
        log_success "Git hooks removed"
    fi
}

remove_homebrew() {
    log_step "Removing Homebrew..."

    if ! command -v brew >/dev/null 2>&1; then
        log_info "Homebrew not installed"
        return 0
    fi

    local brew_prefix
    brew_prefix="$(brew --prefix)"

    log_warning "╔════════════════════════════════════════════════════════════╗"
    log_warning "║  WARNING: This will uninstall Homebrew completely!        ║"
    log_warning "║  All Homebrew packages will be removed!                   ║"
    log_warning "║  This may break other applications on your system!        ║"
    log_warning "╚════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Homebrew prefix: $brew_prefix"
    echo ""

    if ! confirm "Are you ABSOLUTELY SURE you want to uninstall Homebrew?" "n"; then
        log_info "Keeping Homebrew"
        return 0
    fi

    if ! confirm "Last chance! Uninstall Homebrew and all its packages?" "n"; then
        log_info "Keeping Homebrew"
        return 0
    fi

    if is_dry_run; then
        log_dry_run "Would download and run Homebrew uninstall script"
    else
        log_info "Downloading Homebrew uninstall script..."
        if command -v curl >/dev/null 2>&1; then
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
        else
            log_error "curl not found, cannot download uninstall script"
            log_info "Manual uninstall: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""
            return 1
        fi
        log_success "Homebrew removed"
    fi
}

reset_iterm2_preferences() {
    log_step "Resetting iTerm2 preferences..."

    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_info "Skipping iTerm2 reset (macOS only)"
        return 0
    fi

    # Check if iTerm2 preferences were configured
    local prefs_folder
    prefs_folder=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || echo "")

    if [[ -z "$prefs_folder" ]]; then
        log_info "iTerm2 not configured to use custom preferences"
        return 0
    fi

    if is_dry_run; then
        log_dry_run "Would reset iTerm2 preferences to system default"
    else
        if confirm "Reset iTerm2 to use system preferences?" "n"; then
            defaults delete com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true
            defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool false
            log_success "iTerm2 reset to system preferences"
            log_info "Restart iTerm2 for changes to take effect"
        else
            log_info "Keeping iTerm2 custom preferences"
        fi
    fi
}

cleanup_shell_integration() {
    log_step "Cleaning up shell integration..."

    # Note: We don't remove shell rc files since user may have customized them
    # We just notify the user
    log_info "Shell integration is in your dotfile symlinks"
    log_info "Symlink removal will revert to your original shell configs"

    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Original configs backed up to: $BACKUP_DIR"
    fi
}

#------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------

main() {
    # Parse command line arguments
    if [[ $# -eq 0 ]]; then
        # Default: just remove symlinks
        REMOVE_SYMLINKS=true
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                REMOVE_SYMLINKS=true
                REMOVE_MISE_TOOLS=true
                REMOVE_MISE=true
                REMOVE_CONFIGS=true
                REMOVE_LOCAL_FILES=true
                REMOVE_LOGS=true
                REMOVE_GIT_HOOKS=true
                REMOVE_HOMEBREW=true
                ;;
            --symlinks)
                REMOVE_SYMLINKS=true
                ;;
            --mise-tools)
                REMOVE_MISE_TOOLS=true
                ;;
            --mise)
                REMOVE_MISE=true
                ;;
            --configs)
                REMOVE_CONFIGS=true
                ;;
            --local-files)
                REMOVE_LOCAL_FILES=true
                ;;
            --logs)
                REMOVE_LOGS=true
                ;;
            --git-hooks)
                REMOVE_GIT_HOOKS=true
                ;;
            --homebrew)
                REMOVE_HOMEBREW=true
                ;;
            --dry-run|-n)
                # shellcheck disable=SC2034
                DRY_RUN=true
                ;;
            --yes|-y)
                INTERACTIVE=false
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
        shift
    done

    print_header "Dotfiles Uninstaller"

    if is_dry_run; then
        log_info "DRY RUN MODE: No changes will be made"
        echo ""
    fi

    # Show what will be removed
    log_step "Uninstall Summary"
    echo ""
    echo "The following will be removed:"
    [[ "$REMOVE_SYMLINKS" == "true" ]] && echo "  ✓ Dotfile symlinks (.bashrc, .zshrc, .gitconfig, etc.)"
    [[ "$REMOVE_CONFIGS" == "true" ]] && echo "  ✓ Config directories (~/.config/mise, ~/.config/ghostty)"
    [[ "$REMOVE_LOCAL_FILES" == "true" ]] && echo "  ✓ Local files (~/.env.local, ~/.gitconfig.local)"
    [[ "$REMOVE_LOGS" == "true" ]] && echo "  ✓ Installation logs (~/.dotfiles-install-logs)"
    [[ "$REMOVE_GIT_HOOKS" == "true" ]] && echo "  ✓ Git hooks (lefthook)"
    [[ "$REMOVE_MISE_TOOLS" == "true" ]] && echo "  ✓ Mise-managed tools (50+ packages)"
    [[ "$REMOVE_MISE" == "true" ]] && echo "  ✓ Mise binary and data directories"
    [[ "$REMOVE_HOMEBREW" == "true" ]] && echo "  ✓ Homebrew (DANGEROUS - will remove ALL brew packages!)"
    echo ""

    if [[ "$REMOVE_SYMLINKS" == "false" && "$REMOVE_CONFIGS" == "false" && \
          "$REMOVE_MISE_TOOLS" == "false" && "$REMOVE_MISE" == "false" && \
          "$REMOVE_LOCAL_FILES" == "false" && "$REMOVE_LOGS" == "false" && \
          "$REMOVE_GIT_HOOKS" == "false" && "$REMOVE_HOMEBREW" == "false" ]]; then
        log_warning "Nothing selected to remove"
        echo ""
        print_usage
        exit 0
    fi

    # Final confirmation
    if ! is_dry_run; then
        log_warning "This operation cannot be easily undone!"
        log_info "Backups will be created in: $BACKUP_DIR"
        echo ""

        if ! confirm "Continue with uninstall?" "n"; then
            log_info "Uninstall cancelled"
            exit 0
        fi
        echo ""
    fi

    # Execute uninstall steps in order (safest to most destructive)
    [[ "$REMOVE_GIT_HOOKS" == "true" ]] && remove_git_hooks
    [[ "$REMOVE_LOGS" == "true" ]] && remove_install_logs
    [[ "$REMOVE_SYMLINKS" == "true" ]] && remove_symlinks
    [[ "$REMOVE_SYMLINKS" == "true" ]] && reset_iterm2_preferences
    [[ "$REMOVE_CONFIGS" == "true" ]] && remove_config_directories
    [[ "$REMOVE_LOCAL_FILES" == "true" ]] && remove_local_files
    [[ "$REMOVE_MISE_TOOLS" == "true" ]] && remove_mise_tools
    [[ "$REMOVE_MISE" == "true" ]] && remove_mise_binary
    [[ "$REMOVE_HOMEBREW" == "true" ]] && remove_homebrew

    cleanup_shell_integration

    # Print summary
    echo ""
    print_header "Uninstall Complete"
    echo ""

    if [[ -d "$BACKUP_DIR" ]] && ! is_dry_run; then
        log_success "Backups saved to: $BACKUP_DIR"
        echo ""
        log_info "To restore your dotfiles:"
        log_info "  cp -r ${BACKUP_DIR}/. ~/"
        echo ""
    fi

    if [[ "$REMOVE_SYMLINKS" == "true" ]]; then
        log_info "Your shell configs have been restored to pre-dotfiles state"
        log_info "Restart your shell or source your config:"
        log_info "  source ~/.zshrc  (or ~/.bashrc)"
        echo ""
    fi

    if [[ "$REMOVE_MISE" == "true" ]] || [[ "$REMOVE_MISE_TOOLS" == "true" ]]; then
        log_info "Mise and its tools have been removed"
        log_info "If you had other mise configurations, you may need to reinstall"
        echo ""
    fi

    if [[ "$REMOVE_HOMEBREW" == "true" ]] && ! is_dry_run; then
        log_info "Homebrew has been removed"
        log_info "To reinstall: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
    fi

    if [[ "$REMOVE_LOCAL_FILES" == "true" ]]; then
        log_info "Local configuration files removed"
        log_info "Remember to reconfigure secrets if you reinstall"
        echo ""
    fi

    log_success "Uninstall complete!"

    if is_dry_run; then
        echo ""
        log_info "This was a dry run. To actually uninstall, run without --dry-run"
    fi
}

# Run main function
main "$@"
