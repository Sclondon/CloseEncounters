class_name Tornado
extends MultiMeshInstance3D
## A thin whirl of dust swirling up the tractor beam: specks lifting off the ground at the beam's
## foot a few at a time, round and round faster as they near the ship's belly. Let the beam go and
## those in it are let go too, drifting out and settling as they fade. The ship moves it
## (`follow`). The specks hang in the air: they drift toward their place in the whirl, so a ship that
## flies on leaves them behind for a moment.

const COUNT := 36

## Each speck: 0 waiting on the ground, 1 swirling up, 2 let go
var _state := PackedInt32Array()
## Height up the beam (0 the ground, 1 the ship), angle round it, how far out (0 to 1), how fast it
## climbs
var _h := PackedFloat32Array()
var _a := PackedFloat32Array()
var _out := PackedFloat32Array()
var _climb := PackedFloat32Array()
## Seconds before it lifts off, or left of fading once let go
var _wait := PackedFloat32Array()
var _at := PackedVector3Array()
var _v := PackedVector3Array()
var _was_on := false
## The colour of what is being swirled up: dust, grass, water... (see Main._surface_fx)
var tint := Color(0.75, 1.0, 0.8)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mote := BoxMesh.new()
	mote.size = Vector3(0.08, 0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	mote.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mote
	multimesh.instance_count = COUNT
	_state.resize(COUNT)
	_h.resize(COUNT)
	_a.resize(COUNT)
	_out.resize(COUNT)
	_climb.resize(COUNT)
	_wait.resize(COUNT)
	_at.resize(COUNT)
	_v.resize(COUNT)
	for i in COUNT:
		multimesh.set_instance_color(i, Color(0, 0, 0, 0))
	extra_cull_margin = 20.0
	visible = false


## Under the ship at `top` (its belly), the beam `foot` wide on the ground and `neck` at the top, its
## foot leant `lean` off from under the ship; `on` while the beam is
func follow(top: Vector3, foot: float, neck: float, delta: float, lean := Vector3.ZERO, on := true) -> void:
	if on and not _was_on:
		# (the beam just on: the specks start lifting off the ground, a few at a time)
		for i in COUNT:
			if _state[i] == 0:
				_wait[i] = randf_range(0.0, 1.4)
	_was_on = on
	var any := false
	for i in COUNT:
		match _state[i]:
			0:
				if not on:
					continue
				_wait[i] -= delta
				if _wait[i] > 0.0:
					continue
				_state[i] = 1
				_h[i] = 0.0
				_a[i] = randf() * TAU
				_out[i] = randf_range(0.4, 1.0)
				_climb[i] = randf_range(0.22, 0.45)
				_at[i] = _swirl(i, top, foot, neck, lean)
			1:
				if not on:
					# (let go: off it drifts the way it was going, outward)
					_state[i] = 2
					_wait[i] = randf_range(0.8, 1.4)
					continue
				_h[i] += _climb[i] * delta * (0.6 + _h[i])
				_a[i] += delta * (2.5 + 6.0 * _h[i] * _h[i])
				var was := _at[i]
				# (drifting toward its place in the whirl, not carried along with the ship: fly on and it
				# is left behind for a moment)
				_at[i] = was.lerp(_swirl(i, top, foot, neck, lean), minf(delta * 2.5, 1.0))
				_v[i] = (_at[i] - was) / maxf(delta, 0.001)
				if _h[i] >= 1.0:
					_state[i] = 0
					_wait[i] = randf_range(0.0, 0.8)
					multimesh.set_instance_color(i, Color(0, 0, 0, 0))
					continue
				var fade := smoothstep(0.0, 0.1, _h[i]) * (1.0 - smoothstep(0.85, 1.0, _h[i]))
				multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, _at[i]))
				multimesh.set_instance_color(i, Color(tint, 0.75 * fade))
				any = true
			2:
				_wait[i] -= delta
				_v[i] = _v[i] * (1.0 - minf(delta * 1.5, 1.0)) + Vector3.DOWN * 1.5 * delta
				_at[i] += _v[i] * delta
				if _wait[i] <= 0.0:
					_state[i] = 0
					multimesh.set_instance_color(i, Color(0, 0, 0, 0))
					continue
				multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, _at[i]))
				multimesh.set_instance_color(i, Color(tint, 0.6 * minf(_wait[i], 1.0)))
				any = true
	visible = any


func _swirl(i: int, top: Vector3, foot: float, neck: float, lean: Vector3) -> Vector3:
	var r := lerpf(foot, neck, _h[i]) * _out[i] * 0.85
	return Vector3(top.x + cos(_a[i]) * r, top.y * _h[i], top.z + sin(_a[i]) * r) + lean * (1.0 - _h[i])
