class_name Ufo
extends Node3D
## The saucer, with the alien at the controls under its dome. It flies at one height over the
## farm, banks into its turns, and holds a beam down to the ground that slows it while it is on.
## Its shield (`hull`) takes the shots; at nothing it falls out of the sky.

const ALTITUDE := 8.0
const SPEED := 10.0
const BEAM_SLOW := 0.5
## The beam's reach: its radius on the ground and up under the saucer
const BEAM_FOOT := 2.7
const BEAM_TOP := 1.0
const BOUNDS := 115.0

var velocity := Vector3.ZERO
var beaming := false
var hull := 100.0
var dead := false
var crashed := false
var since_hit := 10.0
var body: Node3D
var alien: Alien
var beam: MeshInstance3D
var beam_mat: ShaderMaterial
var spot: SpotLight3D
var glow: OmniLight3D
var _power := 0.0
var _t := 0.0
var _fall_v := 0.0


func _ready() -> void:
	position = Vector3(0, ALTITUDE, 0)
	body = Node3D.new()
	add_child(body)
	var saucer := Ps1.model("ufo", {}, true)
	body.add_child(saucer)
	alien = Alien.new()
	alien.scale = Vector3.ONE * 0.9
	alien.position = Vector3(0, 0.3, 0)
	body.add_child(alien)
	# The dome is drawn after the alien inside it
	var dome := saucer.find_child("dome", true, false) as MeshInstance3D
	if dome != null:
		dome.sorting_offset = 1.0

	beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = BEAM_TOP
	cone.bottom_radius = BEAM_FOOT
	cone.height = ALTITUDE - 0.5
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	beam_mat = ShaderMaterial.new()
	beam_mat.shader = load("res://shaders/beam.gdshader")
	beam.material_override = beam_mat
	beam.position.y = -(ALTITUDE - 0.5) * 0.5 - 0.5
	beam.visible = false
	add_child(beam)

	# A pale light always on the ground under it (to see where it is), green and bright in the beam
	spot = SpotLight3D.new()
	spot.rotation.x = -PI / 2
	spot.spot_range = ALTITUDE + 4.0
	spot.spot_angle = 24.0
	spot.light_energy = 1.5
	spot.light_color = Color(0.75, 0.85, 1.0)
	spot.position.y = -0.6
	add_child(spot)
	glow = OmniLight3D.new()
	glow.omni_range = 5.0
	glow.light_energy = 0.8
	glow.light_color = Color(0.7, 1.0, 0.75)
	glow.position.y = 1.5
	add_child(glow)


func ground() -> Vector3:
	return Vector3(position.x, 0.0, position.z)


## Flies by `steer` (a stick, at most 1 long); `beam_on` holds the beam down
func tick(delta: float, steer: Vector2, beam_on: bool) -> void:
	_t += delta
	since_hit += delta
	if dead:
		_falling(delta)
		return
	beaming = beam_on
	var top := SPEED * (BEAM_SLOW if beaming else 1.0)
	var want := Vector3(steer.x, 0, steer.y) * top
	velocity = velocity.lerp(want, minf(delta * (4.0 if want.length() > 0.1 else 2.5), 1.0))
	position += velocity * delta
	position.x = clampf(position.x, -BOUNDS, BOUNDS)
	position.z = clampf(position.z, -BOUNDS, BOUNDS)
	position.y = ALTITUDE + sin(_t * 1.7) * 0.15
	# Banks into the way it is going, and the whole saucer turns slowly
	body.rotation.x = lerpf(body.rotation.x, velocity.z / SPEED * 0.25, minf(delta * 5.0, 1.0))
	body.rotation.z = lerpf(body.rotation.z, -velocity.x / SPEED * 0.25, minf(delta * 5.0, 1.0))
	var saucer := body.get_child(0) as Node3D
	saucer.rotation.y += delta * (0.6 + (1.8 if beaming else 0.0))
	alien.look = Vector2(velocity.x, velocity.z) / SPEED
	if alien.mood in ["steer", "beam"]:
		alien.mood = "beam" if beaming else "steer"
	_power = move_toward(_power, 1.0 if beaming else 0.0, delta * 6.0)
	beam.visible = _power > 0.01
	beam_mat.set_shader_parameter("power", _power)
	spot.light_color = Color(0.75, 0.85, 1.0).lerp(Color(0.5, 1.0, 0.6), _power)
	spot.light_energy = 1.5 + _power * 3.0
	# A shield that has not been hit for a while mends, but only once the heat is off
	if since_hit > 3.0 and hull < 100.0:
		hull = minf(hull + delta * mend_rate, 100.0)
	Ps1.flash(saucer, Color(0.8, 0.1, 0.05) * maxf(0.0, 1.0 - since_hit * 5.0))


## How fast the shield mends (the game sets it from the heat)
var mend_rate := 0.0


## Whether a point is inside the beam: wide at the ground, narrow under the saucer
func in_beam(p: Vector3, slack := 0.0) -> bool:
	if not beaming or dead:
		return false
	var h := clampf(p.y / (ALTITUDE - 0.5), 0.0, 1.0)
	var r := lerpf(BEAM_FOOT, BEAM_TOP, h) + slack
	return Vector2(p.x - position.x, p.z - position.z).length() < r


## Whether a shot at `p` has struck the saucer (a flat disc of it)
func struck(p: Vector3) -> bool:
	if dead:
		return false
	var flat := Vector2(p.x - position.x, p.z - position.z).length()
	return flat < 2.8 and absf(p.y - position.y) < 0.9 + (1.0 - flat / 2.8) * 0.6


func hurt(amount: float) -> void:
	if dead:
		return
	hull -= amount
	since_hit = 0.0
	alien.feel("hurt", 0.4)
	if hull <= 0.0:
		hull = 0.0
		dead = true
		beaming = false
		beam.visible = false
		alien.feel("dead")


## Shot down: it tips over and spirals into the ground
func _falling(delta: float) -> void:
	if crashed:
		return
	_fall_v -= 9.0 * delta
	position.y += _fall_v * delta
	position += velocity * delta
	velocity = velocity.lerp(Vector3.ZERO, delta * 0.5)
	body.rotation.z = lerpf(body.rotation.z, 0.9, delta * 2.0)
	body.rotation.y += delta * 6.0
	if position.y < 0.8:
		crashed = true
