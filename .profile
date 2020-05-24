# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin(s) if they exists
[[ -d $HOME/bin && ":$PATH:" != *":$HOME/bin:"* ]] && PATH=$HOME/bin:$PATH
[[ -d $HOME/.local/bin && ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH=$HOME/.local/bin:$PATH
[[ -d $HOME/bin/$(uname -m) && ":$PATH:" != *":$HOME/bin/$(uname -m):"* ]] && PATH=$HOME/bin/$(uname -m):$PATH

#test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
