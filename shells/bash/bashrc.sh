# Bash specific configuration

#----------------------------------------------------------------------------//
# => PROMPT
#----------------------------------------------------------------------------//
PS1="\n\[$bldgrn\]\u@\h\[$txtrst\] \[$txtpur\][\A]\[$txtrst\] [\[$txtgrn\]\w\[$txtrst\]]  \n\[$txtpur\] $\[$txtrst\] "


#----------------------------------------------------------------------------//
# => DEFAULT .BASHRC CONTENTS
#----------------------------------------------------------------------------//
# If not running interactively, don't do anything
[ -z "$PS1" ] && return


# History settings
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s cmdhist

# Check window size after each command
shopt -s checkwinsize

# Correct minor directory spelling errors
shopt -s cdspell

# Set vi Editing Mode
set -o vi

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
