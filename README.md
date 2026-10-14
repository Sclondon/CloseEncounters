# Close Encounters

An arcade game for the website. You fly a ship over the American West at night and beam up whatever you can
for points. Everything you take draws **heat**, and the more heat you have, the harder it is to stay alive.
Godot 4.7 (GL Compatibility), exported for the web.

The pilot is the alien from Cryptlins, built the same way (`scripts/alien.gd`, ported from `cryptlin.gd`
`_build_alien`), and a different one every run: its coat and eye lights come from the Cryptlins alien's colours,
and its build, head, eyes and the odd extra (a tuft, a tooth, one small eye, eyes of two colours) are its own.
The world is drawn with Cryptlins' PS1 look (low-res, snapped corners, dither) and curls away over the horizon
like Animal Crossing (`shaders/bend.gdshaderinc`).

## Playing

- **Move**: WASD / arrows / left stick, or drag on the left of the screen.
- **Beam**: hold Space (or J, Z), gamepad A / right trigger, or the BEAM button on a touch screen. The ship slows
  while the beam is on. Things rise slowly (the heavier, the slower) and are taken when they reach the ship.
  Let go early and they fall. Drop something from high enough onto the police or the army and it crushes them.
- **Dodge**: Shift (or X, K), gamepad B / left shoulder, or a quick swipe on a touch screen: a short dash,
  untouchable while it lasts. It drops whatever is in the beam.
- **Pause**: Esc / P / Start.

### Ships

Chosen on the title screen (left / right, or the arrows), and remembered.

| Ship | Speed | Beam | Shield | Flies | Beam strength |
| --- | --- | --- | --- | --- | --- |
| Classic saucer | 12 | x1 | 100 | 8 m | 2: trees and rocks |
| The orb (after the scout ships of *Close Encounters of the Third Kind*) | 9.5 | x1.5, wide | 150 | 10.5 m | 3: buildings |
| Black triangle | 15 | x0.72, narrow | 70 | 6 m | 1: small things only |

### What the beam can take

The beam's strength (its tier) says what it can lift: **1** animals, people, vehicles, bushes, fences, hay,
cacti; **2** trees, rocks, tents; **3** houses, barns, silos, windmills, water towers, diners, adobes,
cabins; **4** the land itself: buttes, mesas, peaks and Devils Tower (up to 5000 points). Over something too
heavy, it says so. Taking a mesa or a peak clears it out of the way.

### Heat

Points are multiplied by the heat: x1 with no stars, up to x6 at five. Heat cools after 5 seconds without taking
anything; the shield mends only with no stars.

| Heat | Who comes |
| --- | --- |
| 1 star | Farmers and cowboys draw; a police car |
| 2 | Three police cars, and the traders flee |
| 3 | Police and army jeeps with machine guns |
| 4 | A tank as well |
| 5 | Two tanks, and jets fly over firing missiles |

**Patrols** rove about whatever the heat: police cars and army jeeps sweeping searchlights over the sky (more
of them the longer you last). Fly into a beam and you are **spotted**: the heat jumps and keeps rising while
it holds you. Once there is heat, the patrols lock their lights on and join in.

### Traders

Saucers parked out in the country, each with its owner standing by (another alien, with a name). Bring the ship
over the glowing pad with **no heat** and the game pauses to trade upgrades **for score**: ENGINE (+12% speed),
BEAM (lifts faster, and one tier stronger), SHIELD (+25), each up to four times, dearer each time, and a patch
for the shield at a point a point. At one star they won't deal; at two they take off. Upgrades last the run.

When the shield is gone the ship comes down and the game is over. The score goes to the arcade page
(`PLAYER_DIED`); the best score and the ship are kept in `user://best.cfg`.

## The world

Endless, made in 48 m chunks round the ship as it flies (`scripts/world.gd`) and dropped behind it; the same
place is always the same. Five regions, several chunks across, blended at their edges on the ground:

- **Farm**: Colorado farm country (where it starts): fields, farmsteads, pens of cows, pigs, sheep, chickens.
- **Plains**: the Wyoming high plains: golden grass, sagebrush, bison, ranches with horses and cowboys,
  windmills, oil pumpjacks, buttes, and **Devils Tower** (always one just north of the start).
- **Desert**: Arizona: red sand, saguaros, prickly pear, red rock, mesas and buttes, coyotes, RVs.
- **Mesa**: New Mexico: ochre earth, pinyon, adobe villages with water towers, longhorns.
- **Mountain**: the Colorado Rockies: snow-capped peaks, pines, aspens gone gold, log cabins, campers.

Highways cross every 240 m, with a town at each crossing. Landforms are planned per chunk before anything else
(`World.landforms`), so nothing is ever put down on top of one, and buildings stay inside their own chunk.
Anything between the camera and the ship is drawn see-through (`shaders/ps1.gdshader`).

## Layout

- `scripts/main.gd`: the game: modes, heat, forces, patrols and spotting, traders and upgrades, ship choice,
  scenery pulled up by the beam, the autopilot (behind the title and in tests), effects, camera, HUD, touch.
- `scripts/ufo.gd` (the ships, `SHIPS`), `alien.gd` (the pilot), `thing.gd` (everything that can be taken:
  `KINDS` holds points, weight, heat, tier, how it moves, its gun, its searchlight), `shop.gd` (a trader),
  `shot.gd`, `world.gd`, `sfx.gd` (synthesised sounds), `ps1.gd` (materials, and the Blender models in them).
- `shaders/`: `bend.gdshaderinc` (the bend and PS1 snap), `ps1` (with the see-through), `ps1_flat`, `glass`,
  `beam` (the tractor beam and the searchlights), `ground` (each region, the roads), `sky`, `screen`.

## Models

Every model except the aliens is built in Blender by `tools/build_models.py`, which saves `art/models.blend`
(all of them in a row, to open and edit) and `models/<name>.glb`:

    "C:/Program Files/Blender Foundation/Blender 4.3/blender.exe" -b --factory-startup --python tools/build_models.py
    godot --headless --path . --import      (run it again if any .glb has no .import yet)

Only material colours matter: the game swaps each material for a PS1 one of the same colour. `shirt`, `walls`
and `paint` are recoloured per copy. Models face -Y in Blender (+Z in Godot) and stand on their origin. Child
objects the game moves: the tank's `turret`, the windmill's `fan`, the pumpjack's `beam`, and every ship's `dome`.

## Tests and build

    godot --headless --path . --fixed-fps 60 -s res://tests/smoke.gd      # heat, forces, patrols, dodge, crash
    godot --headless --path . --fixed-fps 60 -s res://tests/travel.gd     # the endless world
    godot --headless --path . --fixed-fps 60 -s res://tests/upgrades.gd   # traders, tiers, a tree, a mesa
    godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/<shots|regions|look>.gd -- <out dir>
    godot --path . --resolution 1280x720 -s res://tests/aliens.gd -- <out.png>
    godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie <out.avi> -s res://tests/preview.gd
    godot --headless --path . --export-release "Web" build/index.html

(`godot` is `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`.)
