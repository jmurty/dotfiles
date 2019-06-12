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
plugins=(git autojump battery brew pip python vagrant virtualenv tmux tmuxinator)

# Include homebrew builds in path
PATH=/usr/local/bin:/usr/local/sbin:$PATH

source $ZSH/oh-my-zsh.sh

# Customize to your needs...

# Auto-export new env variables
# Disabled for now because it segfaults the session when you paste into it
#setopt allexport

# Avoid constant command failures with error "zsh: no matches found"
unsetopt nomatch

# History
HISTFILE=$HOME/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
# History search key bindings handled by history-substring-search plugin

EDITOR=nvim

##############
# Key bindings
##############

# Option-left/right for backward/forward a word
bindkey "\e\eOD" backward-word
bindkey "\e\eOC" forward-word

#########
# Aliases
#########

# zmv
autoload zmv
alias zcp='zmv -C'

# scp resume - http://panela.blog-city.com/resume_scp_after_interrupted_downloads_use_rsync.htm
alias scpresume="rsync --partial --progress --rsh=ssh"

# ag: silver searcher
alias ag="ag --pager=less"

# Cleanup python bytecode files
alias pycclean="find . -name '*.pyc' -exec rm {} +"

# Cleanup vim swap files
alias vimclean="find . -name '*.sw[p0]' -exec rm {} +"

# Run ctags in Python virtualenv project
alias ctags-virtualenv='ack --python --ignore-dir=locale -f . $VIRTUAL_ENV | ctags -L -'

# Run Ant
alias ant=~/Documents/code/java/apache-ant-1.9.2/bin/ant

# Run Maven
alias mvn=~/Documents/code/java/apache-maven-3.2.1/bin/mvn

# Run Markdown
alias markdown=~/Documents/code/Markdown.pl

# git status for all repos in a Python virtualenv environment
alias gitstat-venv='pwd; git status --short; for repo in $(find $VIRTUAL_ENV -type d -name .git); do pushd > /dev/null; echo; echo `dirname $repo`; cd `dirname $repo`; git status --short; popd > /dev/null; done'

git_status() {
    DIR=${1:-$VIRTUAL_ENV}
    for repo in $(find "$DIR" -type d -name .git); do
        pushd > /dev/null;
        cd "$repo/.."
        STATUS=$(git status --short)
        if [[ -n "$STATUS" ]]; then
            echo
            echo "$PWD"
            git status --short
        fi
        popd > /dev/null
    done
}

#######
# Tools
#######

# Force Python UTF-8 (if LC_CTYPE doesn't work)
#PYTHONIOENCODING=utf-8

# Pip config
PIP_RESPECT_VIRTUALENV=true
# IC devpi PyPI mirro
#PIP_INDEX_URL=https://ic:reck-rac-yok-tev-gog-bim-zoy@devpi.ixcsandbox.com/ic/dev/+simple/
#PIP_DOWNLOAD_CACHE=$HOME/.pip_download_cache
#if [ ! -d $PIP_DOWNLOAD_CACHE ]
#then
#    mkdir $PIP_DOWNLOAD_CACHE
#fi

# Tmuxinator
#[[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator

# Pyenv
if which pyenv > /dev/null; then eval "$(pyenv init -)"; fi

#############
# Virtualenvs
#############

WORKON_HOME=~/Documents/code/virtualenvs
source /usr/local/bin/virtualenvwrapper.sh

#########
# Vagrant
#########
#VAGRANT_DEFAULT_PROVIDER=vmware_fusion

### Added by the Heroku Toolbelt
#PATH="/usr/local/heroku/bin:$PATH"

# Overide Apple Java JDK
JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_05.jdk/Contents/Home

########
# golang
########

PATH=$PATH:/usr/local/opt/go/libexec/bin

# AWS CLI
PATH=$PATH:~/Library/Python/2.7/bin

###################
# Docker via Dinghy
###################
#eval $(dinghy env)

#test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

alias vim='echo "Use NeoVim!"'

################
# PostgreSQL App
################
PATH=$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin/
