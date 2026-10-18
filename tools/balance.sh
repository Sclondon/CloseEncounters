#!/bin/sh
# Every ship flown by the autopilot over the same country for the same time (tests/balance.gd),
# four at a time; prints a table of score, things taken and seconds alive, best first.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
OUT="${TMPDIR:-/tmp}/ce_balance"
rm -rf "$OUT"; mkdir -p "$OUT"
SHIPS="${SHIPS:-saucer orb triangle foo cigar bell tictac saturn diamond jelly tug frigate trek meteor carnival}"
for seed in ${SEEDS:-4242}; do
for s in $SHIPS; do
	"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/balance.gd -- --ship=$s --seed=$seed $EXTRA 2>/dev/null | grep "^BALANCE" > "$OUT/$s-$seed.txt" &
	while [ "$(jobs -r | wc -l)" -ge 4 ]; do sleep 1; done
done
done
wait
cat "$OUT"/*.txt | sort -k3 -n -r
