#!/bin/bash
# A shell version of build.c

bootsect=$1
setup=$2
system=$3
image=$4
rootdev=$5

SYS_SIZE=$((0x3000*16))

if [ -z "$rootdev" ]; then
    # First partition of first hard disk
    DEFAULT_MAJOR_ROOT=3
    DEFAULT_MINOR_ROOT=1
else
    DEFAULT_MAJOR_ROOT=${rootdev:0:2}
    DEFAULT_MINOR_ROOT=${rootdev:2:3}
fi

if [ ! -f "$bootsect" -o ! -f "$setup" -o ! -f "$system" ]; then
    echo "Usage: build.sh bootsect setup system image [rootdev]"
    exit 1
fi

system_size=`wc -c $system | cut -d ' ' -f1`
[[ $system_size -gt $SYS_SIZE ]] && echo "error: system is over-sized" && exit 1

# [ bootsect ] ( 1 sector  )
# [ setup    ] ( 4 sectors )
# [ system   ] ( $SYS_SIZE )

dd if=$bootsect bs=512 count=1 of=$image 1>/dev/null 2>/dev/null
dd if=$setup seek=1 bs=512 count=4 of=$image 1>/dev/null 2>/dev/null
dd if=$system seek=5 bs=512 of=$image 1>/dev/null 2>/dev/null

# Tell boot image the root device id
printf "\x$DEFAULT_MINOR_ROOT\x$DEFAULT_MAJOR_ROOT" | \
    dd ibs=1 obs=1 count=2 seek=508 of=$image conv=notrunc 1>/dev/null 2>/dev/null
