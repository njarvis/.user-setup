#!/bin/sh

if [ -e /usr/share/zoneinfo/US ]; then
    CA_TIME=`TZ=US/Pacific date +"CA: %H:%M"`
    NH_TIME=`TZ=US/Eastern date +"NH: %H:%M"`
else
    CA_TIME=`TZ=America/Los_Angeles date +"CA: %H:%M"`
    NH_TIME=`TZ=America/New_York date +"NH: %H:%M"`
fi

DUB_TIME=`TZ=Europe/Dublin date +"DUB: %H:%M"`
BANGALORE_TIME=`TZ=Asia/Kolkata date +"BLR: %H:%M"`

echo "$CA_TIME $NH_TIME $DUB_TIME $BANGALORE_TIME"
