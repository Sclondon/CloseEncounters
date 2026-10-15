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
	"scarecrow": {"points": 40, "weight": 1.0, "heat": 0.06, "move": "still", "size": 0.8},
	"outhouse": {"points": 90, "weight": 2.2, "heat": 0.2, "move": "still", "size": 1.2, "voice": "scream"},
	"farmer": {"points": 100, "weight": 1.3, "heat": 0.4, "move": "flee", "speed": 3.4, "size": 0.7, "voice": "scream", "gun": "shotgun", "caller": true},
	"person": {"points": 100, "weight": 1.3, "heat": 0.35, "move": "flee", "speed": 3.6, "size": 0.7, "voice": "scream", "caller": true},
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
	"saguaro": {"points": 30, "weight": 1.3, "heat": 0.03, "move": "still", "size": 0.8},
	"pumpjack": {"points": 160, "weight": 3.0, "heat": 0.25, "move": "still", "size": 2.0},
	"rv": {"points": 220, "weight": 3.2, "heat": 0.4, "move": "road", "speed": 7.0, "size": 2.6},
	# On patrol whatever the heat, sweeping a searchlight over the sky: be caught in it and the heat
	# goes up. Once there is heat they lock the light on and come after the ship like the rest.
	"patrol_car": {"model": "police_car", "points": 300, "weight": 3.0, "heat": 0.6, "move": "patrol", "speed": 6.0, "size": 2.2, "keep": 10.0, "enemy": true, "searchlight": true, "police": true},
	"patrol_jeep": {"model": "jeep", "points": 400, "weight": 3.4, "heat": 0.7, "move": "patrol", "speed": 5.5, "size": 2.2, "gun": "mg", "keep": 12.0, "enemy": true, "searchlight": true},
	# Scenery, pulled out of the ground (tier 1 and 2)
	"sagebrush": {"points": 5, "weight": 0.5, "heat": 0.01, "move": "still", "size": 0.8},
	"prickly_pear": {"points": 10, "weight": 0.6, "heat": 0.01, "move": "still", "size": 0.8},
	"fence": {"points": 5, "weight": 0.6, "heat": 0.01, "move": "still", "size": 1.5},
	"tree": {"points": 25, "weight": 1.6, "heat": 0.03, "move": "still", "size": 1.5, "tier": 2},
	"pine": {"points": 25, "weight": 1.6, "heat": 0.03, "move": "still", "size": 1.5, "tier": 2},
	"aspen": {"points": 25, "weight": 1.4, "heat": 0.03, "move": "still", "size": 1.4, "tier": 2},
	"pinyon": {"points": 20, "weight": 1.2, "heat": 0.03, "move": "still", "size": 1.4, "tier": 2},
	"rock": {"points": 30, "weight": 1.8, "heat": 0.03, "move": "still", "size": 1.5, "tier": 2},
	"camp_tent": {"points": 40, "weight": 1.0, "heat": 0.1, "move": "still", "size": 1.5, "tier": 2, "voice": "scream"},
	# Buildings (tier 3)
	"house": {"points": 250, "weight": 4.0, "heat": 0.5, "move": "still", "size": 3.0, "tier": 3, "voice": "scream"},
	"farmhouse": {"points": 300, "weight": 4.5, "heat": 0.5, "move": "still", "size": 3.0, "tier": 3, "voice": "scream"},
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
	"devils_tower": {"points": 5000, "weight": 12.0, "heat": 2.0, "move": "still", "size": 2.0, "tier": 4},
	# The law, the army, and those who watch the sky (tier 3, but for the jets and the parked ones)
	"police_station": {"points": 600, "weight": 5.0, "heat": 0.8, "move": "still", "size": 4.0, "tier": 3, "station": "police"},
	"hangar": {"points": 800, "weight": 6.0, "heat": 0.8, "move": "still", "size": 5.0, "tier": 3, "station": "army"},
	"watchtower": {"points": 300, "weight": 4.0, "heat": 0.5, "move": "still", "size": 2.0, "tier": 3, "searchlight": true, "light_y": 9.0, "station": "army"},
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
	"captured_orb": {"title": "YOU FOUND THE ORB: IT'S YOURS", "model": "orb", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 2.5, "rare": true, "unlock": "orb", "rest_y": 1.5},
	"captured_triangle": {"title": "YOU FOUND THE TRIANGLE: IT'S YOURS", "model": "triangle", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 3.0, "rare": true, "unlock": "triangle", "rest_y": 0.6},
	"captured_foo": {"title": "YOU FOUND THE FOO: IT'S YOURS", "model": "foo", "points": 3000, "weight": 2.0, "heat": 1.5, "move": "still", "size": 1.5, "rare": true, "unlock": "foo", "rest_y": 0.9},
	"captured_cigar": {"title": "YOU FOUND THE CIGAR: IT'S YOURS", "model": "cigar", "points": 3000, "weight": 3.5, "heat": 1.5, "move": "still", "size": 3.5, "rare": true, "unlock": "cigar", "rest_y": 1.05},
	"captured_bell": {"title": "YOU FOUND THE BELL: IT'S YOURS", "model": "bell", "points": 3000, "weight": 3.0, "heat": 1.5, "move": "still", "size": 2.8, "rare": true, "unlock": "bell", "rest_y": 0.72},
	"floodlight": {"points": 150, "weight": 2.5, "heat": 0.3, "move": "still", "size": 1.2, "tier": 3},
	# A trader's goods (see main.gd spawn_shop): beam one up to buy it
	"pod": {"points": 0, "weight": 0.9, "heat": 0.0, "move": "still", "size": 1.0},
	# (the police cannot shoot from the car: they pull up and an officer gets out, see `_police`)
	"police_car": {"points": 300, "weight": 3.0, "heat": 0.6, "move": "police", "speed": 7.5, "size": 2.2, "keep": 10.0, "enemy": true, "police": true},
	"officer": {"model": "person", "tints": {"shirt": Color(0.15, 0.25, 0.55)}, "points": 150, "weight": 1.3, "heat": 0.5, "move": "guard", "speed": 3.4, "size": 0.7, "voice": "scream", "gun": "pistol", "enemy": true, "crew": true},
	# The men in black: a black sedan at three stars, agents in black suits getting out of it
	"agent_car": {"model": "car", "tints": {"paint": Color(0.06, 0.06, 0.08)}, "points": 500, "weight": 3.0, "heat": 0.7, "move": "police", "speed": 8.0, "size": 2.2, "keep": 11.0, "enemy": true, "police": true, "crew_kind": "agent"},
	"agent": {"model": "person", "tints": {"shirt": Color(0.05, 0.05, 0.06), "denim": Color(0.05, 0.05, 0.06)}, "points": 250, "weight": 1.3, "heat": 0.6, "move": "guard", "speed": 3.8, "size": 0.7, "voice": "scream", "gun": "pistol", "enemy": true, "crew": true},
	# Over you at three stars and up, circling with a searchlight on you (it cannot be reached)
	"helicopter": {"points": 900, "weight": 6.0, "heat": 0.5, "move": "hover", "speed": 9.0, "size": 2.6, "tier": 4, "enemy": true, "searchlight": true, "light_y": -0.4},
	"jeep": {"points": 400, "weight": 3.4, "heat": 0.7, "move": "chase", "speed": 7.0, "size": 2.2, "gun": "mg", "keep": 12.0, "enemy": true},
	"tank": {"points": 800, "weight": 5.0, "heat": 1.0, "move": "chase", "speed": 4.0, "size": 3.0, "gun": "cannon", "keep": 16.0, "enemy": true},
}
# How far each gun reaches, and the pause between one go and the next
const GUNS := {
	"shotgun": {"range": 15.0, "reload": 2.6},
	"pistol": {"range": 20.0, "reload": 1.3},
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
## A helicopter's rotors
var rotor: Node3D
var tail_rotor: Node3D
var wings: Array[Node3D] = []
## How high a bird flies
var fly_y := 0.0
## A phone pole's wires to the next pole along, and where they go
var wires: Node3D
var wire_to := Vector3.INF
## A person who has seen the ship counts down to getting through to the police (see main.gd `phone_call`)
var calling := -1.0
var _call_label: Label3D
## The phone booth a caller runs to and calls from (see `witness`), and the way to its door; a
## booth's aerial (see Broadcast)
var booth: Thing
var _booth_way := Vector3.ZERO
var broadcast: Broadcast
## How far a caller will run to a phone booth
const BOOTH_REACH := 60.0
## The visual layer the beam's shadow-casting light shines on (the ground, and what is in the beam)
const BEAM_LAYER := 2
var _beam_lit := false
var beacon: MeshInstance3D
## How far its model sits off the ground (a jet on its wheels)
var model_y := 0.0
## A substation's power left; the parts that aim at the ship (a dish, an observatory's dome)
var power := 0.0
var aim: Node3D
## How long a watcher has had the ship in view
var watching := 0.0
var _rattling := false
## A pumpjack nods its beam
var beam_arm: Node3D
## A patrol's searchlight: the lamp turns on `light`, whose +Y is where it points
var light: Node3D
var _sweep := 0.0
const LIGHT_LONG := 28.0
const LIGHT_WIDE := 3.2
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
	model.scale = Vector3.ONE * base_size
	model_y = info.get("rest_y", 0.0)
	model.position.y = model_y
	power = info.get("power", 0.0)
	aim = model.find_child("dish*", true, false) as Node3D
	if aim == null:
		aim = model.find_child("cupola*", true, false) as Node3D
	chunk = extra.get("chunk", NO_CHUNK)
	obstacle = extra.get("obstacle", Vector4.ZERO)
	reach = obstacle.z + 3.5 if obstacle != Vector4.ZERO else size() * 0.4 * base_size
	fan = model.find_child("fan*", true, false) as Node3D
	wings = [model.find_child("wing_l*", true, false) as Node3D, model.find_child("wing_r*", true, false) as Node3D]
	if info["move"] == "hover":
		position.y = HOVER_Y
	rotor = model.find_child("rotor*", true, false) as Node3D
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
	if k == "phone_booth":
		broadcast = Broadcast.new()
		add_child(broadcast)
	if info.get("searchlight", false):
		_build_searchlight()
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
			_walk(delta, ufo)
	held = false


## Pulled up the beam toward the saucer, turning slowly and kicking its legs
func _rise(delta: float, ufo: Ufo) -> void:
	if not held:
		state = "falling"
		fall_v = 0.0
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
	var top := ufo.position.y - 0.9
	var axis := ufo.beam_axis(position.y)
	position = position.lerp(axis, minf(delta * 3.0, 1.0))
	position.y = lerpf(0.0, top, ease(clampf(lift, 0.0, 1.0), 1.6))
	if not _beam_lit:
		# (lit by the beam's own light, so it throws a shadow on the ground below: see Ufo.beam_light)
		_beam_lit = true
		_beam_layer(model, true)
	spin += delta * (1.5 + lift * 4.0)
	# (the big things shrink as they go up, to fit inside)
	var shrink := ease(clampf(lift, 0.0, 1.0), 0.6) if tier() >= 3 else clampf((lift - 0.8) / 0.2, 0.0, 1.0)
	model.scale = Vector3.ONE * base_size * lerpf(1.0, 0.3 if tier() < 3 else 0.12, shrink)
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
	model.rotation.x = lerpf(model.rotation.x, 0.0, delta * 3.0)
	model.rotation.z = lerpf(model.rotation.z, 0.0, delta * 3.0)
	if position.y <= 0.0:
		position.y = 0.0
		state = "walk"
		lift = 0.0
		model.rotation = Vector3.ZERO
		model.scale = Vector3.ONE * base_size
		panic = 6.0
		game.landed(self, fall_from)


func _walk(delta: float, ufo: Ufo) -> void:
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
			if near < 6.0 and ufo.beaming or panic > 0.0:
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
			var armed: bool = gun != "" and game.heat_level() >= 1 and not leaving
			if _to_booth():
				# (running for the phone booth, or on the phone in it)
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
			elif near < 16.0 or panic > 0.0:
				want = -to_ufo.normalized() if near > 0.01 else Vector3.FORWARD
			else:
				think -= delta
				if think <= 0.0:
					think = randf_range(2.0, 6.0)
					goal = home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				if here.distance_to(goal) > 0.6:
					want = (goal - here).normalized()
					pace *= 0.4
		"road":
			want = Vector3(0, 0, road_dir) if road_axis == "z" else Vector3(road_dir, 0, 0)
		"police":
			pace = _police(delta, ufo, to_ufo, near, pace)
			want = _chase_want
		"guard":
			pace = _guard(delta, ufo, to_ufo, near, pace)
			want = _chase_want
		"hover":
			pace = _hover(delta, ufo, here)
			want = _chase_want
		"patrol":
			# (on the look-out until the police are after the ship, two stars, then after it too)
			if game.heat_level() >= 2 or leaving:
				pace = _police(delta, ufo, to_ufo, near, pace) if info.get("police", false) else _chase(delta, ufo, to_ufo, near, pace)
				want = _chase_want
			else:
				think -= delta
				if think <= 0.0 or here.distance_to(goal) < 3.0:
					think = randf_range(6.0, 12.0)
					var a := randf() * TAU
					goal = here + Vector3(sin(a), 0, cos(a)) * randf_range(20.0, 40.0)
				want = (goal - here).normalized()
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
	rotation.y = heading
	if rotor != null:
		rotor.rotation.y += delta * 22.0
	if tail_rotor != null:
		tail_rotor.rotation.x += delta * 30.0
	if fan != null:
		fan.rotation.z += delta * 3.0
	if beam_arm != null:
		beam_arm.rotation.x = sin(_t * 1.6) * 0.35
	# Walkers bob and waddle; anything on wheels only rocks a little
	var on_legs: bool = info["move"] in ["peck", "graze", "flee", "guard"] and kind != "tractor"
	if on_legs and speed > 0.2:
		model.position.y = absf(sin(_t * speed * 4.0)) * 0.12
		model.rotation.z = sin(_t * speed * 4.0) * 0.08
	elif kind == "chicken" and info["move"] == "peck" and speed < 0.2:
		model.rotation.x = maxf(sin(_t * 5.0), 0.0) * 0.6
	elif not _rattling:
		model.position = Vector3(0, model_y, 0)
		model.rotation.z = sin(_t * 3.0) * 0.01 * speed
	_rattling = false
	if aim != null:
		_aim(delta, ufo)


var _chase_want := Vector3.ZERO
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
	_shoot(delta, ufo, near)
	return 0.0


## A helicopter: circling the ship high up, its searchlight on it
func _hover(delta: float, ufo: Ufo, here: Vector3) -> float:
	_orbit += delta * 0.3
	var goal := ufo.ground() + Vector3(sin(_orbit), 0, cos(_orbit)) * HOVER_OUT
	if leaving:
		goal = here + (here - ufo.ground()).normalized() * 20.0
	position.y = lerpf(position.y, HOVER_Y, minf(delta * 0.8, 1.0))
	_chase_want = (goal - here).normalized() if here.distance_to(goal) > 1.0 else Vector3.ZERO
	return float(info["speed"]) * clampf(here.distance_to(goal) / 6.0, 0.3, 1.0)

func _build_searchlight() -> void:
	light = Node3D.new()
	light.position = Vector3(0, info.get("light_y", 2.3), 0)
	add_child(light)
	Ps1.part(light, BoxMesh.new(), Ps1.flat(Color(1.0, 0.97, 0.85)), Vector3.ZERO, Vector3(0.45, 0.25, 0.45))
	var cone := CylinderMesh.new()
	cone.top_radius = LIGHT_WIDE
	cone.bottom_radius = 0.2
	cone.height = LIGHT_LONG
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/beam.gdshader")
	m.set_shader_parameter("tint", Color(1.0, 0.95, 0.75))
	m.set_shader_parameter("power", 0.7)
	m.set_shader_parameter("soft", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.material_override = m
	mi.position.y = LIGHT_LONG * 0.5
	light.add_child(mi)
	_sweep = randf() * TAU


## Sweeps the sky with no heat; locks on to the ship with heat. Tells the game when the ship is in it.
func _aim_light(delta: float, ufo: Ufo) -> void:
	var yaw: float
	var tilt: float
	var to := ufo.position - light.global_position
	if game.heat_level() >= 1 and not leaving and to.length() < LIGHT_LONG * 1.3:
		yaw = atan2(to.x, to.z)
		tilt = acos(clampf(to.normalized().y, -1.0, 1.0))
	else:
		_sweep += delta * 0.7
		yaw = _sweep
		tilt = 0.55 + 0.35 * sin(_t * 0.37)
	# (the light is the world's way up, not the car's: the car turns under it)
	var want := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	light.global_basis = light.global_basis.slerp(want.orthonormalized(), minf(delta * 4.0, 1.0)).orthonormalized()
	var axis := light.global_basis.y.normalized()
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
	beacon = MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.6
	shaft.bottom_radius = 0.9
	shaft.height = 40.0
	shaft.radial_segments = 8
	shaft.cap_top = false
	shaft.cap_bottom = false
	beacon.mesh = shaft
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/beam.gdshader")
	m.set_shader_parameter("tint", Color(1.0, 0.8, 0.3))
	m.set_shader_parameter("power", 0.8)
	m.set_shader_parameter("soft", 1.0)
	beacon.material_override = m
	beacon.position.y = 20.0
	beacon.extra_cull_margin = 60.0
	add_child(beacon)


func _arm_gun() -> void:
	if gun_node != null:
		return
	gun_node = Ps1.part(model, BoxMesh.new(), Ps1.mat(Color(0.15, 0.12, 0.1)), Vector3(0.18, 1.35, 0.35), Vector3(0.06, 0.06, 0.8), Vector3(-0.7, 0, 0))


func _shoot(delta: float, ufo: Ufo, near: float) -> void:
	var gun: String = info.get("gun", "")
	if gun == "" or ufo.dead:
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
	reload = float(spec["reload"]) * randf_range(0.85, 1.2) / pow(game.danger(), 0.6)
	if gun == "mg":
		burst = 3
		burst_time = 0.0
	else:
		game.fire(self, gun, ufo)


## Where shots leave it from
func muzzle() -> Vector3:
	match kind:
		"farmer", "cowboy", "officer", "agent":
			return global_position + Vector3(0, 1.5, 0)
		"tank":
			return global_position + Vector3(0, 1.9, 0)
		"jeep":
			return global_position + Vector3(0, 2.1, 0)
	return global_position + Vector3(0, 1.4, 0)
