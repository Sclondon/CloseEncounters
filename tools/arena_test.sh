#!/bin/sh
# The ARENA, end to end: a local relay running the site's own route, and two copies of the game in it.
#   sh tools/arena_test.sh <path to scareathon-v3/server, with node_modules> [shots dir]
# (with a shots dir the two copies run in windows and save pictures along the way)
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
SERVER_DIR="$1"
SHOTS="$2"
PORT=3113
node tools/dev_relay.mjs "$SERVER_DIR" $PORT &
RELAY=$!
trap 'kill $RELAY 2>/dev/null' EXIT
sleep 2
HEADLESS="--headless"
EXTRA=""
if [ -n "$SHOTS" ]; then
	HEADLESS="--resolution ${RES:-390x844}"
	EXTRA="--shots=$SHOTS"
fi
LOG=$(mktemp)
"$GODOT" $HEADLESS --path . -s res://tests/arena_test.gd -- --role=a --server=http://127.0.0.1:$PORT $EXTRA > "$LOG" 2>&1 &
A=$!
sleep 1
"$GODOT" $HEADLESS --path . -s res://tests/arena_test.gd -- --role=b --server=http://127.0.0.1:$PORT $EXTRA 2>&1 | grep -E '^\[b\]|SCRIPT ERROR' || true
wait $A || true
grep -E '^\[a\]|SCRIPT ERROR' "$LOG"
