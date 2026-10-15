class_name Dust
extends MultiMeshInstance3D
## Specks hanging in the air (or in space) round the ship, for its going to be seen: fixed in the
## world, in a pattern that repeats every `span` (so there are always some round the ship, however
## far it goes), drawn as streaks along the way it is going, longer the faster it goes, and fading
## out toward the edges of the box round it, and near the camera, so none pop in or out or fill the
## picture. Dust in space as the ship climbs off the moon and comes down to Earth (`Dust.new()`),
## and motes of dust in the air as it flies about (`Dust.motes()`).

var count := 180
var span := Vector3.ONE * 60.0
## Each streak this long for each metre a second the ship goes, between `shortest` and `longest`
var stretch := 0.012
var shortest := 0.09
var longest := 2.0
var thick := 0.045
var colour := Color(0.8, 0.85, 1.0, 0.45)
## How the specks drift on their own, a metre a second
var drift := Vector3.ZERO
var _drifted := Vector3.ZERO

## How much of it shows (the game fades it in and out)
var fade := 0.0
var _specks: Array[Vector3] = []
var _last := Vector3.ZERO
var _velocity := Vector3.ZERO


## Motes of dust hanging in the air round the ship as it flies, from near the ground to above the
## camera: still in the world (drifting a little on the breeze), never stretched or turned, so it is
## flying past them, the near ones sliding by faster than the far, that shows it moving
static func motes() -> Dust:
	var d := Dust.new()
	d.count = 160
	d.span = Vector3(56.0, 24.0, 56.0)
	d.stretch = 0.0
	d.shortest = 0.11
	d.longest = 0.11
	d.thick = 0.11
	d.drift = Vector3(0.6, 0.05, 0.25)
	d.colour = Color(0.88, 0.88, 0.8, 0.18)
	return d


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var streak := BoxMesh.new()
	streak.size = Vector3(thick, thick, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	streak.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = streak
	multimesh.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	for i in count:
		_specks.append(Vector3(rng.randf(), rng.randf(), rng.randf()) * span)
	visible = false


## Round `center` (the ship), streaked by how it has moved since the last frame, and gone near
## `eye` (the camera), where a speck would fill the picture
func follow(center: Vector3, eye: Vector3, delta: float) -> void:
	_drifted += drift * delta
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
	if speed > 0.5 and stretch > 0.0:
		basis = Basis.looking_at(_velocity / speed, Vector3.FORWARD if absf(_velocity.normalized().y) > 0.9 else Vector3.UP)
	basis = basis.scaled_local(Vector3(1, 1, clampf(speed * stretch, shortest, longest)))
	var half := span * 0.5
	var corner := center - half
	for i in count:
		var s := _specks[i]
		s += _drifted
		var at := corner + Vector3(fposmod(s.x - corner.x, span.x), fposmod(s.y - corner.y, span.y), fposmod(s.z - corner.z, span.z))
		var off := (at - center).abs() / half
		var edge := (1.0 - smoothstep(0.6, 1.0, maxf(off.x, maxf(off.y, off.z)))) * smoothstep(4.0, 9.0, at.distance_to(eye))
		multimesh.set_instance_transform(i, Transform3D(basis, at))
		multimesh.set_instance_color(i, Color(colour, colour.a * fade * edge))
