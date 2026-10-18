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
the buttons on the moon; now and then a saucer streaks by behind them. **LOG** is a field guide: every ship, every kind of thing there is to take (with how
many have been taken, ever), every hunter met and every item had, each as a little model, ??? until found (kept in `user://best.cfg`). **SCORES**
and **QUIT** ask the arcade page to show this game's leaderboard or close the game (`OPEN_LEADERBOARD`,
`QUIT_GAME`), so they show only inside it.

The first few frames draw the farm under a black cover, so its shaders are made before the ship arrives,
and while on the moon the world stays loaded round where the run starts (no stutter on the way down).

- **Move**: WASD / arrows / left stick, or a thumb on the left half of a touch screen: a stick comes up under it,
  and the ship goes the way the thumb is then pushed.
- **Beam**: hold Space (or J, Z), gamepad A / right trigger, or a finger held on the right half of a touch screen
  (the beam's mark, which rests in the bottom right corner, comes up under it).
  The beam is on only while held. The ship slows while the beam is on. Things rise slowly (the heavier, the slower) and are taken when they reach the ship.
  Let go early and they fall. Drop something from high enough onto the police or the army and it crushes them. A car dropped hard (or thrown, or an oil drum dropped at all) blows up: the police and army near it are destroyed, other cars and drums near it go up after it one by one, buildings, trees and fences round it are damaged (a shed or a tree comes down at once, a house wants two or three blasts), and whatever is loose is thrown back (`explode`, `_blast`; `tests/car_drop.gd`).
- **Fire and aim**: the beam's button fires whichever weapon is aimed by hand (see **Weapons**): the beam itself, the
  LASER RAY, the LIGHTNING GUN, and the gravity sling on the KRAKKATOOM or the star bits on the KRYSTALLIX-9. Drag
  the finger holding the button (or the mouse, held) to push their mark out from under the ship; without a finger,
  aim with T F G H (or the keypad's arrows) or the right stick. With two such weapons, L / Tab / C, gamepad Y, or
  the round button over the beam's mark (it shows the weapon aimed) goes over to the other. A ship with no beam
  takes nothing up: it wrecks things instead.
- **Dodge**: Shift (or X, K), gamepad B / left shoulder, or a quick swipe: a dash that spins the ship like a
  top and leaves afterimages, untouchable while it lasts. It starts with **one charge** (6 s to refill), and each
  DASH item adds another. It drops whatever is in the beam, and throws the pilot about. Dash with no charge and
  the engine fizzles: the ship shudders, smokes and spits sparks.
- **Pause**: Esc / P / Start, or the pause button in the top right; from there, RESUME, OPTIONS or TO THE MOON (the run is given up, and the ship flies home).

**OPTIONS** (a button on the title beside SAUCERS and LOG, or from the pause), kept with the bests in user://best.cfg:
MUSIC and EFFECTS loudness (sliders, each its own audio bus), PICTURE (LOW / MEDIUM / HIGH: 220, 300 or 420
lines), DITHER (the PlayStation dither and 15-bit colour, on or off), SHAKE (screen shake on or off) and FRAMES
(30, 60 or as fast as the screen goes).

**After a crash**: the wreck lies half in the ground in a ring of heaped dirt, burning; the pilot runs for it and
is gunned down. The score and level orb leave the corner and the **RESULTS** (left-justified under a centred heading, typed out; on a wide screen what was destroyed in a column of its own beside the rest; always sized to fit the screen, smaller for a long run, `_fit_results`, `tests/results_look.gd`) give the **threat level** they had reached (LOW, GUARDED, ELEVATED, HIGH or SEVERE), what was **analyzed** (taken) by category, the police
and army **destroyed** by kind (each section's lines indented under it), the total and best, and the **items**
had as their holograms with their counts. TO THE MOON flies home; **REPLAY** flies straight up off the wreck into
the stars and down again onto a new country, the new ship dropping into the picture from above. Watch long enough
and the **men in black** take over: a black car drives up; one agent zips the pilot into a body bag and carries it
off to the car and gets in; their Chinook comes in over the wreck, lowers a cable and flies off with it hanging
underneath; as it goes a second helicopter, a black one, comes in from the other side with a meteorite (a little pale moon, pocked with craters, as the KRAKKATOOM is: `moonlet` in build_models.py) hanging
on its own cable, lets it down into the crater in the wreck's place (a thud, a ring of dust), lets go and flies
off (`_mib_rock`); and only then does the other agent flash the crowd with a memory eraser (they forget and
wander away) and get back in, before they drive off. Once the ship is down the army is done: a few seconds after the crash its jeeps, tanks and trucks drive off and every helicopter flies away, and the police come to the crash site and stay (`_army_away`); after the men in black have gone a police car pulls up, one officer walks round the crater setting posts and stringing POLICE LINE tape between them while the other sets out numbered evidence markers (`_crime_scene`). Everything on the ground keeps to where the ship fell even after the wreck is carried off. `tests/heat_look.gd` (with `mib`) plays it through and
checks both agents are gone with the car.

The menus' buttons are holograms: well rounded, roomy, glowing green, with scanlines, a flicker and a band of light sweeping through them (`shaders/holo_button.gdshader`).

The HUD: down the top left, three glass orbs the same size: the shield (blue energy), the round **radar**, and
the dash (an arrow for each charge, lit once charged, filling as it charges).
The heat's news (the police coming, spotted, a nuke) shows just under the stars. Top right, beside the pause button, the score in alien money and its multiplier,
and under them a log of everything taken, typed out in glowing green. Left of the cash, the **level orb** (the size of the shield's) fills with little hologram balls of what was taken, dropping in, toward the next level-up.
The radar shows the nearest secret facility, substation and rare
find (on the rim, pointing the way, when out of range), and the police and army about in red. The touch stick
shows only while a thumb is on it.

The saucer turns slowly, faster on the move and with the beam on, fastest with both; with the beam on its lights chase round through every colour.

The pilot works a stick and a panel of buttons in front of it, mashes the buttons while the beam is on, and is
thrown about the cockpit in a dodge. The ship's
lights flash with the beam, a dodge and a hit.

At start-up the game comes down out of the stars onto the moon, as it does after a crash, to the title.

**Only the Zeebzer can be flown at first.** The other twelve are held in **secret government facilities** out
in the country (fenced compounds, four searchlight towers, a gold beacon over the captured ship): beam the ship
up to make it yours, for good. A facility whose ship has already been found holds one not yet found instead
(`captive` in main.gd). A locked ship says so on the title screen.

### The shield

A bubble round the ship takes the shots, fading as it weakens. **Once it is gone, the next shot is fatal.** It
recharges slowly by itself with no heat, a little with everything taken (more for heavier things), and fast from an **electric substation**: hold the beam over one and
its power runs up the beam into the shield until the station goes dark.

### Ships

Chosen on the title screen (left / right, or the arrows), and remembered. Balanced with `tools/balance.sh` (2026-10-17): with no upgrades and kept from dying, they average about 99k in 150 s over the same three countries (`SEEDS="4242 1234 777" EXTRA=--immortal`), each with its own weapons (the autopilot fires the hand-aimed ones at the nearest thing it can hurt, the sling at the thickest crowd, and never swaps a weapon). Averages: STARZOID 148k, FIZZWIGGLER 130k, CARNIVORB 124k, TIKTAKKORAX 121k, YESTROMO 121k, XELETRON-22 112k, ZEEBZER 108k, BLOOPUS-7 103k, NEBULONK-B 99k, DINGDONGULUS 96k, GLORBULON 95k, BLORPMOTHER 85k, ENTERBLORPRISE 77k, KRAKKATOOM about 70k to 100k and KRYSTALLIX-9 about 60k (these two retuned after the full run, measured alone). The run-to-run spread is wide, a third or more either way. Scores are scaled by `Thing.WORTH` (2.5) to put the average there: everything scores that many times its listed points, and the level-ups and the danger go by the score over it, so nothing else changes.

| Ship | Weapons | Speed | Beam | Shield | Flies | Beam strength |
| --- | --- | --- | --- | --- | --- | --- |
| ZEEBZER (`saucer`), the classic | beam | 12 | x1 | 50 | 8 m | 2: trees and rocks |
| GLORBULON (`orb`, after the scout ships of *Close Encounters of the Third Kind*) | beam | 12.5 | x1.6, wide | 80 | 7 m (low) | 2: trees and rocks |
| XELETRON-22 (`triangle`), the black triangle | beam, missiles | 15 | x1.05, narrow | 35 | 10.5 m (high) | 1: small things only |
| FIZZWIGGLER (`foo`), a foo fighter (the balls of light pilots saw in the war): tiny, so hard to hit | lightning gun (no beam) | 16 | x1.3, narrow | 25 | 6.5 m (lowest) | 1: small things only |
| BLORPMOTHER (`cigar`), the cigar-shaped mother ship of the 1950s: huge, so hard to miss | beam, auto turret | 8.5 | x0.8, widest | 120 | 11 m (highest) | 2: trees and rocks |
| DINGDONGULUS (`bell`), the bell-shaped scout ship of the 1952 photographs | beam | 11 | x1.35 | 40 | 9 m | 2: trees and rocks |
| TIKTAKKORAX (`tictac`), the Nimitz tic tac of 2004: the fastest | laser ray, EMP (no beam) | 18 | x0.75, narrow | 30 | 7 m | 1: small things only |
| STARZOID (`saturn`), a ball in a ring of lights | beam, star bits | 10.5 | x1.4 | 55 | 8.5 m | 2: trees and rocks |
| KRYSTALLIX-9 (`diamond`), a pale blue crystal | star bits, by hand (no beam) | 11 | x0.5 (very slow) | 75 | 9 m | 3: buildings (the only ship that starts able to) |
| BLOOPUS-7 (`jelly`), a glowing pink jellyfish trailing tentacles | beam, lightning gun | 12.5 | x0.95, widest | 45 | 7.5 m | 2: trees and rocks |
| YESTROMO (`tug`), a hauler after the Nostromo | beam, auto turret | 9.5 | x1.1 | 110 | 10 m | 2: trees and rocks |
| NEBULONK-B (`frigate`), after the Nebulon-B frigate | laser ray, missiles (no beam) | 13.5 | x0.85, narrow | 65 | 11 m | 2: trees and rocks |
| ENTERBLORPRISE (`trek`), a starship of the Federation sort | beam, laser ray | 12 | x0.8 | 70 | 9.5 m | 2: trees and rocks |
| KRAKKATOOM (`meteor`), a meteorite of a ship: a little pale moon pocked with craters | gravity sling, by hand (no beam) | 14 | x1.15 | 60 | 9 m | 2: trees and rocks |
| CARNIVORB (`carnival`), the Moon Market's own saucer, held in a facility only once every other ship has been found | beam (a rainbow one) | 12.5 | x1.0 | 70 | 8.5 m | 2: trees and rocks |

The beam is green, turns a deep **blue** from the second BEAM item after the ship's own and **purple** from the fourth; the
CARNIVORB's runs through every colour of the rainbow, its swirl of motes and its light too (`beam.gdshader` `rainbow`).
The beam is a strong light: while it is on, everything standing in the broad pool of light round its foot (people,
animals, cars, buildings, fences, crops, and the scenery's trees and rocks, a chunk's MultiMesh at a time) throws
shadows from it onto the ground and each other, not only what is up it (`_beam_shadows`, looked over five times a
second, all let go when the beam goes off; `tests/beam_shadows.gd`).

### Weapons

The abduction **beam** is a weapon like the rest: BEAM, LASER RAY, LIGHTNING GUN, AUTO TURRET, MISSILES, GRAVITY SLING,
STAR BIT BLASTER and EMP (`Main.WEAPONS`). A ship has **two at most** (more of one it has still stacks); each starts
with its own (the table above, `Ufo.SHIPS` "weapons"). Picking a new one at the Moon Market with both slots full
asks which to drop (or keep both and take nothing); the autopilot and the tests never swap theirs. Without the beam a
ship takes nothing up, and earns by wrecking instead: whatever a weapon wrecks (shot, burnt, blown up, zapped) scores
its points (half for the police and army) and is listed under **WRECKED** in the results, by category.

The weapons go for **anything** standing about, the police and army first: people and animals are zapped away in a
flash of light, cars and oil drums blow up, buildings, trees, crops and fences take damage until they come apart
(`weapon_hit`, `weapon_target`, `shootable`; never the land, the power-ups, a captured ship or a rare find). The
turret shoots at things on a reload of its own, so they never keep it from a shell coming in.

- **Fired by hand** (the beam's button, aimed: see **Fire and aim**): the beam; the **LASER RAY**; the **LIGHTNING
  GUN**, a bolt from the ship to the mark every third of a second, striking what is there and leaping on to the next
  near thing and the next (two leaps, one more a stack), each hit weaker; and, on the ship made for them only, the
  **GRAVITY SLING** (the KRAKKATOOM flings a moonlet at the mark, landing harder and wider than one flung by itself, ready again in about 2.3 s, sooner a stack) and the **STAR
  BIT BLASTER** (the KRYSTALLIX-9 sprays them at the mark while held, quicker, tighter and harder-hitting than by themselves).
  A mark on the ground in the weapon's colour shows where they fall. The sling's moonlet is pulled in to just over
  the ship and slung out and down on a curve, held on a glowing purple tether (a bezier from the ship's belly,
  swinging, motes of light running down it) that fades as it lands (`_tether`).
- **By themselves**: the AUTO TURRET, MISSILES (a blast round where each lands), the GRAVITY SLING and STAR BIT
  BLASTER on any other ship, and the EMP, set off by a dash: it stuns and hurts the police and army in it, fries cars
  (they may go up) and anything on wires (poles, street lights, dishes, substations come down: `ELECTRIC`), and shakes
  whatever else stands in it.
- **SIZE RAY** (the item that was WIDE BEAM) makes everything fired a fifth bigger a stack: the beam's width, the
  laser's ray and what it cuts, every blast (missiles, the sling's moonlet, the turret's bolt, which only splashes
  with it), the lightning's strike and leaps, the star bits and what they hit, and the EMP. **SWIVEL MOUNT** leans
  the beam further out and pushes every weapon's mark further from under the ship.

`tests/weapons_look.gd` takes pictures of each (lightning, with SIZE RAY, the sling and the star bits by hand, the
rainbow beam, the beam's three colours, the EMP, and the drop-one choice at the market).

### What the beam can take

The beam's strength (its tier) says what it can lift: **1** animals, people, vehicles, bushes, fences, hay,
cacti; **2** trees, rocks, tents; **3** houses, barns, silos, windmills, water towers, diners, adobes,
cabins; **4** the land itself: buttes, mesas, peaks and Devils Tower (up to 5000 points). Over something too
heavy, it only rattles (and a roof sheds tiles up the beam). Taking a mesa or a peak clears it out of the way. Under the beam, bits of the ground jump up (grass, clods, chaff, sand, drops over a lake) and the swirl up the beam takes their colour; phone wires near it spark.

The hot air balloon is a proper teardrop of coloured gores. Watermelons are round striped balls, dark green with pale bands.

**Crop circles**: hold the beam still over a field of crops and a circle presses into it (60 points), joined by a pressed line to its nearest neighbours within 14 m (two lines at most to a circle, never through another).
**Rare finds**, each under a shaft of gold light: the golden cow, a jackalope, Bigfoot, a meteorite, a fallen
satellite (900 to 3000 points), and, rarer, **crash sites**: another saucer that came down long ago, tipped up in a
ring of heaped dirt, a few lights still glowing (3500 points).

**Power-ups**: every 22 to 40 s a glowing canister turns up somewhere near (two about at most). Beam it up for a
boost: DOUBLE POINTS (15 s), OVERDRIVE (half as fast again, 15 s), HEAT FREEZE (no heat, 12 s), SUPER BEAM
(lifts far faster and one tier stronger, 12 s) or a SHIELD CELL (the shield full at once). What is under way
shows under the heat's news with its seconds left.

**Ponds and lakes** have lumpy shores with a mud bank, reeds and cattails, lily pads (a pink flower here and there), slow rings spreading over them and a pale line where they lap the bank. Nothing walks on the water (`World.out_of_water`). In it swim **trout, bass and catfish** (koi in a park's pond), leaping now and then (`swim`), and **frogs** hop about the bank. All of them can be beamed up.

**Power-up canisters** hover and spin over a glowing ring in their colour, with a halo round them. Taken, they burst into motes of that colour whirling round the saucer.

Everything has a goofy alien name in the pilot's log (`Thing.ALIEN_NAMES` and `MORE_NAMES`; a captured ship goes by its ship's name). The log and the Moon Market show every model as a hologram turning slowly round (`Holograms`: each drawn once from 16 sides in one picture, stepped through), each tile with what one is worth (an item, its price), and the log is only rebuilt when something new is in it. Some drive-in screens are showing a film: the BLOOPUS-7 burning a town down with the laser (`sh tools/drive_in_film.sh` records it into `textures/drive_in_film.png`, played by `shaders/film.gdshader`). The ITEMS section of the log runs common, uncommon, then rare. Every item has a detailed model (see `item_*` in build_models.py), and `sh tools/look_models.sh <dir> <name>...` builds and renders any model from four sides to check its layout.


**Buildings come apart where they stand**: a beam strong enough for one does not carry it up whole. It stays put, shaking, and comes apart from the top down in the very parts it was built of in Blender (roof, chimney, walls, porch, windows: each run of faces that meet, found once a model, `Thing.islands`), one after another breaking off and tumbling up the beam into the ship, anything fixed to a part and smaller going with it, until nothing is left; let go, it stands as much of it as is left, and the beam picks up again where it stopped (`Thing._dismantle`). Blown up, a building throws those parts out, tumbling, and they fall back and lie a moment (`Thing.fly_apart`; `tests/house_apart.gd`). No ship but the slow-beamed KRYSTALLIX-9 starts able to take buildings: the rest need BEAM upgrades.

**Dev room**: on the title, type D-E-V, or tap the game's name seven times quickly, and every ship is unlocked to try (again to switch it off; `?dev` on the address outside the arcade does it straight away). Its scores are not sent to the scoreboard or kept as a best, and the ships really found are what is saved (`toggle_dev`). **TEST ROOM** (a button under the title's row, in the dev room only: `open_test_room`): a cleared patch of the
country, safe (no heat, police or anything sent after the ship unless spawned, the shield always full, nothing
kept). A **DPS DUMMY** on its post takes every hit and never goes, its damage a second (over the last 3 s), total
and last hit (in laser hits) over it and each hit rising off it as a number; rows of people, animals, cars, hay,
fences, trees, rocks, crops and buildings stand behind it, each put back 2 s after it is gone. The **TEST** button
opens its panel (the game paused): the ship (< >, its own weapons; the other items kept), every item's stack (- +;
a third weapon drops the oldest), POLICE / TANK / HELICOPTER to fight (the heat on while any is near), RESET and
EXIT. `tests/test_room_look.gd` takes pictures of it. `sh tools/balance.sh` flies every ship with the autopilot over the same country (`SEEDS="..."`, `EXTRA=--immortal` to measure earning alone) and prints a table.

**Spaceports**: now and then out in the desert or on the plains, a launch pad with its red service tower and a rocket on it, mission control with its dish, and scientists. Come within 70 m and the countdown starts (T-10 called over the pad), smoke rolls out at ignition, and the rocket lifts off on a column of fire, faster and faster, until it is gone; beam it up first and it is yours ($6000; `main.gd _rocket_launches`). Rodeos and ball games have crowds swaying in the bleachers.

**Rivals hunted**: the police and army shoot at a rival saucer near them as well as at the ship, and police not busy with the ship drive after one. Shot down (`Thing.rival_hp`), it spirals smoking into the ground and leaves its wreck in a ring of heaped dirt, a crashed saucer like any other (`main.gd rival_crashed`). Beaming up a crashed saucer takes only the wreck: its dirt (`crash_dirt`) stays in the ground.
**Trees**: besides the round deciduous tree, pines, aspens and pinyons there are weeping **willows** leaning over ponds and lakes, tall forked **cottonwoods** in the pastures and out on the plains, and **Joshua trees** among the saguaros in the desert. The trees are grown, not modelled: the pines by GameCommon's `PineTree`, and the round tree (an oak), aspens, cottonwoods, willows and pinyons by its `LeafyTree` (`Ps1.GROWN`, `grown_mesh`): a forked trunk under a crown of lumpy leaf clumps ragged with tufts, every facet a shade of its own. Their leaves sway in the wind (`bend.gdshaderinc`, by how much each corner may, in UV2.y), and `ps1.gdshader` cuts them into little leaves, a shade each and dark between, with the sky showing through the crown's edge (`tests/tree_look.gd`).

The moon menu's buttons flicker on like a hologram warming up instead of popping in. Police circling a wreck keep to a ring round it, easing in and out, instead of jittering at its edge.

**No flicker**: big flat things on the ground (fields, the town square, the rail bed, ponds, and lots, runways and yards in the models: `World.slab`, `box` in build_models.py) are cut into a grid of 2 to 3 m, so they bend with the ground instead of sinking under it between their corners, and they sit clear of it and of each other. The ships are held to the same rule: the corners snap to the low-res pixels, so two faces lying on one another, or crossing at a shallow slant, shimmer as the ship turns; every band, rim and light under a hull stands at least 5 cm clear of the face under it. Every ship's glass sits on a collar or on the hull all the way round, no part is left floating, and no part reaches more than 4 m from the pilot (past that, `ps1.gdshader` draws it see-through when it is between the ship and the camera). The big ones (YESTROMO, NEBULONK-B, ENTERBLORPRISE, BLORPMOTHER) are built about the pilot and scaled to between two thirds and four fifths of what they were; their glass keeps its size. `blender -b --factory-startup --python tools/check_ships.py -- <name>...` builds ships and prints any LOOSE part, a DOME GAP under the glass, and each one's REACH. A radio dish's waves now leave from in front of the dish, facing the saucer, and travel out to it.

Bullets, pellets and tracers are bright, with a white-hot core, a small glow round them and a faint streak behind, and slow enough to dodge (pellets 14 m/s, bullets 17, tracers 21). Shots coming at the ship from off the screen show as pulsing red arrows at its edge where they will come in, bigger and brighter the closer they are (`ThreatMarks`). The dash orb fills with green liquid as its charges come back, bubbling, and glows when full.

**Money**: every town may have a **bank**. Hold the beam on it and its cash comes out up the beam over 5 s ($3000, raising the heat). Out in the plains and farmland now and then is **Fort Knox**, a granite gold vault between two watchtowers: 12 s of beam for $25,000 in gold, and a lot of heat. **Fire hydrants** stand along town sidewalks. Beam one up (or blow it up) and water spouts out of the main for good: the beam over the spout drinks it, a trickle of points, and it cools the heat a little. **Railway track** can be beamed up a length at a time, and the next train to reach the gap comes off the rails, ploughing over on its side (`Main.torn_track`).

### Heat

Points are multiplied by the heat: x1 with no stars, up to x6 at five. Heat cools after 5 seconds without taking
anything; the shield mends only with no stars. While anything has the ship **in sight** (a searchlight on it, a
dish tracking it) the heat cools at only a third of the rate, so shaking them off is the quick way down.
A searchlight sweeping across the ship raises the heat; one locked on to it (once there is heat) only keeps it
in sight (`Main.held`). An **eye** left of the stars shows it: wide open, red and throbbing while the ship is
seen, with a point on its rim toward whoever is watching (north up, as on the radar); shut while nothing is,
grey until the heat starts to cool and blue while it does (`Eye`).

**It gets harder as the score climbs** (`danger()`, full at 30,000): heat cools later and slower, witnesses
phone sooner, more patrols and more police and army come, they shoot faster, and their shots hit harder.

Searchlights are soft cones, brightest down the middle and fading to their edges (`beam.gdshader`, `soft`).

| Heat | Who comes |
| --- | --- |
| 1 star | Farmers and cowboys draw their guns |
| 2 | Police cars: each has to be sure first (a "?" over it fills while it can see the ship, faster near and under the beam; full, the siren goes and it gives chase); then they pull up and an officer gets out to shoot (take the officer, or get well away and they drive on after you); the traders flee |
| 3 | A police helicopter circling with its searchlight on you, and the men in black (a black sedan, agents in suits) |
| 4 | The army: jeeps firing machine guns on the move |
| 5 | Tanks, and jets fly over firing missiles. Hold five stars for 30 s and they **nuke** you: a red ring on the ground where the ship is going, five seconds, then a missile, a flash and a mushroom cloud that takes everything inside (and most of a shield); again every 20 s while it lasts |

Each star takes much more heat than the last (the fifth some twenty-five times the first's, and all of it two fifths slower), and for 8 seconds after a new one the heat comes only slowly, so the
stars are stages rather than a rush from one to five.

**Witnesses**: anyone who sees the beam take something runs for the nearest **phone booth** by the road (a red
"!") and calls the police from it, radio waves rising off its aerial; take them, or the booth, first. With no booth
near they call from where they stand (4 seconds). **Phone poles** run along every road: take one and calls within
150 m of it cannot get through (a booth's aerial only sparks).

**Watchers**: radio dishes (in rows, like New Mexico's Very Large Array) and observatories turn to follow the
ship; linger near one for 2 seconds and it gives you away. **Police stations** (in towns) and **army bases**
(a hangar, fighter jets, watchtowers with searchlights) are where the police and army come from. Fighter jets
fly over firing missiles at five stars.

**Patrols** rove about whatever the heat: police cars and army jeeps sweeping searchlights over the sky (more
of them the longer you last). Fly into a beam and you are **spotted**: the heat jumps and keeps rising while
it holds you. Once there is heat, the patrols lock their lights on and join in, keeping the ship in sight
(the heat slow to cool) without raising it further.

### Level-ups and traders

**Level-ups come with the score** (`level_at`: 1,500, 6,000, 13,500, 24,000... points): the game pauses and the **MOON
MARKET** opens: its carnival-painted trading saucer appears at once in a puff of confetti and smoke, lit (`MarketShip`; from above by a stage light and left out of the dark laid over the picture, `market_dim.gdshader`), and its beam throws the market onto the screen (`ProjectorBeam`: from above on a phone, from the side on a wide screen), with a choice
of upgrades (sized for thumbs, biggest on an upright phone). They are items that stack, as in Risk of Rain: each pick is one more of it (up to ten), small at first and growing with the stack (the fleet up to six saucers, rates with floors). The items had show as a row of little tiles under the heat's stars, each a small 3D model of the item (built in Blender, `item_*` in tools/build_models.py) with its stack count, as in Risk of Rain 2; the level-up choices show them too:
ENGINE (+7% speed), BEAM (the beam itself for a ship without one; past the first, it lifts faster, and every second one a tier stronger), SHIELD (+15), DASH (one more
dash charge, refilling a little sooner, two more afterimages), MAGNET (small things drift to the beam), SIZE RAY (everything fired bigger: see **Weapons**), SWIVEL MOUNT (the beam and every weapon's mark lean a third further out from under the ship), GRAVITY SLING (rare: every 16 s or so, sooner with more, a little moon, glowing hot and trailing fire, slung down onto the thickest crowd near, the police and army counting three times over, smashing what it lands among; by hand on the KRAKKATOOM), STAR BIT BLASTER (uncommon: sprays Mario Galaxy-style star bits by itself at shells, then the police, then anything near, many times as fast but wild and very weak, about sixteen hits adding up to a laser hit; each one knocks what it hits back away from the ship, and they are faceted jewels running through every colour of the rainbow),
SCANNER (the radar sees further), JAMMER (they stop looking sooner), COOLANT (the heat cools quicker), NANOBOTS
(the shield mends itself), GOLD (everything taken worth a tenth more), EMP (a weapon: a dash sets off a crackling electric blast that stuns and hurts the police and army caught in it, fries cars and wires and shakes what stands; bigger with each, and from the second it paralyses people and animals too), LUCKY CHARM (power-ups turn up more often, and more of them), ARMOR (an eighth less damage a stack), SECOND WIND (each stack shrugs off one fatal hit, the shield back to two fifths), CLOAK, MISSILES, LIGHTNING GUN (rare), and:

- **LASER RAY**: a ray of your own. With the beam too, switch over to it (L, Tab or C; gamepad Y; or the round button over the beam's mark on a touch screen) and the beam's button fires it, at the mark, leaving a trail of glowing burns on the ground that cool to soot and fade. The police and army there are hit (a few hits blow them up), cars and oil drums blow up, and **anything else burns down** (people, animals, trees, houses...: hits up to its size squared, a LASER's worth a cut each), up to a size the laser's level allows (`laser_burns`: a house wants a second LASER, a church a third); the land itself never burns.
- **AUTO TURRET**: a little gun mount under the hull (a ball on a yoke, twin barrels, amber muzzles) that swivels to its target and fires by itself, a quick burst of glowing amber tracer rounds with a muzzle flash, little pops and sparks where they land and a rapid chatter (`_rattle`: nothing like the laser ray's red beam and zap), every 4.0 s (0.6 s sooner a level,
  down to 2.2 s) out to 9.5 m (2.5 m further a level). It shoots down shells and missiles coming at the ship
  first, then jets, then the nearest police or army, and then anything else near: a hit stuns one (it holds its fire
  for 2 s), and enough hits blow it up (a police car 2, a jeep 3, a tank 5), for half its points and a
  quarter of a star of heat, as a crush is. They are soon replaced, and it never stops the bullets.
- **FLEET**: a little saucer for each level (up to four, `scripts/drone.gd`). Each keeps station round
  the ship, flying with it in a flock, and now and then (oftener the more stacked) goes off by itself after the small things nearby that nobody will miss (animals, hay, bushes:
  nothing heavy, hot, rare or on the road), beaming them up slowly with a beam of its own, for the score and
  the heat as if the ship took them. Shots that meet one stop there, and the police and army sometimes aim
  at one instead of the ship; three hits bring it down, and a new one comes out of the ship 14 s later.

**Traders** no longer park out in the country: level-ups (the Moon Market) and the power-up canisters are where upgrades come from. (`scripts/shop.gd` and `spawn_shop` remain, unused.)

### Rival saucers

Now and then another saucer (purple, a pink beam) comes down out of the sky to abduct from your country:
animals and people out in the open, a few of them, before it leaves. The log says what it took. Fly into it
and you bounce off; **dash into it** and it spins away and drops what it had (500 points).

### Knocks, tosses and bangs

- Fly into something tall (a peak, a mesa, a watchtower, a water tower, a silo, a church) and the ship
  bounces off it and the shield takes a little damage (never the last of the ship).
- Let go of something while moving and it flies on in an arc: you can **toss** things. **Oil drums** blow up
  when they land hard, and so do cars dropped from high enough or thrown hard; the blast takes out any police
  or army near it.
- **People hide**: anyone on foot near the ship runs for the nearest house, barn, store or church and goes in,
  out of the beam's reach, and comes out once the ship has gone a while. Take the building and out they run.

When the shield is gone the ship comes down and the game is over: a **crash site** where it hit, the ship half
in the ground, burning and smoking; the pilot tumbles out, lies a moment and gets up, staggering, and people
come out to stand round and look. The results type out above it in green: what was taken, kind by kind, and
the total by category (Earthlings, beasts, crops, machines...), left-aligned, typed out with a typewriter's keys and bell. The score goes to the arcade page (`PLAYER_DIED`); the best score and the ship are kept in
`user://best.cfg`. **Each run is a new country** (`World.reseed`): new regions, roads and props, and Devils
Tower somewhere else (the tests keep the first one). A run always starts over a cornfield by the first town.

### Multiplayer

On the title the arrows turn the big button between **PLAY** (alone), **HOST** and **JOIN**, and **SAUCERS** shows every ship as a
hologram to pick from (those not yet found greyed out). HOST makes a room at once
(a four-letter code to give friends); JOIN asks for a friend's code. Up to four saucers. The one who made the
room presses START, and everyone lifts off for the same country: the leader's start carries the world's seed
(as the room's "stage").

It runs on the Scareathon server's rooms, the same as 8 Bit Evil Returns V2 and October Valley
(`server/routes/closeEncounters.js` in scareathon-v3, at `/close-encounters/ws`; `scripts/net.gd` is October
Valley's client). Each device flies its own saucer and has its own heat, police and score. Shared
(`scripts/coop.gd`): each saucer's place, speed, heading, beam and score, 20 times a second, drawn for the others
as a `RemoteSaucer` with its pilot, its beam and P2/P3/P4 and its score over it, seen on from where it was heard to be at the speed it was going (no stepping); each player's police and army near them, 5 times a second, drawn for the others; and what happens: anything
taken up a beam is gone for everyone, crop circles are pressed for everyone, blasts are seen by everyone.
The level-ups go by everyone's score together (each picks their own upgrade), and the host's moving things (people, animals, cars) near it are followed by everyone else's copies. The other saucers are real ships, driven by what is heard of them, so their beams look just as one's own. Guests' packets reach only the host, which passes everything on. `--server=<url>` (or `?server=` on the page)
points it at another server.

**Rescues**: a saucer shot down in co-op waits on the ground for 20 s while anyone else is still flying ("DOWN! A FRIEND CAN BEAM YOU UP"). A friend holding their beam over the wreck for 1.5 s (`Coop.RESCUE_HOLD`) beams it back up, flying again with half a shield. Nobody comes, or nobody is left, and the crash plays out as usual. `tests/coop_test.gd` shoots the guest down and has the host beam it back up.

## The world

Endless, made in 48 m chunks round the ship as it flies (`scripts/world.gd`) and dropped behind it; the same
place is always the same. Five regions, several chunks across, blended at their edges on the ground:

- **Farm**: Colorado farm country (where it starts): big fields with rows of wheat, corn and pumpkins (a few points
  each), the odd farmstead (a farmhouse with a wrap-around porch, a barn and a silo), pens of cows, pigs, sheep, chickens.
- **Plains**: the Wyoming high plains: golden grass, sagebrush, bison, ranches with horses and cowboys,
  windmills, oil pumpjacks, buttes, and **Devils Tower** (just the one, about a kilometre out, alone in a pine forest away from the roads).
- **Desert**: Arizona: red sand, saguaros, prickly pear, red rock, mesas and buttes, coyotes, RVs.
- **Mesa**: New Mexico: ochre earth, pinyon, adobe villages with water towers, longhorns.
- **Mountain**: the Colorado Rockies: snow-capped peaks, pines, aspens gone gold, log cabins, campers.

Wildlife lives where nobody does: bears, mountain goats and elk in the mountains, pronghorn on the plains,
rabbits and roadrunners in the desert, crows and hawks overhead (hardly any heat). Highways cross every 240 m;
some crossings are towns (a main street of shops with sign boards and awnings, a clock tower or a water tower, a
police station, a diner, more people about, houses lining the roads out), the rest open country. Out in the
country: low hills, lakes, and now and then a little airfield (a runway, a control tower, prop planes).
Only people and cars are ever put down in a road. Landforms are planned per chunk before anything else
(`World.landforms`), so nothing is ever put down on top of one, and buildings stay inside their own chunk.
Anything between the camera and the ship is drawn see-through (`shaders/ps1.gdshader`).

**Railways** run straight across the country down the middle of a few rows of chunks (`has_rail`), rails on
sleepers on a gravel bed. While the ship is near one, a **train** comes along now and then (whistle blowing): a
locomotive, boxcars and a caboose, each a thing to take (`move` "rail", main.gd `_trains`). **Airliners** cross
high overhead, blinking, out of reach.

**Places** (`_venue`, one now and then in the middle of an open chunk, by the region): a **schoolhouse** and
playground, a **park** with a pond, gazebo and benches, a **carnival** (a turning Ferris wheel and a carousel with people riding them, a big
top and game booths), a **drive-in** (the screen glowing, rows of cars, speaker posts), a **junkyard** (rusted cars,
scrap, tyres, a fence), a **building site** (a tower crane, an excavator, a cement mixer, girders) and a **rodeo** (a
ring of fence, bleachers, cowboys on horseback and a bull), and **football** and **baseball** fields with a game on (players in their teams' colours running about, a crowd in the bleachers). Radio dishes are rarer, and send rings of radio waves up off their dishes while they track the ship. By the roads (`_roadside`): **gas stations** and **car
dealerships** with their lots of cars and **wacky waving inflatable tube men**. Farm ponds; hot air balloons hanging
over the fields; cowboys on horseback out on the plains and mesas; town roads have **sidewalks** with **street lights**, benches and trash cans; country roads have **stop signs**, and **highway signs** on the way into a crossing; parks have lamp posts; **bushes** round towns, farms and parks.

The police see only by their lights: a police car notices the ship only while its searchlight is on it, and an officer, out of the car, swings a **flashlight** after the ship and fires only while it is lit. **Hunters** in blaze orange (mountains and plains) shoot at the ship with rifles whatever the heat. At five stars the jets are fighters, black **stealth** bombers (higher, faster, three missiles) or **warthogs** (low and slow, strafing). Every word on the screen is a hologram, and the results bob gently.

A police car's "?" turns to a red "!" once it is sure. **Liquor stores** (in towns and by the roads, 1500 points) and **coolers** of beer (at campsites, parks, rodeos, drive-ins and liquor stores) are there for the taking. On the moon the pilot holds the drink (an amber bottle, a green one or a can) upside down, shaking it now and then; the cooler holds green bottles and cans as well.

**Items have rarities**, as in Risk of Rain: common (green), uncommon (blue: laser, turret, cloak, nanobots, gold) and rare (red: missiles, EMP, fleet); the rarer, the less often the Moon Market has them, and each is framed in its rarity's colour, its tile tinted it too (on the item bar and in the log). **Havens**: now and then up in the mountains a hidden valley, walled all round by tall crags that nothing on the ground can get past, but for a low saddle of two little peaks the ship flies in over (`World.is_haven`). Inside one no police or army on the ground are sent and those after the ship give up after 4 s; helicopters, Chinooks and jets still come, and the heat cools only a little quicker. Mountain peaks stand a little taller than a mesa, with shoulders, rock outcrops and snow only on top. **Ramming**: fly into a helicopter, a Chinook or the helicarrier and both take a hit (two for it if dashing); with two DASH items a dash into one leaves the ship unhurt.

**More on the roads and off them**: motorcycles, **biker gangs** riding in packs, **motorcycle cops** (from two stars: quick, and they shoot, though less than a quarter as often as a cop on foot, keeping further off), and **cult compounds** (robed cultists round a glowing altar, who want to be taken). Hold five stars for 50 s and they bring out a **helicarrier** (hovering high, firing rail-gun slugs), **rail guns** and **laser trucks**; after 80 s, **laser satellites** strike from orbit (a red ring, then a beam). A run starts over a field of crops: wheat, corn, pumpkins, sunflowers, cabbages, melons or peppers (all of them grown out in farm country too). **Towns** are laid out each its own way round, with **hospitals** and **fire stations** among the houses, and houses near a road face it; **fire trucks** and **ambulances** drive the roads; out in the country, **prisons** (a walled cell block, watchtowers, inmates in orange in the yard): break one (take it, burn it or blow it up) and the inmates run for it while the police go after them (a star of heat off). Shot down, the ship wrecks whatever it lands on. **Hitboxes**: anything 5 m tall or more stands in the ship's way as tall and as wide as its model really is (measured from it, `World.model_size`), and the ship flies over what is lower than it flies; a building burnt, blown up or taken no longer blocks. **Farms**: farmsteads have their cows, a **pig pen** (a muddy wallow and a trough), a **chicken coop** with its chickens, and sometimes a grain bin; **grain elevators** stand by the railway; **center-pivot irrigation** lines stand over some crop fields. The log can be tossed with a finger and runs on.

**People are curious** until something frightens them (a beam on near them, a blast, a laser, seeing something
taken): they edge up to look at the ship from a way off, and come to stand round any crop circle near. **True
believers** (in green shirts) want to be taken: they come running to stand under the ship, hopping and shouting
for it.

**Runs keep**: TO THE MOON from the pause flies home with the run kept (score, level, items, what was taken);
PLAY becomes CONTINUE for that ship and carries on with it. A crash ends the run for good. QUIT is in the pause
menu too (in the arcade, or off the web). After a crash the men in black's work is slower, and once they have gone
two **news vans** from rival stations pull up by the meteorite (KBLP 7 ACTION NEWS and WOOO 13 EYEWITNESS NEWS, painted on their sides, each with its satellite dish up on a mast: `news_van`, `NEWS_STATIONS`), a reporter and a camera crew get out, and the camera's light comes on.

## Layout

- `scripts/main.gd`: the game: modes, heat, forces, patrols and spotting, traders and upgrades, ship choice,
  scenery pulled up by the beam, the moon title and launch, radar, the autopilot (in tests), effects, camera, HUD, touch.
- `scripts/ufo.gd` (the ships, `SHIPS`), `alien.gd` (the pilot), `thing.gd` (everything that can be taken:
  `KINDS` holds points, weight, heat, tier, how it moves, its gun, its searchlight), `shop.gd` (a trader),
  `drone.gd` (one of the mini fleet), `shot.gd`, `world.gd`, `sfx.gd` (synthesised sounds), `ps1.gd` (materials, and the Blender models in them),
  `moon.gd` (the title's moon, and the lift-off blast), `dust.gd` (dust in space and wind lines), `clouds.gd`, `tornado.gd` (the
  whirl up the beam), `puffs.gd` (smoke and sparks), `broadcast.gd` (a phone booth's aerial: radio waves, or sparks with the lines cut).
- `shaders/`: `bend.gdshaderinc` (the bend and PS1 snap), `ps1` (with the see-through), `ps1_flat`, `glass`,
  `beam` (the tractor beam's two cones), `searchlight` (searchlights and beacons: a strip of light turned to the camera), `reticle` (where the beam will fall), `cloud`, `ground`
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

The web build's loading screen (`html/head_include` in export_presets.cfg): stars streaming out of the middle, faster as it
loads; the Godot logo tinted green as a hologram (glowing, scanlines, a flicker); and a spinning star just under it.

## Tests and build

    godot --headless --path . --fixed-fps 60 -s res://tests/smoke.gd      # heat, forces, patrols, dodge, crash
    godot --headless --path . --fixed-fps 60 -s res://tests/travel.gd     # the endless world
    godot --headless --path . --fixed-fps 60 -s res://tests/upgrades.gd   # tiers, a tree, a mesa, the laser, the fleet
    godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/touch.gd   # touch controls, pause, quit
    godot --headless --path . --fixed-fps 60 -s res://tests/unlock.gd     # a secret facility unlocks a ship; every ship flies
    godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/<shots|regions|look|look_more|look_ships>.gd -- <out dir>
    godot --path . --fixed-fps 60 --resolution <390x844|1280x720> -s res://tests/moon_look.gd -- <out dir>   # the title
    godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/launch.gd -- <out dir>     # off the moon, the descent, and home again
    godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/fx_look.gd -- <out dir>    # beam, clouds, phone booths, smoke, windmill
    godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/scale_look.gd -- <out dir>  # one spot drawn at a few world scales
    godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/world_look.gd -- <out dir>  # a town, a farm, a hill, a lake, an airfield
    godot --path . --resolution 390x844 -s res://tests/log_look.gd -- <out dir>    # the title's buttons and the log
    godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/new_look.gd -- <out dir>    # stars, a cop's "?", a rival, hiding, a nuke, the wreck, home, a flyby
    godot --path . --resolution 1280x720 -s res://tests/aliens.gd -- <out.png>
    godot --path . --resolution 1280x720 -s res://tests/perf.gd           # frame time, draw calls, things
    godot --path . --resolution 640x360 --max-fps 60 -s res://tests/hitches.gd  # the worst frames through the lift-off and descent
    godot --path . --resolution 640x360 --max-fps 60 -s res://tests/beam_hitch.gd  # the worst frames round the first press of the beam
    sh tools/coop_test.sh <scareathon-v3/server, with node_modules>   # multiplayer: a local relay of the site's rooms, a host and a guest

Performance: each model is merged into one surface at load (colours on its corners, see `Ps1._merged`), so a
thing is one draw call; nothing is drawn past 115 m (`Ps1.DRAW_TO`); far still things are not ticked and far
movers only every fourth frame; a new chunk's things are put down six a frame (`spawn_later`). About 320 draw
calls a frame, down from 1,100.
    godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie <out.avi> -s res://tests/preview.gd
    sh tools/export_web.sh      # the web build, its .pck named by its contents (phones never keep an old one)

(`godot` is `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`.)

## Sky

The stars are NASA's Deep Star Maps (`textures/starmap_nasa.jpg`, public domain, the 2020 4K map): the Milky
Way and the real constellations, the same sky on the moon, in space and over Earth, its brightest stars
twinkling; over Earth the night's blue and a horizon haze are laid on it (`shaders/sky.gdshader`). The
moon over Earth is NASA's LRO map of it (`textures/moon_lroc.jpg`), hung at one place in the sky like Earth
over the moon: top left in play on a wide screen, top right on a phone, out of the picture where the
descent starts and gone again before the ship is home, a full moon with a soft glow round it (`shaders/moon_glow.gdshader`). On a phone the camera in play sits lower and looks a little up (`_look_up`), so the sky and the moon show over the fields as on a wide screen.
