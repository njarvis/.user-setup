#!/bin/bash

TMUX_SESSION=$1
TMUX_WINDOW=$2
TMUX_PANE=$3
TMUX_PANE_POS=${4:-all-panes}
FMT=""

function extendFMT {
    local extend="$*"

    if [ ! -z "$extend" ]; then
        if [ -z "$FMT" ]; then
	    FMT="$extend"
        else
	    FMT="$FMT——$extend"
        fi
    fi
    echo -n $FMT
}

for p in ~/.local/share/tmux/$(hostname -s)/*; do
    if [ -f $p ]; then
        f=$(basename $p)
        IFS="." read -ra PARTS <<< "$f"
        case "${PARTS[1]}" in
            map)
                FMT=$(extendFMT $(grep "${TMUX_PANE}:" $p | cut -d: -f2-))
                ;;
            position)
                POSITION=$(sed 's/x/\./g' <<< ${PARTS[2]:-x-x-x-x})
                if [[ ${TMUX_PANE_POS} =~ $POSITION ]]; then
                    FMT=$(extendFMT $(cat $p))
                fi
                ;;
            all-panes)
                FMT=$(extendFMT $(cat $p))
                ;;
            \%[0-9]*)
                if [[ ${TMUX_PANE} == ${PARTS[1]} ]]; then
                    FMT=$(extendFMT $(cat $p))
                fi
                ;;
            \@[0-9]*)
                if [[ ${TMUX_WINDOW} == ${PARTS[1]} ]]; then
                    FMT=$(extendFMT $(cat $p))
                fi
                ;;
            *)
                if [[ ${TMUX_SESSION} == "${PARTS[1]}" ]]; then
                    FMT=$(extendFMT $(cat $p))
                fi
                ;;
        esac
    fi
done

if [[ -z "${FMT}" ]]; then
    FMT="<${TMUX_SESSION}:${TMUX_WINDOW}.%${TMUX_PANE} [$TMUX_PANE_POS]>"
fi
    
echo -n "${FMT}"
