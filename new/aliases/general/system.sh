# System aliases
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias h='history'
alias j='jobs -l'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowtime='date +"%d-%m-%Y %T"'

# Process management
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias myps='ps -fp $'
