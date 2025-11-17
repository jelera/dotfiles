#!/usr/bin/env bash
# Git-related functions

# Show recent git branches (sorted by commit date)
branches() {
    git for-each-ref \
        --sort=-committerdate \
        refs/heads/ \
        --format='%(color:yellow)%(refname:short)%(color:reset) - %(color:green)%(committerdate:relative)%(color:reset) - %(color:blue)%(authorname)%(color:reset)' \
        | head -n 50
}

# Find git co-author by name
coauthor() {
    local name="${*}"

    if [[ -z "$name" ]]; then
        echo "Usage: coauthor <name>"
        echo "Search for git commit authors across all branches."
        return 1
    fi

    if ! command -v git &>/dev/null; then
        echo "Error: git not found"
        return 1
    fi

    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        echo "Error: not in a git repository"
        return 1
    fi

    echo "Searching for authors matching: $name"
    echo ""
    git shortlog --summary --numbered --email --all --regexp-ignore-case --author="$name" | cut -f2-
}

# Delete local branches that have been merged
git-clean-branches() {
    git branch --merged | grep -v "\*" | grep -v "main" | grep -v "master" | xargs -n 1 git branch -d
}

# Fetch and prune, then show status
git-fresh() {
    git fetch --prune && git status
}
