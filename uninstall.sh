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
    --all                   Remove everything (symlinks, configs, mise)
    --symlinks              Remove dotfile symlinks only (default if no options)
    --mise-tools            Uninstall mise-managed tools
    --mise                  Remove mise itself
    --configs               Remove config directories (~/.config/mise, etc.)
    --dry-run, -n           Show what would be removed without doing it
    --yes, -y               Skip confirmation prompts
    --help, -h              Show this help message

Examples:
    # Remove only symlinks (safest)
    $0 --symlinks

    # Remove symlinks and configs (keeps mise and tools)
    $0 --symlinks --configs

    # Remove everything including mise and all tools
    $0 --all

    # Dry run to see what would be removed
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
    [[ "$REMOVE_SYMLINKS" == "true" ]] && echo "  ✓ Dotfile symlinks"
    [[ "$REMOVE_CONFIGS" == "true" ]] && echo "  ✓ Config directories (~/.config/mise, ~/.config/ghostty)"
    [[ "$REMOVE_MISE_TOOLS" == "true" ]] && echo "  ✓ Mise-managed tools (50+ packages)"
    [[ "$REMOVE_MISE" == "true" ]] && echo "  ✓ Mise binary and data"
    echo ""

    if [[ "$REMOVE_SYMLINKS" == "false" && "$REMOVE_CONFIGS" == "false" && \
          "$REMOVE_MISE_TOOLS" == "false" && "$REMOVE_MISE" == "false" ]]; then
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

    # Execute uninstall steps in order
    [[ "$REMOVE_SYMLINKS" == "true" ]] && remove_symlinks
    [[ "$REMOVE_CONFIGS" == "true" ]] && remove_config_directories
    [[ "$REMOVE_MISE_TOOLS" == "true" ]] && remove_mise_tools
    [[ "$REMOVE_MISE" == "true" ]] && remove_mise_binary

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

    log_success "Uninstall complete!"
}

# Run main function
main "$@"
