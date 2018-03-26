#!/usr/bin/env bash

canonical_path() {
    TARGET_FILE=$1

    cd `dirname $TARGET_FILE`
    TARGET_FILE=`basename $TARGET_FILE`

    # Iterate down a (possible) chain of symlinks
    while [ -L "$TARGET_FILE" ]
    do
	TARGET_FILE=`readlink $TARGET_FILE`
	cd `dirname $TARGET_FILE`
	TARGET_FILE=`basename $TARGET_FILE`
    done

    # Compute the canonicalized name by finding the physical path
    # for the directory we're in and appending the target file.
    PHYS_DIR=`pwd -P`
    RESULT=$PHYS_DIR/$TARGET_FILE
    echo $RESULT
}

if [ $# -ne 0 ]; then
    dryrun="echo "
else
    dryrun=""
fi

usd=$(canonical_path $(dirname $0))
echo "Installing from $usd"

files=$(cd $usd; find . -path ./.git -prune -o -path ./systemd -prune -o -path ./osx -prune -o \( -type f -a -not -name $(basename $0) -a -not -name README.md -a -not -name SERVER.md -print \))
for f in $files; do
    echo "Installing $f"

    s=$usd/$f
    d=$HOME/$f

    if [ ! -d $(dirname $d) ]; then
	$dryrun mkdir -p $(dirname $d)
    fi
    $dryrun ln -sf $s $d
done
