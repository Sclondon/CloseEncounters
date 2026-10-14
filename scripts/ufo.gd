class_name Ufo
extends Node3D
## The ship, with the alien at the controls under its dome. It flies at one height over the land,
## banks into its turns, and holds a beam down to the ground that slows it while it is on. Its
## shield (`hull`) takes the shots; at nothing it falls out of the sky.
##
## There are three ships (SHIPS), chosen on the title screen. The classic saucer is the all-rounder;
## the orb (after the scout ships of Close Encounters of the Third Kind) is slow but tough, flies
## high (shots take longer to reach it) and pulls things up fast; the black triangle is quick but
## thin-skinned, flies low and has a weak beam.

const SHIPS := {
	"saucer": {"title": "CLASSIC SAUCER", "model": "ufo", "speed": 12.0, "lift": 1.0, "hull": 100.0, "tier": 2, "altitude": 8.0,
		"radius": 2.8, "beam_foot": 2.7, "alien_y": 0.3, "alien_size": 0.9, "spin": true,
		"about": "The all-rounder. Its beam pulls up trees and rocks."},
	"orb": {"title": "THE ORB", "model": "orb", "speed": 9.5, "lift": 1.5, "hull": 150.0, "tier": 3, "altitude": 10.5,
		"radius": 2.2, "beam_foot": 3.2, "alien_y": 1.2, "alien_size": 0.72, "spin": true,
		"about": "Slow but tough. Flies high; its beam lifts buildings."},
	"triangle": {"title": "BLACK TRIANGLE", "model": "triangle", "speed": 15.0, "lift": 0.72, "hull": 70.0, "tier": 1, "altitude": 6.0,
		"radius": 3.0, "beam_foot": 2.3, "alien_y": 0.2, "alien_size": 0.62, "spin": false,
		"about": "Fast and low. Thin shield; a beam for small things only."},
}
const ORDER: Array[String] = ["saucer", "orb", "triangle"]
const BEAM_SLOW := 0.6
## The dodge: a dash this fast for this long, untouchable while it lasts, then a wait before the next
const DASH_SPEED := 34.0
const DASH_TIME := 0.22
const DASH_SAFE := 0.35
const DASH_WAIT := 0.9
## The beam's radius up under the ship
const BEAM_TOP := 1.0

## Which of SHIPS this is (set before it is added)
var ship := "saucer"
## Which alien is at the controls (see Alien.look_seed)
var alien_seed := 1
var speed := 12.0
## How much faster than the plain weight of a thing this ship's beam lifts it
var lift_rate := 1.0
## How strong the beam is: what it can take (see Thing.tier); 4 takes the land itself
var tier := 2
var hull_max := 100.0
var altitude := 8.0
var radius := 2.8
var beam_foot := 2.7
var velocity := Vector3.ZERO
var beaming := false
var hull := 100.0
var dead := false
var crashed := false
var since_hit := 10.0
var dash_left := 0.0
var dash_wait := 0.0
var _dash_dir := Vector3.ZERO
var _roll := 0.0
var _spins := true
var body: Node3D
var hull_model: Node3D
var alien: Alien
var beam: MeshInstance3D
var beam_mat: ShaderMaterial
var spot: SpotLight3D
var glow: OmniLight3D
var _power := 0.0
var _t := 0.0
var _fall_v := 0.0


func _ready() -> void:
	var spec: Dictionary = SHIPS[ship]
	speed = spec["speed"]
	lift_rate = spec["lift"]
	tier = spec["tier"]
	hull_max = spec["hull"]
	hull = hull_max
	altitude = spec["altitude"]
	radius = spec["radius"]
	beam_foot = spec["beam_foot"]
	_spins = spec["spin"]
	position = Vector3(position.x, altitude, position.z)
	body = Node3D.new()
	add_child(body)
	hull_model = Ps1.model(spec["model"], {}, true)
	body.add_child(hull_model)
	alien = Alien.new()
	alien.look_seed = alien_seed
	alien.scale = Vector3.ONE * float(spec["alien_size"])
	alien.position = Vector3(0, spec["alien_y"], 0)
	body.add_child(alien)
	# The dome is drawn after the alien inside it
	var dome := hull_model.find_child("dome", true, false) as MeshInstance3D
	if dome != null:
		dome.sorting_offset = 1.0

	beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = BEAM_TOP
	cone.bottom_radius = beam_foot
	cone.height = altitude - 0.5
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	beam_mat = ShaderMaterial.new()
	beam_mat.shader = load("res://shaders/beam.gdshader")
	beam.material_override = beam_mat
	beam.position.y = -(altitude - 0.5) * 0.5 - 0.5
	beam.visible = false
	add_child(beam)

	# A pale light always on the ground under it (to see where it is), green and bright in the beam
	spot = SpotLight3D.new()
	spot.rotation.x = -PI / 2
	spot.spot_range = altitude + 4.0
	spot.spot_angle = rad_to_deg(atan(beam_foot * 1.3 / altitude))
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
	dash_wait -= delta
	dash_left -= delta
	# (no beam while dashing: whatever was in it drops)
	beaming = beam_on and dash_left <= 0.0
	var top := speed * (BEAM_SLOW if beaming else 1.0)
	var want := Vector3(steer.x, 0, steer.y) * top
	if dash_left > 0.0:
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = velocity.lerp(want, minf(delta * (4.0 if want.length() > 0.1 else 2.5), 1.0))
	position += velocity * delta
	position.y = altitude + sin(_t * 1.7) * 0.15
	# Banks into the way it is going
	body.rotation.x = lerpf(body.rotation.x, velocity.z / speed * 0.25, minf(delta * 5.0, 1.0))
	body.rotation.z = lerpf(body.rotation.z, -velocity.x / speed * 0.25, minf(delta * 5.0, 1.0))
	# (a dodge is a barrel roll the way it goes)
	_roll = move_toward(_roll, 0.0, delta * TAU / DASH_SAFE)
	body.rotation.z += _roll * -signf(_dash_dir.x if absf(_dash_dir.x) > 0.3 else 1.0)
	if _spins:
		# The saucer and the orb turn slowly, faster with the beam on
		hull_model.rotation.y += delta * (0.6 + (1.8 if beaming else 0.0))
	elif velocity.length() > 1.0:
		# The triangle points where it is going
		hull_model.rotation.y = lerp_angle(hull_model.rotation.y, atan2(velocity.x, velocity.z), minf(delta * 6.0, 1.0))
	alien.look = Vector2(velocity.x, velocity.z) / speed
	if alien.mood in ["steer", "beam"]:
		alien.mood = "beam" if beaming else "steer"
	_power = move_toward(_power, 1.0 if beaming else 0.0, delta * 6.0)
	beam.visible = _power > 0.01
	beam_mat.set_shader_parameter("power", _power)
	spot.light_color = Color(0.75, 0.85, 1.0).lerp(Color(0.5, 1.0, 0.6), _power)
	spot.light_energy = 1.5 + _power * 3.0
	# A shield that has not been hit for a while mends, but only once the heat is off
	if since_hit > 3.0 and hull < hull_max:
		hull = minf(hull + delta * mend_rate * hull_max / 100.0, hull_max)
	Ps1.flash(hull_model, Color(0.8, 0.1, 0.05) * maxf(0.0, 1.0 - since_hit * 5.0))


## How fast the shield mends (the game sets it from the heat)
var mend_rate := 0.0


## A quick dash `dir` (on the ground plane, x across and y toward the camera), if one is ready
func dodge(dir: Vector2) -> bool:
	if dead or dash_wait > 0.0 or dir.length() < 0.01:
		return false
	_dash_dir = Vector3(dir.x, 0, dir.y).normalized()
	dash_left = DASH_TIME
	dash_wait = DASH_WAIT
	_roll = TAU
	return true


## Untouchable for a moment at the start of a dodge
func dodging() -> bool:
	return dash_wait > DASH_WAIT - DASH_SAFE


## Whether a point is inside the beam: wide at the ground, narrow under the ship
func in_beam(p: Vector3, slack := 0.0) -> bool:
	if not beaming or dead:
		return false
	var h := clampf(p.y / (altitude - 0.5), 0.0, 1.0)
	var r := lerpf(beam_foot, BEAM_TOP, h) + slack
	return Vector2(p.x - position.x, p.z - position.z).length() < r


## Whether a shot at `p` has struck the ship (a flat disc of it)
func struck(p: Vector3) -> bool:
	if dead or dodging():
		return false
	var flat := Vector2(p.x - position.x, p.z - position.z).length()
	return flat < radius and absf(p.y - position.y) < 0.9 + (1.0 - flat / radius) * 0.6


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
