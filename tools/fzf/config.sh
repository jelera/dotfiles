# FZF configuration and functions

# FZF key bindings and fuzzy completion
if [ -f ~/.fzf.bash ]; then
    source ~/.fzf.bash
elif [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
fi

# Enhanced FZF functions
fzf_git_log() {
    git log --oneline --graph --color=always |
    fzf --ansi --no-sort --reverse --tiebreak=index \
        --bind=ctrl-s:toggle-sort \
        --preview 'grep -o "[a-f0-9]\{7\}" <<< {} | xargs git show --color=always' \
        --bind "enter:execute:grep -o '[a-f0-9]\{7\}' <<< {} | xargs git show"
}

fzf_git_branch() {
    git branch -a |
    grep -v HEAD |
    sed 's/.* //' | sed 's#remotes/[^/]*/##' |
    sort -u |
    fzf --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed s/\*// <<< {} | cut -c3-) | head -20'
}

# File and directory navigation
fzf_cd() {
    local dir
    dir=$(fd --type d . ${1:-.} 2>/dev/null | fzf +m) && cd "$dir"
}

fzf_edit() {
    local file
    file=$(fd --type f . ${1:-.} 2>/dev/null | fzf +m) && ${EDITOR:-nvim} "$file"
}

# Process management
fzf_kill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')

    if [ "x$pid" != "x" ]; then
        echo $pid | xargs kill -${1:-9}
    fi
}

# Docker container selection
fzf_docker_exec() {
    local container
    container=$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | fzf | awk '{print $1}')

    if [ -n "$container" ]; then
        docker exec -it "$container" ${1:-/bin/bash}
    fi
}

# Bind FZF functions to keys (works in both bash and zsh)
if [ -n "$ZSH_VERSION" ]; then
    # Zsh key bindings
    bindkey -s '^g^l' 'fzf_git_log\n'
    bindkey -s '^g^b' 'fzf_git_branch\n'
    bindkey -s '^f^d' 'fzf_cd\n'
    bindkey -s '^f^e' 'fzf_edit\n'
elif [ -n "$BASH_VERSION" ]; then
    # Bash key bindings
    bind -x '"\C-g\C-l": fzf_git_log'
    bind -x '"\C-g\C-b": fzf_git_branch'
    bind -x '"\C-f\C-d": fzf_cd'
    bind -x '"\C-f\C-e": fzf_edit'
fi

# Aliases for FZF functions
alias fgl='fzf_git_log'
alias fgb='fzf_git_branch'
alias fcd='fzf_cd'
