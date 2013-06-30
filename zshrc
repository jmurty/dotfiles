ZSH=$HOME/.oh-my-zsh

ZSH_CUSTOM=$HOME/.zsh

# Theme to load. Looks in $ZSH_CUSTOM/themes, $ZSH_CUSTOM, $ZSH/themes/
ZSH_THEME="jmurty"  # Suffix .zsh-theme is assumed

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable bi-weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment to change how often before auto-updates occur? (in days)
# export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want to disable command autocorrection
DISABLE_CORRECTION="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(history-substring-search autojump battery brew pip python vagrant virtualenv tmux tmuxinator)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...

# Auto-export new env variables
setopt allexport

# History
HISTFILE=$HOME/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
# History search key bindings handled by history-substring-search plugin

EDITOR=vim

# Include homebrew builds in path
PATH=/usr/local/bin:$PATH

# Include python installs in brew location
PATH=/usr/local/share/python:/usr/local/share/python3:$PATH

#########
# Aliases
#########

# scp resume - http://panela.blog-city.com/resume_scp_after_interrupted_downloads_use_rsync.htm
alias scpresume="rsync --partial --progress --rsh=ssh"

# ag: silver searcher
alias ag="ag --pager=less"

#######
# Tools
#######

# Pip config
PIP_RESPECT_VIRTUALENV=true
PIP_DOWNLOAD_CACHE=$HOME/.pip_download_cache
if [ ! -d $PIP_DOWNLOAD_CACHE ]
then
    mkdir $PIP_DOWNLOAD_CACHE
fi

# Tmuxinator
[[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator

#############
# Virtualenvs
#############

WORKON_HOME=~/Documents/code/virtualenvs
source /usr/local/bin/virtualenvwrapper.sh

#########
# Vagrant
#########
VAGRANT_DEFAULT_PROVIDER=vmware_fusion

### Added by the Heroku Toolbelt
PATH="/usr/local/heroku/bin:$PATH"
