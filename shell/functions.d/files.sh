#!/usr/bin/env bash
# File and directory functions

# Extract various archive formats
extract() {
    if [[ ! -f "$1" ]]; then
        echo "'$1' is not a file."
        return 1
    fi

    case "$1" in
        *.tar.bz2) tar xjf "$1" ;;
        *.tar.gz) tar xzf "$1" ;;
        *.tar.xz) tar xJf "$1" ;;
        *.tar.Z) tar xzf "$1" ;;
        *.bz2) bunzip2 "$1" ;;
        *.rar) unrar x "$1" ;;
        *.gz) gunzip "$1" ;;
        *.jar) unzip "$1" ;;
        *.tar) tar xf "$1" ;;
        *.tbz2) tar xjf "$1" ;;
        *.tgz) tar xzf "$1" ;;
        *.zip) unzip "$1" ;;
        *.Z) uncompress "$1" ;;
        *.7z) 7z x "$1" ;;
        *) echo "'$1' cannot be extracted." ;;
    esac
}

# Create directory and cd into it
take() {
    mkdir -p "$1" && cd "$1" || return
}

# Alias for take
mkcd() {
    take "$1"
}

# Find and replace in files
find-replace() {
    if [[ $# -ne 3 ]]; then
        echo "Usage: find-replace <directory> <search> <replace>"
        return 1
    fi

    local dir="$1"
    local search="$2"
    local replace="$3"

    if command -v rg &>/dev/null; then
        rg -l "$search" "$dir" | xargs -I {} sed -i.bak "s/$search/$replace/g" {}
    else
        grep -rl "$search" "$dir" | xargs -I {} sed -i.bak "s/$search/$replace/g" {}
    fi

    echo "Replaced '$search' with '$replace' in $dir"
}

# Show disk usage for current directory
duh() {
    du -sh ./* | sort -hr | head -n 20
}

# Create a backup of a file
backup() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    local backup_file
    backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup_file"
    echo "Backup created: $backup_file"
}
