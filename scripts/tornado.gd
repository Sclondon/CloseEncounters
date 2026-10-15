class_name Tornado
extends MultiMeshInstance3D
## A whirl of motes swirling up the tractor beam, from its foot on the ground to the ship's belly,
## round and round faster as they near the top. The ship moves it (`follow`) and fades it with the
## beam (`power`).

const COUNT := 70

var power := 0.0
## Each mote: height up the beam (0 the ground, 1 the ship), angle round it, how far out (0 to 1),
## how fast it climbs
var _motes: Array[Vector4] = []


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mote := BoxMesh.new()
	mote.size = Vector3(0.14, 0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	mote.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mote
	multimesh.instance_count = COUNT
	for i in COUNT:
		_motes.append(Vector4(randf(), randf() * TAU, randf_range(0.35, 1.0), randf_range(0.25, 0.55)))
	extra_cull_margin = 20.0
	visible = false


## Under the ship at `top` (its belly), the beam `foot` wide on the ground and `neck` at the top
func follow(top: Vector3, foot: float, neck: float, delta: float) -> void:
	visible = power > 0.01
	if not visible:
		return
	for i in COUNT:
		var m := _motes[i]
		m.x += m.w * delta * (0.6 + m.x)
		m.y += delta * (2.5 + 6.0 * m.x * m.x)
		if m.x >= 1.0:
			m = Vector4(0.0, randf() * TAU, randf_range(0.35, 1.0), randf_range(0.25, 0.55))
		_motes[i] = m
		var r := lerpf(foot, neck, m.x) * m.z * 0.85
		var at := Vector3(top.x + cos(m.y) * r, top.y * m.x, top.z + sin(m.y) * r)
		var spin := Basis(Vector3.UP, m.y).scaled(Vector3.ONE * lerpf(1.2, 0.5, m.x))
		multimesh.set_instance_transform(i, Transform3D(spin, at))
		var fade := smoothstep(0.0, 0.12, m.x) * (1.0 - smoothstep(0.85, 1.0, m.x))
		multimesh.set_instance_color(i, Color(0.75, 1.0, 0.8, 0.9 * power * fade))
