class_name Shop
extends Node3D
## A saucer parked out in the country, its owner standing by it: a trader, a different alien every
## time (see Alien), with a name of its own. Three of its goods stand in front of it, in pods
## (see main.gd `spawn_shop`): beam one up to buy it with score, and the trader packs up the rest
## and leaves. It will not deal with a ship that is being looked for, and once the heat reaches
## FLEE_AT it takes off and is gone.

const FLEE_AT := 2
const PAD := 4.0
const SYLLABLES: Array[String] = ["zo", "rp", "kli", "ix", "qua", "vee", "glo", "th", "xu", "bri", "mo", "nak", "ul", "zee", "pr"]

var game: Node
var keeper: Alien
var saucer: Node3D
var keeper_name := ""
var chunk := Vector2i.ZERO
## "parked" or "leaving" (then gone)
var state := "parked"
var gone := false
var _t := 0.0
var _rise := 0.0
var _cheer := 2.0
## Its goods on the ground, until one is bought
var pods: Array = []


func setup(g: Node, at: Vector3, c: Vector2i, look_seed: int) -> void:
	game = g
	chunk = c
	position = at
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	for i in rng.randi_range(2, 3):
		keeper_name += SYLLABLES[rng.randi() % SYLLABLES.size()]
	keeper_name = keeper_name.capitalize()
	# The ship, down on three legs on a pad that glows
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PAD
	disc.bottom_radius = PAD
	disc.height = 0.06
	disc.radial_segments = 20
	pad.mesh = disc
	pad.material_override = Ps1.mat(Color(0.25, 0.45, 0.3), 0.6)
	pad.position.y = 0.03
	add_child(pad)
	saucer = Ps1.model("ufo", {}, true)
	saucer.position = Vector3(0, 1.4, 0)
	saucer.rotation = Vector3(0.06, rng.randf() * TAU, -0.04)
	add_child(saucer)
	for i in 3:
		var a := i * TAU / 3.0
		Ps1.part(saucer, CylinderMesh.new(), Ps1.mat(Color(0.32, 0.34, 0.38)), Vector3(sin(a) * 1.6, -0.8, cos(a) * 1.6), Vector3(0.08, 0.8, 0.08), Vector3(sin(a) * -0.3, 0, cos(a) * 0.3))
	keeper = Alien.new()
	keeper.look_seed = look_seed
	keeper.scale = Vector3.ONE * 1.3
	keeper.position = Vector3(2.6, 0.3, 2.2)
	add_child(keeper)


func tick(delta: float, ufo: Ufo, heat_level: int) -> void:
	_t += delta
	if state == "parked":
		var to := ufo.position - keeper.global_position
		keeper.look = Vector2(clampf(to.x / 10.0, -1, 1), 0)
		# Waves the ship over now and then
		_cheer -= delta
		if _cheer <= 0.0:
			_cheer = randf_range(3.0, 6.0)
			keeper.feel("cheer", 1.2)
		if heat_level >= FLEE_AT and ufo.ground().distance_to(Vector3(position.x, 0, position.z)) < 90.0:
			leave(false)
	else:
		_rise += delta * 7.0
		saucer.position.y += _rise * delta
		saucer.rotation.y += delta * (2.0 + _rise)
		position.x += delta * _rise * 0.5
		if saucer.position.y > 45.0:
			gone = true


## Takes off: after a sale (`sold`), or fleeing the heat
func leave(sold: bool) -> void:
	if state != "parked":
		return
	state = "leaving"
	keeper.visible = false
	game.sfx.play("whoosh", 1.3)
	if not sold:
		game.trader_fled(self)
