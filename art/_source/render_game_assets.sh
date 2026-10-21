#!/bin/sh
# Tüm oyun asset'lerini şeffaf PNG'ye çevirir: render_game_assets.sh <game_src klasörü>
DIR="$(cd "$1" && pwd)"; HERE="$(cd "$(dirname "$0")" && pwd)"  # mutlak yol: file:/// adresi için şart
while read -r p w h; do
  [ -z "$p" ] && continue
  png="$DIR/${p%.svg}.png"; [ -s "$png" ] && [ "$png" -nt "$DIR/$p" ] && { echo "var $p"; continue; }  # güncel PNG varsa atla
  for i in 1 2 3; do  # Edge bazen headless'ta çöküyor: yeniden dene
    rm -f "$DIR/${p%.svg}.png"
    sh "$HERE/render_transparent.sh" "$DIR/$p" "$w" "$h" >/dev/null 2>&1
    [ -s "$DIR/${p%.svg}.png" ] && break
  done
  [ -s "$DIR/${p%.svg}.png" ] && echo "ok  $p" || echo "HATA $p"
done < "$DIR/render_list.txt"
