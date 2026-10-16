class_name Starfall
extends MeshInstance3D
## Little five-pointed stars thrown out of the ship's belly when it swallows something, each falling
## in an arc with a fading trail behind it. Drawn afresh each frame, facing the camera.

const GRAVITY := 11.0
const LIFE := 1.3
const TRAIL := 4

## Each star: [where, velocity, age, colour, trail of where it was]
var _stars: Array = []
var _im := ImmediateMesh.new()
var _open := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true


	material_override = m
	extra_cull_margin = 60.0


## Throws `count` stars out from `at`, outward and a little up, to fall in arcs
func burst(at: Vector3, count: int, drift := Vector3.ZERO) -> void:
	for i in count:
		var a := randf() * TAU
		var out := randf_range(2.5, 6.0)
		var v := Vector3(cos(a) * out, randf_range(0.5, 4.5), sin(a) * out) + drift * 0.5
		var c := Color(1.0, 0.95, 0.6) if i % 3 == 0 else Color(0.6, 1.0, 0.7)
		_stars.append([at, v, 0.0, c, [at]])


func _process(delta: float) -> void:
	_im.clear_surfaces()
	if _stars.is_empty():
		visible = false
		return
	visible = true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var keep: Array = []
	_open = false
	for s: Array in _stars:
		s[2] += delta
		if s[2] >= LIFE:
			continue
		s[1] += Vector3.DOWN * GRAVITY * delta
		s[0] += s[1] * delta
		var trail: Array = s[4]
		trail.push_front(s[0])
		if trail.size() > TRAIL:
			trail.pop_back()
		var fade := 1.0 - smoothstep(LIFE * 0.6, LIFE, s[2])
		var c: Color = s[3]
		# the trail: a ribbon narrowing and fading behind it
		for k in trail.size() - 1:
			var a: Vector3 = trail[k]
			var b: Vector3 = trail[k + 1]
			var side := (b - a).cross(cam.global_basis.z).normalized()
			var wa := 0.03 * (1.0 - float(k) / TRAIL)
			var wb := 0.03 * (1.0 - float(k + 1) / TRAIL)
			var ca := Color(c, 0.4 * fade * (1.0 - float(k) / TRAIL))
			var cb := Color(c, 0.4 * fade * (1.0 - float(k + 1) / TRAIL))
			_tri(a + side * wa, a - side * wa, b + side * wb, ca, ca, cb)
			_tri(a - side * wa, b - side * wb, b + side * wb, ca, cb, cb)
		# the star: five points round its middle, turning as it falls
		var r := 0.13 * (0.6 + 0.4 * fade)
		var spin: float = s[2] * 5.0
		var mid := Color(1, 1, 1, fade)
		var tip := Color(c, fade)
		for p in 5:
			var a0 := spin + p * TAU / 5.0
			var o := Vector3(s[0])
			var point := o + (right * sin(a0) + up * cos(a0)) * r
			var l := o + (right * sin(a0 - PI / 5.0) + up * cos(a0 - PI / 5.0)) * r * 0.42
			var rr := o + (right * sin(a0 + PI / 5.0) + up * cos(a0 + PI / 5.0)) * r * 0.42
			_tri(o, l, point, mid, tip, tip)
			_tri(o, point, rr, mid, tip, tip)
		keep.append(s)
	if _open:
		_im.surface_end()
	_stars = keep


func _tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if not _open:
		_open = true
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_im.surface_set_color(ca)
	_im.surface_add_vertex(a)
	_im.surface_set_color(cb)
	_im.surface_add_vertex(b)
	_im.surface_set_color(cc)
	_im.surface_add_vertex(c)
