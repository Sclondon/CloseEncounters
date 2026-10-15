class_name Dust
extends MultiMeshInstance3D
## Dust hanging in space round the ship as it climbs off the moon and comes down to Earth, for its
## going to be seen against stars that never move: specks fixed in the world, in a pattern that
## repeats every SPAN (so there are always some round the ship, however far it goes), drawn as
## streaks along the way it is going, longer the faster it goes, and fading out toward the edges of
## the box round it so none pop in or out.

const COUNT := 180
const SPAN := 60.0

## How much of it shows (the game fades it in after lift-off and out as the ground comes up)
var fade := 0.0
var _specks: Array[Vector3] = []
var _last := Vector3.ZERO
var _velocity := Vector3.ZERO


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var streak := BoxMesh.new()
	streak.size = Vector3(0.09, 0.09, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	streak.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = streak
	multimesh.instance_count = COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	for i in COUNT:
		_specks.append(Vector3(rng.randf(), rng.randf(), rng.randf()) * SPAN)
	visible = false


## Round `center` (the ship), streaked by how it has moved since the last frame, and gone near
## `eye` (the camera), where a speck would fill the picture
func follow(center: Vector3, eye: Vector3, delta: float) -> void:
	var moved := center - _last
	_last = center
	# (a jump, such as the run starting with a new ship, is not a speed)
	if delta > 0.0 and moved.length() < 60.0:
		_velocity = moved / delta
	visible = fade > 0.0
	if not visible:
		return
	var speed := _velocity.length()
	var basis := Basis.IDENTITY
	if speed > 0.5:
		basis = Basis.looking_at(_velocity / speed, Vector3.FORWARD if absf(_velocity.normalized().y) > 0.9 else Vector3.UP)
	basis = basis.scaled_local(Vector3(1, 1, clampf(speed * 0.012, 0.09, 2.0)))
	var half := SPAN * 0.5
	var corner := center - Vector3.ONE * half
	for i in COUNT:
		var s := _specks[i]
		var at := corner + Vector3(fposmod(s.x - corner.x, SPAN), fposmod(s.y - corner.y, SPAN), fposmod(s.z - corner.z, SPAN))
		var off := (at - center).abs() / half
		var edge := (1.0 - smoothstep(0.6, 1.0, maxf(off.x, maxf(off.y, off.z)))) * smoothstep(4.0, 9.0, at.distance_to(eye))
		multimesh.set_instance_transform(i, Transform3D(basis, at))
		multimesh.set_instance_color(i, Color(0.8, 0.85, 1.0, 0.55 * fade * edge))
