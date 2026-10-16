class_name Ufo
extends Node3D
## The ship, with the alien at the controls under its dome. It flies at one height over the land,
## banks into its turns, and holds a beam down to the ground that slows it while it is on.
##
## A bubble of shield round it (`hull`, drawn by `bubble`) takes the shots, fading as it weakens.
## Once it is gone the ship is bare, and the next shot brings it down. It recharges only once the
## heat is off.
##
## There are six ships (SHIPS), chosen on the title screen. The classic saucer is the all-rounder;
## the orb (after the scout ships of Close Encounters of the Third Kind) is slow and low but tough,
## and pulls things up fast; the black triangle is quick and flies high (shots take longer to reach
## it), but is thin-skinned and its beam is slow and weak. The foo fighter (the balls of light
## pilots saw in the war) is tiny and quick, hard to hit but with hardly any shield, and low, so
## shots reach it soon; the cigar (the mother ship of the 1950s sightings) is huge and slow and hard
## to miss, with the toughest shield and the widest beam; the bell (the scout ship of the 1952
## photographs) takes the land itself from the start, but slowly, and its shield is thin.
##
## A dodge spins the ship like a top, leaves afterimages behind it and throws the pilot about.
## The ship's lights flash with the beam, a dodge and a hit. The pilot works a stick and a panel
## of buttons in front of it (see `panel`), mashing the buttons while the beam is on.

const SHIPS := {
	"saucer": {"title": "SAUCER", "model": "ufo", "speed": 12.0, "lift": 1.0, "hull": 50.0, "tier": 2, "altitude": 8.0,
		"radius": 2.8, "beam_foot": 2.7, "alien_y": 0.3, "alien_size": 0.9, "spin": true,
		"about": "The all-rounder. Its beam pulls up trees and rocks.", "ghost": Color(0.5, 1.0, 0.65)},
	"orb": {"title": "ORB", "model": "orb", "speed": 9.5, "lift": 1.5, "hull": 80.0, "tier": 3, "altitude": 6.0,
		"radius": 2.2, "beam_foot": 3.2, "alien_y": 1.2, "alien_size": 0.72, "spin": true,
		"about": "Slow and low, but tough. Its beam lifts buildings.", "ghost": Color(1.0, 0.7, 0.3)},
	"triangle": {"title": "TRIANGLE", "model": "triangle", "speed": 15.0, "lift": 0.6, "hull": 35.0, "tier": 1, "altitude": 10.5,
		"radius": 2.3, "beam_foot": 2.3, "alien_y": 0.14, "alien_size": 0.46, "spin": false, "scale": 0.7,
		"about": "High and fast. Thin shield; a slow beam for small things.", "ghost": Color(0.6, 0.8, 1.0)},
	"foo": {"title": "FOO", "model": "foo", "speed": 16.0, "lift": 1.3, "hull": 25.0, "tier": 1, "altitude": 5.0,
		"radius": 1.2, "beam_foot": 1.8, "alien_y": 0.66, "alien_size": 0.42, "spin": true,
		"about": "Tiny, quick, hard to hit. Hardly any shield; small things.", "ghost": Color(1.0, 0.55, 0.25)},
	"cigar": {"title": "CIGAR", "model": "cigar", "speed": 8.5, "lift": 0.9, "hull": 120.0, "tier": 2, "altitude": 11.0,
		"radius": 3.8, "beam_foot": 4.2, "alien_y": 0.66, "alien_size": 0.66, "spin": false, "lamps": Vector3(0, 0.95, 2.0),
		"about": "Huge and slow. The toughest shield and the widest beam.", "ghost": Color(0.85, 0.9, 1.0)},
	"bell": {"title": "BELL", "model": "bell", "speed": 10.5, "lift": 0.7, "hull": 40.0, "tier": 4, "altitude": 9.0,
		"radius": 2.7, "beam_foot": 2.6, "alien_y": 1.12, "alien_size": 0.72, "spin": true,
		"about": "Its beam takes the land itself, slowly. A thin shield.", "ghost": Color(1.0, 0.85, 0.5)},
}
const ORDER: Array[String] = ["saucer", "orb", "triangle", "foo", "cigar", "bell"]
const BEAM_SLOW := 0.6
## The dodge: a dash this fast for this long, untouchable while it lasts, then a wait before the next
const DASH_SPEED := 34.0
const DASH_TIME := 0.22
const DASH_SAFE := 0.35
const DASH_WAIT := 7.5
## The dodge has three charges (the arrows), each refilling in a third of DASH_WAIT (2.5 s at first); a dodge
## spends every charge that is full, and goes further, and leaves more afterimages, the more it spends
const CHARGES := 3
## Afterimages a dodge leaves, before upgrades (the DASH upgrade adds two a level)
const GHOSTS := 3
## The beam's radius up under the ship
const BEAM_TOP := 1.0
## How far the beam's foot can be leant off from under the ship (see `beam_aim`)
const BEAM_REACH := 3.0
## The ship's own visual layer, which its glow lights alone
const SHIP_LAYER := 4

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
var _shadow: MeshInstance3D
var beam_foot := 2.7
var velocity := Vector3.ZERO
## A shove off something it flew into (see bump), dying away
var knock := Vector3.ZERO
## Cloaked: seconds left of it (see Main.cloak), and how long until it can be used again
var cloak := 0.0
var cloak_wait := 0.0
var _was_cloaked := false
var _bumped := 0.0
var beaming := false
var hull := 100.0
var dead := false
var crashed := false
var since_hit := 10.0
var dash_left := 0.0
## Charges of the dodge, 0 to CHARGES (the pistons)
var charge := 3.0
var _safe := 0.0
var _ghosts_left := 0
var _dash_dir := Vector3.ZERO
## Bought from traders: each level a quicker recharge and two more afterimages
var dash_level := 0
## How far above its flying height it still is, coming down from space at the start of a run
var descent := 0.0
## How much of the shield bubble shows (it comes up as the ship comes down from space)
var bubble_fade := 1.0
## Landed (on the moon, on the title): it stands on its legs and goes nowhere
var parked := false:
	set(value):
		parked = value
		if _legs != null:
			_legs.visible = value
var _legs: Node3D
## Parked on the moon with the canopy swung open and the pilot out on top of the hull in a deck
## chair, drink in hand (`lounge`); off it, the pilot hops down into the cockpit (HOP seconds) and
## the canopy shuts after it
var lounging := false
var _canopy := 0.0
var _canopy_hinge: Node3D
var _drink: Node3D
var chair: Node3D
var _hop := 0.0
const HOP := 0.6
## Seconds of climbing out of the cockpit into the chair, home again (see `climb_out`)
const HOP_OUT := 1.4
var _hop_out := 0.0
## Seconds since the pilot landed in the cockpit, the ship rocking on its legs (-1 when still)
var _rock := -1.0
## A swallow going (1 just taken, down to 0), how big, and the hull's own size to bulge from
var _gulp := 0.0
var _gulp_size := 1.0
var _hull_scale := Vector3.ONE
## The bounce as the beam comes on (1 just on, down to 0), and how far back it tilts while beaming
var _kick := 0.0
const BEAM_TILT := 0.5
## How fast the hull spins in a dodge, and how fast it spins now (winding down after one)
const DASH_SPIN := 30.0
var _spin_rate := 0.6
## Smoke and sparks off the ship (with its shield gone), and the beam's whirl of dust
var puffs: Puffs
var stars: Starfall
var _smoke_wait := 0.0
## Where the chair floats over the hull, for a ship of the saucer's size (to the left of the cockpit
## as the camera sees it), how high above it, how far it bobs, and how high the pilot sits in it
const CHAIR_AT := Vector3(-1.5, 0.0, 0.3)
const CHAIR_FLOAT := 0.45
const CHAIR_BOB := 0.1
const CHAIR_SEAT := Vector3(0, 0.36, 0.02)
var _chair_y := 0.0
## Where the pilot sits, and how long it is still being thrown about after a dodge
var seat := Vector3.ZERO
var pilot_size := 1.0
var _toss := 0.0
## Three lamps on the front of the hull, lit one by one as the dodge recharges
var _lamps: Array[ShaderMaterial] = []
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
var beam_core: MeshInstance3D
var _core_mat: ShaderMaterial
var tornado: Tornado
var beam_pivot: Node3D
## Where the beam is aimed, from -1 to 1 each way (the beam thumb dragged, see Main): its foot leans
## that much of BEAM_REACH off from under the ship; and where the foot is now, from under the ship
var beam_aim := Vector2.ZERO
var _aim := Vector3.ZERO
var beam_mat: ShaderMaterial
var spot: SpotLight3D
var beam_light: SpotLight3D
## Where the beam will fall, on the ground under the ship, until the beam comes on (reticle.gdshader)
var reticle: MeshInstance3D
var _reticle_mat: ShaderMaterial
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
	_hull_scale = hull_model.scale
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
	# (on the front of the rim; or where the ship says, on its hull and turning with it: the cigar's
	# are on its back, its nose being too narrow)
	var lamps: Vector3 = spec.get("lamps", Vector3(0, 0.22, radius * 0.78))
	for i in 3:
		var m := Ps1.own(Color(0.4, 1.0, 0.5), 1.5)
		_lamps.append(m)
		Ps1.part(hull_model if spec.has("lamps") else body, Ps1.ball(), m, lamps + Vector3((i - 1) * 0.42, 0, 0), Vector3.ONE * 0.13)
	_legs = Node3D.new()
	body.add_child(_legs)
	# (three legs splayed out, each 1.2 long, its foot pad right at the bottom of it)
	const SPLAY := 0.3
	for i in 3:
		var a := i * TAU / 3.0
		var out := Vector3(sin(a), 0, cos(a))
		var mid := out * radius * 0.6 + Vector3(0, -0.9, 0)
		var foot := mid + out * 0.6 * sin(SPLAY) + Vector3(0, -0.6 * cos(SPLAY), 0)
		Ps1.part(_legs, CylinderMesh.new(), Ps1.mat(Color(0.32, 0.34, 0.38)), mid, Vector3(0.08, 0.6, 0.08), Vector3(-cos(a) * SPLAY, 0, sin(a) * SPLAY))
		Ps1.part(_legs, Ps1.ball(), Ps1.mat(Color(0.32, 0.34, 0.38)), foot + Vector3(0, -0.03, 0), Vector3(0.25, 0.08, 0.25))
	_legs.visible = parked
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
		# (hinged at its back edge, to swing open backwards like a lid)
		var box := dome.get_aabb()
		_canopy_hinge = Node3D.new()
		dome.get_parent().add_child(_canopy_hinge)
		_canopy_hinge.position = dome.transform * Vector3(box.get_center().x, box.position.y, box.position.z)
		dome.reparent(_canopy_hinge)

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
	beam.position.y = -(altitude - 0.5) * 0.5
	beam.visible = false
	# (hung from a pivot at the belly, which leans it toward where it is aimed: see `_lean_beam`)
	beam_pivot = Node3D.new()
	beam_pivot.position.y = -0.5
	add_child(beam_pivot)
	beam_pivot.add_child(beam)
	# (and a second, narrower cone inside it, and the whirl of motes swirling up it)
	beam_core = MeshInstance3D.new()
	var inner := cone.duplicate() as CylinderMesh
	inner.top_radius = BEAM_TOP * 0.8
	inner.bottom_radius = beam_foot * 0.8
	beam_core.mesh = inner
	_core_mat = ShaderMaterial.new()
	_core_mat.shader = beam_mat.shader
	_core_mat.set_shader_parameter("core", 1.0)
	_core_mat.set_shader_parameter("tint", Color(0.75, 1.0, 0.8))
	beam_core.material_override = _core_mat
	beam.add_child(beam_core)
	tornado = Tornado.new()
	add_child(tornado)

	# A pale light always on the ground under it (to see where it is), green and bright in the beam
	spot = SpotLight3D.new()
	spot.rotation.x = -PI / 2
	spot.spot_range = altitude + 4.0
	spot.spot_angle = rad_to_deg(atan(beam_foot * 1.3 / altitude))
	spot.light_energy = 1.5
	spot.light_color = Color(0.75, 0.85, 1.0)
	# (a soft edge to the circle it throws on the ground)
	spot.spot_angle_attenuation = 2.5
	spot.spot_angle *= 1.25
	spot.position.y = -0.6
	add_child(spot)
	# The beam's own light, green, throwing shadows of whatever is in the beam onto the ground. It
	# shines only on the ground and on what is in the beam (Thing.BEAM_LAYER), so the shadows cost
	# little: everything else is left out of them
	beam_light = SpotLight3D.new()
	beam_light.rotation.x = -PI / 2
	beam_light.position.y = -0.1
	beam_light.spot_range = altitude + 14.0
	beam_light.spot_angle = 55.0
	beam_light.spot_angle_attenuation = 3.0
	beam_light.light_color = Color(0.55, 1.0, 0.65)
	beam_light.light_cull_mask = 1 << (Thing.BEAM_LAYER - 1)
	beam_light.shadow_enabled = true
	beam_light.visible = false
	beam_pivot.add_child(beam_light)
	reticle = MeshInstance3D.new()
	var pad := PlaneMesh.new()
	pad.size = Vector2.ONE * beam_foot * 1.6
	pad.subdivide_width = 4
	pad.subdivide_depth = 4
	reticle.mesh = pad
	_reticle_mat = ShaderMaterial.new()
	_reticle_mat.shader = load("res://shaders/reticle.gdshader")
	reticle.material_override = _reticle_mat
	reticle.top_level = true
	reticle.visible = false
	add_child(reticle)
	puffs = Puffs.new()
	add_child(puffs)
	stars = Starfall.new()
	add_child(stars)
	glow = OmniLight3D.new()
	# (only the ship itself: lighting anything else, whose wide cull margin had it "lit" from far off,
	# made a shader for it at that moment, which stalled the game in the descent; see `_ship_layer`)
	glow.light_cull_mask = 1 << (SHIP_LAYER - 1)
	glow.omni_range = 5.0
	glow.light_energy = 0.8
	glow.light_color = Color(0.7, 1.0, 0.75)
	glow.position.y = 1.5
	add_child(glow)
	_ship_layer(body)
	# Its shadow on the ground below: a soft dark round, fading out higher up (see _cast_shadow)
	_shadow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_shadow.mesh = plane
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.disable_fog = true
	var blot := GradientTexture2D.new()
	blot.fill = GradientTexture2D.FILL_RADIAL
	blot.fill_from = Vector2(0.5, 0.5)
	blot.fill_to = Vector2(1.0, 0.5)
	blot.gradient = Gradient.new()
	blot.gradient.set_color(0, Color(0, 0, 0, 0.55))
	blot.gradient.set_color(1, Color(0, 0, 0, 0.0))
	shade.albedo_texture = blot
	_shadow.material_override = shade
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func ground() -> Vector3:
	return Vector3(position.x, 0.0, position.z)


## On the moon: the canopy open, the pilot up on top lounging with a beer (`on`), or the
## drink gone and the pilot back down at the controls with the canopy shutting (not `on`)
func lounge(on: bool) -> void:
	if not on and lounging:
		_hop = HOP
		alien.feel("tossed", HOP)
	lounging = on
	if on:
		alien.feel("lounge")
		if chair == null:
			chair = Ps1.model("lounge_chair")
			chair.scale = Vector3.ONE * pilot_size
			_chair_y = _hull_top() + CHAIR_FLOAT * pilot_size
			chair.position = Vector3(CHAIR_AT.x * radius / 2.8, _chair_y, CHAIR_AT.z * radius / 2.8)
			# (on the ship's steady root, not its body: the body rocks as the pilot drops in, the chair
			# floating over it does not)
			add_child(chair)
		if _drink == null:
			_drink = Ps1.model("beer")
			_drink.scale = Vector3.ONE * 1.6
			alien.arms[1].add_child(_drink)
			_drink.position = Vector3(0.02, -0.36, 0.03)
			_drink.rotation = Vector3(PI, 0, 0)
	else:
		alien.feel("steer")
		if _drink != null:
			_drink.queue_free()
			_drink = null


## Home on the moon: the canopy opens and the pilot climbs out of the cockpit and up into the chair,
## to lounge (see `lounge`)
func climb_out() -> void:
	if chair == null:
		chair = Ps1.model("lounge_chair")
		chair.scale = Vector3.ONE * pilot_size
		_chair_y = _hull_top() + CHAIR_FLOAT * pilot_size
		chair.position = Vector3(CHAIR_AT.x * radius / 2.8, _chair_y, CHAIR_AT.z * radius / 2.8)
		add_child(chair)
	alien.feel("cheer", HOP_OUT)
	_hop_out = HOP_OUT


## The chair, left behind as the ship lifts off (for the blast to blow away, see MoonSet.blast), or
## null with none
func leave_chair() -> Node3D:
	var left := chair
	chair = null
	return left


## How high the top of the hull is just in front of the cockpit (where the chair stands)
func _hull_top() -> float:
	if _canopy_hinge != null:
		return _canopy_hinge.position.y - 0.08
	return seat.y


## Flies by `steer` (a stick, at most 1 long); `beam_on` holds the beam down
func tick(delta: float, steer: Vector2, beam_on: bool) -> void:
	_cloaking(delta, beam_on)
	_cast_shadow()
	_t += delta
	since_hit += delta
	if dead:
		reticle.visible = false
		_falling(delta)
		return
	if parked:
		# (on its legs: its lights going, the canopy open with the pilot up on top or shut with it
		# inside, nothing more)
		beaming = false
		beam.visible = false
		bubble.visible = false
		var was_hopping := _hop > 0.0
		_hop = maxf(_hop - delta, 0.0)
		if was_hopping and _hop <= 0.0:
			_rock = 0.0
		if _rock >= 0.0:
			# (the pilot landing in the cockpit: the ship dips on its legs and rocks, settling)
			_rock += delta
			var fade := exp(-3.2 * _rock)
			body.position.y = -0.22 * fade * sin(_rock * 13.0)
			body.rotation.z = 0.11 * fade * sin(_rock * 9.0)
			body.rotation.x = 0.06 * fade * sin(_rock * 7.0 + 1.0)
			if _rock > 2.0:
				_rock = -1.0
				body.position.y = 0.0
				body.rotation = Vector3.ZERO
		_canopy = move_toward(_canopy, 1.0 if lounging or _hop > 0.0 or _hop_out > 0.0 else 0.0, delta * 2.2)
		if _canopy_hinge != null:
			_canopy_hinge.rotation.x = -1.75 * smoothstep(0.0, 1.0, _canopy)
		if chair != null:
			# (floating over the hull, bobbing gently, rocking a little)
			chair.position.y = _chair_y + sin(_t * 1.4) * CHAIR_BOB * pilot_size
			chair.rotation.z = sin(_t * 0.9) * 0.06
			var in_chair := chair.position + CHAIR_SEAT * pilot_size
			if lounging:
				alien.position = in_chair
				alien.rotation.z = chair.rotation.z
			elif _hop_out > 0.0:
				# (the canopy opening, then up out of the cockpit and into the chair)
				_hop_out = maxf(_hop_out - delta, 0.0)
				var k := clampf((1.0 - _hop_out / HOP_OUT - 0.4) / 0.6, 0.0, 1.0)
				alien.position = seat.lerp(in_chair, k) + Vector3(0, sin(k * PI) * 1.1, 0)
				if _hop_out <= 0.0:
					lounge(true)
			elif _hop > 0.0:
				# (up out of the chair and down into the cockpit)
				var k := 1.0 - _hop / HOP
				alien.position = in_chair.lerp(seat, k) + Vector3(0, sin(k * PI) * 1.1, 0)
				alien.rotation.z = 0.0
			else:
				alien.position = seat
		_flash_lights()
		return
	charge = minf(charge + delta * CHARGES / dash_wait_max(), CHARGES)
	_safe -= delta
	dash_left -= delta
	# (no beam while dashing: whatever was in it drops)
	var was_beaming := beaming
	beaming = beam_on and dash_left <= 0.0
	if beaming and not was_beaming:
		# (a little bounce as the beam comes on)
		_kick = 1.0
	var top := speed * (BEAM_SLOW if beaming else 1.0)
	var want := Vector3(steer.x, 0, steer.y) * top
	if dash_left > 0.0:
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = velocity.lerp(want, minf(delta * (4.0 if want.length() > 0.1 else 2.5), 1.0))
	position += (velocity + knock) * delta
	knock = knock.lerp(Vector3.ZERO, minf(delta * 3.0, 1.0))
	position.y = altitude + descent + sin(_t * 1.7) * 0.15
	# Banks into the way it is going
	# (leaning into the way it goes, never more than a little, a dash being far faster than flying;
	# tilted back while beaming, its underside and the beam toward the camera)
	body.rotation.x = lerpf(body.rotation.x, clampf(velocity.z / speed * 0.25, -0.3, 0.3) - (BEAM_TILT if beaming else 0.0), minf(delta * 5.0, 1.0))
	body.rotation.z = lerpf(body.rotation.z, clampf(-velocity.x / speed * 0.25, -0.3, 0.3), minf(delta * 5.0, 1.0))
	_steer = steer
	if _spin > 0.0:
		# A dodge spins the hull like a top, and leaves afterimages behind it
		_spin -= delta
		_spin_rate = DASH_SPIN
		hull_model.rotation.y += delta * _spin_rate
		_ghost_wait -= delta
		if _ghost_wait <= 0.0 and _ghosts_left > 0:
			_ghosts_left -= 1
			_ghost_wait = _spin / float(maxi(_ghosts_left, 1))
			_afterimage()
	elif _spins:
		# The saucer and the orb turn slowly, faster with the beam on (and after a dodge, winding
		# down from its spin to that)
		_spin_rate = lerpf(_spin_rate, 0.6 + (1.8 if beaming else 0.0), minf(delta * 1.2, 1.0))
		hull_model.rotation.y += delta * _spin_rate
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
	_core_mat.set_shader_parameter("power", _power)
	# (the two cones breathing in and out against each other)
	var bob := sin(_t * 5.0) * 0.06
	beam.scale = Vector3(1.0 + bob, 1.0, 1.0 + bob)
	beam_core.scale = Vector3(1.0 - bob * 1.5, 1.0, 1.0 - bob * 1.5)
	_lean_beam(delta)
	tornado.follow(Vector3(position.x, position.y - 0.6, position.z), beam_foot, BEAM_TOP, delta, _aim, beaming)
	# (the beam's light throws shadows of whatever is in it)
	beam_light.visible = _power > 0.05
	beam_light.light_energy = _power * 2.6
	spot.light_color = Color(0.75, 0.85, 1.0).lerp(Color(0.5, 1.0, 0.6), _power)
	spot.light_energy = 2.2
	# (the reticle on the ground where the beam will fall, giving way to the beam itself)
	reticle.visible = _power < 0.99 and descent < 2.0
	reticle.global_position = Vector3(position.x, 0.06, position.z)
	_reticle_mat.set_shader_parameter("power", 1.0 - _power)
	# A shield that has not been hit for a while mends, but only once the heat is off
	if since_hit > 3.0 and hull < hull_max:
		hull = minf(hull + delta * mend_rate * hull_max / 100.0, hull_max)
	_gulping(delta)
	_smoking(delta)
	_flash_lights()
	var ready := dodge_ready()
	for i in _lamps.size():
		var lit := ready >= (i + 1) / 3.0
		_lamps[i].set_shader_parameter("tint", Color(0.4, 1.0, 0.5) if lit else Color(0.35, 0.08, 0.06))
		_lamps[i].set_shader_parameter("glow", 1.5 if lit else 0.3)
	var left := hull / hull_max
	bubble.visible = hull > 0.0 and bubble_fade > 0.0 and cloak <= 0.0
	_bubble_mat.set_shader_parameter("strength", (0.25 + 0.75 * left) * bubble_fade)
	_bubble_mat.set_shader_parameter("hit_age", since_hit)
	if stick != null:
		stick.rotation = Vector3(steer.y * 0.5, 0, -steer.x * 0.5)
	for i in _buttons.size():
		var lit := beaming and fmod(_t * 9.0 + i * 0.37, 1.0) < 0.5
		_buttons[i].set_shader_parameter("flash", Color(0.6, 0.6, 0.6) if lit else Color.BLACK)


## How fast the shield mends (the game sets it from the heat)
var mend_rate := 0.0


## A quick dash `dir` (on the ground plane, x across and y toward the camera), if one is ready
func dodge(dir: Vector2) -> bool:
	if dead or charge < 1.0 or dir.length() < 0.01:
		return false
	_dash_dir = Vector3(dir.x, 0, dir.y).normalized()
	# One charge a dash, each the whole dash (up to three in a row)
	charge -= 1.0
	dash_left = DASH_TIME
	_safe = DASH_SAFE
	_spin = DASH_SAFE
	_ghosts_left = GHOSTS + 2 * dash_level
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
	return clampf(charge / CHARGES, 0.0, 1.0)


## The wait between dodges, shorter with each DASH upgrade
func dash_wait_max() -> float:
	return maxf(DASH_WAIT - 0.6 * dash_level, 2.5)


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
	elif _gulp > 0.0:
		# (something swallowed: the rim lights flash yellow)
		light = Color(1.8, 1.4, 0.15) * (1.0 if fmod(_t, 0.14) < 0.08 else 0.25) * (0.4 + 0.6 * _gulp)
	elif beaming:
		light = Color(0.2, 1.0, 0.35) * (0.5 + 0.5 * sin(_t * 18.0))
	for m in _lights:
		m.set_shader_parameter("flash", light)
	for m in _plates:
		m.set_shader_parameter("flash", Color(0.8, 0.1, 0.05) * hit)



## Something taken up into the ship: the hull bulges and squashes back, the ship dips and bounces,
## the lights flash and sparkles pop out (`size` 0.5 for a chicken to 2 for a barn)
func gulp(size := 1.0) -> void:
	_gulp = 1.0
	_gulp_size = clampf(size, 0.5, 2.0)
	sparkle()



## Something swallowed: a burst of sparkles popping out of the ship's belly
func sparkle() -> void:
	# (little stars out of the bottom of the ship, falling away in arcs)
	stars.burst(global_position + Vector3(0, -1.0, 0), 14, velocity)


func _gulping(delta: float) -> void:
	var dip := 0.0
	if _kick > 0.0:
		_kick = maxf(_kick - delta * 1.8, 0.0)
		var k := 1.0 - _kick
		dip -= sin(k * 13.0) * exp(-4.0 * k) * 0.28
	if _gulp > 0.0:
		_gulp = maxf(_gulp - delta * 1.6, 0.0)
		var t := 1.0 - _gulp
		var wobble := sin(t * 20.0) * exp(-4.0 * t) * 0.16 * _gulp_size
		hull_model.scale = _hull_scale * Vector3(1.0 + wobble, 1.0 - wobble * 0.9, 1.0 + wobble)
		dip -= sin(t * 14.0) * exp(-5.0 * t) * 0.35 * _gulp_size
		if _gulp <= 0.0:
			hull_model.scale = _hull_scale
	body.position.y = dip


## With its shield gone the ship smokes, trailing dark puffs off its rim, and throws sparks
func _smoking(delta: float) -> void:
	if hull > 0.0:
		return
	_smoke_wait -= delta
	if _smoke_wait > 0.0:
		return
	_smoke_wait = 0.08
	var a := randf() * TAU
	var rim := global_position + Vector3(cos(a) * radius * 0.7, 0.2, sin(a) * radius * 0.7)
	puffs.puff(rim, Color(0.16, 0.16, 0.18, 0.8), randf_range(0.5, 0.9), Vector3(0, 2.2, 0) - velocity * 0.4, 1.1)
	if randf() < 0.35:
		for i in 3:
			var out := Vector3(cos(a), 0, sin(a))
			puffs.spark(rim, (out + Vector3(randf_range(-0.5, 0.5), randf_range(0.4, 1.2), randf_range(-0.5, 0.5))) * randf_range(3.0, 6.0))

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


## The defence laser bought from a trader: a turret slung under the hull, turning to whatever it
## fires at (see main.gd `_laser`), nothing until then
var laser: Node3D
var _laser_tip: ShaderMaterial


func arm_laser() -> void:
	if laser != null:
		return
	# (under the front of the hull, a little way up into it, whatever the ship's shape)
	var under := 0.0
	var mesh := Ps1._first_mesh(hull_model)
	if mesh != null:
		under = mesh.get_aabb().position.y * hull_model.scale.y
	laser = Node3D.new()
	laser.position = Vector3(0, under * 0.75, radius * 0.3)
	body.add_child(laser)
	Ps1.part(laser, Ps1.ball(), Ps1.mat(Color(0.2, 0.21, 0.25)), Vector3.ZERO, Vector3.ONE * 0.3)
	Ps1.part(laser, BoxMesh.new(), Ps1.mat(Color(0.3, 0.31, 0.35)), Vector3(0, 0, 0.35), Vector3(0.09, 0.09, 0.6))
	_laser_tip = Ps1.own(Color(1.0, 0.25, 0.4), 1.5)
	Ps1.part(laser, Ps1.ball(), _laser_tip, Vector3(0, 0, 0.68), Vector3.ONE * 0.1)


## Turns the laser on `at` and says where its beam leaves from (the tip flashes as it fires)
func aim_laser(at: Vector3) -> Vector3:
	var to := at - laser.global_position
	if to.length() < 0.1:
		return laser.global_position
	laser.look_at(at, Vector3.UP if Vector2(to.x, to.z).length() > 0.2 else Vector3.FORWARD)
	# (look_at points -Z at it, and the barrel is on +Z)
	laser.rotate_object_local(Vector3.UP, PI)
	_laser_tip.set_shader_parameter("flash", Color(1.5, 0.6, 0.8))
	create_tween().tween_callback(func() -> void: _laser_tip.set_shader_parameter("flash", Color.BLACK)).set_delay(0.12)
	return laser.global_position + laser.global_basis.z * 0.7


## Untouchable for a moment at the start of a dodge
func dodging() -> bool:
	return _safe > 0.0




## Leans the beam toward `beam_aim` (easing there), and back straight once it is off
func _lean_beam(delta: float) -> void:
	var want := Vector3(beam_aim.x, 0, beam_aim.y).limit_length(1.0) * BEAM_REACH if beaming else Vector3.ZERO
	_aim = _aim.lerp(want, minf(delta * 6.0, 1.0))
	var down := altitude - 0.5
	var to_foot := Vector3(_aim.x, -down, _aim.z)
	# (sheared, not turned: its foot stays a flat round on the ground wherever it is aimed, all of
	# its rim down on the ground, rather than tipping up on one side)
	beam_pivot.basis = Basis(Vector3.RIGHT, -to_foot / down, Vector3.BACK)


## Where the middle of the beam is at height `y`: under the ship at the top, leant off by the aim
## lower down
func beam_axis(y: float) -> Vector3:
	var h := clampf(y / (altitude - 0.5), 0.0, 1.0)
	return Vector3(position.x, y, position.z) + _aim * (1.0 - h)
## Whether a point is inside the beam: wide at the ground, narrow under the ship
func in_beam(p: Vector3, slack := 0.0) -> bool:
	if not beaming or dead:
		return false
	var h := clampf(p.y / (altitude - 0.5), 0.0, 1.0)
	var r := lerpf(beam_foot, BEAM_TOP, h) + slack
	var mid := beam_axis(p.y)
	return Vector2(p.x - mid.x, p.z - mid.z).length() < r


## Whether a shot at `p` has struck the ship (a flat disc of it)
func struck(p: Vector3) -> bool:
	if dead or dodging() or cloak > 0.0:
		return false
	var flat := Vector2(p.x - position.x, p.z - position.z).length()
	return flat < radius and absf(p.y - position.y) < 0.9 + (1.0 - flat / radius) * 0.6


func hurt(amount: float, from := Vector3.INF) -> void:
	if dead:
		return
	since_hit = 0.0
	alien.feel("hurt", 0.4)
	# (the shield ripples out from where it was struck)
	var toward := from - bubble.global_position if from != Vector3.INF else Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1))
	_bubble_mat.set_shader_parameter("hit_dir", (bubble.global_basis.inverse() * toward).normalized())
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


## Puts the ship's own meshes on SHIP_LAYER as well, for its glow to light them
func _ship_layer(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).set_layer_mask_value(SHIP_LAYER, true)
	for c in n.get_children():
		_ship_layer(c)


## Flew into something tall (a peak, a tower) and was pushed `out` of it: knocked back off it with a
## jolt and a bit of damage (not again for a moment, so grinding along a cliff does not drain it)
func bump(out: Vector3) -> void:
	var flat := Vector3(out.x, 0, out.z)
	if flat.length() < 0.01 or dead:
		return
	var n := flat.normalized()
	var into := -velocity.dot(n)
	# (bounced back off it: its way into the thing turned round, a good part of it kept; a dash into
	# it ends there)
	if into > 0.0:
		velocity += n * into * 1.6
	dash_left = 0.0
	if Time.get_ticks_msec() / 1000.0 - _bumped < 0.4 or into < 1.0:
		return
	_bumped = Time.get_ticks_msec() / 1000.0
	knock = n * clampf(into * 0.9, 6.0, 12.0)
	_kick = 1.0
	if hull > 0.0 and into > 4.0:
		# (a hard knock takes a little of the shield, never the last of the ship; rippling out from
		# where it struck)
		hurt(minf(clampf(into * 0.6, 3.0, 8.0), hull), position - n * radius)


## The shadow under the ship, on the ground: as wide as the ship, fainter the higher it comes from
## (none on the moon or out in space, or once it is down)
func _cast_shadow() -> void:
	var high := position.y
	_shadow.visible = not dead and not parked and high < 80.0 and cloak <= 0.0
	if not _shadow.visible:
		return
	_shadow.global_position = Vector3(position.x, 0.06, position.z)
	_shadow.global_basis = Basis.IDENTITY.scaled(Vector3.ONE * radius * 2.6 * (1.0 + high * 0.02))
	(_shadow.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - (high - altitude) / 40.0, 0.0, 1.0)


## The cloak running down (the beam put on breaks it), and the ship shimmering, nearly gone, while
## it lasts: the hull seen only in flickers, the shield's bubble not at all
func _cloaking(delta: float, beam_on: bool) -> void:
	cloak_wait = maxf(cloak_wait - delta, 0.0)
	if cloak > 0.0:
		cloak = maxf(cloak - delta, 0.0)
		if beam_on:
			cloak = 0.0
	if cloak > 0.0:
		body.visible = fmod(_t * 13.0, 1.0) < 0.22
		_was_cloaked = true
	elif _was_cloaked:
		_was_cloaked = false
		body.visible = true
