#!/bin/bash
# System information helpers

# Show system information
sysinfo() {
    echo "=== System Information ==="
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Shell: $SHELL"
    echo ""
    echo "=== Development Tools ==="
    command -v node >/dev/null && echo "Node.js: $(node --version)"
    command -v npm >/dev/null && echo "npm: $(npm --version)"
    command -v python >/dev/null && echo "Python: $(python --version 2>&1)"
    command -v go >/dev/null && echo "Go: $(go version | cut -d' ' -f3)"
    command -v rustc >/dev/null && echo "Rust: $(rustc --version | cut -d' ' -f2)"
    command -v ruby >/dev/null && echo "Ruby: $(ruby --version | cut -d' ' -f2)"
    command -v nvim >/dev/null && echo "Neovim: $(nvim --version | head -n1 | cut -d' ' -f2)"
    command -v git >/dev/null && echo "Git: $(git --version | cut -d' ' -f3)"
}

# Show disk usage for development directories
devdisk() {
    echo "=== Development Directory Usage ==="
    if [ -d "$DEV_HOME" ]; then
        du -sh "$DEV_HOME"/* 2>/dev/null | sort -hr
    else
        echo "Development directory not found: $DEV_HOME"
    fi
}

# Show running development services
devservices() {
    echo "=== Development Services ==="

    # Check PostgreSQL
    if command -v psql >/dev/null; then
        if pgrep -f postgres >/dev/null; then
            echo "PostgreSQL: Running"
        else
            echo "PostgreSQL: Stopped"
        fi
    fi

    # Check Docker
    if command -v docker >/dev/null; then
        if docker info >/dev/null 2>&1; then
            echo "Docker: Running"
            echo "  Containers: $(docker ps | wc -l | tr -d ' ') running"
        else
            echo "Docker: Stopped"
        fi
    fi

    # Check Node.js processes
    local node_procs=$(pgrep -f node | wc -l | tr -d ' ')
    if [ "$node_procs" -gt 0 ]; then
        echo "Node.js processes: $node_procs"
    fi

    # Check Ruby processes
    local ruby_procs=$(pgrep -f ruby | wc -l | tr -d ' ')
    if [ "$ruby_procs" -gt 0 ]; then
        echo "Ruby processes: $ruby_procs"
    fi
}
