#!/usr/bin/env bash
# Development helper functions

# Quick project navigation
# Usage: proj <project-name>
proj() {
    local projects_dir="${PROJECTS:-$HOME/projects}"
    if [[ -z "$1" ]]; then
        cd "$projects_dir" || return 1
    else
        cd "$projects_dir/$1" || return 1
    fi
}

# List all projects
# Usage: projls
projls() {
    local projects_dir="${PROJECTS:-$HOME/projects}"
    if [[ -d "$projects_dir" ]]; then
        ls -1 "$projects_dir"
    else
        echo "Projects directory not found: $projects_dir"
        return 1
    fi
}

# Create new project directory and initialize git
# Usage: projnew <project-name>
projnew() {
    if [[ -z "$1" ]]; then
        echo "Usage: projnew <project-name>"
        return 1
    fi

    local projects_dir="${PROJECTS:-$HOME/projects}"
    local project_path="$projects_dir/$1"

    if [[ -d "$project_path" ]]; then
        echo "Project already exists: $project_path"
        return 1
    fi

    mkdir -p "$project_path"
    cd "$project_path" || return 1
    git init
    echo "# $1" > README.md
    echo "Created new project: $project_path"
}

# Quick search in code (ripgrep with context)
# Usage: search <pattern> [path]
search() {
    if [[ -z "$1" ]]; then
        echo "Usage: search <pattern> [path]"
        return 1
    fi

    if command -v rg &> /dev/null; then
        rg --context 3 --color always "$@" | less -R
    else
        grep -r --context=3 --color=always "$@" | less -R
    fi
}

# Count lines of code in current directory
# Usage: loc [path]
loc() {
    if command -v tokei &> /dev/null; then
        tokei "$@"
    else
        echo "tokei not installed. Install with: mise install tokei@latest"
        return 1
    fi
}

# Watch files and run command
# Usage: watch-run "make test" [path]
watch-run() {
    if [[ -z "$1" ]]; then
        echo "Usage: watch-run <command> [path]"
        return 1
    fi

    if command -v watchexec &> /dev/null; then
        watchexec --clear "$@"
    else
        echo "watchexec not installed. Install with: mise install watchexec@latest"
        return 1
    fi
}

# Benchmark a command
# Usage: bench "command to benchmark"
bench() {
    if [[ -z "$1" ]]; then
        echo "Usage: bench <command>"
        return 1
    fi

    if command -v hyperfine &> /dev/null; then
        hyperfine "$@"
    else
        echo "hyperfine not installed. Install with: mise install hyperfine@latest"
        return 1
    fi
}

# Generate regex from examples
# Usage: genregex "example1" "example2" ...
genregex() {
    if [[ -z "$1" ]]; then
        echo "Usage: genregex <example1> [example2] ..."
        echo "Example: genregex 'hello' 'world' 'test'"
        return 1
    fi

    if command -v grex &> /dev/null; then
        grex "$@"
    else
        echo "grex not installed. Install with: mise install grex@latest"
        return 1
    fi
}

# Preview markdown files
# Usage: mdpreview [file.md]
mdpreview() {
    if command -v glow &> /dev/null; then
        if [[ -z "$1" ]]; then
            glow README.md 2>/dev/null || glow .
        else
            glow "$@"
        fi
    else
        echo "glow not installed. Install with: mise install glow@latest"
        return 1
    fi
}

# Quick HTTP requests with httpie
# Usage: http-get <url>
http-get() {
    if [[ -z "$1" ]]; then
        echo "Usage: http-get <url>"
        return 1
    fi

    if command -v http &> /dev/null; then
        http GET "$@"
    else
        curl -i "$@"
    fi
}

# Check disk usage in current directory (using dust)
# Usage: diskuse [path]
diskuse() {
    if command -v dust &> /dev/null; then
        dust "$@"
    else
        du -h -d 1 "$@" | sort -h
    fi
}

# Better process viewer
# Usage: pss [pattern]
pss() {
    if command -v procs &> /dev/null; then
        procs "$@"
    else
        # shellcheck disable=SC2009
        ps aux | grep -i "${1:-.}"
    fi
}

# Quick file find with preview
# Usage: ff [pattern]
ff() {
    if command -v fd &> /dev/null && command -v fzf &> /dev/null; then
        fd --type f --hidden --follow --exclude .git "${1:-.}" | fzf --preview 'bat --color=always {}'
    else
        find . -type f -name "*${1:-*}*"
    fi
}

# Interactive directory navigation with fzf
# Usage: cdf
cdf() {
    if command -v fd &> /dev/null && command -v fzf &> /dev/null; then
        local dir
        dir=$(fd --type d --hidden --follow --exclude .git | fzf --preview 'ls -la {}')
        if [[ -n "$dir" ]]; then
            cd "$dir" || return 1
        fi
    else
        echo "fd and fzf required. Install with: mise install fd@latest fzf@latest"
        return 1
    fi
}

# Quick git log viewer with fzf
# Usage: fzlog
fzlog() {
    if command -v fzf &> /dev/null; then
        git log --oneline --decorate --color=always | fzf --ansi --preview 'git show --color=always {1}'
    else
        git log --oneline --decorate
    fi
}

# Show all mise-installed tools
# Usage: mise-tools
mise-tools() {
    if command -v mise &> /dev/null; then
        echo "=== Language Runtimes ==="
        mise current ruby node python go erlang elixir 2>/dev/null | grep -v "not installed"
        echo ""
        echo "=== CLI Tools ==="
        mise current jq fzf ripgrep bat neovim shellcheck 2>/dev/null | grep -v "not installed"
        echo ""
        echo "=== Modern Tools ==="
        mise current eza fd delta gh lazygit 2>/dev/null | grep -v "not installed"
        echo ""
        echo "Total tools: $(mise list | wc -l)"
    else
        echo "mise not installed"
        return 1
    fi
}

# Update all mise tools
# Usage: mise-update
mise-update() {
    if command -v mise &> /dev/null; then
        echo "Updating mise itself..."
        mise self-update
        echo ""
        echo "Upgrading all tools..."
        mise upgrade
        echo ""
        echo "Done! Run 'mise-tools' to see current versions."
    else
        echo "mise not installed"
        return 1
    fi
}

# Install a tool globally via mise
# Usage: mise-add <tool>
mise-add() {
    if [[ -z "$1" ]]; then
        echo "Usage: mise-add <tool>"
        echo "Example: mise-add terraform"
        echo ""
        echo "To see available tools: mise registry"
        return 1
    fi

    if command -v mise &> /dev/null; then
        echo "Installing $1 globally..."
        mise install "$1@latest" && mise use -g "$1@latest"
    else
        echo "mise not installed"
        return 1
    fi
}
