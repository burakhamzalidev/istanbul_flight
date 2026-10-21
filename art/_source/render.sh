#!/bin/sh
# kullanım: render.sh <svg> <w> <h>
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
svg="$1"; png="${svg%.svg}.png"
win=$(cygpath -w "$svg"); wpng=$(cygpath -w "$png")
"$EDGE" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=$2,$3 --screenshot="$wpng" "file:///${win//\//}" >/dev/null 2>&1
ls -la "$png"
