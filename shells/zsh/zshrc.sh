# History settings
setopt SHARE_HISTORY             # Share command history between zsh sessions
setopt HIST_IGNORE_DUPS          # Don't save duplicate commands in a row
setopt HIST_IGNORE_ALL_DUPS      # Remove older duplicates when adding to history
setopt HIST_IGNORE_SPACE         # Don't save commands that start with a space
setopt HIST_VERIFY               # Show command with history expansion before execution
setopt APPEND_HISTORY            # Append to history file rather than overwriting
setopt INC_APPEND_HISTORY        # Add commands to history as they're typed, not at shell exit

# Directory navigation
setopt AUTO_CD                   # Change to a directory path without using 'cd'
setopt AUTO_PUSHD                # Make cd push the old directory onto the directory stack
setopt PUSHD_IGNORE_DUPS         # Don't push multiple copies of the same directory onto the stack

# Completion settings
setopt COMPLETE_ALIASES          # Complete aliased commands as their full command
setopt LIST_PACKED               # Use variable column widths for completion list
setopt LIST_ROWS_FIRST           # Fill rows first when showing completion matches

# Error handling
setopt NO_BEEP                   # Disable beeping on errors
setopt CORRECT                   # Try to correct the spelling of commands
setopt RC_QUOTES                 # Allow '' to represent ' in single-quoted strings

# Job control improvements
setopt AUTO_RESUME               # Allow simple commands to resume background jobs
setopt LONG_LIST_JOBS            # List jobs in the long format
setopt NOTIFY                    # Report status of background jobs immediately
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="bira"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    brew
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf-tab
    docker
    docker-compose
    npm
    node
    sudo
)

source $ZSH/oh-my-zsh.sh

# Mise setup
eval "$(~/.local/bin/mise activate zsh)"
