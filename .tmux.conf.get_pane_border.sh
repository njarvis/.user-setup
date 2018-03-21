#!/bin/sh

TMUX_PANE=$1

if [ -f ~/.local/share/tmux/virtualenv.$TMUX_PANE ]; then
    VIRTUAL_ENV=$(cat ~/.local/share/tmux/virtualenv.$TMUX_PANE)
    echo " #[fg=blue,bright]Virtual Env: #[fg=yellow,bright]${VIRTUAL_ENV} "
else
    echo ""
fi

# echo "#[fg=white,bright] | "
