class_name Ufo
extends Node3D
## The ship, with the alien at the controls under its dome. It flies at one height over the land,
## banks into its turns, and holds a beam down to the ground that slows it while it is on.
##
## A bubble of shield round it (`hull`, drawn by `bubble`) takes the shots, fading as it weakens.
## Once it is gone the ship is bare, and the next shot brings it down. It recharges only once the
## heat is off.
##
## There are three ships (SHIPS), chosen on the title screen. The classic saucer is the all-rounder;
## the orb (after the scout ships of Close Encounters of the Third Kind) is slow and low but tough,
## and pulls things up fast; the black triangle is quick and flies high (shots take longer to reach
## it), but is thin-skinned and its beam is slow and weak.
##
## A dodge spins the ship like a top, leaves afterimages behind it and throws the pilot about.
## The ship's lights flash with the beam, a dodge and a hit. The pilot works a stick and a panel
## of buttons in front of it (see `panel`), mashing the buttons while the beam is on.

const SHIPS := {
	"saucer": {"title": "CLASSIC SAUCER", "model": "ufo", "speed": 12.0, "lift": 1.0, "hull": 50.0, "tier": 2, "altitude": 8.0,
		"radius": 2.8, "beam_foot": 2.7, "alien_y": 0.3, "alien_size": 0.9, "spin": true,
		"about": "The all-rounder. Its beam pulls up trees and rocks.", "ghost": Color(0.5, 1.0, 0.65)},
	"orb": {"title": "THE ORB", "model": "orb", "speed": 9.5, "lift": 1.5, "hull": 80.0, "tier": 3, "altitude": 6.0,
		"radius": 2.2, "beam_foot": 3.2, "alien_y": 1.2, "alien_size": 0.72, "spin": true,
		"about": "Slow and low, but tough. Its beam lifts buildings.", "ghost": Color(1.0, 0.7, 0.3)},
	"triangle": {"title": "BLACK TRIANGLE", "model": "triangle", "speed": 15.0, "lift": 0.6, "hull": 35.0, "tier": 1, "altitude": 10.5,
		"radius": 2.3, "beam_foot": 2.3, "alien_y": 0.14, "alien_size": 0.46, "spin": false, "scale": 0.7,
		"about": "High and fast. Thin shield; a slow beam for small things.", "ghost": Color(0.6, 0.8, 1.0)},
}
const ORDER: Array[String] = ["saucer", "orb", "triangle"]
const BEAM_SLOW := 0.6
## The dodge: a dash this fast for this long, untouchable while it lasts, then a wait before the next
const DASH_SPEED := 34.0
const DASH_TIME := 0.22
const DASH_SAFE := 0.35
const DASH_WAIT := 2.5
## Afterimages a dodge leaves, before upgrades (the DASH upgrade adds two a level)
const GHOSTS := 3
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
## Bought from traders: each level a quicker recharge and two more afterimages
var dash_level := 0
## How far above its flying height it still is, coming down from space at the start of a run
var descent := 0.0
## Where the pilot sits, and how long it is still being thrown about after a dodge
var seat := Vector3.ZERO
var pilot_size := 1.0
var _toss := 0.0
var _spin := 0.0
var _ghost_wait := 0.0
var _model_name := "ufo"
var _ghost_colour := Color.WHITE
## The ship's own lights, and the rest of its hull (to flash them apart)
var _lights: Array[ShaderMaterial] = []
var _plates: Array[ShaderMaterial] = []
## The pilot's controls: a panel of buttons and a stick that leans as the ship is steered
var panel: Node3D
var stick: Node3D
var _buttons: Array[ShaderMaterial] = []
var _steer := Vector2.ZERO
## The shield, seen: a bubble round the ship
var bubble: MeshInstance3D
var _bubble_mat: ShaderMaterial
## Whether the last hit broke the shield (the game says so)
var shield_broke := false
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
	hull_model.scale = Vector3.ONE * float(spec.get("scale", 1.0))
	body.add_child(hull_model)
	_model_name = spec["model"]
	_ghost_colour = spec.get("ghost", Color.WHITE)
	_sort_materials(hull_model)
	alien = Alien.new()
	alien.look_seed = alien_seed
	alien.scale = Vector3.ONE * float(spec["alien_size"])
	alien.position = Vector3(0, spec["alien_y"], 0)
	seat = alien.position
	pilot_size = float(spec["alien_size"])
	body.add_child(alien)
	_build_panel(float(spec["alien_size"]), Vector3(0, spec["alien_y"], 0))
	bubble = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 20
	ball.rings = 10
	bubble.mesh = ball
	_bubble_mat = ShaderMaterial.new()
	_bubble_mat.shader = load("res://shaders/shield.gdshader")
	bubble.material_override = _bubble_mat
	bubble.scale = Vector3(radius + 0.7, radius * 0.55 + 0.6, radius + 0.7)
	bubble.position.y = 0.3
	body.add_child(bubble)
	# The dome is drawn after the alien inside it
	var dome := hull_model.find_child("dome*", true, false) as MeshInstance3D
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
	position.y = altitude + descent + sin(_t * 1.7) * 0.15
	# Banks into the way it is going
	body.rotation.x = lerpf(body.rotation.x, velocity.z / speed * 0.25, minf(delta * 5.0, 1.0))
	body.rotation.z = lerpf(body.rotation.z, -velocity.x / speed * 0.25, minf(delta * 5.0, 1.0))
	_steer = steer
	if _spin > 0.0:
		# A dodge spins the hull like a top, and leaves afterimages behind it
		_spin -= delta
		hull_model.rotation.y += delta * 30.0
		_ghost_wait -= delta
		if _ghost_wait <= 0.0:
			_ghost_wait = DASH_SAFE / float(GHOSTS + 2 * dash_level)
			_afterimage()
	elif _spins:
		# The saucer and the orb turn slowly, faster with the beam on
		hull_model.rotation.y += delta * (0.6 + (1.8 if beaming else 0.0))
	elif velocity.length() > 1.0 and not _spins:
		# The triangle points where it is going
		hull_model.rotation.y = lerp_angle(hull_model.rotation.y, atan2(velocity.x, velocity.z), minf(delta * 6.0, 1.0))
	alien.look = Vector2(velocity.x, velocity.z) / speed
	_throw_pilot(delta)
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
	_flash_lights()
	var left := hull / hull_max
	bubble.visible = hull > 0.0
	_bubble_mat.set_shader_parameter("strength", 0.25 + 0.75 * left)
	_bubble_mat.set_shader_parameter("hit", maxf(0.0, 1.0 - since_hit * 3.0))
	if stick != null:
		stick.rotation = Vector3(steer.y * 0.5, 0, -steer.x * 0.5)
	for i in _buttons.size():
		var lit := beaming and fmod(_t * 9.0 + i * 0.37, 1.0) < 0.5
		_buttons[i].set_shader_parameter("flash", Color(0.6, 0.6, 0.6) if lit else Color.BLACK)


## How fast the shield mends (the game sets it from the heat)
var mend_rate := 0.0


## A quick dash `dir` (on the ground plane, x across and y toward the camera), if one is ready
func dodge(dir: Vector2) -> bool:
	if dead or dash_wait > 0.0 or dir.length() < 0.01:
		return false
	_dash_dir = Vector3(dir.x, 0, dir.y).normalized()
	dash_left = DASH_TIME
	dash_wait = dash_wait_max()
	_spin = DASH_SAFE
	_ghost_wait = 0.0
	alien.feel("tossed", DASH_SAFE + 0.35)
	_toss = DASH_SAFE + 0.35
	return true


## In a dodge the pilot is flung round the cockpit with the spin, tumbling, and then drops back
## into the seat
func _throw_pilot(delta: float) -> void:
	if _toss > 0.0:
		_toss -= delta
		var a := _t * 24.0
		var r := 0.32 * pilot_size
		alien.position = seat + Vector3(cos(a) * r, absf(sin(_t * 17.0)) * 0.35 * pilot_size, sin(a) * r)
		alien.rotation = Vector3(sin(_t * 21.0) * 1.1, sin(_t * 9.0) * 1.5, cos(_t * 16.0) * 1.2)
	else:
		alien.position = alien.position.lerp(seat, minf(delta * 10.0, 1.0))
		alien.rotation = alien.rotation.lerp(Vector3.ZERO, minf(delta * 10.0, 1.0))


## How ready the next dodge is, 0 (just used) to 1
func dodge_ready() -> float:
	return clampf(1.0 - dash_wait / dash_wait_max(), 0.0, 1.0)


## The wait between dodges, shorter with each DASH upgrade
func dash_wait_max() -> float:
	return DASH_WAIT - 0.35 * dash_level


## The lights apart from the plates of the hull: what is drawn glowing is a light
func _sort_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null or m.shader != Ps1.LIT:
				continue
			if float(m.get_shader_parameter("glow")) > 0.0:
				_lights.append(m)
			else:
				_plates.append(m)
	for c in n.get_children():
		_sort_materials(c)


## Red on a hit (the whole hull), a white strobe in a dodge, a quick green pulse with the beam
func _flash_lights() -> void:
	var hit := maxf(0.0, 1.0 - since_hit * 4.0)
	var light := Color.BLACK
	if hit > 0.0:
		light = Color(1.5, 0.1, 0.05) * (1.0 if fmod(_t, 0.1) < 0.05 else 0.3)
	elif dodging():
		light = Color(1.4, 1.4, 1.4) if fmod(_t, 0.08) < 0.04 else Color.BLACK
	elif beaming:
		light = Color(0.2, 1.0, 0.35) * (0.5 + 0.5 * sin(_t * 18.0))
	for m in _lights:
		m.set_shader_parameter("flash", light)
	for m in _plates:
		m.set_shader_parameter("flash", Color(0.8, 0.1, 0.05) * hit)


## A see-through copy of the hull where it is, fading out behind the dodge
func _afterimage() -> void:
	var ghost := Ps1.ghost_of(_model_name, _ghost_colour, 0.55)
	get_parent().add_child(ghost)
	ghost.global_transform = hull_model.global_transform
	var m: ShaderMaterial = ghost.get_meta("ghost")
	var tw := ghost.create_tween()
	tw.tween_method(func(a: float) -> void: m.set_shader_parameter("alpha", a), 0.55, 0.0, 0.4)
	tw.tween_callback(ghost.queue_free)


## The desk in front of the pilot: a row of buttons and a stick, at the pilot's size
func _build_panel(size: float, at: Vector3) -> void:
	panel = Node3D.new()
	panel.position = at
	panel.scale = Vector3.ONE * size
	body.add_child(panel)
	var desk := Ps1.mat(Color(0.25, 0.27, 0.32))
	Ps1.part(panel, BoxMesh.new(), desk, Vector3(0, 0.28, 0.3), Vector3(0.44, 0.04, 0.16), Vector3(0.35, 0, 0))
	Ps1.part(panel, BoxMesh.new(), desk, Vector3(0, 0.14, 0.32), Vector3(0.36, 0.28, 0.06))
	var colours: Array[Color] = [Color(1.0, 0.25, 0.2), Color(0.3, 1.0, 0.4), Color(0.3, 0.5, 1.0), Color(1.0, 0.85, 0.2), Color(1.0, 0.4, 0.9)]
	for i in 5:
		var m := Ps1.own(colours[i], 0.6)
		_buttons.append(m)
		Ps1.part(panel, BoxMesh.new(), m, Vector3(-0.17 + i * 0.05, 0.305, 0.3), Vector3(0.03, 0.02, 0.03), Vector3(0.35, 0, 0))
	stick = Node3D.new()
	stick.position = Vector3(0.14, 0.3, 0.28)
	panel.add_child(stick)
	Ps1.part(stick, CylinderMesh.new(), Ps1.mat(Color(0.12, 0.12, 0.14)), Vector3(0, 0.05, 0), Vector3(0.012, 0.05, 0.012))
	Ps1.part(stick, Ps1.ball(), Ps1.mat(Color(0.9, 0.15, 0.1), 0.3), Vector3(0, 0.1, 0), Vector3.ONE * 0.022)


## Untouchable for a moment at the start of a dodge
func dodging() -> bool:
	return dash_wait > dash_wait_max() - DASH_SAFE


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
	since_hit = 0.0
	alien.feel("hurt", 0.4)
	if hull > 0.0:
		# The shield takes it
		hull -= amount
		if hull <= 0.0:
			hull = 0.0
			shield_broke = true
		return
	# Nothing left to take it: one shot is enough
	if true:
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
