#!/bin/sh
# Records the drive-in's film (tests/drive_in_film.gd) and packs its last 80 frames into one
# flipbook texture, 8 across and 10 down, for shaders/film.gdshader: textures/drive_in_film.png
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
FFMPEG="${FFMPEG:-/c/Projects/scareathon/trailer/node_modules/ffmpeg-static/ffmpeg.exe}"
TMP="${TMPDIR:-/tmp}/ce_film"
rm -rf "$TMP"; mkdir -p "$TMP" textures
"$GODOT" --path . --fixed-fps 15 --resolution 384x216 --write-movie "$TMP/f.png" -s res://tests/drive_in_film.gd > /dev/null 2>&1 || true
N=$(ls "$TMP"/f*.png | wc -l)
START=$((N - 80))
"$FFMPEG" -y -loglevel error -start_number $START -i "$TMP/f%08d.png" -frames:v 80 -vf "scale=156:88,pad=192:88:18:0:black,tile=8x10" textures/drive_in_film.png
echo "film: $N frames recorded, textures/drive_in_film.png"
