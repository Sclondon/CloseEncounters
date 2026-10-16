class_name Puffs
extends Node3D
## Short-lived bits in the world: puffs of smoke that rise, swell and fade, and sparks that fly off
## and fall, and little chips (a roof tile, a clod, a blade of grass) that tumble up and fall back.
## Placed in the world wherever its parent is (it sits at the world's origin).

## Each bit: {node, age, life, velocity, grow, gravity, alpha}
var _bits: Array[Dictionary] = []
var _ball: SphereMesh
var _streak: BoxMesh
var _chip: BoxMesh


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_ball = SphereMesh.new()
	_ball.radius = 0.5
	_ball.height = 1.0
	_ball.radial_segments = 8
	_ball.rings = 4
	_streak = BoxMesh.new()
	_streak.size = Vector3(0.1, 0.1, 0.4)
	_chip = BoxMesh.new()
	_chip.size = Vector3(1.0, 0.35, 0.7)


## A puff of smoke at `at`, `size` across, drifting by `drift`
func puff(at: Vector3, c: Color, size: float, drift := Vector3.UP, life := 1.2) -> void:
	var n := _piece(_ball, c, false)
	n.position = at
	n.scale = Vector3.ONE * size
	_bits.append({"node": n, "age": 0.0, "life": life, "velocity": drift, "grow": size * 1.4, "gravity": 0.0, "alpha": c.a})


## A spark flying off from `at` along `velocity`, falling
func spark(at: Vector3, velocity: Vector3, c := Color(1.0, 0.85, 0.4)) -> void:
	var n := _piece(_streak, c, true)
	n.position = at
	_bits.append({"node": n, "age": 0.0, "life": 0.45, "velocity": velocity, "grow": 0.0, "gravity": 9.0, "alpha": 1.0})


## A little chip of something (`size` across) flung off along `velocity`, tumbling, falling back
func chip(at: Vector3, velocity: Vector3, c: Color, size := 0.18, gravity := 6.0, life := 1.1) -> void:
	var n := _piece(_chip, c, false)
	n.position = at
	n.scale = Vector3.ONE * size
	n.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	_bits.append({"node": n, "age": 0.0, "life": life, "velocity": velocity, "grow": 0.0, "gravity": gravity, "alpha": c.a, "spin": Vector3(randf_range(-8, 8), randf_range(-8, 8), 0)})


func _process(delta: float) -> void:
	for b in _bits.duplicate():
		var n: MeshInstance3D = b["node"]
		b["age"] += delta
		var k: float = b["age"] / b["life"]
		if k >= 1.0:
			n.queue_free()
			_bits.erase(b)
			continue
		b["velocity"] += Vector3.DOWN * b["gravity"] * delta
		n.position += b["velocity"] * delta
		if b.has("spin"):
			n.rotation += (b["spin"] as Vector3) * delta
		elif b["grow"] > 0.0:
			n.scale += Vector3.ONE * b["grow"] * delta
		elif (b["velocity"] as Vector3).length() > 0.1:
			var v: Vector3 = b["velocity"]
			n.look_at(n.position + v, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.FORWARD)
		(n.material_override as StandardMaterial3D).albedo_color.a = b["alpha"] * (1.0 - k)


func _piece(mesh: Mesh, c: Color, glow: bool) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n
