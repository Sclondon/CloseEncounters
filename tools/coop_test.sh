#!/bin/sh
# Multiplayer, end to end: a local relay running the site's own route, a host and a guest.
#   sh tools/coop_test.sh <path to scareathon-v3/server, with node_modules>
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
SERVER_DIR="$1"
PORT=3112
node tools/dev_relay.mjs "$SERVER_DIR" $PORT &
RELAY=$!
trap 'kill $RELAY 2>/dev/null' EXIT
sleep 2
LOG=$(mktemp)
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/coop_test.gd -- --role=host --server=http://127.0.0.1:$PORT > "$LOG" 2>&1 &
HOST=$!
CODE=""
for i in $(seq 1 60); do
	CODE=$(grep -o '^\[room\] [A-Z0-9]*' "$LOG" | head -1 | cut -d' ' -f2)
	[ -n "$CODE" ] && break
	sleep 0.5
done
echo "room $CODE"
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/coop_test.gd -- --role=join --room=$CODE --server=http://127.0.0.1:$PORT 2>&1 | grep '^\[join\]'
wait $HOST || true
grep '^\[host\]' "$LOG"
