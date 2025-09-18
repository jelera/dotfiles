# ZSH specific configuration
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf-tab
    docker
    docker-compose
    npm
    node
)

# Set ZSH theme
ZSH_THEME="robbyrussell"

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# Completion settings
setopt COMPLETE_ALIASES
setopt LIST_PACKED
setopt LIST_ROWS_FIRST
