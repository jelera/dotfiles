#!/usr/bin/env bash
# Symlink management for dotfiles
# Creates symlinks from home directory to dotfiles repository

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

# Get dotfiles directory
DOTFILES_DIR="$(get_dotfiles_dir)"

# Backup directory with timestamp
BACKUP_DIR="${HOME}/.dotfiles.backup.$(date +%Y%m%d_%H%M%S)"

create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi
}

backup_existing() {
    local target="$1"
    local name
    name="$(basename "$target")"

    if [[ -e "$target" || -L "$target" ]]; then
        create_backup_dir
        mv "$target" "${BACKUP_DIR}/${name}"
        log_warning "Backed up: $name"
        return 0
    fi

    return 1
}

create_dotfile_symlink() {
    local source="$1"
    local target="$2"

    if [[ ! -e "$source" ]]; then
        log_error "Source file does not exist: $source"
        return 1
    fi

    # Backup if exists
    backup_existing "$target"

    # Create parent directory if needed
    local target_dir
    target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi

    # Create symlink
    ln -sf "$source" "$target"
    log_success "Linked: $(basename "$target")"

    return 0
}

symlink_bash_configs() {
    log_step "Linking bash configuration..."

    if [[ -f "${DOTFILES_DIR}/bash/bashrc" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/bash/bashrc" "${HOME}/.bashrc"
    fi

    if [[ -f "${DOTFILES_DIR}/bash/bash_profile" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/bash/bash_profile" "${HOME}/.bash_profile"
    fi

    return 0
}

symlink_zsh_configs() {
    log_step "Linking zsh configuration..."

    if [[ -f "${DOTFILES_DIR}/zsh/zshrc" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/zsh/zshrc" "${HOME}/.zshrc"
    fi

    if [[ -f "${DOTFILES_DIR}/zsh/zshenv" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/zsh/zshenv" "${HOME}/.zshenv"
    fi

    return 0
}

symlink_git_configs() {
    log_step "Linking git configuration..."

    if [[ -f "${DOTFILES_DIR}/git/gitconfig" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/git/gitconfig" "${HOME}/.gitconfig"
    fi

    if [[ -f "${DOTFILES_DIR}/git/gitignore" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/git/gitignore" "${HOME}/.gitignore_global"
    fi

    if [[ -f "${DOTFILES_DIR}/git/gitmessage" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/git/gitmessage" "${HOME}/.gitmessage"
    fi

    return 0
}

symlink_tmux_config() {
    log_step "Linking tmux configuration..."

    if [[ -f "${DOTFILES_DIR}/tmux/tmux.conf" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/tmux/tmux.conf" "${HOME}/.tmux.conf"
    fi

    return 0
}

symlink_bin_scripts() {
    log_step "Linking utility scripts..."

    if [[ -d "${DOTFILES_DIR}/bin" ]]; then
        # Note: Most utilities are now shell functions in shell/functions
        # Keeping bin/ for compatibility or standalone scripts
        create_dotfile_symlink "${DOTFILES_DIR}/bin" "${HOME}/.bin"

        # Make scripts executable
        if [[ -d "${DOTFILES_DIR}/bin" ]]; then
            chmod +x "${DOTFILES_DIR}"/bin/* 2>/dev/null || true
            log_info "Made bin scripts executable"
        fi
    fi

    log_info "Tip: Add personal scripts to ~/bin.local (auto-loaded)"

    return 0
}

symlink_config_dirs() {
    log_step "Linking XDG config directories..."

    # Ensure ~/.config exists
    mkdir -p "${HOME}/.config"

    # Link mise config if exists
    if [[ -d "${DOTFILES_DIR}/config/mise" ]]; then
        create_dotfile_symlink "${DOTFILES_DIR}/config/mise" "${HOME}/.config/mise"
    fi

    return 0
}

create_all_symlinks() {
    log_step "Creating all dotfile symlinks..."

    symlink_bash_configs
    symlink_zsh_configs
    symlink_git_configs
    symlink_tmux_config
    symlink_bin_scripts
    symlink_config_dirs

    log_success "All symlinks created"

    if [[ -d "$BACKUP_DIR" ]]; then
        echo ""
        log_info "Previous dotfiles backed up to:"
        log_info "  $BACKUP_DIR"
        echo ""
        log_info "To restore, run:"
        log_info "  cp -r ${BACKUP_DIR}/. ~/"
    fi

    return 0
}

remove_symlinks() {
    log_step "Removing dotfile symlinks..."

    local symlinks=(
        "${HOME}/.bashrc"
        "${HOME}/.bash_profile"
        "${HOME}/.zshrc"
        "${HOME}/.zshenv"
        "${HOME}/.gitconfig"
        "${HOME}/.gitignore_global"
        "${HOME}/.gitmessage"
        "${HOME}/.tmux.conf"
        "${HOME}/.bin"
        "${HOME}/.config/mise"
    )

    for symlink in "${symlinks[@]}"; do
        if [[ -L "$symlink" ]]; then
            # Check if it points to our dotfiles
            if readlink "$symlink" | grep -q "$DOTFILES_DIR"; then
                rm "$symlink"
                log_info "Removed symlink: $(basename "$symlink")"
            fi
        fi
    done

    log_success "Symlinks removed"
    return 0
}

restore_from_backup() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory does not exist: $backup_dir"
        return 1
    fi

    log_step "Restoring from backup: $backup_dir"

    # First remove existing symlinks
    remove_symlinks

    # Copy files back
    cp -r "${backup_dir}"/. "${HOME}/"

    log_success "Restored from backup"
    return 0
}

verify_symlinks() {
    log_step "Verifying symlinks..."

    local symlinks=(
        "${HOME}/.bashrc"
        "${HOME}/.zshrc"
        "${HOME}/.gitconfig"
        "${HOME}/.tmux.conf"
        "${HOME}/.bin"
    )

    local all_valid=true

    for symlink in "${symlinks[@]}"; do
        if [[ -L "$symlink" ]]; then
            local target
            target="$(readlink "$symlink")"

            if [[ -e "$target" ]]; then
                log_success "✓ $(basename "$symlink") -> $target"
            else
                log_error "✗ $(basename "$symlink") -> $target (broken link)"
                all_valid=false
            fi
        else
            log_warning "  $(basename "$symlink") (not a symlink)"
        fi
    done

    if $all_valid; then
        log_success "All symlinks are valid"
        return 0
    else
        log_warning "Some symlinks are broken or missing"
        return 1
    fi
}

# Main execution if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_header "Dotfiles Symlink Management"

    case "${1:-}" in
        create|install)
            create_all_symlinks
            verify_symlinks
            ;;
        remove|uninstall)
            remove_symlinks
            ;;
        restore)
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 restore <backup_directory>"
                exit 1
            fi
            restore_from_backup "$2"
            ;;
        verify)
            verify_symlinks
            ;;
        *)
            echo "Usage: $0 {create|remove|restore|verify}"
            echo ""
            echo "Commands:"
            echo "  create   - Create all dotfile symlinks"
            echo "  remove   - Remove all dotfile symlinks"
            echo "  restore  - Restore from backup directory"
            echo "  verify   - Verify symlinks are valid"
            exit 1
            ;;
    esac
fi
