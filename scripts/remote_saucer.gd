class_name RemoteSaucer
extends Node3D
## Another player's saucer, as this device sees it (see Coop): their ship with its pilot under the
## dome, their beam when it is on, their seat and score over it; gliding after where they were last
## heard to be, and smoking and dark once they are down.

var slot := 0
var ship := "saucer"
var _to := Vector3.ZERO
var _turn := 0.0
var _beam: Node3D
var _hull: Node3D
var _tag: Label3D
var _heard := false
var _dead := false
## How fast they were going when last heard, and when that was (to see them on from there between
## what is heard of them, rather than stepping from one word to the next)
var _vel := Vector3.ZERO
var _heard_at := 0.0


func _ready() -> void:
	var spec: Dictionary = Ufo.SHIPS.get(ship, Ufo.SHIPS["saucer"])
	_hull = Ps1.model(spec["model"])
	_hull.scale = Vector3.ONE * float(spec.get("scale", 1.0))
	add_child(_hull)
	var pilot := Alien.new()
	pilot.look_seed = slot * 7919 + 13
	pilot.scale = Vector3.ONE * float(spec["alien_size"])
	pilot.position.y = float(spec["alien_y"])
	_hull.add_child(pilot)
	# (their beam: a soft green strip down to the ground, as the searchlights are drawn)
	_beam = Node3D.new()
	_beam.rotation.x = PI
	_beam.position.y = -0.5
	add_child(_beam)
	Thing.light_strip(_beam, Color(0.45, 1.0, 0.6), 0.8, 8.0, 1.2, 4.5, 0.97)
	_beam.visible = false
	_tag = Label3D.new()
	_tag.font_size = 64
	_tag.pixel_size = 0.02
	_tag.outline_size = 12
	_tag.modulate = Color(0.75, 1.0, 0.78)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.position.y = 2.6
	add_child(_tag)


## What was heard of them: [seat, x, y, z, turn, beaming, aim x, aim z, ship, score, down, going x,
## going z]
func hear(state: Array) -> void:
	_to = Vector3(float(state[1]), float(state[2]), float(state[3]))
	_vel = Vector3(float(state[11]), 0.0, float(state[12])) if state.size() > 12 else Vector3.ZERO
	_heard_at = Time.get_ticks_msec() / 1000.0
	_turn = float(state[4])
	if not _heard:
		_heard = true
		position = _to
	_beam.visible = bool(state[5]) and not bool(state[10])
	if _beam.visible:
		# (leant as theirs is: the strip turned toward where its foot falls)
		var lean := Vector3(float(state[6]), -maxf(_to.y - 0.5, 1.0), float(state[7]))
		_beam.basis = Basis(Quaternion(Vector3.UP, lean.normalized()))
	_tag.text = "P%d  $%d" % [slot + 1, int(state[9])]
	_dead = bool(state[10])


func glide(delta: float) -> void:
	# (where they will be by now, from where they were heard to be and how fast they were going)
	var age := minf(Time.get_ticks_msec() / 1000.0 - _heard_at, 0.3)
	position = position.lerp(_to + _vel * age, 1.0 - exp(-10.0 * delta))
	_hull.rotation.y = lerp_angle(_hull.rotation.y, _turn, 1.0 - exp(-12.0 * delta))
	if _dead:
		_hull.rotation.z = lerpf(_hull.rotation.z, 0.5, delta * 2.0)
