#!/bin/sh
# Şeffaf PNG: render_transparent.sh <svg> <w> <h>
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
svg="$1"; png="${svg%.svg}.png"
win=$(cygpath -w "$svg"); wpng=$(cygpath -w "$png")
timeout 40 "$EDGE" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --default-background-color=00000000 --window-size=$2,$3 --screenshot="$wpng" "file:///${win//\//}" >/dev/null 2>&1
echo "$png"
