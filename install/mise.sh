#!/usr/bin/env bash
# mise installation and configuration
# https://mise.jdx.dev/

# Get the directory of this script
# Use _INSTALL_SCRIPT_DIR to avoid overwriting parent's SCRIPT_DIR
_INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=install/common.sh
source "${_INSTALL_SCRIPT_DIR}/common.sh"

install_mise() {
    log_step "Installing mise..."

    if command_exists mise; then
        local mise_version
        mise_version="$(mise --version)"
        log_info "mise already installed: $mise_version"

        if is_dry_run; then
            log_dry_run "Would update mise"
        else
            # Update mise
            log_info "Updating mise..."
            mise self-update || log_warning "Failed to update mise (this is okay)"
        fi

        return 0
    fi

    if is_dry_run; then
        log_dry_run "Would download and install mise from https://mise.run"
        log_dry_run "Would add mise to PATH"
        return 0
    fi

    # Install mise using official installer
    log_info "Downloading and installing mise..."

    if ! curl https://mise.run | sh; then
        log_error "mise installation failed"
        log_info "Trying alternative installation method..."

        # Alternative: install via Homebrew
        if command_exists brew; then
            log_info "Installing mise via Homebrew..."
            brew install mise
        else
            log_error "Cannot install mise. Please install manually:"
            log_error "  https://mise.jdx.dev/getting-started.html"
            return 1
        fi
    fi

    # Add mise to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    # Verify installation
    if command_exists mise; then
        local mise_version
        mise_version="$(mise --version)"
        log_success "mise installed successfully: $mise_version"
    else
        log_error "mise installation verification failed"
        return 1
    fi

    return 0
}

configure_mise_shell_integration() {
    log_step "Configuring mise shell integration..."

    # shellcheck disable=SC2016
    local mise_activate_bash='eval "$(~/.local/bin/mise activate bash)"'
    # shellcheck disable=SC2016
    local mise_activate_zsh='eval "$(~/.local/bin/mise activate zsh)"'

    # Add PATH for mise
    # shellcheck disable=SC2016
    local mise_path='export PATH="$HOME/.local/bin:$PATH"'

    # Configure bash
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "mise activate" "$HOME/.bashrc"; then
            {
                echo ""
                echo "# mise - polyglot version manager"
                echo "$mise_path"
                echo "$mise_activate_bash"
            } >> "$HOME/.bashrc"
            log_success "Added mise to ~/.bashrc"
        else
            log_info "mise already configured in ~/.bashrc"
        fi
    fi

    # Configure zsh
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "mise activate" "$HOME/.zshrc"; then
            {
                echo ""
                echo "# mise - polyglot version manager"
                echo "$mise_path"
                echo "$mise_activate_zsh"
            } >> "$HOME/.zshrc"
            log_success "Added mise to ~/.zshrc"
        else
            log_info "mise already configured in ~/.zshrc"
        fi
    fi

    # Activate mise for current session
    export PATH="$HOME/.local/bin:$PATH"
    if [[ -n "${BASH_VERSION:-}" ]]; then
        eval "$(mise activate bash)" 2>/dev/null || true
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        eval "$(mise activate zsh)" 2>/dev/null || true
    fi

    log_success "mise shell integration configured"
    return 0
}

setup_mise_config() {
    log_step "Setting up mise configuration..."

    local dotfiles_dir
    dotfiles_dir="$(get_dotfiles_dir)"

    # Note: mise config symlink is created by install/symlinks.sh
    # Here we just trust the config and install tools

    local mise_config_dir="${HOME}/.config/mise"
    local mise_config="${mise_config_dir}/config.toml"

    if [[ -f "$mise_config" ]]; then
        log_info "Using global mise config: $mise_config"

        # Trust mise config files to avoid "not trusted" errors
        mise trust "${mise_config}" 2>/dev/null || true
        if [[ -f "${dotfiles_dir}/.mise.toml" ]]; then
            mise trust "${dotfiles_dir}/.mise.toml" 2>/dev/null || true
        fi
        log_success "Trusted mise config files"
    else
        log_warning "Global mise config not found at: $mise_config"
        log_warning "Make sure symlinks are created first (install/symlinks.sh)"
        return 1
    fi

    return 0
}

install_mise_tools() {
    log_step "Installing tools via mise..."

    if ! command_exists mise; then
        log_error "mise not found. Please install it first."
        return 1
    fi

    log_info "Installing tools defined in global config (mise/config.toml)..."
    log_info "This may take 10-30 minutes depending on your system..."
    log_info ""
    log_info "Categories of tools to be installed:"
    log_info "  • Languages: Ruby, Node, Python, Go, Erlang, Elixir"
    log_info "  • Essential CLI: jq, fzf, ripgrep, bat, neovim, shellcheck"
    log_info "  • Modern Tools: eza, fd, dust, procs, bottom, duf, httpie"
    log_info "  • Git Tools: gh, lazygit, delta, gitleaks, lefthook"
    log_info "  • Dev Utils: direnv, just, watchexec, tokei, hyperfine, grex, glow, yq"
    log_info "  • Go Tools: gopls, golangci-lint"
    log_info "  • Node Tools: typescript, prettier, eslint, pnpm, yarn"
    log_info "  • Ruby Tools: rubocop, solargraph, standardrb, rails"
    log_info "  • Python Tools: black, ruff, mypy, poetry, pipenv, ipython"
    log_info "  • Rust Tools: stylua, cargo-watch"
    log_info ""
    log_info "Total: 50+ development tools"
    log_info ""

    # Install all tools from global config
    # Tools defined in ~/.config/mise/config.toml are automatically available globally
    # No need for explicit `mise use -g` calls - the global config handles this
    # mise install reads from global config by default
    if mise install; then
        log_success "All mise tools installed successfully"
        log_info "Tools are configured globally via ~/.config/mise/config.toml"
        log_info "They will be available after shell restart"
    else
        log_warning "Some mise tools failed to install"
        log_info "Check the output above for errors. Common issues:"
        log_info "  • Network timeouts - retry with: mise install"
        log_info "  • Compilation errors - check system dependencies"
        log_info "  • Missing compilers - install build tools for your platform"
        log_info ""
        log_info "You can install tools individually later with:"
        log_info "  mise install <tool>@<version>"
        return 1
    fi

    # Show installed tools
    log_step "Installed mise tools:"
    mise list

    # Install lefthook git hooks if lefthook is installed
    if mise list 2>/dev/null | grep -q "lefthook"; then
        log_step "Setting up lefthook git hooks..."
        if lefthook install 2>/dev/null; then
            log_success "✓ Lefthook git hooks installed"
        else
            log_info "  Lefthook hooks will be installed on next shell session"
        fi
    fi

    return 0
}

install_language_runtimes_fallback() {
    log_step "Installing language runtimes (fallback method)..."

    local failed_tools=()

    # Ruby
    log_info "Checking Ruby..."
    if ! mise list ruby 2>/dev/null | grep -q "ruby"; then
        log_info "Installing Ruby..."
        if mise install ruby@latest && mise use -g ruby@latest; then
            log_success "✓ Ruby installed"
        else
            log_warning "✗ Ruby failed"
            failed_tools+=("ruby")
        fi
    else
        log_info "✓ Ruby already installed"
    fi

    # Node.js
    log_info "Checking Node.js..."
    if ! mise list node 2>/dev/null | grep -q "node"; then
        log_info "Installing Node.js..."
        if mise install node@lts && mise use -g node@lts; then
            log_success "✓ Node.js installed"
        else
            log_warning "✗ Node.js failed"
            failed_tools+=("node")
        fi
    else
        log_info "✓ Node.js already installed"
    fi

    # Python
    log_info "Checking Python..."
    if ! mise list python 2>/dev/null | grep -q "python"; then
        log_info "Installing Python..."
        if mise install python@latest && mise use -g python@latest; then
            log_success "✓ Python installed"
        else
            log_warning "✗ Python failed"
            failed_tools+=("python")
        fi
    else
        log_info "✓ Python already installed"
    fi

    # Go
    log_info "Checking Go..."
    if ! mise list go 2>/dev/null | grep -q "go"; then
        log_info "Installing Go..."
        if mise install go@latest && mise use -g go@latest; then
            log_success "✓ Go installed"
        else
            log_warning "✗ Go failed"
            failed_tools+=("go")
        fi
    else
        log_info "✓ Go already installed"
    fi

    # Erlang (required for Elixir)
    log_info "Checking Erlang..."
    if ! mise list erlang 2>/dev/null | grep -q "erlang"; then
        log_info "Installing Erlang (this takes a while)..."
        if mise install erlang@latest && mise use -g erlang@latest; then
            log_success "✓ Erlang installed"
        else
            log_warning "✗ Erlang failed"
            failed_tools+=("erlang")
        fi
    else
        log_info "✓ Erlang already installed"
    fi

    # Elixir
    log_info "Checking Elixir..."
    if ! mise list elixir 2>/dev/null | grep -q "elixir"; then
        log_info "Installing Elixir..."
        if mise install elixir@latest && mise use -g elixir@latest; then
            log_success "✓ Elixir installed"
        else
            log_warning "✗ Elixir failed"
            failed_tools+=("elixir")
        fi
    else
        log_info "✓ Elixir already installed"
    fi

    if (( ${#failed_tools[@]} > 0 )); then
        log_warning "Some tools failed to install: ${failed_tools[*]}"
        log_info "You can retry manually with:"
        log_info "  mise install <tool>@latest"
        return 1
    fi

    log_success "All language runtimes installed successfully"
    return 0
}

verify_mise_installation() {
    log_step "Verifying mise installation..."

    if ! command_exists mise; then
        log_error "mise verification failed - command not found"
        return 1
    fi

    # Show mise info
    log_info "mise version: $(mise --version)"
    log_info "mise location: $(command -v mise)"

    # Check activated tools
    log_info "Checking available tools..."

    # Get all current tools at once to avoid N+1 queries
    local all_tools
    all_tools=$(mise current 2>/dev/null || echo "")

    # Helper function to check and display tool
    check_tool() {
        local tool=$1
        local version
        version=$(echo "$all_tools" | grep "^${tool} " | awk '{print $2}')
        if [[ -n "$version" ]]; then
            log_success "  ✓ $tool: $version"
        else
            log_info "    $tool: not installed"
        fi
    }

    # Language runtimes
    local lang_tools=("ruby" "node" "python" "go" "erlang" "elixir")
    log_info "Language runtimes:"
    for tool in "${lang_tools[@]}"; do
        check_tool "$tool"
    done

    # Essential CLI tools
    local essential_tools=("jq" "fzf" "ripgrep" "bat" "neovim" "shellcheck")
    log_info "Essential CLI tools:"
    for tool in "${essential_tools[@]}"; do
        check_tool "$tool"
    done

    # Modern tools
    local modern_tools=("eza" "fd" "delta" "gh" "lazygit")
    log_info "Modern tools:"
    for tool in "${modern_tools[@]}"; do
        check_tool "$tool"
    done

    # Show count of installed tools
    local total_tools
    total_tools=$(mise list 2>/dev/null | wc -l)
    log_info ""
    log_info "Total tools installed via mise: $total_tools"

    return 0
}

print_mise_usage() {
    log_step "mise Usage Guide"
    echo ""
    echo "Common mise commands:"
    echo "  mise install              # Install all tools from .mise.toml"
    echo "  mise install <tool>       # Install specific tool"
    echo "  mise install ruby@3.3.0   # Install specific version"
    echo ""
    echo "  mise use <tool>@<version> # Use version in current directory"
    echo "  mise use -g <tool>@<ver>  # Set global version"
    echo ""
    echo "  mise list                 # Show installed tools"
    echo "  mise current              # Show active versions"
    echo "  mise ls-remote <tool>     # Show available versions"
    echo ""
    echo "  mise upgrade              # Upgrade all tools"
    echo "  mise uninstall <tool>     # Remove tool"
    echo ""
    echo "Documentation: https://mise.jdx.dev/"
    echo ""
}

# Main execution if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    require_non_root

    print_header "mise Installation"

    # Install mise
    install_mise || exit 1

    # Configure shell integration
    configure_mise_shell_integration || exit 1

    # Setup mise config
    setup_mise_config || exit 1

    # Ask to install language runtimes
    if confirm "Install language runtimes now? (Ruby, Node, Python, Go, Erlang, Elixir)" "y"; then
        log_info "This will take 10-30 minutes depending on your system"

        if ! install_mise_tools; then
            log_info "Trying fallback installation method..."
            install_language_runtimes_fallback
        fi
    else
        log_info "Skipping language runtime installation"
        log_info "You can install them later with: mise install"
    fi

    # Verify installation
    verify_mise_installation

    # Print usage guide
    print_mise_usage

    log_success "mise setup complete!"
    log_info "Please restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
fi
