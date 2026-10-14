# Close Encounters

An arcade game for the website. You fly a flying saucer over farm country at night and beam up whatever you
can for points. Everything you take draws **heat**, and the more heat you have, the harder it is to stay
alive. Godot 4.7 (GL Compatibility), exported for the web.

The pilot is the alien from Cryptlins, built the same way (`scripts/alien.gd`, ported from `cryptlin.gd`
`_build_alien`). It sits under the dome, raises its arms while the beam is on, cheers each catch and flinches
when hit. The world is drawn with Cryptlins' PS1 look (low-res, snapped corners, dither) and curls away over
the horizon like Animal Crossing (`shaders/bend.gdshaderinc`).

## Playing

- **Move**: WASD / arrows / left stick, or drag on the left of the screen.
- **Dodge**: Shift (or X, K), gamepad B / left shoulder, or a quick swipe on a touch screen. A short dash the way
  you swipe or steer, untouchable while it lasts, then a moment before the next. It drops whatever is in the beam.
- **Beam**: hold Space (or J, Z), gamepad A / right trigger, or the BEAM button on the right of a touch screen.
  The saucer slows while the beam is on. Things rise slowly (the heavier, the slower) and are taken when they
  reach the saucer. Let go early and they fall. Drop something from high enough onto the police or the army and
  it crushes them.
- **Pause**: Esc / P / Start.

| Thing | Points | Heat |
| --- | --- | --- |
| chicken, hay bale | 10, 15 | a little |
| sheep, pig, scarecrow, cow | 25 to 50 | a little |
| outhouse | 90 | some |
| farmer, townsperson | 100 | a lot |
| tractor, car, pickup | 150 to 180 | a lot |
| police car, army jeep, tank | 300, 400, 800 | the most |

Points are multiplied by the heat: x1 with no stars, up to x6 at five.

| Heat | Who comes |
| --- | --- |
| 1 star | Farmers take up shotguns; a police car |
| 2 | Three police cars |
| 3 | Police and army jeeps with machine guns |
| 4 | A tank as well |
| 5 | Two tanks, and jets fly over firing missiles |

Heat cools after 5 seconds without taking anything. Forces no longer wanted drive off. The shield mends only
when the heat is down to no stars. When the shield is gone the saucer comes down and the game is over. The
score goes to the arcade page (`PLAYER_DIED`), and the best score is kept in `user://best.cfg`.

## Layout

- `scripts/main.gd`: the game: modes (title, play, over), heat, forces, score, autopilot (it flies the saucer
  behind the title and in tests), effects, camera, HUD, touch controls.
- `scripts/ufo.gd` (the saucer and beam), `alien.gd` (the pilot), `thing.gd` (everything on the ground: the
  `KINDS` table holds points, weight, heat, how it moves and what gun it has), `shot.gd` (bullets, shells,
  missiles), `world.gd` (the map: fields, roads, farms, town, army camp, woods), `sfx.gd` (synthesised sounds),
  `ps1.gd` (materials, and the Blender models dressed in them).
- `shaders/`: `bend.gdshaderinc` (the bend and PS1 snap, included by every world shader), `ps1`, `ps1_flat`,
  `glass` (the dome), `beam`, `ground` (the fields, painted from position), `sky`, `screen` (the dither and the
  red flash when hit).

## Models

Every model except the alien is built in Blender by `tools/build_models.py`, which saves `art/models.blend`
(all of them in a row, to open and edit) and `models/<name>.glb`:

    "C:/Program Files/Blender Foundation/Blender 4.3/blender.exe" -b --factory-startup --python tools/build_models.py
    godot --headless --path . --import

Only material colours matter. The game swaps each material for a PS1 one of the same colour. Materials named
`shirt`, `walls` and `paint` are recoloured per copy. Models face -Y in Blender (+Z in Godot) and stand on their
origin.

## Tests and build

    godot --headless --path . --fixed-fps 60 -s res://tests/smoke.gd          # ends PASSED / FAILED
    godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/shots.gd -- <out dir>
    godot --headless --path . --export-release "Web" build/index.html

(`godot` is `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`.)
