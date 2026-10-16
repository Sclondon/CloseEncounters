#!/bin/sh
# Builds just the named models and renders each from four sides into one picture, to check that
# its parts are laid out right:  sh tools/look_models.sh <out dir> <name> [<name> ...]
# (the pictures are <out dir>/<name>.png: front, back, side and top)
set -e
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 4.3/blender.exe}"
FFMPEG="${FFMPEG:-/c/Projects/scareathon/trailer/node_modules/ffmpeg-static/ffmpeg.exe}"
OUT="$1"; shift
NAMES=$(echo "$@" | tr ' ' ',')
CE_ONLY="$NAMES" "$BLENDER" -b --factory-startup --python tools/build_models.py > /dev/null 2>&1
"$BLENDER" -b --factory-startup --python tools/look_models.py -- "$OUT" "$@" 2>&1 | grep "looked at"
for n in "$@"; do
	"$FFMPEG" -y -loglevel error -i "$OUT/${n}_front.png" -i "$OUT/${n}_back.png" -i "$OUT/${n}_side.png" -i "$OUT/${n}_top.png" \
		-filter_complex "[0][1][2][3]hstack=inputs=4" "$OUT/$n.png"
done
