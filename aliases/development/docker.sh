# Docker aliases
alias d='docker'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias drmi='docker rmi'
alias drm='docker rm'
alias dstop='docker stop $(docker ps -q)'
alias dkill='docker kill $(docker ps -q)'

# Docker Compose aliases
alias dc='docker-compose'
alias dcup='docker-compose up'
alias dcdown='docker-compose down'
alias dcbuild='docker-compose build'
alias dclogs='docker-compose logs'
alias dcps='docker-compose ps'
