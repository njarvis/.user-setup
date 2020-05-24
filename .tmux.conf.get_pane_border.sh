#!/bin/sh

TMUX_PANE=$1
FMT=""

for f in ~/.local/share/tmux/$(hostname -s)/*.$TMUX_PANE; do
    PART_FMT=$(cat $f)
    if [ -z "$FMT" ]; then
	FMT="$PART_FMT"
    else
	FMT="$FMT——$PART_FMT"
    fi
done

echo $FMT
