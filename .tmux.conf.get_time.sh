#!/bin/sh
# When entered directly in .tmux.conf via "set -g status-right ...", TZ env var is ignored, so do this in a script.

# Installed in .tmux.conf via:
#  set -g status-right '#(~/bin/get_non_dublin_time.sh)'
#  set -g status-right-length 100

CA_TIME=`TZ=US/Pacific date +"CA: %H:%M"`
NH_TIME=`TZ=US/Eastern date +"NH: %H:%M"`
DUB_TIME=`TZ=Europe/Dublin date +"DUB: %H:%M"`
BANGALORE_TIME=`TZ=Asia/Kolkata date +"BLR: %H:%M"`

echo "$CA_TIME $NH_TIME $DUB_TIME $BANGALORE_TIME"
