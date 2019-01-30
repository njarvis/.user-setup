#!/bin/sh

if [ -e /proc/loadavg ]; then
    cat /proc/loadavg | cut -d " " -f 1-4
else
    uptime | tr -d , | cut -d: -f4 | cut -d' ' -f2-
fi

