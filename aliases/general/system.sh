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
alias psmem='ps aux --sort=-%mem | head'
alias pscpu='ps aux --sort=-%cpu | head'
alias meminfo='free -h'
alias cpuinfo='lscpu'
alias dfall='df -hT'
