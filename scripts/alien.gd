class_name Alien
extends Node3D
## The pilot: the alien of Cryptlins, built the same way (cryptlin.gd `_build_alien`, with its parts,
## proportions and colours: a head too big for its body, long thin hands, and two great slanted
## black eyes with a light far down in each). Here it sits in the saucer's dome and looks where it
## is going, raises its arms while the beam is on, cheers each catch and flinches when hit.

const REST_ARM := Vector3(0.0, 0.0, 0.35)
const UP_ARM := Vector3(-0.3, 0.0, 2.5)
const STEER_ARM := Vector3(-1.1, 0.0, 0.3)
# Its coat and eyes: the grey-green one of the alien's coats in Cryptlins, and the green light
const COAT := Color(0.4, 0.6, 0.36)
const LIGHT := Color(0.6, 1.0, 0.6)

var fur: ShaderMaterial
var pale: ShaderMaterial
var dark: ShaderMaterial
var black: ShaderMaterial
var eye_mat: ShaderMaterial
var neck_y := 0.52
var torso: Node3D
var neck: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var eyes: Array[Node3D] = []
var mouth_node: Node3D

## What it is doing: "steer", "beam", "cheer", "hurt", "dead"
var mood := "steer"
var mood_time := 0.0
## Where it is looking, in the saucer's own space (x across, z ahead)
var look := Vector2.ZERO
var _t := 0.0
var _blink := 2.0
var _arm := REST_ARM
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	fur = Ps1.mat(COAT * 0.76, 0.0, 0.35)
	pale = Ps1.mat(COAT.lightened(0.2) * 0.9, 0.0, 0.35)
	dark = Ps1.mat(COAT.darkened(0.5), 0.0, 0.35)
	black = Ps1.flat(Color(0.02, 0.01, 0.02))
	eye_mat = Ps1.mat(LIGHT, 0.85)
	_build(1.0)


## As cryptlin.gd builds it, part for part
func _build(chub: float) -> void:
	for side: float in [-1.0, 1.0]:
		var leg := _pivot(self, Vector3(0.07 * side, 0.24, 0))
		_part(leg, _capsule(0.03, 0.24), fur, Vector3(0, -0.1, 0))
		_part(leg, Ps1.ball(), dark, Vector3(0, -0.215, 0.03), Vector3(0.045, 0.025, 0.08))
		legs.append(leg)

	torso = _pivot(self, Vector3.ZERO)
	_part(torso, Ps1.ball(), fur, Vector3(0, 0.4, 0), Vector3(0.13 * chub, 0.19, 0.11 * chub))
	_part(torso, Ps1.ball(), pale, Vector3(0, 0.34, 0.04), Vector3(0.12 * chub, 0.11, 0.1))

	for side: float in [-1.0, 1.0]:
		var a := _pivot(torso, Vector3(0.14 * chub * side, 0.5, 0))
		_part(a, _capsule(0.022, 0.36), fur, Vector3(0, -0.16, 0))
		for finger: float in [-1.0, 0.0, 1.0]:
			_part(a, _cone(), dark, Vector3(0.02 * finger, -0.37, 0), Vector3(0.008, 0.09, 0.008), Vector3(PI, 0, 0.2 * finger))
		arms.append(a)

	neck = _pivot(torso, Vector3(0, neck_y, 0.01))
	_part(neck, _capsule(0.035, 0.12), fur, Vector3(0, 0.03, 0))
	_part(neck, Ps1.ball(), fur, Vector3(0, 0.3, -0.02), Vector3(0.3, 0.26, 0.3))
	_part(neck, Ps1.ball(), fur, Vector3(0, 0.15, 0.05), Vector3(0.19, 0.17, 0.2))
	# Great slanted eyes, all dark but for the light in them
	for side: float in [-1.0, 1.0]:
		var eye := _pivot(neck, Vector3(0.115 * side, 0.2, 0.225))
		eye.rotation = Vector3(-0.1, 0.45 * side, 0.45 * side)
		_part(eye, Ps1.ball(), black, Vector3.ZERO, Vector3(0.1, 0.062, 0.03))
		_part(eye, Ps1.ball(), eye_mat, Vector3(0, 0, 0.03), Vector3(0.026, 0.026, 0.02))
		eyes.append(eye)
	mouth_node = _pivot(neck, Vector3(0, 0.05, 0.215))
	_part(mouth_node, Ps1.ball(), black, Vector3.ZERO, Vector3(0.04, 0.025, 0.02))


func feel(how: String, seconds := 0.0) -> void:
	if mood == "dead":
		return
	mood = how
	mood_time = seconds


func _process(delta: float) -> void:
	_t += delta
	if mood_time > 0.0:
		mood_time -= delta
		if mood_time <= 0.0 and mood in ["cheer", "hurt"]:
			mood = "steer"
	var arm_goal := STEER_ARM
	var wave := 0.0
	var hop := 0.0
	var open := 1.0
	match mood:
		"beam":
			arm_goal = UP_ARM
			wave = 0.15
		"cheer":
			arm_goal = UP_ARM
			wave = 0.5
			hop = absf(sin(_t * 14.0)) * 0.06
			open = 1.2
		"hurt":
			arm_goal = Vector3(-2.2, 0.0, 0.6)
			open = 0.4
		"dead":
			arm_goal = UP_ARM
			wave = 0.9
			open = 1.3
	_arm = _arm.lerp(arm_goal, minf(delta * 8.0, 1.0))
	var w := sin(_t * 9.0) * wave
	# (at the controls, its hands work them a little)
	var work := sin(_t * 5.0) * 0.12 if mood == "steer" else 0.0
	arms[1].rotation = Vector3(_arm.x + w + work, _arm.y, _arm.z)
	arms[0].rotation = Vector3(_arm.x - w - work, -_arm.y, -_arm.z)
	torso.position.y = hop + sin(_t * 2.0) * 0.008
	if mood == "hurt":
		torso.rotation.z = sin(_t * 40.0) * 0.12
	else:
		torso.rotation.z = lerpf(torso.rotation.z, -look.x * 0.15, minf(delta * 4.0, 1.0))
	_yaw = lerpf(_yaw, clampf(look.x * 0.9, -0.9, 0.9), minf(delta * 5.0, 1.0))
	_pitch = lerpf(_pitch, 0.35 if mood == "beam" else clampf(-look.y * 0.2, -0.3, 0.3), minf(delta * 5.0, 1.0))
	neck.rotation = Vector3(_pitch, _yaw, 0.0)
	# It blinks now and then, both eyes together
	_blink -= delta
	if _blink < 0.0:
		open = 0.1
		if _blink < -0.12:
			_blink = randf_range(1.5, 4.5)
	for e in eyes:
		e.scale.y = lerpf(e.scale.y, open, minf(delta * 25.0, 1.0))
	mouth_node.scale = Vector3.ONE * (1.6 if mood in ["cheer", "dead"] else 1.0)


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, size := Vector3.ONE, turn := Vector3.ZERO) -> MeshInstance3D:
	return Ps1.part(parent, mesh, material, at, size, turn)


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 6
	m.rings = 2
	return m


func _cone() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 1.0
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 1
	return m
