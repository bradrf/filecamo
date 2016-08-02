#!/bin/bash

# script to demo operations of filecamo for ttyrec
#
# example:
#   > ttyrec -e 'bash run_demo.sh'
#   > ttygif ttyrecord
#   > mv tty.gif img/usage.gif

function eit()
{
    local cmd="$(printf ' %q' "$@")"
    eval "echo \"> $cmd\";$cmd"
    sleep 3
    printf "\033c" # better than "clear" (the latter just adds new lines)
}

printf '\e[8;30;120t'
printf "\033c"

eit git init files

eit filecamo gen
eit filecamo gen -d files 1 50KiB 20 2 30
git -C files add \.
eit git -C files commit -m 'added 20 initial files'

eit filecamo muck
eit filecamo muck 30 .1 files
eit git --no-pager -C files diff
