#!/bin/sh
# Exports the web build to build/, with the game's data under a name of its own contents
# (index-<hash>.pck), so a phone that kept the last one can never start the new page with it.
#   sh tools/export_web.sh
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
"$GODOT" --headless --path . --export-release "Web" build/index.html
rm -f build/index-*.pck
hash=$(md5sum build/index.pck | cut -c1-10)
mv build/index.pck "build/index-$hash.pck"
sed -i "s/const GODOT_CONFIG = {/const GODOT_CONFIG = {\"mainPack\":\"index-$hash.pck\",/; s/\"index.pck\":/\"index-$hash.pck\":/" build/index.html
grep -q "\"mainPack\":\"index-$hash.pck\"" build/index.html
echo "build/index-$hash.pck"
