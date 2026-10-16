class_name Thing
extends Node3D
## Anything on the ground that the beam can take: animals, people, things about the farm, cars,
## and the police and army who come after the saucer. Each kind is a row of KINDS. The game moves
## them all through `tick` (no _process of their own).
##
## A thing in the beam rises (slower the heavier it is: `weight` is the seconds it takes) and is
## taken when it reaches the saucer. Let go of before then, it falls; dropped from high enough on
## one of the police or army, it crushes them.
##
## How strong a beam it takes is its `tier` (1 if not given): 1, anything that moves and the
## small things about; 2, trees, cacti, rocks and tents; 3, buildings; 4, the mesas, buttes,
## peaks and Devils Tower. Ships start at a tier of their own and upgrade from there. Scenery and
## buildings come from the world (see World), which may say which `chunk` they belong to.

const KINDS := {
	"chicken": {"points": 10, "weight": 0.7, "heat": 0.03, "move": "peck", "speed": 1.6, "size": 0.5, "voice": "cluck"},
	"sheep": {"points": 25, "weight": 1.1, "heat": 0.04, "move": "graze", "speed": 1.3, "size": 0.9, "voice": "baa"},
	"pig": {"points": 30, "weight": 1.2, "heat": 0.04, "move": "graze", "speed": 1.3, "size": 0.9, "voice": "oink"},
	"cow": {"points": 50, "weight": 1.7, "heat": 0.06, "move": "graze", "speed": 1.0, "size": 1.3, "voice": "moo"},
	"hay_bale": {"points": 15, "weight": 1.0, "heat": 0.04, "move": "still", "size": 1.0},
	"hay_pile": {"points": 30, "weight": 1.6, "heat": 0.05, "move": "still", "size": 2.6},
	# An oil drum: drop it (from any height) and it blows up, taking out the police and army near it
	"barrel": {"points": 40, "weight": 0.8, "heat": 0.1, "move": "still", "size": 0.9, "explosive": true},
	"scarecrow": {"points": 40, "weight": 1.0, "heat": 0.06, "move": "still", "size": 0.8},
	"outhouse": {"points": 90, "weight": 2.2, "heat": 0.2, "move": "still", "size": 1.2, "voice": "scream"},
	"farmer": {"points": 100, "weight": 1.3, "heat": 0.4, "move": "flee", "speed": 3.4, "size": 0.7, "voice": "scream", "gun": "shotgun", "caller": true},
	"person": {"points": 100, "weight": 1.3, "heat": 0.35, "move": "flee", "speed": 3.6, "size": 0.7, "voice": "scream", "caller": true},
	# Out in the country: campers round their tents, hikers in the hills, and stargazers at their
	# telescopes (who, like the dishes, give the ship away if it lingers in their sky)
	"camper": {"model": "person", "tints": {"shirt": Color(0.75, 0.2, 0.15), "denim": Color(0.35, 0.3, 0.2)}, "points": 110, "weight": 1.3, "heat": 0.35, "move": "flee", "speed": 3.4, "size": 0.7, "voice": "scream", "caller": true},
	"hiker": {"model": "person", "tints": {"shirt": Color(0.95, 0.6, 0.15), "denim": Color(0.3, 0.32, 0.28)}, "points": 110, "weight": 1.3, "heat": 0.35, "move": "flee", "speed": 3.8, "size": 0.7, "voice": "scream", "caller": true},
	"stargazer": {"model": "person", "tints": {"shirt": Color(0.3, 0.3, 0.6)}, "points": 150, "weight": 1.3, "heat": 0.4, "move": "flee", "speed": 3.2, "size": 0.7, "voice": "scream", "caller": true, "watch": 26.0, "why": "SEEN THROUGH A TELESCOPE!"},
	"telescope": {"points": 60, "weight": 0.8, "heat": 0.05, "move": "still", "size": 0.9},
	"tractor": {"points": 150, "weight": 2.6, "heat": 0.3, "move": "graze", "speed": 1.5, "size": 2.0},
	"car": {"points": 150, "weight": 2.6, "heat": 0.4, "move": "road", "speed": 9.0, "size": 2.2},
	"pickup": {"points": 180, "weight": 2.9, "heat": 0.4, "move": "road", "speed": 8.0, "size": 2.4},
	# The West
	"horse": {"points": 60, "weight": 1.6, "heat": 0.05, "move": "graze", "speed": 1.8, "size": 1.3, "voice": "neigh"},
	"bison": {"points": 120, "weight": 2.6, "heat": 0.06, "move": "graze", "speed": 1.0, "size": 1.6, "voice": "moo"},
	"longhorn": {"points": 70, "weight": 1.9, "heat": 0.06, "move": "graze", "speed": 1.0, "size": 1.4, "voice": "moo"},
	"coyote": {"points": 45, "weight": 0.9, "heat": 0.02, "move": "flee", "speed": 5.0, "size": 0.8, "voice": "howl"},
	"cowboy": {"points": 110, "weight": 1.3, "heat": 0.4, "move": "flee", "speed": 3.4, "size": 0.7, "voice": "scream", "gun": "pistol", "caller": true},
	# Wildlife, out where nobody lives: hardly any heat
	"bear": {"points": 120, "weight": 2.0, "heat": 0.02, "move": "graze", "speed": 1.4, "size": 1.4, "voice": "growl"},
	"mountain_goat": {"points": 55, "weight": 1.0, "heat": 0.01, "move": "graze", "speed": 1.6, "size": 0.9, "voice": "baa"},
	"elk": {"points": 80, "weight": 1.8, "heat": 0.02, "move": "graze", "speed": 1.6, "size": 1.4, "voice": "bugle"},
	"pronghorn": {"points": 45, "weight": 1.0, "heat": 0.01, "move": "flee", "speed": 7.0, "size": 0.9},
	"rabbit": {"points": 15, "weight": 0.5, "heat": 0.005, "move": "flee", "speed": 5.0, "size": 0.5},
	# By the water: fish in it (`swim`: round their pond, leaping now and then) and frogs on its bank
	"trout": {"model": "fish", "tints": {"fish_body": Color(0.5, 0.58, 0.5), "fish_belly": Color(0.95, 0.6, 0.62)}, "points": 45, "weight": 0.6, "heat": 0.01, "move": "swim", "speed": 1.8, "size": 0.6},
	"bass": {"model": "fish", "tints": {"fish_body": Color(0.28, 0.45, 0.2), "fish_belly": Color(0.88, 0.88, 0.62)}, "points": 45, "weight": 0.7, "heat": 0.01, "move": "swim", "speed": 1.6, "size": 0.65},
	"catfish": {"model": "catfish", "points": 60, "weight": 0.8, "heat": 0.01, "move": "swim", "speed": 1.1, "size": 0.75},
	"koi": {"model": "fish", "tints": {"fish_body": Color(1.0, 0.45, 0.1), "fish_belly": Color(0.98, 0.95, 0.9)}, "points": 70, "weight": 0.6, "heat": 0.02, "move": "swim", "speed": 1.2, "size": 0.6},
	"frog": {"points": 20, "weight": 0.4, "heat": 0.005, "move": "flee", "speed": 2.6, "size": 0.4, "hops": true, "voice": "croak"},
	"roadrunner": {"points": 30, "weight": 0.5, "heat": 0.01, "move": "flee", "speed": 7.0, "size": 0.5},
	"crow": {"points": 10, "weight": 0.4, "heat": 0.005, "move": "fly", "speed": 3.0, "size": 0.7, "voice": "caw"},
	"hawk": {"points": 35, "weight": 0.7, "heat": 0.01, "move": "fly", "speed": 4.0, "size": 1.1, "voice": "caw"},
	# The telephone lines along the roads: take a pole and nobody near can call the police
	"phone_pole": {"points": 40, "weight": 1.0, "heat": 0.05, "move": "still", "size": 1.2},
	# By the roads: a caller runs to one to phone the police, its aerial sending out the call (see
	# Broadcast); take it and they must find another
	"phone_booth": {"points": 120, "weight": 1.6, "heat": 0.15, "move": "still", "size": 1.3},
	# Rare finds, each with a beacon of light to be seen from far off
	"golden_cow": {"title": "THE GOLDEN COW", "model": "cow", "tints": {"hide": Color(1.0, 0.8, 0.25), "spot": Color(0.85, 0.55, 0.1), "pink": Color(1.0, 0.85, 0.5)}, "points": 2000, "weight": 1.7, "heat": 0.2, "move": "graze", "speed": 1.0, "size": 1.3, "voice": "moo", "rare": true},
	"jackalope": {"title": "A JACKALOPE", "points": 900, "weight": 0.6, "heat": 0.05, "move": "flee", "speed": 7.5, "size": 0.6, "rare": true},
	"sasquatch": {"title": "BIGFOOT!", "points": 3000, "weight": 2.2, "heat": 0.3, "move": "flee", "speed": 4.6, "size": 1.0, "voice": "growl", "rare": true},
	"meteorite": {"title": "A METEORITE", "points": 2500, "weight": 2.5, "heat": 0.2, "move": "still", "size": 1.4, "rare": true},
	"satellite": {"title": "A FALLEN SATELLITE", "points": 2000, "weight": 2.0, "heat": 0.3, "move": "still", "size": 2.0, "rare": true},
	"crash_site": {"title": "A CRASHED SAUCER", "points": 3500, "weight": 3.5, "heat": 0.3, "move": "still", "size": 2.6, "rare": true},
	"saguaro": {"points": 30, "weight": 1.3, "heat": 0.03, "move": "still", "size": 0.8},
	"pumpjack": {"points": 160, "weight": 3.0, "heat": 0.25, "move": "still", "size": 2.0},
	"rv": {"points": 220, "weight": 3.2, "heat": 0.4, "move": "road", "speed": 7.0, "size": 2.6},
	# On patrol whatever the heat, sweeping a searchlight over the sky: be caught in it and the heat
	# goes up. Once there is heat they lock the light on and come after the ship like the rest.
	"patrol_car": {"model": "police_car", "points": 300, "weight": 3.0, "heat": 0.6, "move": "patrol", "speed": 6.0, "size": 2.2, "keep": 10.0, "enemy": true, "searchlight": true, "police": true},
	"patrol_jeep": {"model": "jeep", "points": 400, "weight": 3.4, "heat": 0.7, "move": "patrol", "speed": 5.5, "size": 2.2, "gun": "mg", "keep": 12.0, "enemy": true, "searchlight": true, "lights": 2},
	# Scenery, pulled out of the ground (tier 1 and 2)
	"sagebrush": {"points": 5, "weight": 0.5, "heat": 0.01, "move": "still", "size": 0.8},
	"prickly_pear": {"points": 10, "weight": 0.6, "heat": 0.01, "move": "still", "size": 0.8},
	"fence": {"points": 5, "weight": 0.6, "heat": 0.01, "move": "still", "size": 1.5},
	"tree": {"points": 25, "weight": 1.6, "heat": 0.03, "move": "still", "size": 1.5, "tier": 2},
	"pine": {"points": 25, "weight": 1.6, "heat": 0.03, "move": "still", "size": 1.5, "tier": 2},
	"aspen": {"points": 25, "weight": 1.4, "heat": 0.03, "move": "still", "size": 1.4, "tier": 2},
	"pinyon": {"points": 20, "weight": 1.2, "heat": 0.03, "move": "still", "size": 1.4, "tier": 2},
	"willow": {"points": 30, "weight": 1.8, "heat": 0.03, "move": "still", "size": 1.8, "tier": 2},
	"cottonwood": {"points": 35, "weight": 2.0, "heat": 0.03, "move": "still", "size": 1.8, "tier": 2},
	"joshua_tree": {"points": 30, "weight": 1.4, "heat": 0.03, "move": "still", "size": 1.2, "tier": 2},
	"rock": {"points": 30, "weight": 1.8, "heat": 0.03, "move": "still", "size": 1.5, "tier": 2},
	"camp_tent": {"points": 40, "weight": 1.0, "heat": 0.1, "move": "still", "size": 1.5, "tier": 2, "voice": "scream"},
	# Buildings (tier 3)
	"house": {"points": 250, "weight": 4.0, "heat": 0.5, "move": "still", "size": 3.0, "tier": 3, "voice": "scream"},
	"farmhouse": {"points": 300, "weight": 4.5, "heat": 0.5, "move": "still", "size": 3.0, "tier": 3, "voice": "scream"},
	# Main street, in the towns: shops with sign boards and awnings, and a clock tower
	"storefront": {"points": 500, "weight": 4.5, "heat": 0.6, "move": "still", "size": 3.2, "tier": 3, "voice": "scream"},
	"clock_tower": {"points": 1200, "weight": 6.0, "heat": 0.8, "move": "still", "size": 2.6, "tier": 3},
	"city_hall": {"points": 1500, "weight": 7.0, "heat": 0.9, "move": "still", "size": 5.0, "tier": 3, "voice": "scream"},
	"fountain": {"points": 250, "weight": 3.0, "heat": 0.4, "move": "still", "size": 2.6, "tier": 2},
	# Now and then a white wooden church, by a road out of town or out in the country
	"church": {"points": 800, "weight": 5.5, "heat": 0.7, "move": "still", "size": 3.6, "tier": 3},
	# The airfield: its control tower and little planes
	"control_tower": {"points": 900, "weight": 5.5, "heat": 0.7, "move": "still", "size": 2.6, "tier": 3},
	"plane": {"points": 600, "weight": 3.5, "heat": 0.5, "move": "still", "size": 3.0, "tier": 2},
	# The crops in the fields, in rows: hardly worth anything, but a field of them adds up
	"wheat": {"points": 8, "weight": 0.5, "heat": 0.01, "move": "still", "size": 0.8},
	"corn": {"points": 10, "weight": 0.5, "heat": 0.01, "move": "still", "size": 0.8},
	"pumpkin": {"points": 15, "weight": 0.6, "heat": 0.01, "move": "still", "size": 0.8},
	"sunflower": {"points": 12, "weight": 0.5, "heat": 0.01, "move": "still", "size": 0.8},
	"cabbage": {"points": 10, "weight": 0.4, "heat": 0.01, "move": "still", "size": 0.6},
	"melon": {"points": 18, "weight": 0.6, "heat": 0.01, "move": "still", "size": 1.1},
	"pepper": {"points": 14, "weight": 0.4, "heat": 0.01, "move": "still", "size": 0.6},
	# A low rolling hill (the land itself)
	"hill": {"points": 1500, "weight": 9.0, "heat": 0.5, "move": "still", "size": 8.0, "tier": 4},
	"barn": {"points": 350, "weight": 5.0, "heat": 0.5, "move": "still", "size": 3.0, "tier": 3, "voice": "moo"},
	"silo": {"points": 300, "weight": 4.5, "heat": 0.4, "move": "still", "size": 2.0, "tier": 3},
	"windmill": {"points": 200, "weight": 3.5, "heat": 0.3, "move": "still", "size": 1.6, "tier": 3},
	"water_tower": {"points": 300, "weight": 4.5, "heat": 0.5, "move": "still", "size": 2.6, "tier": 3},
	"diner": {"points": 400, "weight": 5.0, "heat": 0.6, "move": "still", "size": 4.0, "tier": 3, "voice": "scream"},
	"adobe": {"points": 250, "weight": 4.0, "heat": 0.5, "move": "still", "size": 3.0, "tier": 3, "voice": "scream"},
	"cabin": {"points": 220, "weight": 3.5, "heat": 0.4, "move": "still", "size": 2.6, "tier": 3, "voice": "scream"},
	# The land itself (tier 4): the beam takes hold of these from all round them
	"butte": {"points": 1500, "weight": 8.0, "heat": 1.0, "move": "still", "size": 2.0, "tier": 4},
	"mesa": {"points": 2500, "weight": 10.0, "heat": 1.2, "move": "still", "size": 2.0, "tier": 4},
	"peak": {"points": 4000, "weight": 12.0, "heat": 1.5, "move": "still", "size": 2.0, "tier": 4},
	"crag": {"points": 3000, "weight": 10.0, "heat": 1.5, "move": "still", "size": 1.5, "tier": 4},
	"devils_tower": {"points": 5000, "weight": 12.0, "heat": 2.0, "move": "still", "size": 2.0, "tier": 4},
	# The law, the army, and those who watch the sky (tier 3, but for the jets and the parked ones)
	"police_station": {"points": 600, "weight": 5.0, "heat": 0.8, "move": "still", "size": 4.0, "tier": 3, "station": "police"},
	"hangar": {"points": 800, "weight": 6.0, "heat": 0.8, "move": "still", "size": 5.0, "tier": 3, "station": "army"},
	"watchtower": {"points": 300, "weight": 4.0, "heat": 0.5, "move": "still", "size": 2.0, "tier": 3, "searchlight": true, "light_y": 9.0, "station": "army", "guard": true},
	"tent": {"points": 40, "weight": 1.0, "heat": 0.1, "move": "still", "size": 2.0, "tier": 2},
	"fighter_jet": {"model": "jet", "points": 1500, "weight": 3.0, "heat": 0.8, "move": "still", "size": 3.0, "tier": 2, "rest_y": 1.1},
	"parked_jeep": {"model": "jeep", "points": 300, "weight": 3.0, "heat": 0.5, "move": "still", "size": 2.2},
	"parked_tank": {"model": "tank", "points": 700, "weight": 4.5, "heat": 0.8, "move": "still", "size": 3.0},
	# A substation: hold the beam over it to drain its power into the shield (then it can be taken)
	"substation": {"points": 500, "weight": 5.0, "heat": 0.4, "move": "still", "size": 4.0, "tier": 3, "power": 60.0},
	# They watch for the ship; linger near one and it gives the ship away
	"observatory": {"points": 900, "weight": 6.0, "heat": 0.6, "move": "still", "size": 4.0, "tier": 3, "watch": 45.0, "why": "THE OBSERVATORY SAW YOU"},
	"seti_dish": {"points": 600, "weight": 5.0, "heat": 0.5, "move": "still", "size": 3.0, "tier": 3, "watch": 55.0, "why": "SIGNAL DETECTED"},
	# Ships held in secret government facilities: take one and it is yours to fly
	"captured_orb": {"title": "YOU FOUND THE GLORBULON: IT'S YOURS", "model": "orb", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 2.5, "rare": true, "unlock": "orb", "rest_y": 1.5},
	"captured_triangle": {"title": "YOU FOUND THE XELETRON-22: IT'S YOURS", "model": "triangle", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 3.0, "rare": true, "unlock": "triangle", "rest_y": 0.6},
	"captured_foo": {"title": "YOU FOUND THE FIZZWIGGLER: IT'S YOURS", "model": "foo", "points": 3000, "weight": 2.0, "heat": 1.5, "move": "still", "size": 1.5, "rare": true, "unlock": "foo", "rest_y": 0.9},
	"captured_cigar": {"title": "YOU FOUND THE BLORPMOTHER: IT'S YOURS", "model": "cigar", "points": 3000, "weight": 3.5, "heat": 1.5, "move": "still", "size": 3.5, "rare": true, "unlock": "cigar", "rest_y": 1.05},
	"captured_bell": {"title": "YOU FOUND THE DINGDONGULUS: IT'S YOURS", "model": "bell", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 2.8, "rare": true, "unlock": "bell", "rest_y": 0.72},
	"captured_tictac": {"title": "YOU FOUND THE TIKTAKKORAX: IT'S YOURS", "model": "tictac", "points": 3000, "weight": 2.5, "heat": 1.5, "move": "still", "size": 2.3, "rare": true, "unlock": "tictac", "rest_y": 0.7},
	"captured_saturn": {"title": "YOU FOUND THE STARZOID: IT'S YOURS", "model": "saturn", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 2.9, "rare": true, "unlock": "saturn", "rest_y": 1.25},
	"captured_diamond": {"title": "YOU FOUND THE KRYSTALLIX-9: IT'S YOURS", "model": "diamond", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 2.2, "rare": true, "unlock": "diamond", "rest_y": 1.7},
	"captured_jelly": {"title": "YOU FOUND THE BLOOPUS-7: IT'S YOURS", "model": "jelly", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 2.5, "rare": true, "unlock": "jelly", "rest_y": 2.0},
	"captured_carnival": {"title": "YOU FOUND THE CARNIVORB: IT'S YOURS", "model": "carnival", "points": 5000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 2.5, "rare": true, "unlock": "carnival", "rest_y": 0.9},
	"captured_tug": {"title": "YOU FOUND THE YESTROMO: IT'S YOURS", "model": "tug", "points": 3000, "weight": 3.5, "heat": 1.5, "move": "still", "size": 3.4, "rare": true, "unlock": "tug", "rest_y": 0.8},
	"captured_frigate": {"title": "YOU FOUND THE NEBULONK-B: IT'S YOURS", "model": "frigate", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 3.6, "rare": true, "unlock": "frigate", "rest_y": 1.2},
	"captured_trek": {"title": "YOU FOUND THE ENTERBLORPRISE: IT'S YOURS", "model": "trek", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 3.0, "rare": true, "unlock": "trek", "rest_y": 1.0},
	# The railway: a train runs the line (`move` "rail", see main.gd _trains), a car of it at a time to take
	"locomotive": {"points": 700, "weight": 5.0, "heat": 0.5, "move": "rail", "speed": 11.0, "size": 3.6, "tier": 3},
	"boxcar": {"points": 350, "weight": 4.0, "heat": 0.3, "move": "rail", "speed": 11.0, "size": 3.6, "tier": 2},
	"caboose": {"points": 400, "weight": 3.5, "heat": 0.3, "move": "rail", "speed": 11.0, "size": 3.0, "tier": 2},
	# (a length of the line: beamed up, the next train along comes off the rails there)
	"track": {"points": 120, "weight": 2.0, "heat": 0.4, "move": "still", "size": 3.0, "tier": 1},
	# Cowboys on horseback, about the plains and the rodeos
	"rider": {"points": 180, "weight": 2.0, "heat": 0.4, "move": "flee", "speed": 6.5, "size": 1.4, "voice": "neigh", "gun": "pistol", "caller": true},
	# A hot air balloon hanging over the fields, bobbing (`bob`)
	"balloon": {"points": 550, "weight": 2.0, "heat": 0.3, "move": "still", "size": 3.0, "rest_y": 8.0, "bob": true},
	# A wacky waving inflatable tube man, flailing (`wobble`)
	"tube_man": {"points": 90, "weight": 0.6, "heat": 0.05, "move": "still", "size": 0.8, "wobble": true},
	"gas_station": {"points": 450, "weight": 5.0, "heat": 0.5, "move": "still", "size": 5.0, "tier": 3, "voice": "scream"},
	"dealership": {"points": 500, "weight": 6.0, "heat": 0.5, "move": "still", "size": 6.0, "tier": 3, "voice": "scream"},
	"lot_car": {"model": "car", "points": 150, "weight": 2.6, "heat": 0.3, "move": "still", "size": 2.2},
	"schoolhouse": {"points": 400, "weight": 4.5, "heat": 0.5, "move": "still", "size": 4.5, "tier": 3},
	"playground": {"points": 140, "weight": 2.0, "heat": 0.2, "move": "still", "size": 3.0, "tier": 2},
	"crane": {"points": 500, "weight": 7.0, "heat": 0.4, "move": "still", "size": 3.0, "tier": 4},
	"excavator": {"points": 320, "weight": 3.5, "heat": 0.3, "move": "still", "size": 3.0, "tier": 2},
	"girders": {"points": 110, "weight": 2.5, "heat": 0.1, "move": "still", "size": 2.5},
	"mixer": {"points": 280, "weight": 3.5, "heat": 0.3, "move": "still", "size": 3.0, "tier": 2},
	"tire_stack": {"points": 20, "weight": 0.8, "heat": 0.02, "move": "still", "size": 0.8},
	"scrap_pile": {"points": 70, "weight": 2.5, "heat": 0.05, "move": "still", "size": 2.5, "tier": 2},
	"junk_car": {"model": "car", "tints": {"paint": Color(0.45, 0.22, 0.12)}, "points": 60, "weight": 2.6, "heat": 0.05, "move": "still", "size": 2.2},
	"bench": {"points": 15, "weight": 0.5, "heat": 0.02, "move": "still", "size": 1.0},
	"gazebo": {"points": 220, "weight": 3.5, "heat": 0.2, "move": "still", "size": 3.5, "tier": 3},
	"screen": {"points": 650, "weight": 7.0, "heat": 0.5, "move": "still", "size": 7.0, "tier": 4},
	"speaker_post": {"points": 10, "weight": 0.3, "heat": 0.02, "move": "still", "size": 0.5},
	"bleachers": {"points": 220, "weight": 3.5, "heat": 0.3, "move": "still", "size": 5.0, "tier": 3},
	"ferris_wheel": {"points": 1100, "weight": 7.0, "heat": 0.6, "move": "still", "size": 6.0, "tier": 4},
	"carousel": {"points": 800, "weight": 5.0, "heat": 0.5, "move": "still", "size": 4.5, "tier": 3},
	"circus_tent": {"points": 650, "weight": 5.0, "heat": 0.5, "move": "still", "size": 6.0, "tier": 3},
	"booth": {"points": 120, "weight": 1.8, "heat": 0.1, "move": "still", "size": 1.8, "tier": 2},
	# True believers: they want to be taken, and come running to the beam (`move` "believer")
	"believer": {"model": "person", "tints": {"shirt": Color(0.35, 0.8, 0.4)}, "points": 160, "weight": 1.3, "heat": 0.0, "move": "believer", "speed": 3.8, "size": 0.7, "voice": "star"},
	# Street furniture and roadside signs (scenery, drawn together: see World._plant_at)
	"street_light": {"points": 25, "weight": 1.0, "heat": 0.1, "move": "still", "size": 0.6},
	"lamp_post": {"points": 15, "weight": 0.6, "heat": 0.05, "move": "still", "size": 0.5},
	"road_sign": {"points": 15, "weight": 0.5, "heat": 0.05, "move": "still", "size": 0.5},
	"highway_sign": {"points": 60, "weight": 2.0, "heat": 0.2, "move": "still", "size": 2.0, "tier": 2},
	"trash_can": {"points": 10, "weight": 0.4, "heat": 0.02, "move": "still", "size": 0.5},
	"bush": {"points": 8, "weight": 0.5, "heat": 0.01, "move": "still", "size": 0.8},
	# Farming: grain elevators by the railway, coops, center-pivot irrigation over the fields, feed bins
	"grain_elevator": {"points": 1300, "weight": 8.0, "heat": 0.6, "move": "still", "size": 6.0, "tier": 4},
	"chicken_coop": {"points": 90, "weight": 1.5, "heat": 0.1, "move": "still", "size": 1.6, "tier": 2},
	"irrigation": {"points": 160, "weight": 3.0, "heat": 0.1, "move": "still", "size": 3.0, "tier": 2},
	"feed_bin": {"points": 140, "weight": 2.5, "heat": 0.1, "move": "still", "size": 1.8, "tier": 2},
	# Fire trucks and ambulances on the roads; hospitals and fire stations in town; prisons out in the
	# country, the inmates in orange in the yard
	"fire_truck": {"points": 420, "weight": 4.0, "heat": 0.5, "move": "road", "speed": 9.0, "size": 3.0, "tier": 2},
	"ambulance": {"points": 320, "weight": 3.0, "heat": 0.5, "move": "road", "speed": 10.0, "size": 2.6},
	# Money: hold the beam on one and its cash (or gold) comes out up the beam over `hold` seconds
	"bank": {"points": 800, "weight": 6.0, "heat": 0.8, "move": "still", "size": 4.0, "tier": 4, "voice": "scream", "cash": 3000.0, "hold": 5.0},
	"fort_knox": {"points": 5000, "weight": 12.0, "heat": 2.0, "move": "still", "size": 7.0, "tier": 5, "cash": 25000.0, "hold": 12.0, "gold": true},
	# A fire hydrant: taken (or blown up), a fountain of water bursts out of where it stood
	"hydrant": {"points": 30, "weight": 0.5, "heat": 0.05, "move": "still", "size": 0.5},
	"hospital": {"points": 900, "weight": 7.0, "heat": 0.8, "move": "still", "size": 6.0, "tier": 3, "voice": "scream"},
	"fire_station": {"points": 700, "weight": 6.0, "heat": 0.6, "move": "still", "size": 5.0, "tier": 3},
	"prison": {"points": 2500, "weight": 12.0, "heat": 1.0, "move": "still", "size": 12.0, "tier": 4, "voice": "scream"},
	"inmate": {"model": "person", "tints": {"shirt": Color(1.0, 0.5, 0.1), "denim": Color(1.0, 0.5, 0.1)}, "points": 150, "weight": 1.3, "heat": 0.3, "move": "graze", "speed": 2.2, "size": 0.7, "voice": "scream"},
	# Motorcycles (one model, painted for who rides it): riders on the roads, biker gangs riding in packs,
	# and motorcycle cops, quick, who chase and fire
	"motorcycle": {"tints": {"paint": Color(0.75, 0.12, 0.1)}, "points": 130, "weight": 1.6, "heat": 0.35, "move": "road", "speed": 12.0, "size": 1.2},
	"biker": {"model": "motorcycle", "tints": {"paint": Color(0.08, 0.08, 0.09), "shirt": Color(0.1, 0.1, 0.11), "denim": Color(0.15, 0.15, 0.2)}, "points": 170, "weight": 1.6, "heat": 0.4, "move": "road", "speed": 11.0, "size": 1.2},
	"moto_cop": {"model": "motorcycle", "tints": {"paint": Color(0.95, 0.95, 0.95), "shirt": Color(0.15, 0.25, 0.55)}, "points": 280, "weight": 1.6, "heat": 0.6, "move": "chase", "speed": 12.5, "size": 1.2, "keep": 9.0, "enemy": true, "police": true, "gun": "pistol", "slow_gun": 2.2},
	# A cult's compound: robed cultists round their altar, who want to be taken (as true believers do)
	"cultist": {"model": "person", "tints": {"shirt": Color(0.4, 0.15, 0.5), "denim": Color(0.4, 0.15, 0.5)}, "points": 180, "weight": 1.3, "heat": 0.1, "move": "believer", "speed": 3.0, "size": 0.7, "voice": "star"},
	"cult_altar": {"points": 800, "weight": 4.0, "heat": 0.3, "move": "still", "size": 3.0, "tier": 3},
	# What they bring out once the ship has held five stars long enough (see main.gd ESCALATE)
	"helicarrier": {"points": 5000, "weight": 15.0, "heat": 1.0, "move": "hover", "speed": 6.0, "size": 10.0, "tier": 4, "enemy": true, "gun": "railgun", "hover_up": 13.0},
	"railgun": {"points": 1200, "weight": 6.0, "heat": 0.8, "move": "chase", "speed": 0.5, "size": 3.0, "tier": 3, "keep": 30.0, "enemy": true, "gun": "railgun"},
	"laser_truck": {"points": 900, "weight": 5.0, "heat": 0.8, "move": "chase", "speed": 8.0, "size": 3.0, "tier": 3, "keep": 14.0, "enemy": true, "gun": "laser"},
	"goalpost": {"points": 60, "weight": 1.5, "heat": 0.1, "move": "still", "size": 1.5},
	# Players at a game: they run about the field (and scatter from the ship)
	"player": {"model": "person", "points": 110, "weight": 1.3, "heat": 0.35, "move": "graze", "speed": 4.5, "size": 0.7, "voice": "scream"},
	# Drink: liquor stores (worth a great deal), and coolers of beer left about
	"liquor_store": {"points": 1500, "weight": 5.0, "heat": 0.6, "move": "still", "size": 4.5, "tier": 3, "voice": "scream"},
	"cooler": {"points": 300, "weight": 0.5, "heat": 0.05, "move": "still", "size": 0.6},
	# Hunters, in blaze orange with rifles, out in the hills: they shoot at the ship whatever the heat
	"hunter": {"model": "person", "tints": {"shirt": Color(1.0, 0.45, 0.05), "denim": Color(0.3, 0.33, 0.2)}, "points": 140, "weight": 1.3, "heat": 0.4, "move": "flee", "speed": 3.4, "size": 0.7, "voice": "scream", "gun": "rifle", "hunter": true},
	"floodlight": {"points": 150, "weight": 2.5, "heat": 0.3, "move": "still", "size": 1.2, "tier": 3},
	# A trader's goods (see main.gd spawn_shop): beam one up to buy it
	"pod": {"points": 0, "weight": 0.9, "heat": 0.0, "move": "still", "size": 1.0},
	"canister": {"points": 0, "weight": 0.5, "heat": 0.0, "move": "still", "size": 0.8, "hover": true},
	# (the police cannot shoot from the car: they pull up and an officer gets out, see `_police`)
	"police_car": {"points": 300, "weight": 3.0, "heat": 0.6, "move": "police", "speed": 7.5, "size": 2.2, "keep": 10.0, "enemy": true, "police": true, "searchlight": true},
	"officer": {"model": "person", "tints": {"shirt": Color(0.15, 0.25, 0.55)}, "points": 150, "weight": 1.3, "heat": 0.5, "move": "guard", "speed": 3.4, "size": 0.7, "voice": "scream", "gun": "pistol", "enemy": true, "crew": true},
	# The men in black: a black sedan at three stars, agents in black suits getting out of it
	"agent_car": {"model": "car", "tints": {"paint": Color(0.06, 0.06, 0.08)}, "points": 500, "weight": 3.0, "heat": 0.7, "move": "police", "speed": 8.0, "size": 2.2, "keep": 11.0, "enemy": true, "police": true, "crew_kind": "agent"},
	"agent": {"model": "person", "tints": {"shirt": Color(0.05, 0.05, 0.06), "denim": Color(0.05, 0.05, 0.06)}, "points": 250, "weight": 1.3, "heat": 0.6, "move": "guard", "speed": 3.8, "size": 0.7, "voice": "scream", "gun": "ray", "enemy": true, "crew": true},
	# Over you at three stars and up, circling with a searchlight on you (it cannot be reached)
	"rival": {"title": "RIVAL SAUCER", "model": "ufo", "tints": {"metal": Color(0.5, 0.18, 0.55), "metal_dark": Color(0.25, 0.08, 0.3), "lights": Color(1.0, 0.3, 0.85), "lights_under": Color(1.0, 0.4, 0.9)}, "points": 0, "weight": 99.0, "heat": 0.0, "move": "rival", "speed": 8.5, "size": 4.2, "tier": 99},
	"helicopter": {"points": 900, "weight": 6.0, "heat": 0.5, "move": "hover", "speed": 9.0, "size": 2.6, "tier": 4, "enemy": true, "searchlight": true, "light_y": -0.4},
	# The army's Chinook, at four stars and up: two rotors, two searchlights and a door gunner
	"chinook": {"points": 1400, "weight": 8.0, "heat": 0.7, "move": "hover", "speed": 7.5, "size": 3.4, "tier": 4, "enemy": true, "searchlight": true, "lights": 2, "light_y": -0.2, "gun": "mg"},
	"jeep": {"points": 400, "weight": 3.4, "heat": 0.7, "move": "chase", "speed": 7.0, "size": 2.2, "gun": "mg", "keep": 12.0, "enemy": true},
	"tank": {"points": 800, "weight": 5.0, "heat": 1.0, "move": "chase", "speed": 4.0, "size": 3.0, "gun": "cannon", "keep": 16.0, "enemy": true},
}
# How far each gun reaches, and the pause between one go and the next
const GUNS := {
	"shotgun": {"range": 15.0, "reload": 2.6},
	"pistol": {"range": 20.0, "reload": 1.3},
	"rifle": {"range": 28.0, "reload": 2.4},
	"laser": {"range": 34.0, "reload": 1.2},
	"railgun": {"range": 48.0, "reload": 5.0},
	# (the men in black's: a ray gun, a glowing green bolt)
	"ray": {"range": 24.0, "reload": 1.6},
	"mg": {"range": 24.0, "reload": 4.5},
	"cannon": {"range": 30.0, "reload": 4.5},
}
const GRAVITY := 22.0
const SHIRTS: Array[Color] = [Color(0.8, 0.3, 0.25), Color(0.25, 0.5, 0.8), Color(0.85, 0.75, 0.3), Color(0.4, 0.65, 0.35), Color(0.7, 0.4, 0.7), Color(0.9, 0.9, 0.85)]

var game: Node
var kind := ""
var info := {}
var model: Node3D
var turret: Node3D
## "walk", "lifted", "falling", "gone"; or "drone", in the beam of one of the mini fleet (see Drone)
var state := "walk"
var lift := 0.0
var held := false
var heading := 0.0
var speed := 0.0
var home := Vector3.ZERO
## In a multiplayer game, where the host's game has it (see Coop), its heading, and when that was heard
## (INF: no word of it, it goes its own way)
var net_to := Vector3.INF
var net_turn := 0.0
var net_at := 0.0
var goal := Vector3.ZERO
var think := 0.0
var panic := 0.0
var fall_v := 0.0
var fall_from := 0.0
var spin := 0.0
var reload := 1.5
var burst := 0
var burst_time := 0.0
var leaving := false
var gun_node: Node3D
const NO_CHUNK := Vector2i(-999999, -999999)
## How much bigger or smaller than its model it stands
var base_size := 1.0
## The chunk of the world a building or scenery belongs to (it goes when the chunk does)
var chunk := NO_CHUNK
## For a landform: what it blocks in the world (x, z, radius, height), until it is taken
var obstacle := Vector4.ZERO
## How far from the beam's middle it can be and still be caught
var reach := 0.4
var fan: Node3D
## A part that turns about the upright (a carousel's floor and canopy)
var spin_part: Node3D
## People riding a carnival ride: in the Ferris wheel's cars (kept upright as it turns) or on the
## carousel's horses
var _riders: Array[Node3D] = []
const RIDER_SHIRTS: Array[Color] = [Color(0.8, 0.3, 0.25), Color(0.3, 0.5, 0.8), Color(0.9, 0.8, 0.3), Color(0.4, 0.7, 0.4), Color(0.8, 0.5, 0.8)]


func _seat_riders() -> void:
	if kind == "ferris_wheel" and fan != null:
		for i in range(0, 12, 2):
			var a := i / 12.0 * TAU
			_rider(fan, Vector3(cos(a) * 6.3, sin(a) * 6.3 - 1.05, 0.0))
	elif kind == "carousel" and spin_part != null:
		for i in range(0, 10, 2):
			var a := i / 10.0 * TAU
			_rider(spin_part, Vector3(3.0 * cos(a), 1.55 + 0.3 * (i % 2), -3.0 * sin(a)))


func _rider(on: Node3D, at: Vector3) -> void:
	var r := Ps1.model("person", {"shirt": RIDER_SHIRTS[randi() % RIDER_SHIRTS.size()]})
	r.scale = Vector3.ONE * 0.6
	r.position = at
	on.add_child(r)
	_riders.append(r)
## A helicopter's rotors
var rotors: Array[Node3D] = []
var tail_rotor: Node3D
var wings: Array[Node3D] = []
## How high a bird flies
var fly_y := 0.0
## A phone pole's wires to the next pole along, and where they go
var wires: Node3D
var wire_to := Vector3.INF
## A person who has seen the ship counts down to getting through to the police (see main.gd `phone_call`)
var calling := -1.0
## A person hiding from the ship in a building (`shelter`): out of sight, and out of the beam's reach
var hiding := false
var shelter: Thing
var _hid_for := 0.0
var _call_label: Label3D
## A cop not yet sure of what it saw: `alert` fills (0 to 1) while the ship is in sight, shown by the
## question mark over it (`_wonder`); full, and it gives chase
var alert := 0.0
var chasing := false
var _wonder: MeshInstance3D
var _wonder_mat: ShaderMaterial
var _wonder_pop := 0.0
const SIGHT := 45.0
const WONDER := preload("res://shaders/wonder.gdshader")
## The phone booth a caller runs to and calls from (see `witness`), and the way to its door; a
## booth's aerial (see Broadcast)
var booth: Thing
var _booth_way := Vector3.ZERO
var broadcast: Broadcast
## How far a caller will run to a phone booth
const BOOTH_REACH := 60.0
const STRIP := preload("res://shaders/searchlight.gdshader")
## The visual layer the beam's shadow-casting light shines on (the ground, and what is in the beam)
const BEAM_LAYER := 2
var _beam_lit := false
## How it was being carried up the beam, and, let go, how it flies on and tumbles
var _carry := Vector3.ZERO
var _toss := Vector3.ZERO
var _tumble := Vector3.ZERO
## A police car's light bar, red and blue
var _siren: Array[MeshInstance3D] = []
var beacon: MeshInstance3D
## How far its model sits off the ground (a jet on its wheels)
var model_y := 0.0
## A substation's power left; the parts that aim at the ship (a dish, an observatory's dome)
var power := 0.0
## A bank's (or Fort Knox's) money still in it, and how much has come out since it was last counted
var cash := 0.0
var robbed := 0.0
var aim: Node3D
## How long a watcher has had the ship in view
var watching := 0.0
var _rattling := false
## A pumpjack nods its beam
var beam_arm: Node3D
## A patrol's searchlight: the lamp turns on `light`, whose +Y is where it points
var light: Node3D
## An army truck's second searchlight
var light2: Node3D
var _sweep := 0.0
const LIGHT_LONG := 40.0
const LIGHT_WIDE := 5.5
## How near the ship must be for a searchlight to lock on to it (once there is heat)
const LIGHT_LOCK := 36.0
## For a car on the road: which way it goes (+1 or -1) and along which axis ("x" or "z")
var road_axis := "z"
var road_dir := 1.0
var _t := 0.0

## `extra` may give the model to wear ("model"), recolourings ("tints"), which way it faces ("turn"),
## its size ("size"), the chunk it belongs to ("chunk") and the obstacle it is in the world ("obstacle")
func setup(g: Node, k: String, at: Vector3, extra := {}) -> void:
	game = g
	kind = k
	info = KINDS[k]
	position = Vector3(at.x, 0.0, at.z)
	home = position
	goal = position
	heading = randf() * TAU
	_t = randf() * 10.0
	reload = randf_range(1.0, 2.5)
	var tints := {}
	if k in ["farmer", "person", "scarecrow", "cowboy"]:
		tints["shirt"] = SHIRTS[randi() % SHIRTS.size()]
	if k in ["car"]:
		tints["paint"] = Color.from_hsv(randf(), randf_range(0.4, 0.7), randf_range(0.5, 0.8))
	tints.merge(info.get("tints", {}), true)
	tints.merge(extra.get("tints", {}), true)
	model = Ps1.model(extra.get("model", info.get("model", k)), tints, true)
	add_child(model)
	if extra.has("turn"):
		heading = extra["turn"]
	base_size = extra.get("size", 1.0)
	if info["move"] == "hover":
		# (helicopters smaller, to sit at the saucer's own height without dwarfing it)
		base_size *= 0.6
	model.scale = Vector3.ONE * base_size
	model_y = info.get("rest_y", 0.0)
	model.position.y = model_y
	power = info.get("power", 0.0)
	cash = info.get("cash", 0.0)
	if kind == "rival":
		# (a rival saucer has a pilot of its own under its dome)
		var pilot := Alien.new()
		pilot.look_seed = randi()
		pilot.scale = Vector3.ONE * 0.9
		pilot.position.y = 0.3
		model.add_child(pilot)
	_roof_dish()
	aim = model.find_child("dish*", true, false) as Node3D
	if aim == null:
		aim = model.find_child("cupola*", true, false) as Node3D
	chunk = extra.get("chunk", NO_CHUNK)
	obstacle = extra.get("obstacle", Vector4.ZERO)
	reach = obstacle.z + 3.5 if obstacle != Vector4.ZERO else size() * 0.4 * base_size
	fan = model.find_child("fan*", true, false) as Node3D
	spin_part = model.find_child("spin*", true, false) as Node3D
	_seat_riders()
	wings = [model.find_child("wing_l*", true, false) as Node3D, model.find_child("wing_r*", true, false) as Node3D]
	if info["move"] == "hover":
		position.y = HOVER_Y
	rotors.assign(model.find_children("rotor*", "Node3D", true, false))
	tail_rotor = model.find_child("tail_rotor*", true, false) as Node3D
	if info["move"] == "fly":
		fly_y = randf_range(2.5, 6.0)
		position.y = fly_y
	if extra.has("wire_to"):
		_string_wires(extra["wire_to"])
	if info.get("rare", false):
		_beacon()
	turret = model.find_child("turret*", true, false) as Node3D
	beam_arm = model.find_child("beam*", true, false) as Node3D
	if info.get("model", k) == "police_car":
		# (the light bar, red and blue, flashing when they are after the ship: see `_flash_siren`)
		for side in 2:
			var lamp := Ps1.part(model, BoxMesh.new(), Ps1.flat(Color(1.0, 0.15, 0.1) if side == 0 else Color(0.2, 0.4, 1.0)), Vector3(-0.3 if side == 0 else 0.3, 1.5, -0.15), Vector3(0.56, 0.2, 0.36))
			lamp.visible = false
			_siren.append(lamp)
	if k == "phone_booth":
		broadcast = Broadcast.new()
		add_child(broadcast)
	# (a radio dish sends waves up off its dish while it tracks the ship: see main.gd _watchers)
	if k == "seti_dish" and aim != null:
		broadcast = Broadcast.new()
		broadcast.source = aim
		add_child(broadcast)
	if info.get("searchlight", false):
		_build_searchlight()
	if k == "officer":
		_build_flashlight()
	rotation.y = heading

func is_enemy() -> bool:
	return info.get("enemy", false)

func size() -> float:
	return info["size"]

func tier() -> int:
	return info.get("tier", 1)

## Buildings and scenery stay where they are until their chunk goes
func fixed() -> bool:
	return chunk != NO_CHUNK

func points() -> int:
	return info["points"]

## The ground point it stands on (y = 0), even while it is in the air
func ground() -> Vector3:
	return Vector3(position.x, 0.0, position.z)

func tick(delta: float, ufo: Ufo) -> void:
	_t += delta
	if calling > 0.0:
		calling -= delta
		_call_label.visible = fmod(_t, 0.5) < 0.35
		if calling <= 0.0:
			_call_label.visible = false
			game.phone_call(self)
			booth = null
	elif booth != null:
		_call_label.visible = fmod(_t, 0.5) < 0.35
	if not wings.is_empty() and wings[0] != null:
		var beat := sin(_t * (14.0 if state == "walk" else 24.0)) * 0.7
		wings[0].rotation.y = beat
		wings[1].rotation.y = -beat
	match state:
		"lifted":
			_rise(delta, ufo)
		"falling":
			_fall(delta)
		"walk":
			if stunned > 0.0:
				# (paralysed by an EMP: stock still, shaking, a spark off it now and then)
				stunned -= delta
				model.rotation.z = sin(_t * 40.0) * 0.06
				if randf() < delta * 4.0:
					game.ufo.puffs.spark(position + Vector3(0, 1.0, 0), Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2)), Color(0.55, 0.85, 1.0))
			else:
				_walk(delta, ufo)
	held = false

## Pulled up the beam toward the saucer, turning slowly and kicking its legs
func _rise(delta: float, ufo: Ufo) -> void:
	if not held:
		state = "falling"
		fall_v = 0.0
		# (let go, it flies on the way it was carried, and tumbles: a toss)
		_toss = Vector3(_carry.x, 0, _carry.z) * 1.4
		_tumble = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * minf(_toss.length() * 0.6, 8.0)
		fall_from = position.y
		Ps1.flash(model, Color.BLACK)
		if _beam_lit:
			_beam_lit = false
			_beam_layer(model, false)
		model.position.y = model_y
		return
	if calling > 0.0 or booth != null:
		# (taken before it gets through)
		calling = -1.0
		booth = null
		_call_label.visible = false
	if wires != null and wires.visible:
		wires.visible = false
		game.line_cut(self)
	if beacon != null:
		beacon.visible = false
	if obstacle != Vector4.ZERO:
		# (once the land is in the beam it no longer stands in the way)
		game.world.remove_obstacle(chunk, obstacle)
		obstacle = Vector4.ZERO
	lift += delta * ufo.lift_rate / float(info["weight"])
	# (up to just under the belly: it shrinks away into the ship from there, never into its hull)
	var top := ufo.position.y - 1.6
	var axis := ufo.beam_axis(position.y)
	var was := position
	position = position.lerp(axis, minf(delta * 3.0, 1.0))
	# (how it is being carried along, for it to fly on that way if let go: see `_fall`)
	_carry = _carry.lerp((position - was) / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
	position.y = lerpf(0.0, top, ease(clampf(lift, 0.0, 1.0), 1.6))
	if not _beam_lit:
		# (lit by the beam's own light, so it throws a shadow on the ground below: see Ufo.beam_light)
		_beam_lit = true
		_beam_layer(model, true)
	spin += delta * (1.5 + lift * 4.0)
	# (the big things shrink as they go up, to fit inside)
	var shrink := ease(clampf(lift, 0.0, 1.0), 0.6) if tier() >= 3 else smoothstep(0.7, 1.0, lift)
	model.scale = Vector3.ONE * base_size * maxf(lerpf(1.0, 0.0, shrink), 0.02)
	if tier() >= 3:
		_come_apart(delta, ufo, 1.0 - shrink)
	if info["move"] in ["peck", "graze", "flee", "fly"]:
		# People and animals panic: thrashing end over end, kicking, squirming
		model.rotation = Vector3(sin(_t * 17.0) * 0.7, spin * 1.6, cos(_t * 13.0) * 0.6)
		var squirm := sin(_t * 24.0) * 0.14
		model.scale *= Vector3(1.0 - squirm * 0.5, 1.0 + squirm, 1.0 - squirm * 0.5)
		model.position.y = model_y + absf(sin(_t * 11.0)) * 0.25
	else:
		model.rotation = Vector3(sin(_t * 7.0) * 0.25, spin, cos(_t * 6.0) * 0.25)
	Ps1.flash(model, Color(0.15, 0.4, 0.2) * (0.6 + 0.4 * sin(_t * 12.0)))
	if lift >= 1.0:
		game.abducted(self)

## Puts every mesh of `n` in (or out of) the layer the beam's shadow-casting light shines on, and has it
## cast a shadow (nothing else does)
func _beam_layer(n: Node, on: bool) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).set_layer_mask_value(BEAM_LAYER, on)
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_beam_layer(c, on)

func _fall(delta: float) -> void:
	fall_v -= GRAVITY * delta
	position.y += fall_v * delta
	position += _toss * delta
	_toss *= 1.0 - minf(delta * 0.4, 1.0)
	if _tumble.length() > 0.1:
		model.rotation += _tumble * delta
	else:
		model.rotation.x = lerpf(model.rotation.x, 0.0, delta * 3.0)
		model.rotation.z = lerpf(model.rotation.z, 0.0, delta * 3.0)
	if position.y <= 0.0:
		position.y = 0.0
		state = "walk"
		lift = 0.0
		model.rotation = Vector3(0, model.rotation.y, 0)
		model.scale = Vector3.ONE * base_size
		panic = 6.0
		var thrown := _toss.length()
		_toss = Vector3.ZERO
		_tumble = Vector3.ZERO
		position = game.world.push_out(position, size() * 0.5)
		# (and nothing walks on the water but what swims in it, nor anything that flies)
		if not info["move"] in ["swim", "hover", "rail", "road"] and position.y < 1.0:
			position = game.world.out_of_water(position, size() * 0.4)
		game.landed(self, fall_from, thrown)


func _walk(delta: float, ufo: Ufo) -> void:
	if net_to != Vector3.INF:
		# (another player's game is the one moving it: it goes where that says, see Coop)
		position = position.lerp(net_to, 1.0 - exp(-8.0 * delta))
		heading = lerp_angle(heading, net_turn, 1.0 - exp(-8.0 * delta))
		rotation.y = heading
		if Time.get_ticks_msec() / 1000.0 - net_at > 1.5:
			net_to = Vector3.INF
		return
	var here := ground()
	var to_ufo := ufo.ground() - here
	var near := to_ufo.length()
	if panic > 0.0:
		panic -= delta
	var want := Vector3.ZERO
	var pace: float = info.get("speed", 0.0)
	match info["move"]:
		"still":
			pace = 0.0
		"peck", "graze":
			# (set free, a prison broken: away from it as fast as they can go)
			if has_meta("free"):
				var from: Vector3 = get_meta("free")
				want = (here - Vector3(from.x, here.y, from.z)).normalized()
				pace *= 2.8
			elif near < 6.0 and ufo.beaming or panic > 0.0:
				# (startled by the light: off it goes)
				want = -to_ufo.normalized() if near > 0.01 else Vector3.FORWARD
				pace *= 2.2
			else:
				think -= delta
				if think <= 0.0:
					think = randf_range(1.5, 5.0)
					goal = home + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9)) if randf() < 0.6 else here
				if here.distance_to(goal) > 0.6:
					want = (goal - here).normalized()
		"flee":
			var gun: String = info.get("gun", "")
			var armed: bool = gun != "" and (game.heat_level() >= 1 or info.get("hunter", false)) and not leaving
			var to_wreck := Vector3(game.wreck.x, here.y, game.wreck.z) - here if game.wreck != Vector3.INF else Vector3.INF
			if info.get("caller", false) and not hiding and to_wreck != Vector3.INF and to_wreck.length() < 80.0 and not has_meta("forgot"):
				# (the saucer down: out they come to have a look, edging up and standing round it)
				var gap := to_wreck.length()
				heading = lerp_angle(heading, atan2(to_wreck.x, to_wreck.z), minf(delta * 4.0, 1.0))
				if gap > 7.0 + float(hash(get_instance_id()) % 5):
					want = to_wreck / gap
					pace *= 0.6
				else:
					pace = 0.0
			elif hiding:
				# (in a building, out of sight, till the ship has gone a while; out if it is taken)
				pace = 0.0
				if shelter == null or not is_instance_valid(shelter) or shelter.state != "walk":
					_come_out()
					panic = 2.0
				elif near > 30.0:
					_hid_for += delta
					if _hid_for > 4.0:
						_come_out()
				else:
					_hid_for = 0.0
			elif _to_booth():
				# (running for the phone booth, or on the phone in it: and frightened now, for good)
				set_meta("scared", true)
				want = _booth_way
				pace *= 1.5
				if want == Vector3.ZERO:
					pace = 0.0
					heading = lerp_angle(heading, atan2(booth.position.x - here.x, booth.position.z - here.z), minf(delta * 6.0, 1.0))
			elif armed and near < float(GUNS[gun]["range"]) + 4.0:
				# (a farmer or a cowboy with his blood up stands his ground and fires)
				_arm_gun()
				heading = lerp_angle(heading, atan2(to_ufo.x, to_ufo.z), minf(delta * 6.0, 1.0))
				_shoot(delta, ufo, near)
				pace = 0.0
			elif not has_meta("scared") and panic <= 0.0 and info.get("caller", false) and _curious(here, to_ufo, near):
				# (not yet frightened: curious, edging up to look at the ship, or at a crop circle)
				want = _curious_way
				pace *= 0.55
			elif near < 16.0 or panic > 0.0:
				# (frightened for good once something has given them a fright: see `_curious`)
				if panic > 0.0:
					set_meta("scared", true)
				# (a person makes for the nearest building to hide in it; else runs from the ship)
				if info.get("caller", false) and (shelter == null or not is_instance_valid(shelter)):
					shelter = game.nearest_shelter(here, 25.0)
				if shelter != null and is_instance_valid(shelter) and shelter.state == "walk":
					var to := shelter.position - here
					to.y = 0.0
					if to.length() < shelter.size() * 0.45 + 0.8:
						_hide()
					else:
						want = to.normalized()
						pace *= 1.2
				else:
					want = -to_ufo.normalized() if near > 0.01 else Vector3.FORWARD
			else:
				think -= delta
				if think <= 0.0:
					think = randf_range(2.0, 6.0)
					goal = home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				if here.distance_to(goal) > 0.6:
					want = (goal - here).normalized()
					pace *= 0.4
		"swim":
			# (round and round its pond, from one spot in it to another, never out of it)
			var lake: Vector3 = game.world.lake_at(home)
			if lake.z <= 0.0:
				pace = 0.0
			else:
				if _swim_to == Vector3.INF or here.distance_to(_swim_to) < 0.8 or randf() < delta * 0.15:
					var a := randf() * TAU
					var d := sqrt(randf()) * maxf(lake.z - 1.5, 0.5)
					_swim_to = Vector3(lake.x + cos(a) * d, 0, lake.y + sin(a) * d)
				want = (_swim_to - here).normalized()
				if near < 10.0:
					pace *= 1.8
		"road":
			want = _along_road()
		"rail":
			# (along the line it was put down on, the way it was going, never off it)
			want = Vector3(road_dir, 0, 0)
			if _derail < 0.0 and game.track_torn(position):
				# (the track beamed away from under it: off the rails it goes, ploughing to a stop on its side)
				_derail = 0.0
				_derail_side = 1.0 if randf() < 0.5 else -1.0
				game.boom(position + Vector3(0, 0.8, 0), 1.2 if kind == "locomotive" else 0.7)
			if _derail >= 0.0:
				_derail += delta
				want = Vector3(road_dir, 0, _derail_side * 0.8).normalized()
				pace *= maxf(1.0 - _derail / 1.6, 0.0)
				rotation.z = lerpf(rotation.z, _derail_side * 1.3, minf(delta * 2.5, 1.0))
			else:
				position.z = lerpf(position.z, home.z, minf(delta * 4.0, 1.0))
		"believer":
			want = _believe(delta, ufo, to_ufo, near)
			if want == Vector3.ZERO:
				pace = 0.0
			elif near < 30.0:
				pace *= 1.4
		"police":
			if _noticed(delta, ufo, near):
				pace = _police(delta, ufo, to_ufo, near, pace)
				want = _chase_want
			elif game.heat_level() >= 2:
				# (sent out after a report: making for where the ship was seen, looking for it)
				want = to_ufo.normalized()
				pace *= 0.7
			else:
				want = _along_road()
				pace *= 0.6
		"guard":
			pace = _guard(delta, ufo, to_ufo, near, pace)
			want = _chase_want
		"rival":
			pace = _rival(delta, here)
			want = _chase_want
		"hover":
			pace = _hover(delta, ufo, here)
			want = _chase_want
		"patrol":
			# (on the look-out until the police are after the ship, two stars, then after it too)
			if info.get("police", false) and (game.heat_level() >= 2 or leaving):
				# (a police patrol has to be sure first, see _noticed)
				if _noticed(delta, ufo, near):
					pace = _police(delta, ufo, to_ufo, near, pace)
					want = _chase_want
				else:
					want = _along_road()
			elif game.heat_level() >= 2 or leaving:
				pace = _chase(delta, ufo, to_ufo, near, pace)
				want = _chase_want
			else:
				# (cruising the road it is on)
				want = _along_road()
		"fly":
			if near < 10.0 or panic > 0.0:
				want = -to_ufo.normalized() if near > 0.01 else Vector3.FORWARD
				pace *= 2.0
			else:
				think -= delta
				if think <= 0.0 or here.distance_to(goal) < 2.0:
					think = randf_range(3.0, 7.0)
					goal = home + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
				want = (goal - here).normalized()
			position.y = lerpf(position.y, fly_y + sin(_t * 1.3) * 0.4, minf(delta * 1.5, 1.0))
		"chase":
			var keep: float = info["keep"]
			if leaving:
				want = -to_ufo.normalized()
			elif near > keep + 2.0:
				want = to_ufo.normalized()
			elif near < keep - 3.0:
				want = -to_ufo.normalized()
				pace *= 0.6
			else:
				# (in range: it circles to keep the saucer in its sights)
				want = Vector3(-to_ufo.z, 0, to_ufo.x).normalized() * 0.5
				pace *= 0.5
			if not leaving:
				_shoot(delta, ufo, near)
			if turret != null:
				var local: Vector3 = transform.basis.inverse() * to_ufo
				turret.rotation.y = lerp_angle(turret.rotation.y, atan2(local.x, local.z), minf(delta * 2.0, 1.0))
	if ufo.dead and game.wreck != Vector3.INF and info["move"] in ["police", "patrol", "chase"]:
		# (the ship down: they may circle the crash site, but never drive into the wreck itself)
		var off: Vector3 = here - game.wreck
		off.y = 0.0
		var ring := 7.0 + size()
		if off.length() < ring + 6.0:
			# (near it: round it on a ring, one way or the other, eased out if inside the ring and in if
			# beyond, rather than heading at it and turning back each moment)
			var out := off.normalized() if off.length() > 0.01 else Vector3.RIGHT
			var round_way := Vector3(-out.z, 0, out.x) * (1.0 if get_instance_id() % 2 == 0 else -1.0)
			var push := clampf((ring + 2.0 - off.length()) / 3.0, -0.6, 1.2)
			want = (round_way + out * push).normalized()
			pace = clampf(pace, float(info.get("speed", 0.0)) * 0.35, float(info.get("speed", 0.0)) * 0.55)
	if light != null:
		_aim_light(delta, ufo)
	var moving := want.length() > 0.01 and pace > 0.0
	speed = lerpf(speed, pace if moving else 0.0, minf(delta * 3.0, 1.0))
	if moving:
		var turn_rate := 2.0 if info["move"] in ["chase", "road"] else 6.0
		heading = lerp_angle(heading, atan2(want.x, want.z), minf(delta * turn_rate, 1.0))
	var step := Vector3(sin(heading), 0, cos(heading)) * speed * delta
	position += step
	if speed > 0.05:
		position = game.world.push_out(position, size() * 0.5)
		# (and nothing walks on the water but what swims in it, nor anything that flies)
		if not info["move"] in ["swim", "hover", "rail", "road"] and position.y < 1.0:
			position = game.world.out_of_water(position, size() * 0.4)
	rotation.y = heading
	_flash_siren()
	for r in rotors:
		r.rotation.y += delta * 22.0
	if tail_rotor != null:
		tail_rotor.rotation.x += delta * 30.0
	if fan != null:
		# (a Ferris wheel turns slowly, its riders kept upright; a windmill's fan quickly)
		fan.rotation.z += delta * (0.35 if kind == "ferris_wheel" else 3.0)
		for r: Node3D in _riders:
			if r.get_parent() == fan:
				r.rotation.z = -fan.rotation.z
	if beam_arm != null:
		beam_arm.rotation.x = sin(_t * 1.6) * 0.35
	# Walkers bob and waddle; anything on wheels only rocks a little
	var on_legs: bool = info["move"] in ["peck", "graze", "flee", "guard", "believer"] and kind != "tractor"
	if on_legs and speed > 0.2:
		model.position.y = absf(sin(_t * speed * 4.0)) * 0.12
		model.rotation.z = sin(_t * speed * 4.0) * 0.08
	elif kind == "chicken" and info["move"] == "peck" and speed < 0.2:
		model.rotation.x = maxf(sin(_t * 5.0), 0.0) * 0.6
	elif not _rattling:
		model.position = Vector3(0, model_y, 0)
		model.rotation.z = sin(_t * 3.0) * 0.01 * speed
	_rattling = false
	# (a true believer under the ship hops up and down for it; a tube man flails; a balloon bobs; a
	# carousel turns)
	if info["move"] == "believer" and speed < 0.2 and ufo.ground().distance_to(ground()) < 2.0:
		model.position.y = absf(sin(_t * 8.0)) * 0.35
	if info.get("wobble", false):
		model.rotation = Vector3(sin(_t * 5.3) * 0.22, 0.0, sin(_t * 7.1 + 1.0) * 0.32)
		model.scale.y = 1.0 + sin(_t * 9.0) * 0.06
	# (a fish swims just under the surface, its back showing, and now and then leaps clear; a frog hops)
	if info["move"] == "swim" and state == "walk":
		if _leap < 0.0 and randf() < delta * 0.08:
			_leap = 0.0
		if _leap >= 0.0:
			_leap += delta * 1.4
			model.position.y = 0.15 + sin(_leap * PI) * 1.2
			model.rotation.x = cos(_leap * PI) * -0.9
			if _leap >= 1.0:
				_leap = -1.0
				game.puff(position + Vector3(0, 0.2, 0), Color(0.7, 0.85, 1.0), 0.5)
		else:
			model.position.y = 0.15 + sin(_t * 3.0 + home.z) * 0.03
			model.rotation.x = 0.0
			model.rotation.z = sin(_t * 9.0) * 0.12
	if info.get("hops", false) and state == "walk" and speed > 0.2:
		model.position.y = absf(sin(_t * 7.0)) * 0.45
	# (a power-up hovers over the ground, spinning)
	if info.get("hover", false) and state == "walk":
		model.position.y = model_y + 1.0 + sin(_t * 2.2 + home.x) * 0.25
		model.rotation.y += delta * 2.4
	if info.get("bob", false):
		model.position.y = model_y + sin(_t * 0.8 + home.x) * 0.6
	if spin_part != null:
		spin_part.rotation.y += delta * 0.9
	if aim != null:
		_aim(delta, ufo)

var _chase_want := Vector3.ZERO
## Off the rails (seconds since, -1 while still on them), and which way it went over
var _derail := -1.0
var _derail_side := 1.0
## A fish's next spot in its pond; and how far through a leap out of the water it is (-1 if not)
var _swim_to := Vector3.INF
## Seconds left paralysed by an EMP (see main.gd `_emp`)
var stunned := 0.0
var _leap := -1.0
## A police car's officer out of it (see `_police`), and how many are still in it to get out; an
## officer's car, and whether it is called back to it
var officer: Thing
var crew := 1
var car: Thing
var recall := false
var _pulling_up := 0.0
var _far := 0.0
## A helicopter's way round the ship, how far out and how high
var _orbit := randf() * TAU
const HOVER_OUT := 15.0
const HOVER_Y := 15.0

## As "chase" moves: closes to its range, circles there, and fires (for a patrol once there is heat)
func _chase(delta: float, ufo: Ufo, to_ufo: Vector3, near: float, pace: float) -> float:
	var keep: float = info["keep"]
	if leaving:
		_chase_want = -to_ufo.normalized()
	elif near > keep + 2.0:
		_chase_want = to_ufo.normalized()
	elif near < keep - 3.0:
		_chase_want = -to_ufo.normalized()
		pace *= 0.6
	else:
		_chase_want = Vector3(-to_ufo.z, 0, to_ufo.x).normalized() * 0.5
		pace *= 0.5
	if not leaving:
		_shoot(delta, ufo, near)
	return pace

## A police car (or patrol): after the ship until it is in pistol range, then it pulls up and an
## officer gets out to shoot (the car cannot). If the ship gets well away, the officer gets back in
## and the car is off after it again; with its officer taken it can only follow.
func _police(delta: float, ufo: Ufo, to_ufo: Vector3, near: float, pace: float) -> float:
	var reach: float = GUNS["pistol"]["range"]
	if officer != null and (not is_instance_valid(officer) or officer.state != "walk"):
		officer = null
	if officer != null:
		# (pulled up, the officer out)
		_chase_want = Vector3.ZERO
		if near > reach + 8.0 or leaving:
			_far += delta
			officer.recall = _far > 1.2
		else:
			_far = 0.0
			officer.recall = false
		return 0.0
	if leaving:
		_chase_want = -to_ufo.normalized()
		return pace
	if crew > 0 and near < reach - 2.0:
		# (pulling up; once stopped, out gets the officer)
		_chase_want = Vector3.ZERO
		_pulling_up += delta
		if _pulling_up > 0.7 and speed < 0.5:
			_pulling_up = 0.0
			crew -= 1
			call_deferred("_get_out")
		return 0.0
	_pulling_up = 0.0
	var keep: float = info["keep"]
	if near > keep + 2.0:
		_chase_want = to_ufo.normalized()
	else:
		_chase_want = Vector3(-to_ufo.z, 0, to_ufo.x).normalized() * 0.5
		pace *= 0.5
	return pace


## A cop deciding whether it saw what it thinks it saw: true once it is sure and gives chase. Until
## then it cruises the road, a question mark over it filling while the ship is in sight (faster near,
## under the beam, or with more heat), draining when it is not.
func _noticed(delta: float, ufo: Ufo, near: float) -> bool:
	if chasing or leaving:
		_wonder_show(delta)
		return true
	var sight: float = SIGHT + 10.0 * game.heat_level()
	# (they see only what their light shows them: the ship has to be in its beam)
	var lit := light == null or _in_lamp(light, ufo, LIGHT_LONG, LIGHT_WIDE) or light2 != null and _in_lamp(light2, ufo, LIGHT_LONG, LIGHT_WIDE)
	if near < sight and not ufo.dead and lit:
		var rate: float = lerpf(0.75, 0.3, near / sight) * (1.6 if ufo.beaming else 1.0) * (1.0 + 0.6 * game.heat_level())
		alert = minf(alert + rate * delta, 1.0)
	else:
		alert = maxf(alert - 0.2 * delta, 0.0)
	if alert >= 1.0:
		chasing = true
		_wonder_pop = 1.0
		sfx_alert()
	_wonder_show(delta)
	return chasing


func sfx_alert() -> void:
	if game.has_method("spotted"):
		game.spotted(self, 0.0, "THE COPS ARE ON TO YOU!")


func _wonder_show(delta: float) -> void:
	if alert <= 0.0 and _wonder == null:
		return
	if _wonder == null:
		_wonder = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 2.4)
		_wonder.mesh = q
		_wonder_mat = ShaderMaterial.new()
		_wonder_mat.shader = WONDER
		_wonder_mat.render_priority = 3
		_wonder.material_override = _wonder_mat
		_wonder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wonder.position = Vector3(0, 4.2, 0)
		add_child(_wonder)
	_wonder_pop = maxf(_wonder_pop - delta * 2.5, 0.0)
	_wonder_mat.set_shader_parameter("fill", alert)
	_wonder_mat.set_shader_parameter("pop", sin(_wonder_pop * PI))
	_wonder_mat.set_shader_parameter("lit", Color(1.0, 0.25, 0.2) if chasing else Color(1.0, 0.85, 0.2))
	_wonder_mat.set_shader_parameter("bang", chasing)
	# (sure now: it shows a moment, then goes; unsure and calm again, it goes too)
	_wonder.visible = alert > 0.02 and (not chasing or _wonder_pop > 0.0)
## The officer out of the driver's door (once the frame's things have all been seen to)
func _get_out() -> void:
	if state != "walk" or not is_instance_valid(game):
		return
	var door := position + Vector3(cos(heading), 0, -sin(heading)) * 1.6
	officer = game.spawn(info.get("crew_kind", "officer"), door)
	officer.car = self
	officer.heading = heading

## An officer out of a police car: stands by it and shoots; called back, walks back and gets in;
## with the car gone, runs like anyone
func _guard(delta: float, ufo: Ufo, to_ufo: Vector3, near: float, pace: float) -> float:
	if car == null or not is_instance_valid(car) or car.state != "walk":
		car = null
		_chase_want = -to_ufo.normalized() if near > 0.01 else Vector3.FORWARD
		return pace * 1.2
	if recall:
		var door := car.position + Vector3(cos(car.heading), 0, -sin(car.heading)) * 1.6
		if ground().distance_to(door) < 0.8:
			car.officer = null
			car.crew += 1
			state = "gone"
			queue_free()
			return 0.0
		_chase_want = (door - ground()).normalized()
		return pace * 1.3
	_chase_want = Vector3.ZERO
	heading = lerp_angle(heading, atan2(to_ufo.x, to_ufo.z), minf(delta * 6.0, 1.0))
	# (an officer sees only by the flashlight, swung after the ship: no shot till it is lit)
	if flashlight != null:
		_aim_flashlight(delta, ufo)
		if not _in_lamp(flashlight, ufo, FLASH_LONG, FLASH_WIDE):
			return 0.0
	_shoot(delta, ufo, near)
	return 0.0


## An officer's flashlight: a little beam from the hand, swung after the ship (slower than it can
## dodge), sweeping about when it is not near
const FLASH_LONG := 18.0
const FLASH_WIDE := 2.4
var flashlight: Node3D


func _build_flashlight() -> void:
	flashlight = Node3D.new()
	flashlight.position = Vector3(0.3, 1.0, 0.2)
	add_child(flashlight)
	Ps1.part(flashlight, BoxMesh.new(), Ps1.flat(Color(1.0, 0.97, 0.85)), Vector3.ZERO, Vector3(0.12, 0.25, 0.12))
	light_strip(flashlight, Color(1.0, 0.95, 0.75), 0.55, FLASH_LONG, 0.08, FLASH_WIDE, 0.7)


func _aim_flashlight(delta: float, ufo: Ufo) -> void:
	var to := ufo.position - flashlight.global_position
	var want: Basis
	if to.length() < FLASH_LONG + 4.0 and not ufo.dead:
		want = Basis(Vector3.UP, atan2(to.x, to.z)) * Basis(Vector3.RIGHT, acos(clampf(to.normalized().y, -1.0, 1.0)))
	else:
		want = Basis(Vector3.UP, _t * 0.8) * Basis(Vector3.RIGHT, 0.9 + 0.3 * sin(_t * 0.7))
	flashlight.global_basis = flashlight.global_basis.slerp(want.orthonormalized(), minf(delta * 2.2, 1.0)).orthonormalized()


## Whether the ship is in a lamp's beam (along its +Y, `long` long, `wide` across at its end)
func _in_lamp(lamp: Node3D, ufo: Ufo, long: float, wide: float) -> bool:
	if lamp == null or not is_instance_valid(lamp) or ufo.dead:
		return false
	var to := ufo.position - lamp.global_position
	var axis := lamp.global_basis.y.normalized()
	var along := to.dot(axis)
	if along <= 0.0 or along > long:
		return false
	return (to - axis * along).length() < 0.2 + along * (wide / long) + ufo.radius * 0.6

## A helicopter (or a Chinook): circling the ship high up, its searchlight on it
func _hover(delta: float, ufo: Ufo, here: Vector3) -> float:
	_orbit += delta * 0.3
	var goal := ufo.ground() + Vector3(sin(_orbit), 0, cos(_orbit)) * HOVER_OUT
	if leaving:
		goal = here + (here - ufo.ground()).normalized() * 20.0
	# (at the saucer's own height, level with it)
	position.y = lerpf(position.y, ufo.position.y + float(info.get("hover_up", 0.0)), minf(delta * 0.8, 1.0))
	_chase_want = (goal - here).normalized() if here.distance_to(goal) > 1.0 else Vector3.ZERO
	# (an army Chinook's door gunner fires on the ship)
	if info.has("gun") and not leaving:
		_shoot(delta, ufo, Vector2(ufo.position.x - here.x, ufo.position.z - here.z).length())
	return float(info["speed"]) * clampf(here.distance_to(goal) / 6.0, 0.3, 1.0)

func _build_searchlight() -> void:
	# (an army truck has two, one either side, sweeping a little apart)
	var pair: bool = info.get("lights", 1) == 2
	for i in (2 if pair else 1):
		var lamp := Node3D.new()
		lamp.position = Vector3((-0.55 if i == 0 else 0.55) if pair else 0.0, info.get("light_y", 2.3), 0)
		add_child(lamp)
		Ps1.part(lamp, BoxMesh.new(), Ps1.flat(Color(1.0, 0.97, 0.85)), Vector3.ZERO, Vector3(0.45, 0.25, 0.45))
		# (the beam: a strip of light along the lamp's +Y, see searchlight.gdshader)
		light_strip(lamp, Color(1.0, 0.95, 0.75), 0.75, LIGHT_LONG, 0.3, LIGHT_WIDE, 0.85)
		if i == 0:
			light = lamp
		else:
			light2 = lamp
	_sweep = randf() * TAU
## Sweeps the sky with no heat; locks on to the ship with heat. Tells the game when the ship is in it.
func _aim_light(delta: float, ufo: Ufo) -> void:
	_sweep += delta * 0.7
	_aim_lamp(light, delta, ufo, 0.0)
	if light2 != null:
		_aim_lamp(light2, delta, ufo, 0.9)


## One searchlight: sweeping (the sky, or a guard tower's ground), or locked on to the ship once
## there is heat and it is near; the ship in its beam is spotted
func _aim_lamp(lamp: Node3D, delta: float, ufo: Ufo, apart: float) -> void:
	var yaw: float
	var tilt: float
	var to := ufo.position - lamp.global_position
	var guard: bool = info.get("guard", false)
	if (game.heat_level() >= 1 or guard) and not leaving and to.length() < LIGHT_LOCK:
		yaw = atan2(to.x, to.z) + apart * 0.08
		tilt = acos(clampf(to.normalized().y, -1.0, 1.0))
	else:
		yaw = _sweep + apart
		# (a guard tower sweeps the ground round the base; the rest sweep the sky)
		tilt = (1.95 + 0.3 * sin(_t * 0.37 + apart)) if guard else 0.55 + 0.35 * sin(_t * 0.37 + apart)
	# (the light is the world's way up, not the car's: the car turns under it)
	var want := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	lamp.global_basis = lamp.global_basis.slerp(want.orthonormalized(), minf(delta * 4.0, 1.0)).orthonormalized()
	var axis := lamp.global_basis.y.normalized()
	var along := to.dot(axis)
	if along > 0.0 and along < LIGHT_LONG and not ufo.dead:
		var off := (to - axis * along).length()
		if off < 0.2 + along * (LIGHT_WIDE / LIGHT_LONG) + ufo.radius * 0.6:
			game.spotted(self, delta)

## Too heavy for the beam that has hold of it: it shakes where it stands
func rattle() -> void:
	_rattling = true
	model.position = Vector3(randf_range(-0.1, 0.1), model_y + randf() * 0.08, randf_range(-0.1, 0.1))
	model.rotation.z = randf_range(-0.04, 0.04)

## A dish or an observatory turns to look at the ship when it is about
func _aim(delta: float, ufo: Ufo) -> void:
	var to: Vector3 = transform.basis.inverse() * (ufo.position - aim.global_position)
	if to.length() > 90.0:
		return
	var yaw := atan2(to.x, to.z)
	if aim.name.begins_with("dish"):
		var tilt := acos(clampf(to.normalized().y, -1.0, 1.0))
		aim.rotation.y = lerp_angle(aim.rotation.y, yaw, minf(delta * 1.5, 1.0))
		aim.rotation.x = lerpf(aim.rotation.x, clampf(tilt, 0.1, 1.4), minf(delta * 1.5, 1.0))
	else:
		aim.rotation.y = lerp_angle(aim.rotation.y, yaw, minf(delta * 0.8, 1.0))

## Starts for the phone to call the police (if it can phone, is not already, and is about): runs to
## the nearest phone booth and calls from it (see `_to_booth`), or with none near calls from where it
## is
func witness() -> void:
	if not info.get("caller", false) or calling > 0.0 or booth != null or state != "walk":
		return
	booth = game.nearest_booth(position, BOOTH_REACH)
	if booth == null:
		calling = 4.0 / sqrt(game.danger())
	_show_call()

## The "!" over a caller's head, flashing while it runs for the phone and while it calls
func _show_call() -> void:
	if _call_label == null:
		_call_label = Label3D.new()
		_call_label.text = "!"
		_call_label.font = game.font
		_call_label.font_size = 96
		_call_label.pixel_size = 0.02
		_call_label.modulate = Color(1.0, 0.3, 0.2)
		_call_label.outline_size = 14
		_call_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_call_label.no_depth_test = true
		_call_label.position = Vector3(0, 2.6, 0)
		add_child(_call_label)

## A caller's way to its phone booth's door (none once there, on the phone): true while it has one
## to go to or is calling from it. A booth taken (or gone) sends it looking for another
func _to_booth() -> bool:
	if booth == null:
		return false
	if not is_instance_valid(booth) or booth.state != "walk":
		booth = null
		if calling > 0.0:
			calling = -1.0
		witness()
		if booth == null and calling <= 0.0 and _call_label != null:
			_call_label.visible = false
		return booth != null
	var door := booth.position + Vector3(sin(booth.heading), 0, cos(booth.heading)) * 1.1
	_booth_way = Vector3.ZERO
	if calling > 0.0:
		booth.broadcast.keep(game.lines_down_near(booth.position))
	elif ground().distance_to(door) < 0.7:
		calling = 2.0 / sqrt(game.danger())
	else:
		_booth_way = (door - ground()).normalized()
	return true

func _string_wires(to: Vector3) -> void:
	wire_to = to
	wires = Node3D.new()
	add_child(wires)
	var a := Vector3(position.x, 6.95, position.z)
	var b := Vector3(to.x, 6.95, to.z)
	var across := (b - a).cross(Vector3.UP).normalized()
	var black := Ps1.flat(Color(0.05, 0.05, 0.06))
	for off: float in [-0.8, -0.3, 0.3, 0.8]:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = black
		var from := a + across * off
		var end := b + across * off
		mi.position = (from + end) * 0.5 - position + Vector3(0, -0.15, 0)
		mi.scale = Vector3(0.04, 0.04, from.distance_to(end))
		mi.look_at_from_position(mi.position, mi.position + (end - from), Vector3.UP)
		mi.scale = Vector3(0.04, 0.04, from.distance_to(end))
		wires.add_child(mi)
	# (the wires belong to the world, not to the pole's turning)
	wires.top_level = false

## A tall shaft of gold light over a rare find, so it can be seen from far off
func _beacon() -> void:
	beacon = light_strip(self, Color(1.0, 0.8, 0.3), 0.8, 40.0, 0.9, 0.6, 1.0)

func _arm_gun() -> void:
	if gun_node != null:
		return
	if info.get("gun", "") == "ray":
		# (a silver ray gun, its tip glowing green)
		gun_node = Ps1.part(model, BoxMesh.new(), Ps1.mat(Color(0.75, 0.78, 0.82)), Vector3(0.27, 0.72, 0.2), Vector3(0.08, 0.08, 0.4), Vector3(-0.7, 0, 0))
		Ps1.part(gun_node, Ps1.ball(), Ps1.own(Color(0.3, 1.0, 0.5), 2.0), Vector3(0, 0, 0.6), Vector3(1.2, 1.2, 0.3))
		return
	gun_node = Ps1.part(model, BoxMesh.new(), Ps1.mat(Color(0.15, 0.12, 0.1)), Vector3(0.27, 0.72, 0.25), Vector3(0.05, 0.05, 0.6), Vector3(-0.7, 0, 0))

func _shoot(delta: float, ufo: Ufo, near: float) -> void:
	var gun: String = info.get("gun", "")
	if gun == "" or ufo.dead or ufo.cloak > 0.0:
		return
	var spec: Dictionary = GUNS[gun]
	if burst > 0:
		burst_time -= delta
		if burst_time <= 0.0:
			burst -= 1
			burst_time = 0.1
			game.fire(self, gun, ufo)
		return
	reload -= delta
	if reload > 0.0 or near > float(spec["range"]):
		return
	reload = float(spec["reload"]) * float(info.get("slow_gun", 1.0)) * randf_range(0.85, 1.2) / pow(game.danger(), 0.6)
	if gun == "mg":
		burst = 3
		burst_time = 0.0
	else:
		game.fire(self, gun, ufo)

## Where shots leave it from
func muzzle() -> Vector3:
	match kind:
		"farmer", "cowboy", "officer", "agent":
			return global_position + Vector3(0, 0.85, 0)
		"tank":
			return global_position + Vector3(0, 1.9, 0)
		"jeep":
			return global_position + Vector3(0, 2.1, 0)
	return global_position + Vector3(0, 1.4, 0)

## A beam of light from a lamp at `parent`'s origin along its +Y, `reach` long, `lamp_width` across
## at the lamp and `far_width` at its end, faded to nothing `fade_at` of the way along: a strip that
## turns about the beam to face the camera, so no mesh shows (searchlight.gdshader)
static func light_strip(parent: Node3D, tint: Color, power: float, reach: float, lamp_width: float, far_width: float, fade_at: float) -> MeshInstance3D:
	var strip := QuadMesh.new()
	strip.subdivide_depth = 10
	var m := ShaderMaterial.new()
	m.shader = STRIP
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("reach", reach)
	m.set_shader_parameter("lamp_width", lamp_width)
	m.set_shader_parameter("far_width", far_width)
	m.set_shader_parameter("fade_at", fade_at)
	var mi := MeshInstance3D.new()
	mi.mesh = strip
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = reach + far_width
	parent.add_child(mi)
	return mi


## The way along the road it is on, keeping to its lane (on the right) as the road bends: toward
## its lane a few metres ahead
## Someone not yet frightened, curious: a crop circle near draws them to stand round its edge looking
## in; the ship near, to stand a way off looking up at it. Whether there is anything to be curious
## about (and the way to go, `_curious_way`, none once there). A beam on close by frightens them.
var _curious_way := Vector3.ZERO


func _curious(here: Vector3, to_ufo: Vector3, near: float) -> bool:
	_curious_way = Vector3.ZERO
	var ufo: Ufo = game.ufo
	if not ufo.dead and near < 8.0 and ufo.beaming:
		set_meta("scared", true)
		return false
	var keep := float(hash(get_instance_id()) % 5)
	if not ufo.dead and near < 40.0:
		heading = lerp_angle(heading, atan2(to_ufo.x, to_ufo.z), 0.1)
		if near > 11.0 + keep:
			_curious_way = to_ufo / near
		return true
	var circle: Vector3 = game.world.nearest_circle(here, 45.0)
	if circle != Vector3.INF:
		var middle := Vector3(circle.x, 0, circle.z)
		var out := here - middle
		out.y = 0.0
		var spot := middle + (out.normalized() if out.length() > 0.1 else Vector3.FORWARD) * (circle.y + 1.5 + keep * 0.4)
		if here.distance_to(spot) > 1.0:
			_curious_way = (spot - here).normalized()
		else:
			heading = lerp_angle(heading, atan2(middle.x - here.x, middle.z - here.z), 0.1)
		return true
	return false


## A true believer: they want to be taken. The ship near, they run to stand under it, arms up, hopping
## (and shout for it once); else they wander about waiting
func _believe(delta: float, ufo: Ufo, to_ufo: Vector3, near: float) -> Vector3:
	if not ufo.dead and near < 45.0:
		if not has_meta("shouted") and near < 25.0:
			set_meta("shouted", true)
			game._popup(["TAKE ME!", "OVER HERE!", "I BELIEVE!", "BEAM ME UP!"][randi() % 4], position + Vector3(0, 2.4, 0), Color(0.5, 1.0, 0.55))
		if near > 1.2:
			heading = lerp_angle(heading, atan2(to_ufo.x, to_ufo.z), minf(delta * 6.0, 1.0))
			return to_ufo / near
		return Vector3.ZERO
	think -= delta
	if think <= 0.0:
		think = randf_range(2.0, 6.0)
		goal = home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
	return (goal - ground()).normalized() if ground().distance_to(goal) > 0.6 else Vector3.ZERO


func _along_road() -> Vector3:
	var lane := (1.0 if World.dirt_x(roundi(position.x / World.CHUNK / World.ROAD_EVERY) * World.ROAD_EVERY) else 1.5) if road_axis == "z" \
		else (1.0 if World.dirt_z(roundi(position.z / World.CHUNK / World.ROAD_EVERY) * World.ROAD_EVERY) else 1.5)
	var ahead: Vector3
	if road_axis == "z":
		var n := roundi(position.x / (World.CHUNK * World.ROAD_EVERY)) * World.ROAD_EVERY
		var z := position.z + road_dir * 5.0
		ahead = Vector3(World.road_x(n, z) + lane * road_dir, 0, z)
	else:
		var m := roundi(position.z / (World.CHUNK * World.ROAD_EVERY)) * World.ROAD_EVERY
		var x := position.x + road_dir * 5.0
		ahead = Vector3(x, 0, World.road_z(m, x) - lane * road_dir)
	return (ahead - ground()).normalized()


## A police car's light bar flashing red and blue while they are after the ship (two stars and up,
## or chasing it anyway); dark otherwise
func _flash_siren() -> void:
	if _siren.is_empty():
		return
	var on: bool = not leaving and chasing
	var red := fmod(_t, 0.5) < 0.25
	_siren[0].visible = on and red
	_siren[1].visible = on and not red


## Throws a shadow in the beam's light (or stops): see Main._beam_shadows
func shade(on: bool) -> void:
	if on == _beam_lit:
		return
	_beam_lit = on
	_beam_layer(model, on)


func _hide() -> void:
	hiding = true
	_hid_for = 0.0
	visible = false
	if _call_label != null:
		_call_label.visible = false


func _come_out() -> void:
	hiding = false
	visible = true
	if shelter != null and is_instance_valid(shelter):
		var a := randf() * TAU
		position = shelter.position + Vector3(cos(a), 0, sin(a)) * (shelter.size() * 0.45 + 1.0)
		position.y = 0.0
	shelter = null


# ------------------------------------------------------------------ a rival saucer
# Another ship out abducting: it drifts over the country after small game (animals, people), takes
# them up its own pink beam, and after a few, or a while, goes. Fly into it and you bounce off; dash
# into it and it spins away and drops what it had.

const RIVAL_Y := 8.5
const RIVAL_TAKES := 4
var _prey: Thing
var _taken_by_rival := 0
var _rival_beam: Node3D
var _rival_life := 0.0
var _rival_spin := 1.0
var knock := Vector3.ZERO


func _rival(delta: float, here: Vector3) -> float:
	_rival_life += delta
	if _rival_beam == null:
		_rival_beam = Node3D.new()
		_rival_beam.rotation.x = PI
		_rival_beam.position.y = -0.4
		add_child(_rival_beam)
		light_strip(_rival_beam, Color(1.0, 0.35, 0.85), 0.9, RIVAL_Y, 1.2, 3.2, 0.95)
	position += knock * delta
	knock = knock.lerp(Vector3.ZERO, minf(delta * 2.0, 1.0))
	_rival_spin = lerpf(_rival_spin, 1.0, minf(delta * 0.8, 1.0))
	model.rotation.y += delta * 2.5 * _rival_spin
	if _taken_by_rival >= RIVAL_TAKES or _rival_life > 60.0:
		leaving = true
	if leaving:
		_drop_prey()
		_rival_beam.visible = false
		position.y += delta * 6.0
		_chase_want = Vector3(sin(heading), 0, cos(heading))
		if position.y > 45.0:
			game.remove_thing(self)
		return float(info["speed"]) * 1.5
	position.y = lerpf(position.y, RIVAL_Y + sin(_t * 1.4) * 0.3, minf(delta * 1.2, 1.0))
	if _prey != null and (not is_instance_valid(_prey) or not _prey.state in ["walk", "stolen"]):
		_prey = null
	if _prey == null:
		_rival_beam.visible = false
		_prey = game.rival_prey(here, 45.0)
		if _prey == null:
			# (nothing about: off it drifts)
			think -= delta
			if think <= 0.0:
				think = 3.0
				goal = here + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
			_chase_want = (goal - here).normalized()
			return float(info["speed"]) * 0.6
	var to := _prey.position - here
	to.y = 0.0
	if _prey.state == "walk" and to.length() > 1.2:
		_rival_beam.visible = false
		_chase_want = to.normalized()
		return float(info["speed"]) * clampf(to.length() / 6.0, 0.3, 1.0)
	# (over it: the beam on, up it goes, and it is gone)
	_chase_want = Vector3.ZERO
	_rival_beam.visible = true
	_prey.state = "stolen"
	_prey.position = _prey.position.move_toward(Vector3(here.x, position.y - 1.0, here.z), delta * 3.5)
	_prey.rotation.y += delta * 3.0
	if _prey.position.y > position.y - 1.6:
		game.stolen_by_rival(_prey)
		_prey = null
		_taken_by_rival += 1
	return 0.0


## Rammed by the player's dash: knocked away spinning, letting go of what it had in its beam
func rammed(away: Vector3) -> void:
	knock = away * 18.0
	_rival_spin = 6.0
	_drop_prey()


func _drop_prey() -> void:
	if _prey != null and is_instance_valid(_prey) and _prey.state == "stolen":
		_prey.state = "falling"
		_prey.fall_v = 0.0
		_prey.fall_from = _prey.position.y
	_prey = null
	if _rival_beam != null:
		_rival_beam.visible = false


## Roofs that may carry a little satellite dish, which turns to follow the ship like the big ones
const DISH_ROOFS := ["house", "farmhouse", "storefront", "diner", "cabin", "police_station"]


## About one roof in three gets a little dish, on the ridge (the same roofs every time)
func _roof_dish() -> void:
	if not kind in DISH_ROOFS or World.hash3(roundi(position.x), roundi(position.z), 171) > 0.33:
		return
	var box := AABB()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := (model.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
	var dish := Ps1.model("seti_dish")
	dish.scale = Vector3.ONE * 0.07
	dish.position = Vector3(box.get_center().x, box.end.y - 0.2, box.get_center().z)
	model.add_child(dish)


## What the pilot calls everything (the log, the results, the field guide): Earth as an alien
## naturalist would put it
const ALIEN_NAMES := {
	"chicken": "BEAKED EGG-LAYER", "sheep": "WOOL CLOUD", "pig": "MUD SNORTER", "cow": "MILK BEAST",
	"hay_bale": "GRASS BRICK", "hay_pile": "GRASS HEAP", "barrel": "BOOM CAN", "scarecrow": "STRAW EARTHLING",
	"outhouse": "WASTE SHRINE", "farmer": "SOIL EARTHLING", "person": "EARTHLING", "camper": "TENT EARTHLING",
	"hiker": "WANDERING EARTHLING", "stargazer": "SKY WATCHER", "telescope": "PRIMITIVE EYE TUBE",
	"tractor": "DIRT CRAWLER", "car": "GROUND POD", "pickup": "CARGO POD", "horse": "RIDING BEAST",
	"bison": "SHAGGY GRAZER", "longhorn": "HORNED MILK BEAST", "coyote": "YIP HOUND", "cowboy": "HAT EARTHLING",
	"bear": "FUR TITAN", "mountain_goat": "CLIFF HOPPER", "elk": "ANTLER BEAST", "pronghorn": "SPEED GRAZER",
	"rabbit": "LONG-EAR", "trout": "SPOTTED SWIMMER", "bass": "BIG-MOUTH WIGGLER", "catfish": "WHISKER SLIME", "koi": "ORANGE POND JEWEL", "frog": "GREEN HOPPER", "roadrunner": "MEEP BIRD", "crow": "BLACK SQUAWKER", "hawk": "SKY HUNTER",
	"phone_pole": "TALK STICK", "phone_booth": "TALK BOX", "saguaro": "SPIKE COLUMN", "pumpjack": "OIL NODDER",
	"rv": "DWELLING POD", "patrol_car": "LAW POD", "patrol_jeep": "WAR CRAWLER", "sagebrush": "DRY TUFT",
	"prickly_pear": "SPIKE PADDLE", "fence": "SMALL WALL", "tree": "LEAF TOWER", "pine": "NEEDLE TOWER",
	"aspen": "GOLD LEAF TOWER", "pinyon": "SCRUB TOWER", "willow": "WEEPING TOWER", "cottonwood": "FLUFF TOWER", "joshua_tree": "SPIKY ARM TOWER", "rock": "PLANET CRUMB", "camp_tent": "CLOTH HUT",
	"house": "EARTHLING NEST", "farmhouse": "BIG NEST", "storefront": "TRADE NEST", "clock_tower": "TIME SPIRE",
	"city_hall": "HIVE CENTRE", "fountain": "WATER TOY", "church": "SONG HALL", "control_tower": "SKY WATCH SPIRE",
	"plane": "SLOW SKY POD", "wheat": "GOLD STALK", "corn": "EAR STALK", "pumpkin": "ORANGE ORB",
	"hill": "LAND LUMP", "barn": "BEAST NEST", "silo": "GRAIN TUBE", "windmill": "SPIN FLOWER",
	"water_tower": "WATER BULB", "diner": "FUEL NEST", "adobe": "MUD NEST", "cabin": "LOG NEST",
	"butte": "ROCK STUMP", "mesa": "ROCK TABLE", "peak": "PLANET SPIKE", "crag": "SKY FANG", "devils_tower": "THE GREAT STUMP",
	"police_station": "LAW HIVE", "hangar": "POD BARN", "watchtower": "STARE SPIRE", "tent": "WAR HUT",
	"fighter_jet": "FAST SKY POD", "parked_jeep": "WAR CRAWLER", "parked_tank": "SHELL CRAWLER",
	"substation": "SPARK GARDEN", "observatory": "SKY WATCH DOME", "seti_dish": "LISTENING BOWL",
	"floodlight": "LIGHT STALK", "police_car": "LAW POD", "officer": "LAW EARTHLING", "agent_car": "SHADOW POD",
	"agent": "SHADOW EARTHLING", "helicopter": "WHIRL POD", "chinook": "DOUBLE WHIRL POD", "jeep": "WAR CRAWLER",
	"tank": "SHELL CRAWLER", "jet": "FAST SKY POD", "golden_cow": "GOLDEN MILK BEAST", "jackalope": "HORNED LONG-EAR",
	"sasquatch": "COUSIN", "meteorite": "SPACE PEBBLE", "satellite": "PRIMITIVE PROBE", "crash_site": "LOST COUSIN SHIP", "rival": "RIVAL SAUCER",
}


## What the pilot calls a kind of thing
static func alien_name(of: String) -> String:
	return ALIEN_NAMES.get(of, of.replace("_", " ").to_upper())


# ------------------------------------------------------------------ coming apart in the beam

## The colours a big thing is made of (taken from its model's corners), for the pieces it sheds
var _pieces: PackedColorArray = PackedColorArray()
var _piece_wait := 0.0


## A building or a landform going up the beam comes apart as it goes: pieces of it in its own colours
## (boards, shingles, rock) breaking off all over it and flying up into the ship ahead of it, as
## what is left of it shrinks away (`left`, 1 whole to 0 gone)
func _come_apart(delta: float, ufo: Ufo, left: float) -> void:
	if _pieces.is_empty():
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			var cs = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			if cs is PackedColorArray:
				for i in range(0, cs.size(), maxi(cs.size() / 24, 1)):
					_pieces.append((cs[i] as Color).linear_to_srgb())
		if _pieces.is_empty():
			_pieces.append(Color(0.6, 0.6, 0.6))
	_piece_wait -= delta
	if _piece_wait > 0.0 or left <= 0.05:
		return
	_piece_wait = 0.05
	var reach := size() * base_size * 0.5 * left
	var at := position + Vector3(randf_range(-reach, reach), randf_range(0.2, reach * 1.6), randf_range(-reach, reach))
	var up := (ufo.position - at).normalized()
	var c := _pieces[randi() % _pieces.size()]
	ufo.puffs.chip(at, up * randf_range(5.0, 9.0) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), c, randf_range(0.2, 0.55) * clampf(base_size, 0.6, 1.5), -2.0, 0.8)


## The categories of things taken, as the log and the results group them, in this order
const CATEGORIES := ["EARTHLINGS", "BEASTS", "CROPS", "PLANTS", "MACHINES", "BUILDINGS", "THE LAND", "RARE FINDS", "OTHER"]


## Which of CATEGORIES a kind of thing is in
static func category(of: String) -> String:
	if not KINDS.has(of):
		return "OTHER"
	var info: Dictionary = KINDS[of]
	if info.get("rare", false) or of in ["golden_cow", "jackalope", "sasquatch", "meteorite", "satellite", "crash_site"]:
		return "RARE FINDS"
	if info.get("caller", false) or info.get("enemy", false) and info["move"] == "guard" or of in ["scarecrow", "believer", "hunter", "player", "cultist", "inmate"]:
		return "EARTHLINGS"
	if of in ["wheat", "corn", "pumpkin", "sunflower", "cabbage", "melon", "pepper", "hay_bale", "hay_pile"]:
		return "CROPS"
	if info["move"] in ["graze", "peck", "flee", "fly"]:
		return "BEASTS"
	if of in ["tree", "pine", "aspen", "pinyon", "willow", "cottonwood", "joshua_tree", "sagebrush", "prickly_pear", "saguaro", "bush"]:
		return "PLANTS"
	if of in ["butte", "mesa", "peak", "crag", "devils_tower", "hill", "rock"]:
		return "THE LAND"
	if info["move"] in ["road", "police", "patrol", "hover", "rail"] or info.get("enemy", false) or of in ["tractor", "pumpjack", "windmill", "plane", "telescope", "barrel", "phone_booth", "phone_pole", "irrigation", "lot_car", "junk_car", "excavator", "mixer", "crane", "tube_man", "balloon"]:
		return "MACHINES"
	if int(info.get("tier", 1)) >= 3:
		return "BUILDINGS"
	return "OTHER"


## The same thing's name on every player's device (the world is made from the same seed): its kind
## and where it was put down
func net_key() -> String:
	return "%s@%d,%d" % [kind, roundi(home.x * 2.0), roundi(home.z * 2.0)]
