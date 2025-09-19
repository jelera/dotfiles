# Server utility functions

# Monitor system resources
monitor() {
    watch -n 1 "echo 'Memory:'; free -h; echo; echo 'CPU:'; top -bn1 | head -20; echo; echo 'Disk:'; df -h /"
}

# Check active connections
connections() {
    netstat -nat | awk '{print $6}' | sort | uniq -c | sort -n
}

# Find largest files/directories
find_large() {
    local dir=${1:-.}
    local count=${2:-10}
    find "$dir" -type f -exec du -h {} \; | sort -rh | head -n "$count"
}

# Find files containing text
find_text() {
    local pattern="$1"
    local dir="${2:-.}"

    if command -v rg >/dev/null 2>&1; then
        rg -i "$pattern" "$dir"
    else
        grep -r -i "$pattern" "$dir"
    fi
}

# Backup a file with timestamp
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.$(date +%Y%m%d%H%M%S).bak"
        echo "Backup created: ${file}.$(date +%Y%m%d%H%M%S).bak"
    else
        echo "Error: File $file does not exist"
        return 1
    fi
}

# Check for failed SSH login attempts
check_ssh_fails() {
    if [ -f /var/log/auth.log ]; then
        grep "Failed password" /var/log/auth.log | awk '{print $9}' | sort | uniq -c | sort -nr
    elif [ -f /var/log/secure ]; then
        grep "Failed password" /var/log/secure | awk '{print $9}' | sort | uniq -c | sort -nr
    else
        echo "Could not find SSH log files"
        return 1
    fi
}

# Extract various compressed file formats
extract() {
    if [ -z "$1" ]; then
        echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "'$1' - file does not exist"
        return 1
    fi

    case "$1" in
        *.tar.bz2)   tar xjf "$1"    ;;
        *.tar.gz)    tar xzf "$1"    ;;
        *.tar.xz)    tar xJf "$1"    ;;
        *.bz2)       bunzip2 "$1"    ;;
        *.rar)       unrar x "$1"    ;;
        *.gz)        gunzip "$1"     ;;
        *.tar)       tar xf "$1"     ;;
        *.tbz2)      tar xjf "$1"    ;;
        *.tgz)       tar xzf "$1"    ;;
        *.zip)       unzip "$1"      ;;
        *.Z)         uncompress "$1" ;;
        *.7z)        7z x "$1"       ;;
        *.xz)        unxz "$1"       ;;
        *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
}

# Create a simple HTTP server
serve() {
    local port="${1:-8000}"
    if command -v python3 >/dev/null 2>&1; then
        python3 -m http.server "$port"
    elif command -v python >/dev/null 2>&1; then
        python -m SimpleHTTPServer "$port"
    else
        echo "Python not found. Cannot start HTTP server."
        return 1
    fi
}

# Start a tmux session with a nice layout for server work
tm() {
    local session="${1:-server}"

    if ! command -v tmux >/dev/null 2>&1; then
        echo "tmux is not installed"
        return 1
    fi

    if tmux has-session -t "$session" 2>/dev/null; then
        tmux attach -t "$session"
        return
    fi

    # Create a new session with system monitoring in the top pane
    tmux new-session -d -s "$session" -n "monitor" "top"
    tmux split-window -v -t "$session:0" -p 70
    tmux send-keys -t "$session:0.1" "cd ~" C-m
    tmux send-keys -t "$session:0.1" "clear" C-m

    # Create a second window for work
    tmux new-window -t "$session:1" -n "work"
    tmux send-keys -t "$session:1" "cd ~" C-m
    tmux send-keys -t "$session:1" "clear" C-m

    # Create a third window for logs
    tmux new-window -t "$session:2" -n "logs"
    tmux send-keys -t "$session:2" "cd /var/log" C-m
    tmux send-keys -t "$session:2" "clear" C-m

    # Switch to the first window and attach to the session
    tmux select-window -t "$session:0"
    tmux attach-session -t "$session"
}
