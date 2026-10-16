class_name Boom
extends Node3D
## An explosion drawn the way The Wind Waker draws them: flat cartoon shapes with dark outlines,
## nothing soft. A white flash pops and is gone; chunky yellow and orange fireballs burst out, swell
## and shrink away to nothing; dark smoke balls roll up after them and shrink away too; a white ring
## runs out along the ground; little white sparks fly off and fall. `size` is about how far it reaches.

const LIFE := 1.5
static var _outline_fire: StandardMaterial3D
static var _outline_smoke: StandardMaterial3D

var size := 2.0
var _t := 0.0
## Each piece: [node, born, dies, biggest, velocity, kind]
var _pieces: Array = []
var _ring: MeshInstance3D


func _ready() -> void:
	if _outline_fire == null:
		_outline_fire = _outline(Color(0.45, 0.12, 0.05))
		_outline_smoke = _outline(Color(0.05, 0.04, 0.07))
	var ball := Ps1.ball()
	# the flash
	_add(ball, Ps1.flat(Color(1.0, 1.0, 0.95)), null, Vector3.ZERO, 0.0, 0.28, size * 0.9, Vector3.ZERO, "flash")
	# the fire
	for i in 8:
		var a := randf() * TAU
		var way := Vector3(cos(a), randf_range(0.2, 1.0), sin(a)).normalized()
		var hot := Color(1.0, 0.88, 0.25) if i % 2 == 0 else Color(1.0, 0.48, 0.1)
		_add(ball, Ps1.flat(hot), _outline_fire, way * size * 0.15, randf_range(0.0, 0.08), randf_range(0.45, 0.7), size * randf_range(0.3, 0.45), way * size * randf_range(2.0, 3.2), "fire")
	# the smoke
	for i in 6:
		var a := randf() * TAU
		var way := Vector3(cos(a), 0.0, sin(a)) * randf_range(0.2, 0.6) + Vector3.UP
		var dark := Color(0.22, 0.2, 0.26) if i % 2 == 0 else Color(0.32, 0.29, 0.34)
		_add(ball, Ps1.flat(dark), _outline_smoke, Vector3(0, size * 0.2, 0), randf_range(0.15, 0.3), randf_range(1.1, LIFE), size * randf_range(0.3, 0.42), way * size * randf_range(0.7, 1.1), "smoke")
	# the sparks
	var chip := BoxMesh.new()
	chip.size = Vector3(0.12, 0.12, 0.12)
	for i in 10:
		var a := randf() * TAU
		_add(chip, Ps1.flat(Color(1.0, 1.0, 0.85)), null, Vector3.ZERO, 0.0, randf_range(0.5, 0.8), 1.0, Vector3(cos(a), randf_range(0.8, 1.6), sin(a)) * size * 3.0, "spark")
	# the ring along the ground
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 4
	_ring.mesh = t
	_ring.material_override = Ps1.flat(Color(1.0, 1.0, 0.92))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.15 - position.y
	add_child(_ring)


func _outline(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = 0.08
	m.albedo_color = c
	return m


func _add(mesh: Mesh, material: Material, outline: Material, at: Vector3, born: float, dies: float, biggest: float, velocity: Vector3, kind: String) -> void:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position = at
	n.scale = Vector3.ZERO
	add_child(n)
	if outline != null:
		# (the dark outline: the same ball a little bigger, its inside faces only)
		var rim := MeshInstance3D.new()
		rim.mesh = mesh
		rim.material_override = outline
		rim.scale = Vector3.ONE * 1.12
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(rim)
	_pieces.append([n, born, dies, biggest, velocity, kind])


func _process(delta: float) -> void:
	_t += delta
	for p: Array in _pieces:
		var n: MeshInstance3D = p[0]
		var k := clampf((_t - float(p[1])) / (float(p[2]) - float(p[1])), 0.0, 1.0)
		if _t < float(p[1]):
			continue
		var v: Vector3 = p[4]
		match str(p[5]):
			"flash":
				# (pops out at once, and shrinks away)
				n.scale = Vector3.ONE * float(p[3]) * (minf(k * 6.0, 1.0) * (1.0 - k))
			"fire":
				p[4] = v * (1.0 - minf(delta * 5.0, 1.0))
				n.position += v * delta
				# (swells fast, holds, then shrinks to nothing: never fades)
				n.scale = Vector3.ONE * float(p[3]) * minf(k * 5.0, 1.0) * (1.0 - smoothstep(0.45, 1.0, k))
			"smoke":
				p[4] = v * (1.0 - minf(delta * 1.2, 1.0))
				n.position += v * delta
				n.scale = Vector3.ONE * float(p[3]) * minf(k * 3.0, 1.0) * (1.0 - smoothstep(0.55, 1.0, k))
			"spark":
				p[4] = v + Vector3.DOWN * 14.0 * delta
				n.position += v * delta
				n.scale = Vector3.ONE * (1.0 - k)
	var r := clampf(_t / 0.4, 0.0, 1.0)
	_ring.scale = Vector3(size * 2.4 * r, 0.25 * (1.0 - r) + 0.01, size * 2.4 * r)
	_ring.visible = r < 1.0
	if _t >= LIFE:
		queue_free()
