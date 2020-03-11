# Setup fzf
# ---------
if [[ ! "$PATH" == */home/jelera/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/home/jelera/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/jelera/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/jelera/.fzf/shell/key-bindings.zsh"

bindkey -r '^T'
bindkey -r '^P'
bindkey '^P' fzf-file-widget
