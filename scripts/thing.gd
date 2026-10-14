class_name Thing
extends Node3D
## Anything on the ground that the beam can take: animals, people, things about the farm, cars,
## and the police and army who come after the saucer. Each kind is a row of KINDS. The game moves
## them all through `tick` (no _process of their own).
##
## A thing in the beam rises (slower the heavier it is: `weight` is the seconds it takes) and is
## taken when it reaches the saucer. Let go of before then, it falls; dropped from high enough on
## one of the police or army, it crushes them.

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
	"police_car": {"points": 300, "weight": 3.0, "heat": 0.6, "move": "chase", "speed": 11.0, "size": 2.2, "gun": "pistol", "keep": 10.0, "enemy": true},
	"jeep": {"points": 400, "weight": 3.4, "heat": 0.7, "move": "chase", "speed": 10.0, "size": 2.2, "gun": "mg", "keep": 12.0, "enemy": true},
	"tank": {"points": 800, "weight": 5.0, "heat": 1.0, "move": "chase", "speed": 5.0, "size": 3.0, "gun": "cannon", "keep": 16.0, "enemy": true},
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
## For a car on the road: which way it goes (+1 or -1) and along which axis ("x" or "z")
var road_axis := "z"
var road_dir := 1.0
var _t := 0.0


func setup(g: Node, k: String, at: Vector3) -> void:
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
	if k in ["farmer", "person", "scarecrow"]:
		tints["shirt"] = SHIRTS[randi() % SHIRTS.size()]
	if k in ["car"]:
		tints["paint"] = Color.from_hsv(randf(), randf_range(0.4, 0.7), randf_range(0.5, 0.8))
	model = Ps1.model(k, tints, true)
	add_child(model)
	turret = model.find_child("turret", true, false) as Node3D
	rotation.y = heading


func is_enemy() -> bool:
	return info.get("enemy", false)


func size() -> float:
	return info["size"]


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
	lift += delta / float(info["weight"])
	var top := ufo.position.y - 0.9
	var axis := Vector3(ufo.position.x, position.y, ufo.position.z)
	position = position.lerp(axis, minf(delta * 3.0, 1.0))
	position.y = lerpf(0.0, top, ease(clampf(lift, 0.0, 1.0), 1.6))
	spin += delta * (1.5 + lift * 4.0)
	model.rotation = Vector3(sin(_t * 7.0) * 0.25, spin, cos(_t * 6.0) * 0.25)
	model.scale = Vector3.ONE * lerpf(1.0, 0.35, clampf((lift - 0.8) / 0.2, 0.0, 1.0))
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
		model.scale = Vector3.ONE
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
			var armed: bool = kind == "farmer" and game.heat_level() >= 1 and not leaving
			if armed and near < GUNS["shotgun"]["range"] + 4.0:
				# (a farmer with his blood up stands his ground and fires)
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
			# Off the far edge of the map, back in at the other
			if absf(position.x) > 125.0 or absf(position.z) > 125.0:
				if road_axis == "z":
					position.z = -signf(position.z) * 124.0
				else:
					position.x = -signf(position.x) * 124.0
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
	var moving := want.length() > 0.01 and pace > 0.0
	speed = lerpf(speed, pace if moving else 0.0, minf(delta * 3.0, 1.0))
	if moving:
		var turn_rate := 2.0 if info["move"] in ["chase", "road"] else 6.0
		heading = lerp_angle(heading, atan2(want.x, want.z), minf(delta * turn_rate, 1.0))
	var step := Vector3(sin(heading), 0, cos(heading)) * speed * delta
	position += step
	position.x = clampf(position.x, -128.0, 128.0)
	position.z = clampf(position.z, -128.0, 128.0)
	rotation.y = heading
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
		"farmer":
			return global_position + Vector3(0, 1.5, 0)
		"tank":
			return global_position + Vector3(0, 1.9, 0)
		"jeep":
			return global_position + Vector3(0, 2.1, 0)
	return global_position + Vector3(0, 1.4, 0)
