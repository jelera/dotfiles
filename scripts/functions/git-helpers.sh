#!/bin/bash
# Git helper functions

# Clone repository to projects directory
gclone() {
    if [ -z "$1" ]; then
        echo "Usage: gclone <repository-url> [directory]"
        return 1
    fi

    local repo_url="$1"
    local target_dir="${2:-$PROJECTS_DIR}"
    local repo_name=$(basename "$repo_url" .git)

    cd "$target_dir"
    git clone "$repo_url"

    if [ -d "$repo_name" ]; then
        cd "$repo_name"
        echo "Cloned and entered: $target_dir/$repo_name"
    fi
}

# Quick commit with message
gquick() {
    if [ -z "$1" ]; then
        echo "Usage: gquick <commit_message>"
        return 1
    fi

    git add .
    git commit -m "$1"
}

# Git status for all projects
gstatus_all() {
    echo "Git status for all projects:"
    find "$PROJECTS_DIR" -name ".git" -type d | while read gitdir; do
        local project_dir=$(dirname "$gitdir")
        local project_name=$(basename "$project_dir")
        echo -e "\n--- $project_name ---"
        cd "$project_dir"
        if ! git status --porcelain | grep -q .; then
            echo "Clean"
        else
            git status --short
        fi
    done
}

# Create and switch to new branch
gnewbranch() {
    if [ -z "$1" ]; then
        echo "Usage: gnewbranch <branch_name>"
        return 1
    fi

    git checkout -b "$1"
}

# List recent branches
branches() {
    git for-each-ref --sort=-committerdate refs/heads/ | head -n 50 | awk -F "\t" 'BEGIN { OFS=FS }; { print substr($1, 1, 7), substr($2, 12) }'
}

coauthor() {
    if [ -z "$1" ]; then
        echo "Usage: coauthor <name>"
        return 1
    fi

    git shortlog --summary --numbered --email --all --regexp-ignore-case --author="$1" | cut -f2-
}
