# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# set PATH so it includes user's private bin(s) if they exists
[[ -d $HOME/bin && ":$PATH:" != *":$HOME/bin:"* ]] && PATH=$HOME/bin:$PATH
[[ -d $HOME/.local/bin && ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH=$HOME/.local/bin:$PATH
[[ -d $HOME/bin/$(uname -m) && ":$PATH:" != *":$HOME/bin/$(uname -m):"* ]] && PATH=$HOME/bin/$(uname -m):$PATH

export PATH

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"

