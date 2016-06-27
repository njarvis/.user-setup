#!/bin/bash

if [ $# -ne 0 ]; then
    dryrun="echo "
else
    dryrun=""
fi

usd=$(readlink -m $(dirname $0))
files=$(cd $usd; find . -path ./.git -prune -o \( -type f -a -not -name $(basename $0) -print \))
for f in $files; do
    echo "Installing $f"

    s=$usd/$f
    d=$HOME/$f

    if [ ! -d $(dirname $d) ]; then
	$dryrun mkdir -p $(dirname $d)
    fi
    $dryrun ln -sf $s $d
done
