class_name Broadcast
extends Node3D
## What a phone booth's aerial does while someone calls from it (see Thing.witness): rings of radio
## waves rising off its tip, or, if the phone lines near it are down, sparks and nothing more. The
## caller keeps it going (`keep`); it runs on its own clock, however seldom the booth is looked at.

## Where the aerial's tip is, on the booth's model
const TIP := Vector3(0.3, 4.02, -0.3)
const WAVE_EVERY := 0.3
const WAVE_LIFE := 1.1
const SPARK_EVERY := 0.09

## Where the waves come from instead of a booth's aerial (a radio dish's, while it tracks the ship)
var source: Node3D
var _on := 0.0
var _dead_line := false
var _wait := 0.0
## Rings and sparks still going: {node, age, velocity}
var _bits: Array[Dictionary] = []
var _ring_mesh: TorusMesh
var _spark_mesh: BoxMesh


func _ready() -> void:
	top_level = true
	# (its rings and sparks placed in the world, not off the booth)
	global_transform = Transform3D.IDENTITY
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.8
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 16
	_ring_mesh.ring_segments = 4
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3(0.12, 0.12, 0.4)


## Someone is on the phone here for a little longer; `dead_line` if the lines near are cut
func keep(dead_line: bool) -> void:
	_on = 0.25
	_dead_line = dead_line


func _process(delta: float) -> void:
	var tip := source.global_position if source != null and is_instance_valid(source) else (get_parent() as Thing).model.to_global(TIP)
	_on -= delta
	if _on > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			if _dead_line:
				_wait = SPARK_EVERY
				for i in 5:
					_spark(tip)
			else:
				_wait = WAVE_EVERY
				_wave(tip)
	for b in _bits.duplicate():
		var n: MeshInstance3D = b["node"]
		b["age"] += delta
		var mat := n.material_override as StandardMaterial3D
		if b["velocity"] == Vector3.ZERO:
			var k: float = b["age"] / WAVE_LIFE
			n.scale = Vector3.ONE * lerpf(0.3, 2.4, k)
			n.position.y += delta * 0.8
			mat.albedo_color.a = 0.65 * (1.0 - k)
			if k >= 1.0:
				_drop(b)
		else:
			b["velocity"] += Vector3.DOWN * 9.0 * delta
			n.position += b["velocity"] * delta
			n.look_at(n.position + b["velocity"], Vector3.UP if absf(b["velocity"].normalized().y) < 0.95 else Vector3.FORWARD)
			mat.albedo_color.a = 1.0 - b["age"] / 0.45
			if b["age"] >= 0.45:
				_drop(b)


func _wave(tip: Vector3) -> void:
	var n := _piece(_ring_mesh, Color(0.55, 1.0, 0.8, 0.9))
	n.position = tip
	_bits.append({"node": n, "age": 0.0, "velocity": Vector3.ZERO})


func _spark(tip: Vector3) -> void:
	var n := _piece(_spark_mesh, Color(1.0, 0.9, 0.45, 1.0))
	n.position = tip
	var a := randf() * TAU
	_bits.append({"node": n, "age": 0.0, "velocity": Vector3(cos(a), randf_range(0.6, 1.6), sin(a)) * randf_range(2.0, 4.0)})


func _piece(mesh: Mesh, c: Color) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n


func _drop(b: Dictionary) -> void:
	(b["node"] as Node).queue_free()
	_bits.erase(b)
