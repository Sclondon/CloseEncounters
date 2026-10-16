class_name Drone
extends Node3D
## One of the mini fleet bought from the traders (see main.gd `_fleet`): a little saucer that keeps
## station round the ship, and goes off by itself after the small things near it that nobody will
## miss (animals, hay, bushes: a light thing that draws hardly any heat), beams one up with a little
## beam of its own and brings it home for the score. It stands in the way of shots, too: anything
## fired that meets it stops there, and the police and army sometimes take it for the ship and aim
## at it instead. HITS of them and it is shot down, and a new one comes out of the ship a while later.
## The game moves it through `tick`.

## How high it flies after something, and how far from the ship it will go for it
const HEIGHT := 3.6
const REACH := 13.0
## How fast it flies, and how much slower than the ship its beam lifts
const SPEED := 15.0
const LIFT := 0.55
## The heaviest and the hottest thing it will take
const MOST_WEIGHT := 1.8
const MOST_HEAT := 0.1
## Shots it takes before it goes down, and how long until a new one comes out
const HITS := 3
const REBUILT := 14.0

var game: Node
## Which of the fleet it is (its place round the ship), and how many there are
var slot := 0
var of := 1
## What it is after, or has in its beam
var target: Thing
var lifting := false
var hits := 0
## Shot down: how long until a new one comes out of the ship
var down := 0.0
var hull: Node3D
var beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _lift := 0.0
var _t := 0.0
var _fall_v := 0.0


func setup(g: Node, i: int, at: Vector3) -> void:
	game = g
	slot = i
	_t = i * 1.7
	position = at
	hull = Ps1.model("ufo", {}, true)
	hull.scale = Vector3.ONE * 0.3
	add_child(hull)
	beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 0.9
	cone.height = 1.0
	cone.radial_segments = 10
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = load("res://shaders/beam.gdshader")
	_beam_mat.set_shader_parameter("tint", Color(0.85, 1.0, 0.5))
	beam.material_override = _beam_mat
	beam.visible = false
	add_child(beam)


func is_up() -> bool:
	return down <= 0.0


func tick(delta: float, ufo: Ufo) -> void:
	_t += delta
	if down > 0.0:
		_falling(delta, ufo)
		return
	if target != null and (not is_instance_valid(target) or target.state == "gone"):
		target = null
		lifting = false
	# (the ship's own beam took it first, or the ship has gone on without it)
	if target != null and not lifting and (target.state != "walk" or target.ground().distance_to(ufo.ground()) > REACH + 4.0):
		_let_go()
	if target == null and not ufo.dead and not ufo.beaming:
		target = _look(ufo)
	var goal: Vector3
	if target != null:
		goal = target.ground() + Vector3(0, HEIGHT, 0)
	else:
		# (in station round the ship, going slowly round it, a little under it)
		var a := _t * 0.8 + slot * TAU / float(of)
		var out := ufo.radius + 2.2
		goal = ufo.position + Vector3(cos(a) * out, -1.2 + sin(_t * 2.3 + slot) * 0.25, sin(a) * out)
	var step := goal - position
	# (faster the further it has to go, so it never falls far behind the ship)
	position += step.limit_length((SPEED + step.length() * 2.0) * delta) if step.length() > 1.0 else step * minf(delta * 5.0, 1.0)
	hull.rotation.y += delta * (3.0 if lifting else 1.2)
	hull.rotation.z = lerpf(hull.rotation.z, clampf(-step.x * 0.05, -0.4, 0.4), minf(delta * 4.0, 1.0))
	hull.rotation.x = lerpf(hull.rotation.x, clampf(step.z * 0.05, -0.4, 0.4), minf(delta * 4.0, 1.0))
	Ps1.flash(hull, Color(0.25, 0.5, 0.1) * (0.5 + 0.5 * sin(_t * 18.0)) if lifting else Color.BLACK)
	if target != null and Vector2(step.x, step.z).length() < 0.5:
		_beam_up(delta)
	else:
		beam.visible = false


## The nearest small thing near the ship that no other of the fleet is after (null if none)
func _look(ufo: Ufo) -> Thing:
	var best: Thing
	var best_d := REACH * _strength()
	for t: Thing in game.things:
		if t.state != "walk" or t.is_enemy() or t.kind == "pod" or t.tier() > 1 or t.info["move"] == "road":
			continue
		if float(t.info["weight"]) > MOST_WEIGHT or float(t.info["heat"]) > MOST_HEAT or t.info.get("rare", false):
			continue
		if t.has_meta("drone"):
			continue
		var d := t.ground().distance_to(ufo.ground())
		# (not what the ship's own beam is about to take)
		if d < best_d and d > ufo.beam_foot + 0.5:
			best_d = d
			best = t
	if best != null:
		best.set_meta("drone", self)
	return best


## Over it: the little beam down, and it rises, shrinking, until it is in
func _beam_up(delta: float) -> void:
	beam.visible = true
	var drop := position.y - 0.3
	beam.scale = Vector3(1.0, drop, 1.0)
	beam.position.y = -drop * 0.5 - 0.15
	_beam_mat.set_shader_parameter("power", 0.6 + 0.3 * sin(_t * 20.0))
	if not lifting:
		lifting = true
		_lift = 0.0
		target.state = "drone"
		game._witnessed(target)
	_lift += delta * LIFT * _strength() / float(target.info["weight"])
	var k := clampf(_lift, 0.0, 1.0)
	target.position = Vector3(position.x, lerpf(0.0, position.y - 0.4, ease(k, 1.6)), position.z)
	target.model.rotation = Vector3(sin(_t * 7.0) * 0.25, _t * 3.0, cos(_t * 6.0) * 0.25)
	target.model.scale = Vector3.ONE * target.base_size * lerpf(1.0, 0.2, clampf((k - 0.6) / 0.4, 0.0, 1.0))
	Ps1.flash(target.model, Color(0.25, 0.4, 0.1) * (0.6 + 0.4 * sin(_t * 12.0)))
	if _lift >= 1.0:
		var got := target
		target = null
		lifting = false
		beam.visible = false
		game.drone_took(got)


## Lets go of what it was after: what was in its beam falls
func _let_go() -> void:
	if target != null and is_instance_valid(target) and target.state != "gone":
		if target.has_meta("drone"):
			target.remove_meta("drone")
		if lifting:
			target.state = "falling"
			target.fall_v = 0.0
			target.fall_from = target.position.y
			target.model.scale = Vector3.ONE * target.base_size
			Ps1.flash(target.model, Color.BLACK)
	target = null
	lifting = false
	beam.visible = false


## A shot met it: it stops there. HITS of them and it goes down
func hit() -> void:
	if down > 0.0:
		return
	hits += 1
	Ps1.flash(hull, Color(1.5, 0.2, 0.1))
	create_tween().tween_callback(func() -> void: Ps1.flash(hull, Color.BLACK)).set_delay(0.1)
	if hits >= HITS:
		down = REBUILT
		_fall_v = 0.0
		_let_go()
		game.puff(position, Color(0.4, 0.4, 0.42), 1.0)


## Shot down: it tumbles smoking to the ground and is gone, and in time a new one comes out of the ship
func _falling(delta: float, ufo: Ufo) -> void:
	down -= delta
	beam.visible = false
	if visible:
		_fall_v -= 12.0 * delta
		position.y += _fall_v * delta
		hull.rotation += Vector3(delta * 5.0, delta * 9.0, delta * 3.0)
		if randf() < delta * 15.0:
			game.puff(position, Color(0.3, 0.3, 0.32), 0.5)
		if position.y < 0.3:
			visible = false
			game.boom(position, 1.2)
			game.sfx.play("boom", 2.0, -6.0)
	if down <= 0.0:
		down = 0.0
		hits = 0
		visible = true
		hull.rotation = Vector3.ZERO
		position = ufo.position + Vector3(0, -1.0, 0)
		game.puff(position, Color(0.85, 1.0, 0.5), 0.8)
		game.sfx.play("bloop", 1.8, -4.0)


## How strong the fleet is, by its level: 0.6 at the first (slow to lift, near the ship), the full of
## it by the fourth
func _strength() -> float:
	return 0.47 + 0.13 * float(game.upgrades.get("fleet", 1))
