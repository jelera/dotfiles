# FZF configuration
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=dark'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# Preview files with syntax highlighting
if command -v bat > /dev/null; then
  export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
else
  export FZF_CTRL_T_OPTS="--preview 'cat {}'"
fi

# Preview directories with ls
export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
