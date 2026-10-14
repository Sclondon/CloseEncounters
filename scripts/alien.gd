class_name Alien
extends Node3D
## The pilot: the alien of Cryptlins, built the same way (cryptlin.gd `_build_alien`, with its parts,
## proportions and colours: a head too big for its body, long thin hands, and two great slanted
## black eyes with a light far down in each). Here it sits in the saucer's dome and looks where it
## is going and works the stick and buttons in front of it (see Ufo `panel`), mashing the buttons
## while the beam is on; it cheers each catch, flinches when hit, and is flung about in a dodge.
##
## Each one is its own (`look_seed`, a new one every run): its coat and the light in its eyes are from
## the alien's colours in Cryptlins, drifted a little, and its build, the size of its head and eyes,
## and the odd extra (a tuft, a tooth, one eye smaller, eyes of two colours) are its own.

const REST_ARM := Vector3(0.0, 0.0, 0.35)
const UP_ARM := Vector3(-0.3, 0.0, 2.5)
const STEER_ARM := Vector3(-1.1, 0.0, 0.3)
# The alien's coats and eye lights in Cryptlins (cryptlin.gd FURS, FURS_MORE, EYES)
const COATS: Array[Color] = [Color(0.5, 0.52, 0.5), Color(0.4, 0.6, 0.36), Color(0.45, 0.55, 0.66), Color(0.56, 0.46, 0.62),
	Color(0.6, 0.56, 0.44), Color(0.4, 0.5, 0.5)]
const LIGHTS: Array[Color] = [Color(0.6, 1.0, 0.6), Color(0.7, 0.9, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.5, 0.9), Color(1.0, 0.85, 0.3)]

var look_seed := 1
var coat := COATS[1]
var eye_size := 1.0
var extras: Array[String] = []

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
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	coat = COATS[rng.randi() % COATS.size()]
	coat = Color.from_hsv(fposmod(coat.h + rng.randf_range(-0.035, 0.035), 1.0), clampf(coat.s * rng.randf_range(0.78, 1.28), 0.0, 1.0),
		clampf(coat.v * rng.randf_range(0.88, 1.14), 0.0, 1.0))
	var light: Color = LIGHTS[rng.randi() % LIGHTS.size()]
	fur = Ps1.mat(coat * 0.76, 0.0, 0.35)
	pale = Ps1.mat(coat.lightened(0.2) * 0.9, 0.0, 0.35)
	dark = Ps1.mat(coat.darkened(0.5), 0.0, 0.35)
	black = Ps1.flat(Color(0.02, 0.01, 0.02))
	eye_mat = Ps1.mat(light, 0.85)
	for extra: String in ["tuft", "tooth", "odd", "split"]:
		if rng.randf() < 0.22:
			extras.append(extra)
	if "split" in extras:
		_other_eye = Ps1.mat(Color.from_hsv(fposmod(light.h + 0.38, 1.0), maxf(light.s, 0.5), light.v), 0.85)
	eye_size = rng.randf_range(0.8, 1.3)
	_build(rng.randf_range(0.9, 1.18), rng.randf_range(0.85, 1.25))


## As cryptlin.gd builds it, part for part
var _other_eye: ShaderMaterial


func _build(chub: float, crest: float) -> void:
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
	# (a bigger or smaller cranium, as cryptlin.gd swells it)
	var dome := neck.get_child(1) as Node3D
	dome.transform = Transform3D(Basis.from_scale(Vector3.ONE * crest) * dome.basis, Vector3(0, 0.2, 0.05) + (dome.position - Vector3(0, 0.2, 0.05)) * crest)
	_part(neck, Ps1.ball(), fur, Vector3(0, 0.15, 0.05), Vector3(0.19, 0.17, 0.2))
	if "tuft" in extras:
		for i in 3:
			var tip := Ps1.part(neck, CylinderMesh.new(), dark, Vector3((i - 1) * 0.04, 0.2 + 0.28 * crest + 0.05, -0.02), Vector3(0.012, 0.09, 0.012), Vector3(0.3 - i * 0.3, 0, (i - 1) * 0.4))
			(tip.mesh as CylinderMesh).top_radius = 0.0
	# Great slanted eyes, all dark but for the light in them
	for side: float in [-1.0, 1.0]:
		var eye := _pivot(neck, Vector3(0.115 * side, 0.2, 0.225))
		eye.rotation = Vector3(-0.1, 0.45 * side, 0.45 * side)
		_part(eye, Ps1.ball(), black, Vector3.ZERO, Vector3(0.1, 0.062, 0.03))
		_part(eye, Ps1.ball(), _other_eye if side > 0.0 and _other_eye != null else eye_mat, Vector3(0, 0, 0.03), Vector3(0.026, 0.026, 0.02))
		var size := eye_size * (0.7 if "odd" in extras and side > 0.0 else 1.0)
		eye.scale = Vector3(size, size, 1.0)
		eye.set_meta("size", size)
		eyes.append(eye)
	mouth_node = _pivot(neck, Vector3(0, 0.05, 0.215))
	_part(mouth_node, Ps1.ball(), black, Vector3.ZERO, Vector3(0.04, 0.025, 0.02))
	if "tooth" in extras:
		var fang := Ps1.part(mouth_node, CylinderMesh.new(), Ps1.mat(Color(0.92, 0.89, 0.78)), Vector3(0.018, -0.02, 0.012), Vector3(0.01, 0.03, 0.01), Vector3(PI, 0, 0))
		(fang.mesh as CylinderMesh).top_radius = 0.0


func feel(how: String, seconds := 0.0) -> void:
	if mood == "dead":
		return
	mood = how
	mood_time = seconds


func _process(delta: float) -> void:
	_t += delta
	if mood_time > 0.0:
		mood_time -= delta
		if mood_time <= 0.0 and mood in ["cheer", "hurt", "tossed"]:
			mood = "steer"
	var arm_goal := STEER_ARM
	var wave := 0.0
	var hop := 0.0
	var open := 1.0
	match mood:
		"cheer":
			arm_goal = UP_ARM
			wave = 0.5
			hop = absf(sin(_t * 14.0)) * 0.06
			open = 1.2
		"hurt":
			arm_goal = Vector3(-2.2, 0.0, 0.6)
			open = 0.4
		"tossed":
			arm_goal = UP_ARM
			wave = 1.2
			open = 1.35
		"dead":
			arm_goal = UP_ARM
			wave = 0.9
			open = 1.3
		"lounge":
			# In the deck chair: the drink arm comes up to sip now and then, eyes half shut
			var sip := fmod(_t, 4.5) > 3.3
			arm_goal = Vector3(-2.5, 0.0, 0.75) if sip else Vector3(-1.0, 0.0, 0.45)
			open = 0.55 if sip else 0.75
	_arm = _arm.lerp(arm_goal, minf(delta * (20.0 if mood == "tossed" else 8.0), 1.0))
	var w := sin(_t * (20.0 if mood == "tossed" else 9.0)) * wave
	# At the controls: the right hand on the stick, leaning it the way the ship goes, and the left
	# on the buttons; with the beam on, both hands mash the buttons as fast as they can
	var right := Vector3.ZERO
	var left := Vector3.ZERO
	if mood == "steer":
		right = Vector3(-look.y * 0.6, 0, -look.x * 0.5)
		left = Vector3(sin(_t * 4.0) * 0.15 + maxf(sin(_t * 11.0), 0.0) * 0.2, 0, 0)
	elif mood == "beam":
		right = Vector3(maxf(sin(_t * 30.0), 0.0) * 0.8 - 0.2, 0, 0.25 * sin(_t * 7.0))
		left = Vector3(maxf(sin(_t * 30.0 + PI), 0.0) * 0.8 - 0.2, 0, -0.25 * sin(_t * 5.0))
		hop = absf(sin(_t * 15.0)) * 0.03
	arms[1].rotation = Vector3(_arm.x + w + right.x, _arm.y, _arm.z + right.z)
	arms[0].rotation = Vector3(_arm.x - w + left.x, -_arm.y, -_arm.z + left.z)
	var lounging := mood == "lounge"
	if lounging:
		# (the other arm along the arm of the chair)
		arms[0].rotation = Vector3(-0.5, 0.0, -0.7)
	for leg in legs:
		leg.rotation.x = lerpf(leg.rotation.x, -1.35 if lounging else 0.0, minf(delta * 6.0, 1.0))
	torso.position.y = hop + sin(_t * 2.0) * 0.008
	if mood == "hurt":
		torso.rotation.z = sin(_t * 40.0) * 0.12
		torso.position.x = 0.0
	elif mood == "tossed":
		# Flung about inside the dome as the ship spins
		torso.rotation = Vector3(sin(_t * 31.0) * 0.45, 0.0, sin(_t * 23.0) * 0.6)
		torso.position = Vector3(sin(_t * 17.0) * 0.07, hop + absf(sin(_t * 13.0)) * 0.08, cos(_t * 19.0) * 0.05)
	else:
		torso.rotation.x = lerpf(torso.rotation.x, 0.1 if mood == "beam" else (-0.4 if lounging else 0.0), minf(delta * 8.0, 1.0))
		torso.rotation.z = lerpf(torso.rotation.z, -look.x * 0.15, minf(delta * 4.0, 1.0))
		torso.position.x = lerpf(torso.position.x, 0.0, minf(delta * 8.0, 1.0))
		torso.position.z = lerpf(torso.position.z, 0.0, minf(delta * 8.0, 1.0))
	_yaw =lerpf(_yaw, clampf(look.x * 0.9, -0.9, 0.9), minf(delta * 5.0, 1.0))
	_pitch = lerpf(_pitch, 0.35 if mood == "beam" else clampf(-look.y * 0.2, -0.3, 0.3), minf(delta * 5.0, 1.0))
	if lounging:
		_pitch = lerpf(_pitch, -0.25 if fmod(_t, 4.5) > 3.3 else 0.15, minf(delta * 4.0, 1.0))
		_yaw = sin(_t * 0.4) * 0.3
	if mood == "tossed":
		_yaw = sin(_t * 15.0) * 0.8
		_pitch = cos(_t * 12.0) * 0.4
	neck.rotation = Vector3(_pitch, _yaw, 0.0)
	# It blinks now and then, both eyes together
	_blink -= delta
	if _blink < 0.0:
		open = 0.1
		if _blink < -0.12:
			_blink = randf_range(1.5, 4.5)
	for e in eyes:
		e.scale.y = lerpf(e.scale.y, open * float(e.get_meta("size", 1.0)), minf(delta * 25.0, 1.0))
	mouth_node.scale = Vector3.ONE * (1.6 if mood in ["cheer", "dead", "tossed"] else 1.0)


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
