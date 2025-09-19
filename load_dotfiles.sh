# Modular dotfiles loader script

# Determine dotfiles directory (where this script is located)
# Likely "$HOME/.config/dotfiles"
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load environment variables
for env_dir in "$DOTFILES_DIR/environments"/*; do
    if [ -d "$env_dir" ]; then
        for env_file in "$env_dir"/*.sh; do
            [ -r "$env_file" ] && source "$env_file"
        done
    fi
done

# Load aliases
for alias_dir in "$DOTFILES_DIR/aliases"/*; do
    if [ -d "$alias_dir" ]; then
        for alias_file in "$alias_dir"/*.sh; do
            [ -r "$alias_file" ] && source "$alias_file"
        done
    fi
done

# Load shell functions and helpers
for script_dir in "$DOTFILES_DIR/scripts"/*; do
    if [ -d "$script_dir" ]; then
        for script_file in "$script_dir"/*.sh; do
            [ -r "$script_file" ] && source "$script_file"
        done
    fi
done

# Load tool configurations
for tool_file in "$DOTFILES_DIR/tools"/*/*.sh; do
    [ -r "$tool_file" ] && source "$tool_file"
done

# Load shell-specific configuration
if [ -n "$ZSH_VERSION" ]; then
    for zsh_file in "$DOTFILES_DIR/shells/zsh"/*.sh; do
        [ -r "$zsh_file" ] && source "$zsh_file"
    done
elif [ -n "$BASH_VERSION" ]; then
    for bash_file in "$DOTFILES_DIR/shells/bash"/*.sh; do
        [ -r "$bash_file" ] && source "$bash_file"
    done
fi

# Initialize FZF if available
if command -v fzf >/dev/null 2>&1; then
    # Setup FZF key bindings
    [ -f "$DOTFILES_DIR/tools/fzf/config.sh" ] && source "$DOTFILES_DIR/tools/fzf/config.sh"
fi
