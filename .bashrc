# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000
HISTTIMEFORMAT="%d/%m/%y %T%z "

# Persistent history functions
ph_preexec()
{
    export PH_CMD="$1"
    export PH_PWD=$PWD
    export PH_DATE=$(date +"%d/%m/%y %T%z")
    export PH_TS=$(($(date +%s%N)/1000000))
}

ph_precmd()
{
    local PH_RC=$?
    
    if [[ "$PH_CMD" != "$PH_LAST_CMD" ]]
    then
	local PH_ELA=$((($(date +%s%N)/1000000)-$PH_TS))

	printf "%s | host=%-20s | cwd=%-30s | elapsed=%10sms | rc=%3s | %s\n" "$PH_DATE" $(hostname -s) "$PH_PWD" "$PH_ELA" "$PH_RC" "$PH_CMD" >> ~/.persistent_history
	
	export PH_LAST_CMD="$CMD"
	export PH_CMD=""
	export PH_PWD=""
	export PH_DATE=""
	export PH_TS=0
    fi
}

update_tmux_git_status()
{
    if [ ! -z "$TMUX_PANE" ]; then
	$HOME/.bash_lib/update-tmux-git-status
    fi
}

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    [ ! "$ARTOOLS_NOPROMPTMUNGE" == "1" ] && PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    [ ! "$ARTOOLS_NOPROMPTMUNGE" == "1" ] && PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

function iterm2_print_user_vars() {
    if [ -e ${HOME}/.iterm2-no-badge ]; then
	iterm2_set_user_var gitInfo ""
	iterm2_set_user_var gitVersion ""
	iterm2_set_user_var virtualenvInfo ""
	iterm2_set_user_var badge ""	
    else
        gitDir=$(git rev-parse --show-toplevel 2> /dev/null)
        if [ ! -z "$gitDir" -a ! -e "$gitDir/.nobadge" ]; then
    	    gitBranch=$((git branch 2> /dev/null) | grep \* | cut -c3-)
    	    gitRepo=$(basename -s .git $(git remote show -n origin 2> /dev/null | grep Fetch | cut -d: -f2-))
    	    _gitInfo="\n$gitRepo[$gitBranch]"
    	    gitVer=$(git-version 2> /dev/null)
    	    _gitVersion="\n$gitVer"
        else
    	    _gitInfo=""
    	    _gitVersion=""
        fi

        if [ ! -z "$VIRTUAL_ENV" ]; then
    	    _virtualenvInfo="\n($(basename $VIRTUAL_ENV))"
        else
    	    _virtualenvInfo=""
        fi

        iterm2_set_user_var gitInfo $_gitInfo
        #iterm2_set_user_var gitVersion $_gitVersion
        iterm2_set_user_var virtualenvInfo $_virtualenvInfo

	if [ -x a4c-badge.py ]; then
	    eval $(a4c-badge.py)
	fi
    fi
}

EDITOR="emacs -nw"

screen-log() {
    rm -f /tmp/${USER}-screenrc.$$
    cat <<-EOF > /tmp/${USER}-screenrc.$$
logfile $1
EOF
    shift
    screen -c /tmp/${USER}-screenrc.$$ -L $*
}

alias pip-pyshop="pip install git+git://github.com/njarvis/pyshop.git"

# Add PEW bash completion
hash pew 2>/dev/null && source $(dirname $(pew shell_config))/complete.bash

# Add pythonz
[[ -s $HOME/.pythonz/etc/bashrc ]] && source $HOME/.pythonz/etc/bashrc

# Don't enable iterm shell integration inside Emacs or a namesapce DUT
if [ -z "$INSIDE_EMACS" -a -z "$EMACS" -a -z "$NSNAME" -a -z "$TMUX" ]; then
    echo "Enabling iTerm2 shell integration...."
    test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
else
    echo "Not enabling iTerm2 shell integration...."
fi

#
# tmux split-window and run optional command in shell
#
tsw() {
    if [ ! -z "$TMUX_PANE" ]; then
        tmux split-window -dh -c $PWD -t $TMUX_PANE "bash --rcfile <(echo '. ~/.bashrc;$*')"
    else
        echo "Not running tmux"
    fi
}

#
# tmux new-window and run optional command in shell
#
tnw() {
    if [ ! -z "$TMUX_PANE" ]; then
        tmux new-window -d -c $PWD "bash --rcfile <(echo '. ~/.bashrc;$*')"
    else
        echo "Not running tmux"
    fi        
}

if [ ! -z "$VIRTUAL_ENV" -a ! -z "$TMUX_PANE" ]; then
    mkdir -p ~/.local/share/tmux/$(hostname -s)
    echo "#[bg=black,fg=white,bright]#[fg=white]〰$(basename $VIRTUAL_ENV)#[fg=default]" > ~/.local/share/tmux/$(hostname -s)/10-virtualenv.$TMUX_PANE
    tmux refresh-client -S

    trap_exit() {
	rm -f ~/.local/share/tmux/$(hostname -s)/*virtualenv.$TMUX_PANE
	tmux refresh-client -S
    }
    trap trap_exit EXIT
fi

# Pre-cmd/exec functions
source $HOME/.bash_lib/bash-preexec.sh
precmd_functions+=(update_tmux_git_status)
precmd_functions+=(ph_precmd)
preexec_functions+=(ph_preexec)

# Enable fzf https://github.com/junegunn/fzf
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
export FZF_DEFAULT_OPTS='--reverse'
if [ ! -z "$TMUX_PANE" ]; then
    export FZF_TMUX=1
fi

    
