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

The title is on the moon: the ship stands parked with its canopy open, and the pilot lounges in a deck chair
floating over the hull beside the cockpit, sipping a cocktail, Earth hanging in the black (`scripts/moon.gd`,
`Ufo.lounge`, `shaders/earth.gdshader`). PLAY and it hops down into the cockpit, the canopy shuts, the ship
lifts off and makes for Earth, and the run starts with it coming down from space. The title has only the
name, the ship, PLAY, and a row of LOG, SCORES and QUIT. On an upright phone the name sits in the sky and
the buttons on the moon. **LOG** is a field guide: every ship, every kind of thing there is to take (with how
many have been taken, ever) and every hunter met, ??? until found (kept in `user://best.cfg`). **SCORES**
and **QUIT** ask the arcade page to show this game's leaderboard or close the game (`OPEN_LEADERBOARD`,
`QUIT_GAME`), so they show only inside it.

The first few frames draw the farm under a black cover, so its shaders are made before the ship arrives,
and while on the moon the world stays loaded round where the run starts (no stutter on the way down).

- **Move**: WASD / arrows / left stick, or a thumb on the left half of a touch screen: a stick comes up under it,
  and the ship goes the way the thumb is then pushed.
- **Beam**: hold Space (or J, Z), gamepad A / right trigger, or a finger held on the right half of a touch screen
  (the beam's mark, which rests in the bottom right corner, comes up under it).
  The beam is on only while held. The ship slows while the beam is on. Things rise slowly (the heavier, the slower) and are taken when they reach the ship.
  Let go early and they fall. Drop something from high enough onto the police or the army and it crushes them.
- **Dodge**: Shift (or X, K), gamepad B / left shoulder, or a quick swipe: a dash that spins the ship like a
  top and leaves afterimages, untouchable while it lasts, then 2.5 s before the next (the DODGE bar). It drops
  whatever is in the beam, and throws the pilot about.
- **Pause**: Esc / P / Start, or the II button in the top right; from there, RESUME or QUIT TO MENU (the run is given up).

The HUD: the score in alien money top left, and under it a log of everything taken, typed out in glowing green.
Top right, beside the pause button, the shield as a glass orb of blue energy, and three pistons that pop up as
the dodge recharges (three lamps on the front of the ship light with them). Below them, a round **radar**: the nearest trader, secret facility, substation and rare
find (on the rim, pointing the way, when out of range), and the police and army about in red. The touch stick
shows only while a thumb is on it.

The pilot works a stick and a panel of buttons in front of it, mashes the buttons while the beam is on, and is
thrown about the cockpit in a dodge. The ship's
lights flash with the beam, a dodge and a hit.

**Only the saucer can be flown at first.** The other five are held in **secret government facilities** out
in the country (fenced compounds, four searchlight towers, a gold beacon over the captured ship): beam the ship
up to make it yours, for good. A facility whose ship has already been found holds one not yet found instead
(`captive` in main.gd). A locked ship says so on the title screen.

### The shield

A bubble round the ship takes the shots, fading as it weakens. **Once it is gone, the next shot is fatal.** It
recharges slowly by itself with no heat, and fast from an **electric substation**: hold the beam over one and
its power runs up the beam into the shield until the station goes dark.

### Ships

Chosen on the title screen (left / right, or the arrows), and remembered.

| Ship | Speed | Beam | Shield | Flies | Beam strength |
| --- | --- | --- | --- | --- | --- |
| SAUCER, the classic | 12 | x1 | 50 | 8 m | 2: trees and rocks |
| ORB (after the scout ships of *Close Encounters of the Third Kind*) | 9.5 | x1.5, wide | 80 | 6 m (low) | 3: buildings |
| TRIANGLE, the black triangle | 15 | x0.6, narrow | 35 | 10.5 m (high) | 1: small things only |
| FOO, a foo fighter (the balls of light pilots saw in the war): tiny, so hard to hit | 16 | x1.3, narrow | 25 | 5 m (lowest) | 1: small things only |
| CIGAR, the cigar-shaped mother ship of the 1950s: huge, so hard to miss | 8.5 | x0.9, widest | 120 | 11 m (highest) | 2: trees and rocks |
| BELL, the bell-shaped scout ship of the 1952 photographs | 10.5 | x0.7 | 40 | 9 m | 4: the land itself |

### What the beam can take

The beam's strength (its tier) says what it can lift: **1** animals, people, vehicles, bushes, fences, hay,
cacti; **2** trees, rocks, tents; **3** houses, barns, silos, windmills, water towers, diners, adobes,
cabins; **4** the land itself: buttes, mesas, peaks and Devils Tower (up to 5000 points). Over something too
heavy, it only rattles. Taking a mesa or a peak clears it out of the way.

**Crop circles**: hold the beam still over a field of crops and a circle presses into it (60 points).
**Rare finds**, each under a shaft of gold light: the golden cow, a jackalope, Bigfoot, a meteorite, a fallen
satellite (900 to 3000 points).

### Heat

Points are multiplied by the heat: x1 with no stars, up to x6 at five. Heat cools after 5 seconds without taking
anything; the shield mends only with no stars.

**It gets harder as the score climbs** (`danger()`, full at 12,000): heat cools later and slower, witnesses
phone sooner, more patrols and more police and army come, they shoot faster, and their shots hit harder.

Searchlights are soft cones, brightest down the middle and fading to their edges (`beam.gdshader`, `soft`).

| Heat | Who comes |
| --- | --- |
| 1 star | Farmers and cowboys draw; a police car |
| 2 | Three police cars, and the traders flee |
| 3 | Police and army jeeps with machine guns |
| 4 | A tank as well |
| 5 | Two tanks, and jets fly over firing missiles |

**Witnesses**: anyone who sees the beam take something starts phoning the police (a red "!"). Take them, or
be gone, within 4 seconds, or the heat jumps a star. **Phone poles** run along every road: take one and calls
within 150 m of it cannot get through.

**Watchers**: radio dishes (in rows, like New Mexico's Very Large Array) and observatories turn to follow the
ship; linger near one for 2 seconds and it gives you away. **Police stations** (in towns) and **army bases**
(a hangar, fighter jets, watchtowers with searchlights) are where the police and army come from. Fighter jets
fly over firing missiles from four stars.

**Patrols** rove about whatever the heat: police cars and army jeeps sweeping searchlights over the sky (more
of them the longer you last). Fly into a beam and you are **spotted**: the heat jumps and keeps rising while
it holds you. Once there is heat, the patrols lock their lights on and join in.

### Traders

Saucers parked out in the country, each with its owner standing by (another alien, with a name). In front of
each stand **three pods** of goods, each tagged with what it is and what it costs (green if it can be had):
ENGINE (+12% speed), BEAM (lifts faster, and one tier stronger), SHIELD (+25), DASH (recharges 0.35 s
faster, two more afterimages), PATCH (the shield filled, a point of score a point), and:

- **LASER** (500): a turret under the hull that fires by itself, a pink bolt every 2 s (0.4 s sooner a level,
  down to 0.8 s) out to 16 m (2 m further a level). It shoots down shells and missiles coming at the ship
  first, then jets, then, once there is heat, the nearest police or army: a hit stuns one (it holds its fire
  for 2 s), and enough hits blow it up (a police car 2, a jeep 3, a tank 5), for half its points and a
  quarter of a star of heat, as a crush is. They are soon replaced, and it never stops the bullets.
- **FLEET** (450): a little saucer for each level (up to four, `scripts/drone.gd`). Each keeps station round
  the ship and goes off by itself after the small things nearby that nobody will miss (animals, hay, bushes:
  nothing heavy, hot, rare or on the road), beaming them up slowly with a beam of its own, for the score and
  the heat as if the ship took them. Shots that meet one stop there, and the police and army sometimes aim
  at one instead of the ship; three hits bring it down, and a new one comes out of the ship 14 s later.

**Beam a pod up to buy it with score**; the trader packs up the other two and leaves. With any heat, or too
little score, a pod only rattles. At two stars the traders take off. Upgrades last the run, each up to four
times, dearer each time (x1.8).
When the shield is gone the ship comes down and the game is over. The score goes to the arcade page
(`PLAYER_DIED`); the best score and the ship are kept in `user://best.cfg`.

## The world

Endless, made in 48 m chunks round the ship as it flies (`scripts/world.gd`) and dropped behind it; the same
place is always the same. Five regions, several chunks across, blended at their edges on the ground:

- **Farm**: Colorado farm country (where it starts): fields, the odd farmstead, pens of cows, pigs, sheep, chickens.
- **Plains**: the Wyoming high plains: golden grass, sagebrush, bison, ranches with horses and cowboys,
  windmills, oil pumpjacks, buttes, and **Devils Tower** (just the one, about a kilometre out, alone in a pine forest away from the roads).
- **Desert**: Arizona: red sand, saguaros, prickly pear, red rock, mesas and buttes, coyotes, RVs.
- **Mesa**: New Mexico: ochre earth, pinyon, adobe villages with water towers, longhorns.
- **Mountain**: the Colorado Rockies: snow-capped peaks, pines, aspens gone gold, log cabins, campers.

Wildlife lives where nobody does: bears, mountain goats and elk in the mountains, pronghorn on the plains,
rabbits and roadrunners in the desert, crows and hawks overhead (hardly any heat). Highways cross every 240 m;
some crossings are towns (a police station, a diner, houses lining the roads out), the rest open country.
Only people and cars are ever put down in a road. Landforms are planned per chunk before anything else
(`World.landforms`), so nothing is ever put down on top of one, and buildings stay inside their own chunk.
Anything between the camera and the ship is drawn see-through (`shaders/ps1.gdshader`).

## Layout

- `scripts/main.gd`: the game: modes, heat, forces, patrols and spotting, traders and upgrades, ship choice,
  scenery pulled up by the beam, the moon title and launch, radar, the autopilot (in tests), effects, camera, HUD, touch.
- `scripts/ufo.gd` (the ships, `SHIPS`), `alien.gd` (the pilot), `thing.gd` (everything that can be taken:
  `KINDS` holds points, weight, heat, tier, how it moves, its gun, its searchlight), `shop.gd` (a trader),
  `drone.gd` (one of the mini fleet), `shot.gd`, `world.gd`, `sfx.gd` (synthesised sounds), `ps1.gd` (materials, and the Blender models in them),
  `moon.gd` (the title's moon, and the lift-off blast), `dust.gd` (dust in space and wind lines), `clouds.gd`, `tornado.gd` (the
  whirl up the beam), `puffs.gd` (smoke and sparks), `broadcast.gd` (a phone booth's aerial: radio waves, or sparks with the lines cut).
- `shaders/`: `bend.gdshaderinc` (the bend and PS1 snap), `ps1` (with the see-through), `ps1_flat`, `glass`,
  `beam` (the tractor beam's two cones and the searchlights), `reticle` (where the beam will fall), `cloud`, `ground`
  (each region, the roads), `sky`, `screen`.

## Music

Three songs made in One Man Band (`C:\Projects\FrontRangeInstituteGames\OneManBand`): Moon Lounge (title, pause),
Night Visitors (flying about) and Tanks! (with heat), crossfaded by `scripts/music.gd`. Their One Man Band songs
are `music/*.omb.json`, written by `tools/songs.gd` (or opened and changed in One Man Band); each is played
into `music/<name>.wav` by One Man Band's renderer:

    godot --headless --path . -s tools/songs.gd
    godot --headless --path <OneManBand> -s res://tools/render_song.gd -- <song.omb.json> <out.wav>

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
    godot --headless --path . --fixed-fps 60 -s res://tests/upgrades.gd   # traders, tiers, a tree, a mesa, the laser, the fleet
    godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/touch.gd   # touch controls, pause, quit
    godot --headless --path . --fixed-fps 60 -s res://tests/unlock.gd     # a secret facility unlocks a ship; every ship flies
    godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/<shots|regions|look|look_more|look_ships>.gd -- <out dir>
    godot --path . --fixed-fps 60 --resolution <390x844|1280x720> -s res://tests/moon_look.gd -- <out dir>   # the title
    godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/launch.gd -- <out dir>     # off the moon, the descent, and home again
    godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/fx_look.gd -- <out dir>    # beam, clouds, phone booths, smoke, windmill
    godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/scale_look.gd -- <out dir>  # one spot drawn at a few world scales
    godot --path . --resolution 390x844 -s res://tests/log_look.gd -- <out dir>    # the title's buttons and the log
    godot --path . --resolution 1280x720 -s res://tests/aliens.gd -- <out.png>
    godot --path . --resolution 1280x720 -s res://tests/perf.gd           # frame time, draw calls, things

Performance: each model is merged into one surface at load (colours on its corners, see `Ps1._merged`), so a
thing is one draw call; nothing is drawn past 115 m (`Ps1.DRAW_TO`); far still things are not ticked and far
movers only every fourth frame; a new chunk's things are put down six a frame (`spawn_later`). About 320 draw
calls a frame, down from 1,100.
    godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie <out.avi> -s res://tests/preview.gd
    sh tools/export_web.sh      # the web build, its .pck named by its contents (phones never keep an old one)

(`godot` is `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`.)
