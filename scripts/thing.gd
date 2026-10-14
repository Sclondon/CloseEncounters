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
	"chicken": {"points": 10, "weight": 0.7, "heat": 0.06, "move": "peck", "speed": 1.6, "size": 0.5, "voice": "cluck"},
	"sheep": {"points": 25, "weight": 1.1, "heat": 0.08, "move": "graze", "speed": 1.3, "size": 0.9, "voice": "baa"},
	"pig": {"points": 30, "weight": 1.2, "heat": 0.08, "move": "graze", "speed": 1.3, "size": 0.9, "voice": "oink"},
	"cow": {"points": 50, "weight": 1.7, "heat": 0.12, "move": "graze", "speed": 1.0, "size": 1.3, "voice": "moo"},
	"hay_bale": {"points": 15, "weight": 1.0, "heat": 0.04, "move": "still", "size": 1.0},
	"scarecrow": {"points": 40, "weight": 1.0, "heat": 0.06, "move": "still", "size": 0.8},
	"outhouse": {"points": 90, "weight": 2.2, "heat": 0.2, "move": "still", "size": 1.2, "voice": "scream"},
	"farmer": {"points": 100, "weight": 1.3, "heat": 0.4, "move": "flee", "speed": 3.4, "size": 0.7, "voice": "scream", "gun": "shotgun"},
	"person": {"points": 100, "weight": 1.3, "heat": 0.35, "move": "flee", "speed": 3.6, "size": 0.7, "voice": "scream"},
	"tractor": {"points": 150, "weight": 2.6, "heat": 0.3, "move": "graze", "speed": 1.5, "size": 2.0},
	"car": {"points": 150, "weight": 2.6, "heat": 0.4, "move": "road", "speed": 9.0, "size": 2.2},
	"pickup": {"points": 180, "weight": 2.9, "heat": 0.4, "move": "road", "speed": 8.0, "size": 2.4},
	# The West
	"horse": {"points": 60, "weight": 1.6, "heat": 0.1, "move": "graze", "speed": 1.8, "size": 1.3, "voice": "neigh"},
	"bison": {"points": 120, "weight": 2.6, "heat": 0.15, "move": "graze", "speed": 1.0, "size": 1.6, "voice": "moo"},
	"longhorn": {"points": 70, "weight": 1.9, "heat": 0.12, "move": "graze", "speed": 1.0, "size": 1.4, "voice": "moo"},
	"coyote": {"points": 45, "weight": 0.9, "heat": 0.06, "move": "flee", "speed": 5.0, "size": 0.8, "voice": "howl"},
	"cowboy": {"points": 110, "weight": 1.3, "heat": 0.4, "move": "flee", "speed": 3.4, "size": 0.7, "voice": "scream", "gun": "pistol"},
	"saguaro": {"points": 30, "weight": 1.3, "heat": 0.03, "move": "still", "size": 0.8},
	"pumpjack": {"points": 160, "weight": 3.0, "heat": 0.25, "move": "still", "size": 2.0},
	"rv": {"points": 220, "weight": 3.2, "heat": 0.4, "move": "road", "speed": 7.0, "size": 2.6},
	# On patrol whatever the heat, sweeping a searchlight over the sky: be caught in it and the heat
	# goes up. Once there is heat they lock the light on and come after the ship like the rest.
	"patrol_car": {"model": "police_car", "points": 300, "weight": 3.0, "heat": 0.6, "move": "patrol", "speed": 6.0, "size": 2.2, "gun": "pistol", "keep": 10.0, "enemy": true, "searchlight": true},
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
	"police_car": {"points": 300, "weight": 3.0, "heat": 0.6, "move": "chase", "speed": 7.5, "size": 2.2, "gun": "pistol", "keep": 10.0, "enemy": true},
	"jeep": {"points": 400, "weight": 3.4, "heat": 0.7, "move": "chase", "speed": 7.0, "size": 2.2, "gun": "mg", "keep": 12.0, "enemy": true},
	"tank": {"points": 800, "weight": 5.0, "heat": 1.0, "move": "chase", "speed": 4.0, "size": 3.0, "gun": "cannon", "keep": 16.0, "enemy": true},
}
# How far each gun reaches, and the pause between one go and the next
const GUNS := {
	"shotgun": {"range": 15.0, "reload": 2.6},
	"pistol": {"range": 20.0, "reload": 1.3},
	"mg": {"range": 24.0, "reload": 3.0},
	"cannon": {"range": 30.0, "reload": 4.5},
}
const GRAVITY := 22.0
const SHIRTS: Array[Color] = [Color(0.8, 0.3, 0.25), Color(0.25, 0.5, 0.8), Color(0.85, 0.75, 0.3), Color(0.4, 0.65, 0.35), Color(0.7, 0.4, 0.7), Color(0.9, 0.9, 0.85)]

var game: Node
var kind := ""
var info := {}
var model: Node3D
var turret: Node3D
## "walk", "lifted", "falling", "gone"
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
	tints.merge(extra.get("tints", {}), true)
	model = Ps1.model(extra.get("model", info.get("model", k)), tints, true)
	add_child(model)
	if extra.has("turn"):
		heading = extra["turn"]
	base_size = extra.get("size", 1.0)
	model.scale = Vector3.ONE * base_size
	chunk = extra.get("chunk", NO_CHUNK)
	obstacle = extra.get("obstacle", Vector4.ZERO)
	reach = obstacle.z + 3.5 if obstacle != Vector4.ZERO else size() * 0.4 * base_size
	fan = model.find_child("fan", true, false) as Node3D
	turret = model.find_child("turret", true, false) as Node3D
	beam_arm = model.find_child("beam", true, false) as Node3D
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
		return
	if obstacle != Vector4.ZERO:
		# (once the land is in the beam it no longer stands in the way)
		game.world.remove_obstacle(chunk, obstacle)
		obstacle = Vector4.ZERO
	lift += delta * ufo.lift_rate / float(info["weight"])
	var top := ufo.position.y - 0.9
	var axis := Vector3(ufo.position.x, position.y, ufo.position.z)
	position = position.lerp(axis, minf(delta * 3.0, 1.0))
	position.y = lerpf(0.0, top, ease(clampf(lift, 0.0, 1.0), 1.6))
	spin += delta * (1.5 + lift * 4.0)
	model.rotation = Vector3(sin(_t * 7.0) * 0.25, spin, cos(_t * 6.0) * 0.25)
	# (the big things shrink as they go up, to fit inside)
	var shrink := ease(clampf(lift, 0.0, 1.0), 0.6) if tier() >= 3 else clampf((lift - 0.8) / 0.2, 0.0, 1.0)
	model.scale = Vector3.ONE * base_size * lerpf(1.0, 0.3 if tier() < 3 else 0.12, shrink)
	Ps1.flash(model, Color(0.15, 0.4, 0.2) * (0.6 + 0.4 * sin(_t * 12.0)))
	if lift >= 1.0:
		game.abducted(self)


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
			if armed and near < float(GUNS[gun]["range"]) + 4.0:
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
		"patrol":
			if game.heat_level() >= 1 or leaving:
				pace = _chase(delta, ufo, to_ufo, near, pace)
				want = _chase_want
			else:
				think -= delta
				if think <= 0.0 or here.distance_to(goal) < 3.0:
					think = randf_range(6.0, 12.0)
					var a := randf() * TAU
					goal = here + Vector3(sin(a), 0, cos(a)) * randf_range(20.0, 40.0)
				want = (goal - here).normalized()
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
	if fan != null:
		fan.rotation.z += delta * 3.0
	if beam_arm != null:
		beam_arm.rotation.x = sin(_t * 1.6) * 0.35
	# Walkers bob and waddle; anything on wheels only rocks a little
	var on_legs: bool = info["move"] in ["peck", "graze", "flee"] and kind != "tractor"
	if on_legs and speed > 0.2:
		model.position.y = absf(sin(_t * speed * 4.0)) * 0.12
		model.rotation.z = sin(_t * speed * 4.0) * 0.08
	elif kind == "chicken" and info["move"] == "peck" and speed < 0.2:
		model.rotation.x = maxf(sin(_t * 5.0), 0.0) * 0.6
	else:
		model.position.y = 0.0
		model.rotation.z = sin(_t * 3.0) * 0.01 * speed


var _chase_want := Vector3.ZERO


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


func _build_searchlight() -> void:
	light = Node3D.new()
	light.position = Vector3(0, 2.3, 0)
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
	m.set_shader_parameter("power", 0.5)
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
	reload = float(spec["reload"]) * randf_range(0.85, 1.2)
	if gun == "mg":
		burst = 6
		burst_time = 0.0
	else:
		game.fire(self, gun, ufo)


## Where shots leave it from
func muzzle() -> Vector3:
	match kind:
		"farmer", "cowboy":
			return global_position + Vector3(0, 1.5, 0)
		"tank":
			return global_position + Vector3(0, 1.9, 0)
		"jeep":
			return global_position + Vector3(0, 2.1, 0)
	return global_position + Vector3(0, 1.4, 0)
