class_name RemoteSaucer
extends Node3D
## Another player's saucer, as this device sees it (see Coop): a real ship of theirs (the same model,
## pilot, beam, tilt and glow as one's own), driven by what is heard of it rather than by a stick,
## seen on from where it was last heard to be at the speed it was going; its seat and score over it.

var slot := 0
var ship := "saucer"
var score := 0
var ufo: Ufo
var _to := Vector3.ZERO
var _vel := Vector3.ZERO
var _heard_at := 0.0
var _turn := 0.0
var _beaming := false
var _aim := Vector2.ZERO
var _tag: Label3D
var _heard := false


func _ready() -> void:
	ufo = Ufo.new()
	ufo.ship = ship if Ufo.SHIPS.has(ship) else "saucer"
	ufo.alien_seed = slot * 7919 + 13
	add_child(ufo)
	_tag = Label3D.new()
	_tag.font_size = 64
	_tag.pixel_size = 0.02
	_tag.outline_size = 12
	_tag.modulate = Color(0.75, 1.0, 0.78)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	add_child(_tag)


## What was heard of them: [seat, x, y, z, turn, beaming, aim x, aim z, ship, score, down, going x,
## going z]
func hear(state: Array) -> void:
	_to = Vector3(float(state[1]), float(state[2]), float(state[3]))
	_vel = Vector3(float(state[11]), 0.0, float(state[12])) if state.size() > 12 else Vector3.ZERO
	_heard_at = Time.get_ticks_msec() / 1000.0
	_turn = float(state[4])
	_beaming = bool(state[5]) and not bool(state[10])
	# (their beam's lean, as a stick would give it: see Ufo._lean_beam)
	_aim = Vector2(float(state[6]), float(state[7])) / Ufo.BEAM_REACH
	score = int(state[9])
	_tag.text = "P%d  $%d" % [slot + 1, score]
	if bool(state[10]) and not ufo.dead:
		ufo.hull = 0.0
		ufo.hurt(1.0)
	if not _heard:
		_heard = true
		ufo.position = _to


func glide(delta: float) -> void:
	if ufo == null:
		return
	ufo.beam_aim = _aim
	ufo.velocity = _vel
	var was := ufo.position
	ufo.tick(delta, Vector2.ZERO, _beaming)
	# (their aiming mark is theirs alone)
	ufo.reticle.visible = false
	# (where they will be by now, from where they were heard to be and how fast they were going)
	var age := minf(Time.get_ticks_msec() / 1000.0 - _heard_at, 0.3)
	var goal := _to + _vel * age
	ufo.position = Vector3(was.x, ufo.position.y, was.z).lerp(Vector3(goal.x, ufo.position.y, goal.z), 1.0 - exp(-10.0 * delta))
	if not ufo._spins:
		ufo.hull_model.rotation.y = lerp_angle(ufo.hull_model.rotation.y, _turn - ufo.rotation.y, 1.0 - exp(-12.0 * delta))
	_tag.position = ufo.position + Vector3(0, 2.6, 0)
