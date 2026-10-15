class_name Clouds
extends MultiMeshInstance3D
## A thin layer of clouds over the farm country, between the camera and the ship: a few clumps of
## low-poly puffs (cloud.gdshader), in a pattern that repeats every SPAN so there are always some
## round the ship, drifting on the wind. They fade toward the edges of the patch round the ship and
## out of the way between the camera and the ship, so they never hide it.

const SPAN := 180.0
const CLUMPS := 9
const PUFFS := 5
## How high the layer is over the ground, and how fast it drifts
const HEIGHT := 17.0
const DRIFT := Vector3(1.3, 0, 0.5)

## How much of it shows (the game shows it in a run, not on the moon)
var fade := 0.0
var _puffs: Array[Dictionary] = []
var _drift := Vector3.ZERO


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/cloud.gdshader")
	ball.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = ball
	multimesh.instance_count = CLUMPS * PUFFS
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for c in CLUMPS:
		var at := Vector3(rng.randf() * SPAN, HEIGHT + rng.randf_range(-1.5, 1.5), rng.randf() * SPAN)
		var size := rng.randf_range(0.8, 1.3)
		for p in PUFFS:
			var off := Vector3(rng.randf_range(-4.5, 4.5), rng.randf_range(-0.4, 0.8), rng.randf_range(-2.5, 2.5)) * size
			var r := rng.randf_range(2.0, 3.4) * size
			_puffs.append({"at": at + off, "scale": Vector3(r * 1.3, r * 0.6, r)})
	extra_cull_margin = SPAN
	visible = false


## Round `center` (the ship), clear of the line from `eye` (the camera) down to it
func follow(center: Vector3, eye: Vector3, delta: float) -> void:
	_drift += DRIFT * delta
	visible = fade > 0.0
	if not visible:
		return
	var half := SPAN * 0.5
	var corner := Vector3(center.x - half, 0.0, center.z - half)
	# (where the line from the camera to the ship passes through the layer)
	var through := center
	if absf(eye.y - center.y) > 0.1:
		through = center.lerp(eye, clampf((HEIGHT - center.y) / (eye.y - center.y), 0.0, 1.0))
	for i in _puffs.size():
		var p: Dictionary = _puffs[i]
		var a: Vector3 = p["at"] + _drift
		var at := Vector3(corner.x + fposmod(a.x - corner.x, SPAN), a.y, corner.z + fposmod(a.z - corner.z, SPAN))
		var flat := Vector2(at.x - center.x, at.z - center.z)
		var edge := 1.0 - smoothstep(0.6, 1.0, maxf(absf(flat.x), absf(flat.y)) / half)
		var clear := smoothstep(7.0, 16.0, Vector2(at.x - through.x, at.z - through.z).length())
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(p["scale"]), at))
		multimesh.set_instance_color(i, Color(1, 1, 1, fade * edge * clear))
