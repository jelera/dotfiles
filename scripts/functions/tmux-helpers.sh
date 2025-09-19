# Tmux helper functions

# Create or attach to a tmux session
ta() {
    local session_name="${1:-main}"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux attach-session -t "$session_name"
    else
        tmux new-session -s "$session_name"
    fi
}

# Create a new tmux session for a project
tproject() {
    if [ -z "$1" ]; then
        echo "Usage: tproject <project_name>"
        return 1
    fi

    local project_name="$1"
    local project_dir="$PROJECTS_DIR/$project_name"

    if [ ! -d "$project_dir" ]; then
        echo "Project directory not found: $project_dir"
        return 1
    fi

    tmux new-session -d -s "$project_name" -c "$project_dir"
    tmux split-window -h -p 30 -c "$project_dir"
    tmux split-window -v -p 50 -c "$project_dir"
    tmux select-pane -t 0
    tmux send-keys -t 0 'nvim .' Enter
    tmux attach-session -t "$project_name"
}

# Kill all tmux sessions
tkillall() {
    tmux list-sessions -F '#S' | xargs -I {} tmux kill-session -t {}
    echo "All tmux sessions killed"
}

# List all tmux sessions with details
tlist() {
    if tmux list-sessions >/dev/null 2>&1; then
        tmux list-sessions -F '#S: #{session_windows} windows (created #{session_created_string}) #{?session_attached,(attached),}'
    else
        echo "No tmux sessions found"
    fi
}
