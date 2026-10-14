extends Node
## Close Encounters: an arcade game. Fly the saucer over farm country at night and beam up
## whatever you can for points. Everything you take draws **heat** (five stars of it): the more
## heat, the more each catch is worth, and the harder they come after you. At one star the farmers
## take up their shotguns and a police car comes; then more police, army jeeps with machine guns,
## tanks, and at five stars jets with missiles. Lie low and the heat cools off, and only then does
## the saucer's shield mend. When the shield is gone, so is the saucer.
##
## The world is drawn small and blown up with hard pixels, as in Cryptlins, and it bends away
## over the horizon like a rolling log (shaders/bend.gdshaderinc).
##
## Modes: "title" (the pilot lounging on the moon), "launch" (off to Earth), "play", "over". Tests set
## `autopilot` to fly it themselves and `start_mode` to skip the title.

const MAX_HEAT := 5.0
## Heat cools only after this long without taking anything, and then at this many stars a second
const COOL_AFTER := 5.0
const COOL_RATE := 0.07
## Who comes for you at each level of heat
const FORCES: Array[Dictionary] = [
	{},
	{"police_car": 1},
	{"police_car": 3},
	{"police_car": 2, "jeep": 2},
	{"police_car": 1, "jeep": 2, "tank": 1},
	{"police_car": 1, "jeep": 2, "tank": 2},
]
## How many of each thing the farm keeps about (taken ones are replaced, somewhere else)
const CAMERA_OFFSET := Vector3(0, 21.5, 16.5)
## Each run opens with the ship coming down from space: this long, from this high
const INTRO := 4.5
const INTRO_HEIGHT := 320.0

@export var start_mode := "title"
var autopilot := false
## Tests run without the title screen's script check and must never save bests
var testing := false
## Leaves the camera where a test put it
var hold_camera := false
## Seconds of the descent from space left (nothing can be done until it is over)
var intro := 0.0
## Tests skip the descent unless they ask for it
var intro_in_tests := false
var _sky_mat: ShaderMaterial

var mode := "title"
var view: SubViewport
var screen: TextureRect
var screen_mat: ShaderMaterial
var camera: Camera3D
var world: World
var ufo: Ufo
var sfx: Sfx
var music: Music
var moon_set: MoonSet
## How far into the flight from the moon to Earth
var _launch_t := 0.0
var _launch_from := Vector3.ZERO
const LAUNCH := 4.2
var things: Array[Thing] = []
var shots: Array[Shot] = []
var jets: Array[Node3D] = []
var heat := 0.0
var calm := 0.0
var score := 0
var taken := 0
var best := 0
var time_alive := 0.0
var _spawn_wait := 0.0
var _cull_wait := 0.0
var _threat := 0
var _last_call := -100.0
var _patrol_wait := 1.0
var _pull_wait := 0.0
var _spark_wait := 0.0
var _circle_at := Vector3.INF
var _circle_time := 0.0
var _circle_done := false
## The traders parked about the country, and what has been bought from them this run
var shops: Array[Shop] = []
var upgrades := {"engine": 0, "beam": 0, "shield": 0, "dash": 0}
var _hot_wait := 0.0
## Things the world has asked for, waiting to be put down: [kind, where, extra]
var _to_spawn: Array = []
const SPAWN_A_FRAME := 6
## What traders sell, one pod each: three of these are set out in front of each trader
const GOODS: Array[String] = ["engine", "beam", "shield", "dash", "patch"]
const UPGRADES := {
	"engine": {"title": "ENGINE", "about": "+12% speed", "price": 300, "colour": Color(1.0, 0.55, 0.15)},
	"beam": {"title": "BEAM", "about": "lifts faster, and stronger: one more kind of thing it can take", "price": 400, "colour": Color(0.4, 1.0, 0.5)},
	"shield": {"title": "SHIELD", "about": "+25 shield, and patched up", "price": 300, "colour": Color(0.3, 0.6, 1.0)},
	"patch": {"title": "PATCH", "about": "the shield filled up again", "price": 0, "colour": Color(0.4, 1.0, 1.0)},
	"dash": {"title": "DASH", "about": "recharges faster, and leaves two more afterimages", "price": 250, "colour": Color(0.75, 0.4, 1.0)},
}
const MAX_UPGRADE := 4
## Where phone lines have been cut this run (a call near one cannot get through)
var _cuts: Array[Vector3] = []
const LINE_REACH := 150.0
var _spotted_for := 0.0
## Things further than this from the saucer are let go (their chunk has gone, or soon will)
const CULL := 216.0
var _jet_wait := 8.0
var _shake := 0.0
var _hurt := 0.0
var _over_wait := 0.0
var _last_level := 0
var _pilot_target: Thing
var _pilot_wander := Vector3.ZERO

# The HUD
var hud: CanvasLayer
var score_label: Label
var mult_label: Label
var coin: Control
var radar: Control
## The secret facilities near enough to show on the radar, looked for every few seconds
var _facilities: Array[Vector3] = []
var _facility_wait := 0.0
## The log under the score: each thing taken typed out, in glowing green, then fading
var log_box: VBoxContainer
const LOG_LINES := 6
const LOG_SPEED := 45.0
const LOG_FOR := 5.0
var _typing := 0.0
var stars: Control
var shield_bar: Control
var banner: Label
var banner_time := 0.0
var title_box: Control
var over_box: Control
var over_label: Label
var hint_label: Label
var _play_button: Button
var ship_label: Label
## Which ship is flown (see Ufo.SHIPS), chosen on the title screen and remembered
var ship := "saucer"
## The ships that can be flown: the saucer from the start, the others once found (see World.facility)
var unlocked: Array[String] = ["saucer"]
## The pilot of this run: a new alien every time
var alien_seed := randi()
var font: Font
var _popups: Array[Label3D] = []

# Touch: a stick wherever the left thumb lands, and a beam button on the right
var stick_finger := -1
var stick_from := Vector2.ZERO
var stick := Vector2.ZERO
var beam_finger := -1
var beam_button: Control
var _pause_button: Button
var _pause_box: VBoxContainer
var _resume_button: Button
var stick_ring: Control
var touched := false
var _touch_screen := DisplayServer.is_touchscreen_available()
## With ?touchdebug in the web page's address, every touch is written to the browser's console
var _touch_debug := false
var _debug_label: Label
var _debug_lines: Array[String] = []
var _debug_state := ""
var _coin_taps := 0
var _coin_tapped := 0.0
## Where and when each finger came down, to tell a swipe (a quick flick: a dodge) from a hold
var _touch_from := {}
## No finger
const NO_FINGER := -1
## When and where the mouse Godot makes of a touch went down: [position, time], or empty
var _mouse_down: Array = []
var _mouse_frame := 0
var _touch_frame_seen := true
var _touch_down_frame := -10
## Where the finger beaming is (the mark follows it)
var _beam_at := Vector2.INF
## A finger known only from the mouse Godot made of it (its own coming down was lost), until a
## drag or its lifting says which finger it is
const PENDING := -2
const SWIPE_TIME := 0.3
const SWIPE_LENGTH := 70.0


func _ready() -> void:
	randomize()
	if OS.has_feature("web"):
		_touch_debug = str(JavaScriptBridge.eval("window.location.search")).contains("touchdebug")
	# (the game pauses the tree itself, and has to go on listening for the key that unpauses it)
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://fonts/SpecialElite-Regular.ttf")
	_input_map()
	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	add_child(music)
	_build_view()
	world = World.new()
	world.game = self
	view.add_child(world)
	_load_best()
	moon_set = MoonSet.new()
	view.add_child(moon_set)
	_make_ufo(Vector3.ZERO)
	world.update(ufo.position, 0.0, true)
	_spawn_some(true)
	_warm_models()
	_build_hud()
	if start_mode == "play":
		start()
	else:
		_show_title()
	get_viewport().size_changed.connect(_fit)
	_fit()


func _input_map() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
		"beam": [KEY_SPACE, KEY_J, KEY_Z], "dodge": [KEY_SHIFT, KEY_X, KEY_K], "start": [KEY_ENTER, KEY_SPACE], "pause": [KEY_ESCAPE, KEY_P],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k: int in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for pair: Array in [["beam", JOY_BUTTON_A], ["beam", JOY_BUTTON_RIGHT_SHOULDER], ["dodge", JOY_BUTTON_B], ["dodge", JOY_BUTTON_LEFT_SHOULDER], ["start", JOY_BUTTON_A], ["start", JOY_BUTTON_START], ["pause", JOY_BUTTON_START]]:
		var b := InputEventJoypadButton.new()
		b.button_index = pair[1]
		InputMap.action_add_event(pair[0], b)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	InputMap.action_add_event("beam", trigger)
	for pair: Array in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["up", JOY_AXIS_LEFT_Y, -1.0], ["down", JOY_AXIS_LEFT_Y, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		InputMap.action_add_event(pair[0], m)


func _build_view() -> void:
	view = SubViewport.new()
	view.size = Vector2i(400, 300)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(view)
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 260.0
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	_sky_mat = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.4, 0.62)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.14, 0.26)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	camera.environment = env
	view.add_child(camera)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 0.55
	moon.rotation = Vector3(-0.9, 0.5, 0)
	view.add_child(moon)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.07)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	# (neither the backdrop nor the picture may take a touch: the game reads them, in _unhandled_input)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	screen_mat = ShaderMaterial.new()
	screen_mat.shader = load("res://shaders/screen.gdshader")
	screen = TextureRect.new()
	screen.texture = view.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.material = screen_mat
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)


## The picture is always LINES high (or wide, held upright), whatever the shape of the screen
func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	view.size = Vector2i((size * Ps1.LINES / minf(size.x, size.y)).round())
	# (an upright phone sees more of the world above and below, not less to the sides)
	camera.keep_aspect = Camera3D.KEEP_WIDTH if size.x < size.y else Camera3D.KEEP_HEIGHT
	if size.x < size.y:
		camera.fov = 50.0
	else:
		camera.fov = 42.0
	_layout_touch()


# ------------------------------------------------------------------ the run

func start(from_launch := false) -> void:
	if not ship in unlocked:
		return
	mode = "play"
	for t in things.duplicate():
		if t.is_enemy():
			_remove(t)
	for s in shots:
		s.queue_free()
	shots.clear()
	for j in jets:
		j.queue_free()
	jets.clear()
	ufo.queue_free()
	if not from_launch:
		alien_seed = randi()
	upgrades = {"engine": 0, "beam": 0, "shield": 0, "dash": 0}
	_cuts.clear()
	_forget_fingers()
	_make_ufo(Vector3.ZERO)
	heat = 0.0
	calm = 0.0
	score = 0
	_threat = 0
	taken = 0
	time_alive = 0.0
	_last_level = 0
	_spawn_wait = 2.0
	_jet_wait = 8.0
	title_box.visible = false
	over_box.visible = false
	intro = INTRO if (not testing or intro_in_tests) else 0.0
	sfx.play("whoosh", 0.6, 2.0)


## How seriously they take the ship, from its score: 1 at the start, 3 from DANGER_FULL points on.
## Everything that hunts it is that much keener (see where it is used)
const DANGER_FULL := 12000.0


func danger() -> float:
	return 1.0 + 2.0 * clampf(score / DANGER_FULL, 0.0, 1.0)


func heat_level() -> int:
	return mini(int(heat), int(MAX_HEAT))


func multiplier() -> int:
	return 1 + heat_level()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and mode == "play" and not autopilot:
		set_paused(not get_tree().paused)
	_choose_music()
	if get_tree().paused:
		return
	var steer := Vector2.ZERO
	var beam := false
	if intro > 0.0:
		# Coming down from space: out of the stars, until the planet is under the ship
		intro = maxf(intro - delta, 0.0)
		var k := 1.0 - intro / INTRO
		ufo.descent = INTRO_HEIGHT * pow(1.0 - k, 2.2)
	elif mode == "play" and not autopilot:
		steer = _read_steer()
		beam = Input.is_action_pressed("beam") or beam_finger != NO_FINGER
		if Input.is_action_just_pressed("dodge"):
			# (the way it is steered, or else the way it is going, or else away up the screen)
			var way := steer if steer.length() > 0.2 else Vector2(ufo.velocity.x, ufo.velocity.z)
			_dodge(way if way.length() > 0.5 else Vector2(0, -1))
	elif autopilot and not ufo.dead:
		var pilot := _pilot(delta)
		steer = pilot[0]
		beam = pilot[1]
	if _touch_debug and Engine.get_process_frames() % 30 == 0:
		_debug_state = "stick finger %d %s | beam finger %d | steer %s beam %s | view %s" % [stick_finger, stick.snapped(Vector2(0.01, 0.01)), beam_finger, steer.snapped(Vector2(0.01, 0.01)), beam, get_viewport().get_visible_rect().size]
		print("[CE] " + _debug_state)
		_debug_show()
	if mode == "launch":
		_launch(delta)
	ufo.tick(delta, steer, beam)
	if not ufo.dead:
		var held := ufo.position
		ufo.position = world.push_out(ufo.position, 2.6)
		ufo.position.y = held.y
	ufo.mend_rate = 2.0 if heat_level() == 0 else 0.0
	if ufo.shield_broke:
		ufo.shield_broke = false
		_banner("SHIELD DOWN: ONE MORE HIT AND YOU'RE FINISHED", 2.5)
		sfx.play("boom", 1.8)
	if mode == "title":
		heat = 0.0
		ufo.hull = ufo.hull_max
	# The beam takes hold of whatever is under it
	var here := ufo.ground()
	var frame := Engine.get_process_frames()
	for t in things:
		if t.state == "gone":
			continue
		# Far things are left alone: still ones until the ship comes near, moving ones looked at a
		# frame in four (with four frames' time), searchlights out to where they can be seen
		if t.state == "walk" and t.calling <= 0.0:
			var far := Vector2(t.position.x - here.x, t.position.z - here.z).length()
			var reach := 150.0 if t.light != null else (50.0 if t.info["move"] == "still" else 80.0)
			if far > reach:
				if t.info["move"] == "still" and t.light == null:
					continue
				if (frame + t.get_instance_id()) % 4 != 0:
					continue
				t.tick(delta * 4.0, ufo)
				continue
		if ufo.in_beam(t.position, t.reach):
			if t.kind == "pod" and t.state == "walk" and why_not(t) != "":
				t.tick(delta, ufo)
				t.rattle()
				if _hot_wait <= 0.0:
					_hot_wait = 2.5
					log_line(why_not(t), 0)
				continue
			if t.power > 0.0 and t.state == "walk":
				_drain(t, delta)
				t.tick(delta, ufo)
				continue
			if t.tier() > ufo.tier:
				# (too much for this beam: it only rattles)
				t.tick(delta, ufo)
				if t.state == "walk":
					t.rattle()
				continue
			if t.state == "walk" or t.state == "falling":
				if t.state == "walk" and t.info.has("voice") and randf() < 0.6:
					sfx.play(t.info["voice"], randf_range(0.9, 1.1), -4.0)
				if t.state == "walk":
					_witnessed(t)
				t.state = "lifted"
				t.lift = clampf(t.position.y / (ufo.altitude - 0.9), 0.0, 1.0)
			t.held = true
		t.tick(delta, ufo)
	things = things.filter(func(t: Thing) -> bool: return t.state != "gone")
	_pull_scenery(delta)
	_shops(delta)
	_watchers(delta)
	_crop_circles(delta)
	for s in shots:
		s.tick(delta, ufo, self)
	for s in shots:
		if s.done:
			s.queue_free()
	shots = shots.filter(func(s: Shot) -> bool: return not s.done)
	_jets(delta)
	if mode == "play" and intro <= 0.0:
		time_alive += delta
		_heat(delta)
		_forces(delta)
	if intro <= 0.0:
		_patrols(delta)
	world.update(ufo.position, delta)
	_spawn_some()
	if mode == "play" and not autopilot and not get_tree().paused:
		_pending_fingers()
	_cull(delta)
	_sounds()
	_camera(delta)
	_hud(delta)
	if ufo.dead and mode == "play":
		_crash(delta)
	if mode == "over" and Input.is_action_just_pressed("start") and _over_wait <= 0.0:
		start()
	if mode == "title" and Input.is_action_just_pressed("start"):
		begin_launch()
	elif mode == "title" and Input.is_action_just_pressed("left"):
		_pick_ship(-1)
	elif mode == "title" and Input.is_action_just_pressed("right"):
		_pick_ship(1)
	if _over_wait > 0.0:
		_over_wait -= delta


## A dash out of the way of what is coming, if one is ready
func _dodge(way: Vector2) -> void:
	if ufo.dodge(way.normalized()):
		sfx.play("whoosh", 1.7, -2.0)
		puff(ufo.position, Color(0.6, 0.9, 0.7), 1.2)


func _read_steer() -> Vector2:
	var v := Input.get_vector("left", "right", "up", "down")
	if stick_finger != NO_FINGER:
		v = stick
	return v.limit_length(1.0)


func _heat(delta: float) -> void:
	calm += delta
	# (the more the ship has taken, the longer it takes them to give up looking)
	if calm > COOL_AFTER * sqrt(danger()) and heat > 0.0:
		heat = maxf(heat - COOL_RATE / danger() * delta, 0.0)
	var threat := int((danger() - 1.0) * 2.0)
	if threat > _threat:
		_threat = threat
		log_line("THREAT LEVEL RAISED: THEY ARE TAKING YOU SERIOUSLY", 0)
		sfx.play("star", 0.8)
	var level := heat_level()
	if level != _last_level:
		if level > _last_level:
			_banner(["", "THE FARMERS ARE ARMED", "THE POLICE ARE COMING", "THE ARMY IS HERE", "TANKS!", "THEY SENT THE AIR FORCE"][level], 2.5)
			sfx.play("star", 1.0 + level * 0.06)
		else:
			_banner("COOLING OFF", 1.5)
			sfx.play("cool")
			# (those no longer wanted at this heat drive off)
		_last_level = level
		var wanted: Dictionary = FORCES[level]
		var have := {}
		for t in things:
			if t.is_enemy() and not t.leaving and not t.info.get("searchlight", false):
				have[t.kind] = int(have.get(t.kind, 0)) + 1
				if int(have[t.kind]) > int(wanted.get(t.kind, 0)):
					t.leaving = true


## Keeps a few patrols with searchlights roving round the ship, more the longer it has been out
func _patrols(delta: float) -> void:
	_patrol_wait -= delta
	_spotted_for = maxf(_spotted_for - delta, 0.0)
	if _patrol_wait > 0.0 or ufo.dead:
		return
	_patrol_wait = 3.0
	var have := 0
	for t in things:
		if t.info.get("searchlight", false) and t.ground().distance_to(ufo.ground()) < 120.0:
			have += 1
	if have >= mini(2 + int(time_alive / 90.0) + int((danger() - 1.0) * 1.5), 7):
		return
	var a := randf() * TAU
	var at := world.push_out(ufo.ground() + Vector3(sin(a), 0, cos(a)) * randf_range(45.0, 60.0), 3.0)
	var b := world.biome_at(at)
	spawn("patrol_jeep" if b in [World.Biome.DESERT, World.Biome.PLAINS, World.Biome.MOUNTAIN] else "patrol_car", at)


## A patrol's searchlight has the ship in it: the heat goes up fast, and does not cool while it does
func spotted(_by: Thing, delta: float, why := "SPOTTED!") -> void:
	if mode != "play":
		return
	if _spotted_for <= 0.0:
		_banner(why, 1.4)
		sfx.play("star", 1.3)
		heat = maxf(heat, minf(heat + 0.35, MAX_HEAT))
	_spotted_for = 0.6
	heat = minf(heat + 0.5 * delta, MAX_HEAT)
	calm = 0.0


## A substation under the beam: its power runs up the beam into the shield, until it goes dark
func _drain(t: Thing, delta: float) -> void:
	var take := minf(t.power, 18.0 * delta)
	t.power -= take
	ufo.hull = minf(ufo.hull + take, ufo.hull_max)
	_spark_wait -= delta
	if _spark_wait <= 0.0:
		_spark_wait = 0.06
		var up := randf_range(0.5, ufo.altitude - 1.0)
		puff(Vector3(ufo.position.x + randf_range(-1.2, 1.2), up, ufo.position.z + randf_range(-1.2, 1.2)), Color(0.55, 0.85, 1.0), 0.35)
		sfx.play("static", 2.0, -12.0)
	if t.power <= 0.0:
		Ps1.flash(t.model, Color(-0.5, -0.5, -0.5))
		log_line("POWER SIPHONED: SUBSTATION DARK", 0)
		sfx.play("cool", 0.7)


## Those who watch the sky: linger in range of one and it gives the ship away
func _watchers(delta: float) -> void:
	for t in things:
		var reach: float = t.info.get("watch", 0.0)
		if reach <= 0.0 or t.state != "walk":
			continue
		if not ufo.dead and t.ground().distance_to(ufo.ground()) < reach:
			t.watching += delta
			if t.watching > 2.0:
				spotted(t, delta * 0.6, t.info.get("why", "SPOTTED!"))
		else:
			t.watching = maxf(t.watching - delta, 0.0)


## Crop circles: hold the beam still over a field of crops and a circle presses into it, growing
## as long as the beam stays, and scoring once it is full size
func _crop_circles(delta: float) -> void:
	var here := ufo.ground()
	var over := ufo.beaming and not ufo.dead and ufo.velocity.length() < 5.0 and world.crops_at(here)
	if not over or (_circle_at != Vector3.INF and _circle_at.distance_to(here) > 4.0):
		_circle_at = Vector3.INF
		_circle_time = 0.0
		return
	_circle_time += delta
	if _circle_time < 0.5:
		return
	var full := ufo.beam_foot * 2.2
	if _circle_at == Vector3.INF:
		_circle_at = here
		world.crop_circle(here, 1.0)
		_circle_done = false
	var r := minf(1.0 + (_circle_time - 0.5) * 2.5, full)
	world.grow_circle(r)
	if r >= full and not _circle_done and mode == "play":
		_circle_done = true
		var points := 60 * multiplier()
		score += points
		heat = minf(heat + 0.02, MAX_HEAT)
		log_line("CROP CIRCLE PRESSED", points)
		sfx.play("fanfare", 1.3, -4.0)


## Where the police (or the army) come from: their nearest station or base, if one is near
func _station_for(kind: String) -> Vector3:
	var wants := "police" if kind == "police_car" else "army"
	var best := Vector3.INF
	for t in things:
		if t.info.get("station", "") == wants and t.state == "walk":
			var d := t.ground().distance_to(ufo.ground())
			if d < 120.0 and (best == Vector3.INF or d < best.distance_to(ufo.ground())):
				best = t.ground()
	return best


## Keeps the police and army up to strength for the heat, bringing them in from out of sight
func _forces(delta: float) -> void:
	_spawn_wait -= delta
	for t in things:
		if t.leaving and t.ground().distance_to(ufo.ground()) > 70.0:
			_remove(t)
	if _spawn_wait > 0.0 or ufo.dead:
		return
	var wanted: Dictionary = FORCES[heat_level()].duplicate()
	# (a ship that has taken more is sent more after it: one more of the level's first, a step of danger)
	if not wanted.is_empty():
		var first: String = wanted.keys()[0]
		wanted[first] = int(wanted[first]) + int((danger() - 1.0) * 1.5)
	for kind: String in wanted:
		var have := 0
		for t in things:
			if t.kind == kind and not t.leaving:
				have += 1
		if have < int(wanted[kind]):
			var angle := randf_range(-PI * 0.8, PI * 0.8) + PI
			# (just out of sight: past the bend ahead, or off the edge of the screen behind)
			var at := ufo.ground() + Vector3(sin(angle), 0, cos(angle)) * 32.0
			# (out of the nearest police station or army base, when there is one)
			var home := _station_for(kind)
			if home != Vector3.INF:
				at = home + Vector3(randf_range(-6, 6), 0, 10.0)
			at = world.push_out(at, 3.0)
			var t := spawn(kind, at)
			t.heading = atan2(ufo.position.x - at.x, ufo.position.z - at.z)
			_spawn_wait = 2.5
			if kind == "police_car" and have == 0:
				_banner("SIRENS!", 1.2)
			return


func _jets(delta: float) -> void:
	if mode == "play" and heat_level() >= 4 and not ufo.dead:
		_jet_wait -= delta
		if _jet_wait <= 0.0:
			# Fighter jets from four stars, twice as often at five
			_jet_wait = randf_range(7.0, 10.0) if heat_level() >= 5 else randf_range(13.0, 18.0)
			var jet := Ps1.model("jet")
			jet.position = ufo.ground() + Vector3(randf_range(-20, 20), 15.0, -90.0)
			jet.set_meta("fired", 0)
			view.add_child(jet)
			jets.append(jet)
			sfx.play("whoosh", 0.7, 3.0)
	for jet in jets:
		jet.position.z += delta * 45.0
		var fired: int = jet.get_meta("fired")
		if fired < 2 and jet.position.z > ufo.position.z - 30.0 + fired * 6.0:
			jet.set_meta("fired", fired + 1)
			var s := _shot("missile", jet.position + Vector3(0, -1, 0), ufo.position)
			s.velocity = Vector3(0, -0.2, 1).normalized() * 17.0
	for jet in jets.duplicate():
		if jet.position.z > ufo.position.z + 80.0:
			jets.erase(jet)
			jet.queue_free()


## Lets go of what is far behind the saucer (the world makes more as it goes)
func _cull(delta: float) -> void:
	_cull_wait -= delta
	if _cull_wait > 0.0:
		return
	_cull_wait = 0.5
	for t in things.duplicate():
		if t.state == "walk" and not t.fixed() and t.ground().distance_to(ufo.ground()) > CULL:
			_remove(t)


## A chunk of the world has gone: so do its buildings, scenery and trader
func forget_chunk(c: Vector2i) -> void:
	for s in shops.duplicate():
		if s.chunk == c and s.state == "parked":
			shops.erase(s)
			s.queue_free()
	for t in things.duplicate():
		if t.chunk == c and t.state == "walk":
			_remove(t)


## A trader parked at `at` (the world puts them down), with three of its goods set out in front
func spawn_shop(at: Vector3, c: Vector2i) -> void:
	var s := Shop.new()
	view.add_child(s)
	s.setup(self, at, c, randi())
	shops.append(s)
	var stock: Array = GOODS.duplicate()
	stock.shuffle()
	for i in 3:
		var what: String = stock[i]
		var pod := spawn("pod", world.off_road(at + Vector3((i - 1) * 4.5, 0, 6.5 - absf(i - 1) * 1.5), 1.0),
			{"chunk": c, "turn": 0.0, "tints": {"pod_glow": UPGRADES[what]["colour"]}})
		pod.set_meta("shop", s)
		pod.set_meta("goods", what)
		var tag := Label3D.new()
		tag.font = font
		tag.font_size = 48
		tag.pixel_size = 0.016
		tag.outline_size = 10
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 2.4, 0)
		pod.add_child(tag)
		pod.set_meta("tag", tag)
		s.pods.append(pod)


func _shops(delta: float) -> void:
	_hot_wait -= delta
	for s in shops.duplicate():
		s.tick(delta, ufo, heat_level() if mode == "play" else 0)
		if s.gone:
			shops.erase(s)
			s.queue_free()
	# Each pod's tag: what it is, what it costs, green if it can be had and red if not
	for s in shops:
		for pod: Thing in s.pods:
			if not is_instance_valid(pod) or pod.state == "gone":
				continue
			var what: String = pod.get_meta("goods")
			var tag: Label3D = pod.get_meta("tag")
			var price := goods_price(what)
			if price < 0:
				tag.text = "%s\n%s" % [UPGRADES[what]["title"], "SHIELD FULL" if what == "patch" else "THE BEST THERE IS"]
			else:
				var level := "" if what == "patch" else " %d" % (upgrades[what] + 1)
				tag.text = "%s%s\n%d" % [UPGRADES[what]["title"], level, price]
			tag.modulate = Color(0.6, 1.0, 0.65) if why_not(pod) == "" else Color(1.0, 0.45, 0.35)


## What a pod of these goods costs now (-1: nothing more to be had)
func goods_price(what: String) -> int:
	if what == "patch":
		return repair_price() if repair_price() > 0 else -1
	return upgrade_price(what) if upgrades[what] < MAX_UPGRADE else -1


## Why a pod cannot be taken just now ("" if it can)
func why_not(pod: Thing) -> String:
	var shop: Shop = pod.get_meta("shop")
	if heat_level() >= 1:
		return "%s WON'T TRADE WHILE THEY'RE LOOKING FOR YOU" % shop.keeper_name.to_upper()
	var price := goods_price(pod.get_meta("goods"))
	if price < 0:
		return "THE SHIELD IS ALREADY FULL" if pod.get_meta("goods") == "patch" else "NOTHING MORE TO BE HAD THERE"
	if score < price:
		return "NOT ENOUGH ALIEN MONEY"
	return ""


## A pod has come up the beam: it is paid for, and the trader packs the rest away and is off
func _bought(pod: Thing) -> void:
	var what: String = pod.get_meta("goods")
	var shop: Shop = pod.get_meta("shop")
	if what == "patch":
		repair()
	else:
		buy(what)
	if is_instance_valid(shop):
		log_line("TRADED WITH %s" % shop.keeper_name.to_upper(), 0)
		_pack_up(shop)
		shop.leave(true)


## The pods still on the ground go back into the trader's saucer
func _pack_up(shop: Shop) -> void:
	for pod: Thing in shop.pods:
		if is_instance_valid(pod) and pod.state == "walk":
			puff(pod.position + Vector3(0, 0.8, 0), Color(0.6, 1.0, 0.65), 1.0)
			_remove(pod)
	shop.pods.clear()


func trader_fled(s: Shop) -> void:
	_pack_up(s)
	if mode == "play" and ufo.ground().distance_to(Vector3(s.position.x, 0, s.position.z)) < 60.0:
		_banner("%s FLED THE HEAT" % s.keeper_name.to_upper(), 1.8)


func upgrade_price(what: String) -> int:
	return int(round(float(UPGRADES[what]["price"]) * pow(1.8, upgrades[what]) / 10.0)) * 10


## What has been bought, on the ship: faster, a stronger beam, a bigger shield, a quicker dodge
func _apply_upgrades() -> void:
	var spec: Dictionary = Ufo.SHIPS[ship]
	ufo.speed = float(spec["speed"]) * (1.0 + 0.12 * upgrades["engine"])
	ufo.lift_rate = float(spec["lift"]) * (1.0 + 0.2 * upgrades["beam"])
	ufo.tier = mini(int(spec["tier"]) + int(upgrades["beam"]), 4)
	ufo.hull_max = float(spec["hull"]) + 25.0 * upgrades["shield"]
	ufo.dash_level = upgrades["dash"]


func buy(what: String) -> bool:
	var price := upgrade_price(what)
	if score < price or upgrades[what] >= MAX_UPGRADE:
		return false
	score -= price
	upgrades[what] += 1
	_apply_upgrades()
	log_line("%s UPGRADED TO %d" % [UPGRADES[what]["title"], upgrades[what]], -price)
	if what == "shield":
		ufo.hull = minf(ufo.hull + 25.0, ufo.hull_max)
	sfx.play("bloop", 1.4)
	return true


## Patching the shield back up: a point of score for each point of shield
func repair_price() -> int:
	return int(ceil(ufo.hull_max - ufo.hull))


func repair() -> void:
	var price := mini(repair_price(), score)
	if price <= 0:
		return
	score -= price
	ufo.hull = minf(ufo.hull + price, ufo.hull_max)
	log_line("SHIELD PATCHED", -price)
	sfx.play("bloop", 1.2)

## The beam pulls up the scenery under it that it is strong enough for, a piece at a time
func _pull_scenery(delta: float) -> void:
	_pull_wait -= delta
	# (scenery too much for the beam rattles in the ground)
	world.rattle(ufo.ground(), ufo.beam_foot if ufo.beaming and not ufo.dead else 0.0, ufo.tier)
	if not ufo.beaming or ufo.dead or _pull_wait > 0.0:
		return
	_pull_wait = 0.15
	var found := world.pull(ufo.ground(), ufo.beam_foot, ufo.tier)
	if found.is_empty():
		return
	var xf: Transform3D = found[1]
	var t := spawn(found[0], xf.origin, {"turn": xf.basis.get_euler().y, "size": xf.basis.get_scale().x, "tints": found[2]})
	t.state = "lifted"


## The beam has taken hold of something: anyone near enough to see it reaches for a phone
func _witnessed(taken_thing: Thing) -> void:
	if mode != "play":
		return
	for t in things:
		if t != taken_thing and t.info.get("caller", false) and t.state == "walk" and t.calling <= 0.0 \
				and t.ground().distance_to(ufo.ground()) < 26.0:
			t.witness()
			sfx.play("ring", 1.0, _near_db(t))


## Someone who saw the ship got through to the police (unless the lines near them are cut)
func phone_call(t: Thing) -> void:
	if mode != "play":
		return
	if lines_down_near(t.position):
		_popup("NO SIGNAL", t.position + Vector3(0, 3, 0), Color(0.7, 0.8, 1.0))
		sfx.play("static", 1.0, _near_db(t))
		return
	# (the first call brings a star; more ringing in on top of it within a few seconds add little)
	var now := Time.get_ticks_msec() / 1000.0
	heat = minf(heat + (0.9 if now - _last_call > 6.0 else 0.2), MAX_HEAT)
	_last_call = now
	calm = 0.0
	_banner("SOMEONE CALLED THE POLICE", 1.8)
	sfx.play("ring", 0.8)


## A phone pole was taken: the line is down there, and its wires (and the last pole's, to it) go
func line_cut(pole: Thing) -> void:
	if _cuts.is_empty() and mode == "play":
		_banner("THE PHONE LINES ARE DOWN HERE", 1.8)
	_cuts.append(Vector3(pole.position.x, 0, pole.position.z))
	for t in things:
		if t.kind == "phone_pole" and t.wires != null and t.wire_to.distance_to(Vector3(pole.position.x, 0, pole.position.z)) < 1.0:
			t.wires.visible = false


## Whether a call from `p` cannot get through: a line is down within LINE_REACH of it
func lines_down_near(p: Vector3) -> bool:
	for c in _cuts:
		if Vector2(c.x - p.x, c.z - p.z).length() < LINE_REACH:
			return true
	return false


## A new thing of a kind, standing at `at` (the world calls this as it makes each chunk)
func spawn(kind: String, at: Vector3, extra := {}) -> Thing:
	var t := Thing.new()
	view.add_child(t)
	t.setup(self, kind, at, extra)
	things.append(t)
	return t


## A thing the world wants put down as it makes a chunk: put down a few a frame (see _spawn_some),
## so a new chunk never stalls a frame
## Every model made ready once (merged and dressed) at the start, not the first time one is met
func _warm_models() -> void:
	for kind: String in Thing.KINDS:
		var info: Dictionary = Thing.KINDS[kind]
		var name: String = info.get("model", kind)
		if ResourceLoader.exists("res://models/%s.glb" % name):
			Ps1.model(name, info.get("tints", {})).free()


func spawn_later(kind: String, at: Vector3, extra: Dictionary) -> void:
	_to_spawn.append([kind, at, extra])


## Puts down what is waiting, so many a frame; and once at the start of a run, everything at once
func _spawn_some(all := false) -> void:
	var count := 0
	while not _to_spawn.is_empty() and (all or count < SPAWN_A_FRAME):
		var next: Array = _to_spawn.pop_front()
		var extra: Dictionary = next[2]
		# (a chunk dropped before its things were put down takes them with it)
		if extra.has("chunk") and not world.chunks.has(extra["chunk"]):
			continue
		spawn(next[0], next[1], extra)
		count += 1


## A car on the road, going `dir` (+1 or -1) along `axis` ("x" or "z")
func spawn_car(kind: String, at: Vector3, axis: String, dir: float) -> Thing:
	var t := spawn(kind, at)
	t.road_axis = axis
	t.road_dir = dir
	t.heading = (0.0 if dir > 0.0 else PI) if axis == "z" else (PI / 2 if dir > 0.0 else -PI / 2)
	t.rotation.y = t.heading
	return t

func _remove(t: Thing) -> void:
	t.state = "gone"
	things.erase(t)
	t.queue_free()


## Something reached the saucer
func abducted(t: Thing) -> void:
	if t.kind == "pod":
		_bought(t)
		sfx.play("bloop", 1.3)
		ufo.alien.feel("cheer", 0.9)
		t.state = "gone"
		t.queue_free()
		return
	var points := t.points() * multiplier()
	if mode == "play":
		score += points
		taken += 1
		heat = minf(heat + float(t.info["heat"]), MAX_HEAT)
		calm = 0.0
	ufo.alien.feel("cheer", 0.9)
	sfx.play("bloop", 1.0 + randf() * 0.2)
	if t.info.get("rare", false) and mode == "play":
		_banner(t.info.get("title", "A RARE FIND"), 3.0)
		sfx.play("fanfare")
	var found: String = t.info.get("unlock", "")
	if found != "" and mode == "play" and not found in unlocked:
		unlocked.append(found)
		_save_best()
	if mode == "play":
		var title: String = t.info.get("title", t.kind.replace("_", " ").to_upper())
		log_line("SPECIMEN %03d  %s" % [taken, title], points)
	t.state = "gone"
	t.queue_free()


## Something let go of hit the ground: dropped from high enough on the police or army, it crushes them
func landed(t: Thing, height: float) -> void:
	sfx.play("thud", 1.0, -6.0 + minf(height, 6.0))
	puff(t.position, Color(0.4, 0.35, 0.28), 0.8)
	if height < 3.0 or mode != "play":
		return
	for other in things:
		if other == t or not other.is_enemy() or other.state != "walk":
			continue
		if other.ground().distance_to(t.ground()) < other.size() + t.size() * 0.5:
			var points := other.points() / 2 * multiplier()
			score += points
			heat = minf(heat + 0.25, MAX_HEAT)
			calm = 0.0
			boom(other.position + Vector3(0, 1, 0), 2.0)
			log_line("%s CRUSHED" % other.kind.replace("_", " ").to_upper(), points)
			_remove(other)
			break


func fire(from: Thing, gun: String, target: Ufo) -> void:
	var muzzle := from.muzzle()
	# Aimed where the saucer will be, give or take
	var lead := target.position + target.velocity * (muzzle.distance_to(target.position) / 28.0)
	match gun:
		"shotgun":
			for i in 5:
				_shot("pellet", muzzle, lead + Vector3(randf_range(-2.2, 2.2), randf_range(-1, 1), randf_range(-2.2, 2.2)))
			sfx.play("bang", 1.2, _near_db(from))
		"pistol":
			_shot("bullet", muzzle, lead + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
			sfx.play("pop", 1.0, _near_db(from))
		"mg":
			_shot("tracer", muzzle, lead + Vector3(randf_range(-1.8, 1.8), randf_range(-0.5, 0.5), randf_range(-1.8, 1.8)))
			sfx.play("rat", 1.0, _near_db(from) - 4.0)
		"cannon":
			var aim := target.position + target.velocity * (muzzle.distance_to(target.position) / 20.0)
			_shot("shell", muzzle, aim)
			puff(muzzle, Color(0.8, 0.7, 0.5), 1.2)
			sfx.play("boom", 1.6, _near_db(from))


func _near_db(t: Node3D) -> float:
	return -clampf(t.global_position.distance_to(ufo.position) * 0.25, 0.0, 14.0)


func _shot(kind: String, from: Vector3, toward: Vector3) -> Shot:
	var s := Shot.new()
	view.add_child(s)
	s.setup(kind, from, toward)
	s.damage *= sqrt(danger())
	shots.append(s)
	return s


func shot_hit(s: Shot) -> void:
	_shake = maxf(_shake, 0.15 + s.damage * 0.02)
	_hurt = 1.0
	sfx.play("clang" if s.damage < 10.0 else "boom", 1.0)
	if s.damage >= 10.0:
		boom(s.position, 1.6)


func _crash(delta: float) -> void:
	if not ufo.crashed:
		if randf() < delta * 12.0:
			puff(ufo.position, Color(0.3, 0.3, 0.32), 1.0)
		return
	boom(ufo.position, 4.0)
	sfx.play("boom", 0.7, 4.0)
	_shake = 0.6
	ufo.visible = false
	mode = "over"
	_over_wait = 1.2
	var is_best := score > best
	if is_best:
		best = score
		_save_best()
	_report(score)
	over_label.text = "THE SAUCER IS DOWN\n\nSCORE  %d\nTAKEN  %d\nBEST  %d%s" % [score, taken, best, "  (NEW!)" if is_best and score > 0 else ""]
	over_box.visible = true
	_banner("", 0.0)


## A line for the log under the score: typed out a letter at a time (`points` after it, if any)
func log_line(text: String, points: int) -> void:
	var line := _label(20, Color(0.55, 1.0, 0.62))
	var tail := ""
	if points > 0:
		tail = "  +%d" % points + (" x%d" % multiplier() if multiplier() > 1 else "")
	elif points < 0:
		tail = "  %d" % points
	line.text = "> " + text + tail
	line.visible_characters = 0
	line.set_meta("born", Time.get_ticks_msec() / 1000.0)
	_glow(line, Color(0.25, 1.0, 0.4, 0.5))
	log_box.add_child(line)
	while log_box.get_child_count() > LOG_LINES:
		log_box.get_child(0).free()


## Types the newest lines out a letter at a time, with a ticking key, and fades the old ones
func _type_log(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for line: Label in log_box.get_children():
		if line.visible_characters >= 0 and line.visible_characters < line.text.length():
			_typing += delta * LOG_SPEED
			var more := int(_typing)
			_typing -= more
			line.visible_characters = mini(line.visible_characters + more, line.text.length())
			if more > 0 and line.visible_characters % 3 == 0:
				sfx.play("click", 1.6, -18.0)
			break
		var age := now - float(line.get_meta("born"))
		line.modulate.a = clampf((LOG_FOR - age) / 1.0, 0.0, 1.0)
		if age > LOG_FOR + 1.0:
			line.queue_free()


## A soft glow round the words, as on an old green screen
func _glow(l: Label, c: Color) -> void:
	l.add_theme_color_override("font_shadow_color", c)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 10)


## A finished game's score, told to the arcade page the game is in (it saves it to the board)
func _report(points: int) -> void:
	if OS.has_feature("web") and points > 0 and not testing:
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % points)


# ------------------------------------------------------------------ the autopilot

## Flies the saucer behind the title, and for the tests: to the nearest thing worth taking, beam
## on over it until it is in, away from anything shooting when the shield is low
func _pilot(delta: float) -> Array:
	if _pilot_target != null and (not is_instance_valid(_pilot_target) or _pilot_target.state == "gone"):
		_pilot_target = null
	if _pilot_target == null:
		var best_score := -INF
		for t in things:
			# (it never catches up with a car)
			if t.state == "gone" or (t.is_enemy() and mode == "title") or t.info["move"] == "road" or t.tier() > 1 or t.fixed():
				continue
			var d := t.ground().distance_to(ufo.ground())
			if d > 60.0:
				continue
			var worth := sqrt(float(t.points())) / (1.0 + float(t.info["weight"])) - d * 0.3
			if worth > best_score:
				best_score = worth
				_pilot_target = t
	if _pilot_target == null:
		return [Vector2.ZERO, false]
	var to := _pilot_target.ground() - ufo.ground()
	var flat := Vector2(to.x, to.z)
	var over := flat.length() < 1.2 or _pilot_target.state == "lifted"
	var steer := flat.normalized() * clampf(flat.length() / 2.0, 0.0, 1.0)
	return [steer, over or flat.length() < 2.4]


# ------------------------------------------------------------------ effects

func boom(at: Vector3, size: float) -> void:
	for i in 3:
		var c := [Color(1.0, 0.9, 0.5), Color(1.0, 0.5, 0.15), Color(0.35, 0.33, 0.32)][i] as Color
		_blob(at + Vector3(randf_range(-0.3, 0.3), i * 0.3, randf_range(-0.3, 0.3)), c, size * (0.6 + i * 0.35), 0.35 + i * 0.25)


func puff(at: Vector3, c: Color, size: float) -> void:
	_blob(at, c, size, 0.6)


func _blob(at: Vector3, c: Color, size: float, life: float) -> void:
	var m := Ps1.part(view, Ps1.ball(), Ps1.flat(c), at, Vector3.ONE * size * 0.3)
	var tw := create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * size, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "position:y", at.y + size * 0.5, life)
	tw.tween_callback(m.queue_free)


func _popup(text: String, at: Vector3, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 64
	l.pixel_size = 0.02
	l.modulate = c
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	view.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", at.y + 2.5, 1.1)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(l.queue_free)


func _sounds() -> void:
	sfx.loop(sfx.hum, ufo.beaming and not ufo.dead)
	var police := false
	for t in things:
		if t.kind == "police_car" and not t.leaving and t.ground().distance_to(ufo.ground()) < 40.0:
			police = true
	sfx.loop(sfx.siren, police and mode == "play")


# ------------------------------------------------------------------ the camera

## The descent: first close behind the ship looking up past it into the stars, then swinging up and
## back as it comes down until the curve of the planet fills the picture, and the game's camera
func _intro_camera() -> void:
	var k := 1.0 - intro / INTRO
	var settle := smoothstep(0.45, 1.0, k)
	var normal_from := _camera_offset() - Vector3(0, ufo.altitude, 0)
	camera.position = ufo.position + Vector3(0, 1.2, 8.0).lerp(normal_from, settle)
	var normal_at := ufo.ground() + Vector3(0, ufo.altitude * 0.5, -1.5)
	var look := (ufo.position + Vector3(0, 3.2, -12.0)).lerp(normal_at, smoothstep(0.25, 0.95, k))
	camera.look_at(look, Vector3.UP)
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(ufo.position.x, 0.0, ufo.position.z - 1.0))
	RenderingServer.global_shader_parameter_set("saucer_pos", ufo.position)
	_sky_mat.set_shader_parameter("space", 1.0 - smoothstep(0.3, 0.85, k))
	camera.environment.fog_density = 0.006 * smoothstep(0.55, 1.0, k)


## On the moon: low beside the chair, the ship and Earth in the picture; in the launch it rises
## with the ship and then follows it out toward Earth
func _moon_camera(delta: float) -> void:
	var site := MoonSet.SITE
	var at := site + Vector3(-6.5, 2.4, 9.5)
	var look := site + Vector3(4.0, 5.5, -10.0)
	if mode == "launch" and _launch_t > 0.9:
		var k := smoothstep(0.9, 2.6, _launch_t)
		var earth := moon_set.earth_position()
		var way := (earth - ufo.position).normalized()
		at = at.lerp(ufo.position - way * 12.0 + Vector3(0, 3.0, 0), k)
		look = look.lerp(earth, k)
	camera.position = at
	camera.look_at(look, Vector3.UP)
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(site.x + 1.0, 0.0, site.z))
	RenderingServer.global_shader_parameter_set("saucer_pos", Vector3(0, -9999, 0))
	_sky_mat.set_shader_parameter("space", 1.0)
	camera.environment.fog_density = 0.0


## Further up and back for a ship that flies higher
func _camera_offset() -> Vector3:
	return CAMERA_OFFSET + Vector3(0, 1.3, 0.5) * (ufo.altitude - 8.0)


func _camera(delta: float) -> void:
	if hold_camera:
		return
	if mode == "title" or mode == "launch":
		_moon_camera(delta)
		return
	var focus := Vector3(ufo.position.x, 0.0, ufo.position.z)
	if ufo.crashed or ufo.dead:
		focus = Vector3(ufo.position.x, 0.0, ufo.position.z)
	if intro > 0.0 and mode == "play":
		_intro_camera()
		return
	_sky_mat.set_shader_parameter("space", 0.0)
	camera.environment.fog_density = 0.006
	var goal := focus + _camera_offset()
	if mode == "title":
		goal = focus + Vector3(0, 11.0, 15.0)
	camera.position = camera.position.lerp(goal, minf(delta * 4.0, 1.0)) if camera.position != Vector3.ZERO else goal
	# (the saucer sits a little above the middle of the picture, with more to see ahead of it)
	var look_at_point := camera.position - _camera_offset() + Vector3(0, ufo.altitude * 0.5, -1.5)
	if mode == "title":
		look_at_point = camera.position - Vector3(0, 11.0, 15.0) + Vector3(0, 4.0, -6.0)
	camera.look_at(look_at_point)
	_shake = maxf(_shake - delta, 0.0)
	if _shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
	# The world bends away from the ground under the camera's middle
	var under := camera.position - _camera_offset() if mode != "title" else camera.position - Vector3(0, 11.0, 15.0)
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(under.x, 0.0, under.z - 1.0))
	RenderingServer.global_shader_parameter_set("saucer_pos", ufo.position)
	_hurt = maxf(_hurt - delta * 3.0, 0.0)
	screen_mat.set_shader_parameter("hurt", _hurt)


# ------------------------------------------------------------------ the HUD

func _label(size: int, c := Color(0.92, 0.95, 0.88)) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(size / 6, 4))
	return l


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	coin = Coin.new()
	coin.position = Vector2(20, 22)
	coin.size = Vector2(38, 38)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coin)
	score_label = _label(40, Color(0.75, 1.0, 0.78))
	score_label.position = Vector2(66, 12)
	_glow(score_label, Color(0.3, 1.0, 0.45, 0.55))
	root.add_child(score_label)
	mult_label = _label(24, Color(0.6, 1.0, 0.6))
	mult_label.position = Vector2(68, 58)
	root.add_child(mult_label)
	log_box = VBoxContainer.new()
	log_box.position = Vector2(22, 100)
	log_box.custom_minimum_size = Vector2(560, 0)
	log_box.add_theme_constant_override("separation", 2)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_box)

	stars = Stars.new()
	stars.main = self
	stars.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stars.position = Vector2(-150, 14)
	stars.size = Vector2(300, 64)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stars)

	radar = Radar.new()
	radar.main = self
	radar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	radar.position = Vector2(-404, 8)
	radar.size = Vector2(108, 108)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radar)

	shield_bar = Shield.new()
	shield_bar.main = self
	shield_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shield_bar.position = Vector2(-292, 8)
	shield_bar.size = Vector2(200, 112)
	shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shield_bar)

	banner = _label(40, Color(1.0, 0.85, 0.4))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-400, -150)
	banner.size = Vector2(800, 60)
	root.add_child(banner)

	stick_ring = StickRing.new()
	stick_ring.main = self
	stick_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(stick_ring)
	beam_button = BeamButton.new()
	beam_button.main = self
	beam_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam_button.visible = false
	root.add_child(beam_button)

	title_box = _panel(root)
	# (on the left, so the moon, the pilot and Earth are to be seen on the right)
	title_box.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	title_box.offset_left = 30.0
	title_box.offset_right = 650.0
	title_box.custom_minimum_size = Vector2(620, 0)
	var title := _label(84, Color(0.7, 1.0, 0.72))
	title.text = "CLOSE ENCOUNTERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title)
	var sub := _label(26)
	sub.text = "Beam up whatever you can. The more you take, the hotter it gets."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(sub)
	hint_label = _label(22, Color(0.75, 0.8, 0.85))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(hint_label)
	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 16)
	var left := _button("<", func() -> void: _pick_ship(-1))
	left.custom_minimum_size = Vector2(70, 70)
	picker.add_child(left)
	ship_label = _label(28, Color(0.75, 1.0, 0.78))
	ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship_label.custom_minimum_size = Vector2(500, 0)
	picker.add_child(ship_label)
	var right := _button(">", func() -> void: _pick_ship(1))
	right.custom_minimum_size = Vector2(70, 70)
	picker.add_child(right)
	title_box.add_child(picker)
	_play_button = _button("PLAY", begin_launch)
	title_box.add_child(_play_button)


	# A pause button in the corner, and what pausing shows

	_pause_button = _button("II", func() -> void: set_paused(true))
	_pause_button.custom_minimum_size = Vector2(64, 56)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.position = Vector2(-80, 14)
	_pause_button.focus_mode = Control.FOCUS_NONE
	root.add_child(_pause_button)
	_pause_box = _panel(root)
	var paused := _label(64, Color(0.7, 1.0, 0.72))
	paused.text = "PAUSED"
	paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_box.add_child(paused)
	_resume_button = _button("RESUME", func() -> void: set_paused(false))
	_pause_box.add_child(_resume_button)
	_pause_box.add_child(_button("QUIT TO MENU", quit_to_menu))
	_pause_box.visible = false

	over_box = _panel(root)
	over_label = _label(38)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_box.add_child(over_label)
	over_box.add_child(_button("AGAIN", func() -> void:
		if _over_wait <= 0.0:
			start()))
	over_box.visible = false


func _panel(root: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(760, 0)
	box.position = Vector2(-380, -90)
	box.size = Vector2(760, 400)
	root.add_child(box)
	return box


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 40)
	b.custom_minimum_size = Vector2(260, 70)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.25, 0.14, 0.85)
	normal.border_color = Color(0.55, 1.0, 0.6)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.4, 0.22, 0.95)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", Color(0.75, 1.0, 0.78))
	b.pressed.connect(func() -> void:
		sfx.play("click")
		pressed.call())
	return b


## A ship of this kind where `at` is (on the ground; it flies at its own height)
func _make_ufo(at: Vector3) -> void:
	ufo = Ufo.new()
	ufo.ship = ship
	ufo.alien_seed = alien_seed
	ufo.position = at
	view.add_child(ufo)


## On the moon, beside the pilot's deck chair, on its legs (the pilot is out, in the chair)
func _park_ufo() -> void:
	ufo.parked = true
	ufo.position = MoonSet.SITE + MoonSet.SHIP_AT
	ufo.alien.visible = false
	moon_set.seat(alien_seed)


## Play pressed on the title: the pilot hops in, the ship lifts off and makes for Earth, and the run
## starts with it coming down from space (see `_launch`)
func begin_launch() -> void:
	if mode != "title" or not ship in unlocked:
		return
	mode = "launch"
	_launch_t = 0.0
	title_box.visible = false
	moon_set.hop_aboard(0.9)
	sfx.play("whoosh", 1.4)


func _launch(delta: float) -> void:
	_launch_t += delta
	var site := MoonSet.SITE + MoonSet.SHIP_AT
	if _launch_t >= 0.9 and not ufo.alien.visible:
		ufo.alien.visible = true
		ufo.alien.feel("cheer", 1.0)
		sfx.play("bloop", 1.2)
	if _launch_t < 0.9:
		return
	if _launch_t < 2.1:
		# straight up off the moon, legs folding away
		var k := ease((_launch_t - 0.9) / 1.2, 2.0)
		ufo.position = site + Vector3(0, k * 14.0, 0)
		ufo._legs.visible = _launch_t < 1.2
		_launch_from = ufo.position
		return
	# and away to Earth, faster and faster
	var k := clampf((_launch_t - 2.1) / (LAUNCH - 2.1), 0.0, 1.0)
	ufo.position = _launch_from.lerp(moon_set.earth_position(), pow(k, 2.6) * 0.8)
	ufo.hull_model.rotation.y += delta * 6.0
	if _launch_t >= LAUNCH:
		start(true)


## The next ship along (or the one before), on the title screen
func _pick_ship(step: int) -> void:
	var i := Ufo.ORDER.find(ship)
	ship = Ufo.ORDER[posmod(i + step, Ufo.ORDER.size())]
	var at := ufo.ground()
	ufo.queue_free()
	_make_ufo(at)
	if mode == "title":
		_park_ufo()
	_show_ship()
	_save_best()


func _show_ship() -> void:
	var spec: Dictionary = Ufo.SHIPS[ship]
	if ship in unlocked:
		ship_label.text = "%s\n%s" % [spec["title"], spec["about"]]
		_play_button.text = "PLAY"
		_play_button.disabled = false
	else:
		ship_label.text = "%s (LOCKED)\nFind it in a secret government facility." % spec["title"]
		_play_button.text = "LOCKED"
		_play_button.disabled = true


func _show_title() -> void:
	mode = "title"
	alien_seed = randi()
	ufo.queue_free()
	_make_ufo(Vector3.ZERO)
	_park_ufo()
	_show_ship()
	title_box.visible = true
	over_box.visible = false
	hint_label.text = "Move: WASD, arrows, stick or drag on the left    Beam: hold Space, A, or the right side    Dodge: Shift, B, or swipe"


## The lounge on the title, in the pause and after a crash; Tanks! once the heat is up; else Night Visitors
func _choose_music() -> void:
	if testing:
		return
	if mode != "play" or get_tree().paused:
		music.play("lounge")
	elif heat_level() >= 2:
		music.play("chase")
	else:
		music.play("visitors")


## Gives up the run (no score is sent) and goes back to the title, the ship flying itself again
func quit_to_menu() -> void:
	set_paused(false)
	_forget_fingers()
	for t in things.duplicate():
		if t.is_enemy():
			_remove(t)
	for s in shots:
		s.queue_free()
	shots.clear()
	for j in jets:
		j.queue_free()
	jets.clear()
	heat = 0.0
	score = 0
	var at := ufo.ground()
	ufo.queue_free()
	_make_ufo(at)
	_banner("", 0.0)
	_show_title()


## Forgets every finger (a run starting or ending, or the game pausing)
func _forget_fingers() -> void:
	stick_finger = NO_FINGER
	beam_finger = NO_FINGER
	stick = Vector2.ZERO
	_touch_from.clear()
	_mouse_down = []
	_touch_frame_seen = true


func set_paused(on: bool) -> void:
	if mode != "play":
		return
	get_tree().paused = on
	_pause_box.visible = on
	if on:
		_resume_button.call_deferred("grab_focus")
		_forget_fingers()


func _banner(text: String, seconds: float) -> void:
	banner.text = text
	banner_time = seconds


func _hud(delta: float) -> void:
	# (nothing on the screen while the ship comes down from space)
	var playing := mode == "play" and intro <= 0.0
	score_label.visible = playing or mode == "over"
	if intro > 0.0:
		score_label.visible = false
	mult_label.visible = playing
	coin.visible = playing or mode == "over"
	log_box.visible = playing
	_type_log(delta)
	stars.visible = playing
	shield_bar.visible = playing
	radar.visible = playing
	radar.queue_redraw()
	_facility_wait -= delta
	if playing and _facility_wait <= 0.0:
		_facility_wait = 3.0
		_find_facilities()
	score_label.text = "%d" % score
	mult_label.text = "x%d" % multiplier()
	stars.queue_redraw()
	shield_bar.queue_redraw()
	stick_ring.queue_redraw()
	# (on a touch screen the stick and the beam show from the start, so it is plain how to fly)
	beam_button.visible = (touched or _touch_screen) and playing
	# (under the finger that is beaming, and back in its corner after)
	var mark_at := _beam_at if beam_finger != NO_FINGER and _beam_at != Vector2.INF else _beam_home()
	beam_button.position = mark_at - beam_button.size * 0.5
	stick_ring.visible = playing and stick_finger != NO_FINGER
	beam_button.queue_redraw()
	_pause_button.visible = playing and not autopilot
	if banner_time > 0.0:
		banner_time -= delta
		banner.modulate.a = clampf(banner_time * 2.0, 0.0, 1.0)
	else:
		banner.text = ""


## A mouse press with no touch with it, two frames on: its finger's coming down was lost, so the
## press stands in for it until the finger is heard from (see _name_pending)
func _pending_fingers() -> void:
	if _mouse_down.is_empty() or _touch_frame_seen or Engine.get_process_frames() - _mouse_frame < 2:
		return
	if stick_finger == PENDING or beam_finger == PENDING or _touch_from.has(PENDING):
		return
	_touch_frame_seen = true
	_finger_down(PENDING, _mouse_down[0])


## A finger heard from for the first time takes over a press that stood in for it
func _name_pending(index: int) -> void:
	if index == PENDING or not (stick_finger == PENDING or beam_finger == PENDING or _touch_from.has(PENDING)):
		return
	if _touch_from.has(index):
		return
	if stick_finger == PENDING:
		stick_finger = index
	if beam_finger == PENDING:
		beam_finger = index
	if _touch_from.has(PENDING):
		_touch_from[index] = _touch_from[PENDING]
		_touch_from.erase(PENDING)


## The stick comes up under the thumb, centred there: nothing moves until the thumb does
func _take_stick(index: int, at: Vector2) -> void:
	stick_finger = index
	stick_from = at
	stick = Vector2.ZERO


func _stick_reach() -> float:
	return minf(get_viewport().get_visible_rect().size.y * 0.12, 90.0)


## The stick pushed toward a thumb at `p`: full over the rim (its middle then follows the thumb),
## nothing in a small dead middle
func _stick_toward(p: Vector2) -> Vector2:
	var reach := _stick_reach()
	var off := p - stick_from
	if off.length() > reach:
		stick_from = p - off.normalized() * reach
		off = off.normalized() * reach
	if off.length() < reach * 0.15:
		return Vector2.ZERO
	return off / reach


## The touch readout (with ?touchdebug): the last few touches the game was given, and what it made of them
func _debug_line(text: String) -> void:
	print("[CE] " + text)
	_debug_lines.append(text)
	if _debug_lines.size() > 8:
		_debug_lines.pop_front()
	_debug_show()


func _debug_show() -> void:
	if _debug_label == null:
		_debug_label = Label.new()
		_debug_label.add_theme_font_size_override("font_size", 22)
		_debug_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
		_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_debug_label.add_theme_constant_override("outline_size", 6)
		_debug_label.position = Vector2(20, 180)
		_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(_debug_label)
	_debug_label.visible = _touch_debug
	_debug_label.text = _debug_state + "\n" + "\n".join(_debug_lines)


## Where the beam's mark rests: the bottom right corner
func _beam_home() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var r := minf(view.x, view.y) * 0.13
	return Vector2(view.x - r * 1.35, view.y - r * 1.35)


func _layout_touch() -> void:
	if beam_button == null:
		return
	var size := get_viewport().get_visible_rect().size
	var r := minf(size.x, size.y) * 0.13
	beam_button.size = Vector2(r * 2, r * 2)
	beam_button.position = _beam_home() - Vector2(r, r)


## Touches are read here, before the interface sees them (as Liquid Metal does), so nothing on the
## screen can swallow them; only a finger that comes down on the pause button is left to it
func _input(event: InputEvent) -> void:
	if _touch_debug and (event is InputEventScreenTouch or event is InputEventMouseButton or (event is InputEventScreenDrag and Engine.get_process_frames() % 12 == 0)):
		_debug_line("%s | %s%s" % [event.as_text(), mode, " PAUSED" if get_tree().paused else ""])
	# Five quick taps on the alien coin turn the touch readout on or off (to see what a phone sends)
	if event is InputEventScreenTouch and event.pressed and coin.visible and coin.get_global_rect().grow(24).has_point(event.position):
		var now := Time.get_ticks_msec() / 1000.0
		_coin_taps = _coin_taps + 1 if now - _coin_tapped < 0.6 else 1
		_coin_tapped = now
		if _coin_taps >= 5:
			_coin_taps = 0
			_touch_debug = not _touch_debug
			if _debug_label != null:
				_debug_label.visible = _touch_debug
			_debug_line("touch readout on")
	if mode != "play" or autopilot:
		return
	if get_tree().paused:
		return
	if event is InputEventScreenTouch and event.pressed and _pause_button.visible \
			and _pause_button.get_global_rect().grow(8).has_point(event.position):
		# (a touch, even one left to the button: its mouse is not a lost finger)
		_touch_down_frame = Engine.get_process_frames()
		_touch_frame_seen = true
		return
	if event is InputEventScreenTouch:
		var e: InputEventScreenTouch = event
		if e.pressed:
			_finger_down(e.index, e.position)
		else:
			_finger_up(e.index, e.position)
	elif event is InputEventScreenDrag:
		var e: InputEventScreenDrag = event
		_finger_moved(e.index, e.position)
	# The mouse Godot makes of the first finger is not a finger of its own; only when and where it
	# went down is kept, for a finger whose own coming down was lost
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION and event.pressed:
		_mouse_down = [event.position, Time.get_ticks_msec() / 1000.0]
		_mouse_frame = Engine.get_process_frames()
		# (a touch that came down this frame or the last is the finger this mouse was made of)
		_touch_frame_seen = _touch_down_frame >= _mouse_frame - 1
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION and not event.pressed:
		if stick_finger == PENDING or beam_finger == PENDING or _touch_from.has(PENDING):
			_finger_up(PENDING, event.position)


## A finger down: the right half (or the beam's mark) beams, the left half steers from the stick's home
func _finger_down(index: int, at: Vector2) -> void:
	touched = true
	if index != PENDING:
		_touch_frame_seen = true
		_touch_down_frame = Engine.get_process_frames()
	var now := Time.get_ticks_msec() / 1000.0
	_touch_from[index] = [at, now]
	if at.x > get_viewport().get_visible_rect().size.x * 0.5:
		if beam_finger == NO_FINGER:
			beam_finger = index
			_beam_at = at
	elif stick_finger == NO_FINGER:
		_take_stick(index, at)


## A finger moving: if its coming down was never heard of (some phones lose it), it is taken up now
func _finger_moved(index: int, at: Vector2) -> void:
	touched = true
	_name_pending(index)
	if index == stick_finger:
		stick = _stick_toward(at)
	elif index == beam_finger:
		_beam_at = at
	else:
		if not _touch_from.has(index):
			# (where it came down, if the mouse Godot made of it says, or else here)
			var start: Array = _mouse_down if not _mouse_down.is_empty() and Time.get_ticks_msec() / 1000.0 - float(_mouse_down[1]) < 1.0 else [at, Time.get_ticks_msec() / 1000.0]
			_touch_from[index] = start
		if at.x <= get_viewport().get_visible_rect().size.x * 0.5 and stick_finger == NO_FINGER:
			_take_stick(index, _touch_from[index][0])
			stick = _stick_toward(at)
		elif at.x > get_viewport().get_visible_rect().size.x * 0.5 and beam_finger == NO_FINGER:
			beam_finger = index
			_beam_at = at


## A finger lifted: a flick dodges; a tap on the beam's mark turns the beam on or off, and a tap
## anywhere else flies the ship there (so a phone that only gets taps through can still play)
func _finger_up(index: int, at: Vector2) -> void:
	_name_pending(index)
	var now := Time.get_ticks_msec() / 1000.0
	if not _touch_from.has(index) and not _mouse_down.is_empty() and now - float(_mouse_down[1]) < 1.0:
		_touch_from[index] = _mouse_down
	_mouse_down = []
	if _touch_from.has(index):
		var from: Array = _touch_from[index]
		_touch_from.erase(index)
		var moved: Vector2 = at - from[0]
		var held := now - float(from[1])
		if held < SWIPE_TIME and moved.length() > SWIPE_LENGTH:
			_dodge(moved)
	if index == beam_finger:
		beam_finger = NO_FINGER
	if index == stick_finger:
		stick_finger = NO_FINGER
		stick = Vector2.ZERO


# ------------------------------------------------------------------ bests

func _load_best() -> void:
	# (tests fly the saucer, whatever was last picked here, and may fly any ship)
	if testing:
		unlocked.assign(Ufo.ORDER)
		return
	var cfg := ConfigFile.new()
	if cfg.load("user://best.cfg") == OK:
		best = int(cfg.get_value("best", "score", 0))
		for found: String in cfg.get_value("best", "unlocked", []):
			if Ufo.SHIPS.has(found) and not found in unlocked:
				unlocked.append(found)
		var kept: String = cfg.get_value("best", "ship", "saucer")
		if Ufo.SHIPS.has(kept) and kept in unlocked:
			ship = kept

func _save_best() -> void:
	if testing:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("best", "score", best)
	cfg.set_value("best", "ship", ship)
	cfg.set_value("best", "unlocked", unlocked)
	cfg.save("user://best.cfg")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play" and not autopilot and not testing:
		set_paused(true)


# ------------------------------------------------------------------ HUD pieces

## The five stars of heat, filling as it rises
class Stars extends Control:
	var main: Node

	func _draw() -> void:
		var h: float = main.heat
		for i in 5:
			var c := Vector2(30 + i * 60, 30)
			var fill := clampf(h - i, 0.0, 1.0)
			_star(c, 24.0, Color(0, 0, 0, 0.55))
			if fill > 0.08:
				var hot := Color(1.0, 0.85, 0.2).lerp(Color(1.0, 0.25, 0.1), float(i) / 4.0)
				_star(c, 21.0 * fill, hot if fill >= 1.0 else hot * Color(1, 1, 1, 0.7))
			_star(c, 21.0, Color(1, 1, 1, 0.35), false)

	func _star(c: Vector2, r: float, colour: Color, filled := true) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2 + k * PI / 5
			pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
		if filled:
			draw_colored_polygon(pts, colour)
		else:
			pts.append(pts[0])
			draw_polyline(pts, colour, 2.0)


## The secret facilities within a dozen chunks or so, for the radar
func _find_facilities() -> void:
	_facilities.clear()
	var c := World.chunk_of(ufo.ground())
	for x in range(-12, 13):
		for z in range(-12, 13):
			if World.facility(c + Vector2i(x, z)) != "":
				_facilities.append(World.centre_of(c + Vector2i(x, z)))


## What the radar shows: [where, colour, size], the nearest of each kind of thing worth finding,
## and the police and army about
func radar_marks() -> Array:
	var marks := []
	var here := ufo.ground()
	var nearest := {}
	for s in shops:
		if s.state == "parked":
			nearest = _keep_nearest(nearest, "trader", s.position)
	for f in _facilities:
		nearest = _keep_nearest(nearest, "facility", f)
	for t in things:
		if t.state != "walk":
			continue
		if t.power > 0.0:
			nearest = _keep_nearest(nearest, "power", t.position)
		elif t.info.get("rare", false) and not t.info.has("unlock"):
			nearest = _keep_nearest(nearest, "rare", t.position)
		elif t.is_enemy() and t.ground().distance_to(here) < Radar.RANGE:
			marks.append([t.ground(), Color(1.0, 0.3, 0.25), 3.0])
	var colours := {"trader": Color(0.5, 1.0, 0.55), "facility": Color(1.0, 0.8, 0.25), "power": Color(0.4, 0.75, 1.0), "rare": Color(1.0, 1.0, 0.5)}
	for kind: String in nearest:
		marks.append([nearest[kind], colours[kind], 5.0])
	return marks


func _keep_nearest(nearest: Dictionary, kind: String, at: Vector3) -> Dictionary:
	var flat := Vector3(at.x, 0, at.z)
	if not nearest.has(kind) or flat.distance_to(ufo.ground()) < (nearest[kind] as Vector3).distance_to(ufo.ground()):
		nearest[kind] = flat
	return nearest


## A little round radar: the ship in the middle, north up as on the screen, a sweep going round;
## the nearest trader, secret facility, substation and rare find as dots (on the rim, pointing the
## way, when they are further than it reaches), and the police and army about in red
class Radar extends Control:
	const RANGE := 150.0
	var main: Node

	func _draw() -> void:
		var r := size.x * 0.5 - 4.0
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var t := Time.get_ticks_msec() / 1000.0
		draw_circle(c, r + 4.0, Color(0.6, 1.0, 0.7, 0.18))
		draw_circle(c, r, Color(0.02, 0.1, 0.05, 0.8))
		draw_arc(c, r * 0.5, 0, TAU, 32, Color(0.4, 1.0, 0.5, 0.18), 1.0)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0.4, 1.0, 0.5, 0.12))
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0.4, 1.0, 0.5, 0.12))
		var a := fmod(t * 2.0, TAU)
		for k in 8:
			var back := a - k * 0.06
			draw_line(c, c + Vector2(cos(back), sin(back)) * r, Color(0.5, 1.0, 0.6, 0.3 - k * 0.035), 2.0)
		var here: Vector3 = main.ufo.ground()
		for mark: Array in main.radar_marks():
			var off: Vector3 = mark[0] - here
			var flat := Vector2(off.x, off.z) / RANGE * r
			var edge := flat.length() > r - 4.0
			if edge:
				flat = flat.normalized() * (r - 4.0)
			var col: Color = mark[1]
			var size_px: float = mark[2]
			if edge:
				# (a little arrow on the rim, pointing the way)
				var way := flat.normalized()
				var side := Vector2(-way.y, way.x)
				draw_colored_polygon(PackedVector2Array([c + flat + way * size_px, c + flat - way * size_px + side * size_px, c + flat - way * size_px - side * size_px]), col)
			else:
				draw_circle(c + flat, size_px * 0.7, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(4, 4), c + Vector2(-4, 4)]), Color(0.8, 1.0, 0.85))
		draw_arc(c, r, 0, TAU, 40, Color(0.6, 1.0, 0.7, 0.7), 2.0)


## The alien money the score is counted in: a green coin stamped with an alien's head
class Coin extends Control:
	func _draw() -> void:
		var r := size.x * 0.5
		var c := Vector2(r, r)
		draw_circle(c, r, Color(0.2, 0.6, 0.3))
		draw_circle(c, r * 0.86, Color(0.45, 0.95, 0.55))
		draw_arc(c, r * 0.72, 0, TAU, 32, Color(0.2, 0.6, 0.3), 1.5)
		var head := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			var squeeze := 0.62 if sin(a) > 0.0 else 1.0
			head.append(c + Vector2(cos(a) * r * 0.42 * squeeze, sin(a) * r * 0.5 - r * 0.05))
		draw_colored_polygon(head, Color(0.12, 0.35, 0.18))
		for side: float in [-1.0, 1.0]:
			var eye := PackedVector2Array()
			for k in 10:
				var a := TAU * k / 10.0
				var p := Vector2(cos(a) * r * 0.15, sin(a) * r * 0.07).rotated(0.45 * side)
				eye.append(c + Vector2(side * r * 0.17, -r * 0.08) + p)
			draw_colored_polygon(eye, Color(0.75, 1.0, 0.8))


## The shield: a glass orb of blue energy, its level the shield left, sloshing; beside it three
## pistons that pop up one by one as the dodge recharges
class Shield extends Control:
	var main: Node

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var r := 46.0
		var c := Vector2(r + 6, r + 8)
		var left: float = clampf(main.ufo.hull / float(main.ufo.hull_max), 0.0, 1.0)
		var bare := left <= 0.0
		# the glass, dark inside
		draw_circle(c, r + 6, Color(0.6, 0.85, 1.0, 0.18))
		draw_circle(c, r, Color(0.02, 0.05, 0.1, 0.75))
		# the fluid: thin columns of it from its wavy level down to the bottom of the glass
		if left > 0.0:
			var level := c.y + r - left * 2.0 * r
			var hot := Color(0.15, 0.55, 1.0) if left > 0.3 else Color(1.0, 0.3, 0.2)
			var cols := 40
			var w := 2.0 * r / cols
			for k in cols:
				var x := c.x - r + w * (k + 0.5)
				var half := sqrt(maxf(r * r - pow(x - c.x, 2.0), 0.0))
				var y0 := maxf(level + sin(t * 3.0 + k * 0.5) * 3.0 * (0.4 + left), c.y - half)
				var y1 := c.y + half
				if y1 > y0:
					draw_rect(Rect2(x - w * 0.5, y0, w + 0.6, y1 - y0), hot * Color(1, 1, 1, 0.85))
			for k in 4:
				var bx := c.x + sin(k * 2.3 + t * 0.7) * r * 0.5
				var by := c.y + r - fmod(t * 25.0 + k * 31.0, left * 2.0 * r)
				draw_circle(Vector2(bx, by), 3.0, Color(0.7, 0.9, 1.0, 0.5))
		draw_arc(c, r, 0, TAU, 48, Color(0.6, 0.9, 1.0, 0.9), 3.0)
		draw_arc(c + Vector2(-r * 0.3, -r * 0.35), r * 0.45, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.5), 3.0)
		if bare and fmod(t * 2.5, 2.0) < 1.0:
			draw_string(main.font, c + Vector2(-r, 6), "NO SHIELD", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 18, Color(1.0, 0.35, 0.25))
		# three pistons: each pops up when its third of the recharge is done
		var ready: float = main.ufo.dodge_ready()
		for i in 3:
			var px := c.x + r + 20.0 + i * 24.0
			var base_y := c.y + r * 0.75
			var fill := clampf(ready * 3.0 - i, 0.0, 1.0)
			var up := 34.0 * ease(fill, 0.3) if fill >= 1.0 else 34.0 * fill * 0.4
			draw_rect(Rect2(px - 10, base_y - 6, 20, 12), Color(0.3, 0.33, 0.38))
			draw_rect(Rect2(px - 4, base_y - 6 - up, 8, up), Color(0.7, 0.72, 0.76))
			var cap := Color(0.45, 1.0, 0.55) if fill >= 1.0 else Color(0.45, 0.2, 0.18)
			draw_rect(Rect2(px - 9, base_y - 14 - up, 18, 8), cap)


## Where the thumb is on the touch stick
class StickRing extends Control:
	var main: Node

	## At rest, a stick in the lower left (a thumb anywhere on the left half takes it from there)
	func _draw() -> void:
		var view: Vector2 = main.get_viewport().get_visible_rect().size
		var reach := minf(view.y * 0.12, 90.0)
		var held: bool = main.stick_finger != main.NO_FINGER
		var centre: Vector2 = main.stick_from if held else Vector2(view.x * 0.16, view.y * 0.74)
		draw_circle(centre, reach, Color(0.3, 1.0, 0.45, 0.08 if held else 0.05))
		draw_arc(centre, reach, 0, TAU, 40, Color(0.7, 1.0, 0.75, 0.45 if held else 0.25), 3.0)
		for k in 4:
			var a := k * PI / 2.0
			var tip := centre + Vector2(cos(a), sin(a)) * reach * 0.78
			draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(cos(a), sin(a)) * 10.0 + Vector2(-sin(a), cos(a)) * 7.0,
				tip - Vector2(cos(a), sin(a)) * 10.0 - Vector2(-sin(a), cos(a)) * 7.0]), Color(0.7, 1.0, 0.75, 0.3))
		var knob: Vector2 = main.stick if held else Vector2.ZERO
		draw_circle(centre + knob * reach, reach * 0.38, Color(0.6, 1.0, 0.65, 0.45 if held else 0.25))


class BeamButton extends Control:
	var main: Node

	## A little saucer with its beam down, in a soft glow: brighter, with rings running out, while held
	func _draw() -> void:
		var r := size.x * 0.5
		var c := Vector2(r, r)
		var on: bool = main.beam_finger != main.NO_FINGER
		var t := Time.get_ticks_msec() / 1000.0
		for i in 6:
			draw_circle(c, r * (1.0 - i * 0.12), Color(0.3, 1.0, 0.45, (0.05 if on else 0.012) * (i + 1)))
		if on:
			for i in 3:
				var k := fmod(t * 1.5 + i / 3.0, 1.0)
				draw_arc(c, r * (0.5 + k * 0.5), 0, TAU, 40, Color(0.7, 1.0, 0.75, (1.0 - k) * 0.6), 3.0)
		var glow := Color(0.7, 1.0, 0.75, 0.95 if on else 0.3)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.12, -r * 0.12), c + Vector2(r * 0.12, -r * 0.12),
			c + Vector2(r * 0.34, r * 0.5), c + Vector2(-r * 0.34, r * 0.5)]), Color(0.5, 1.0, 0.6, 0.45 if on else 0.1))
		var hull := PackedVector2Array()
		for k in 24:
			var a := TAU * k / 24.0
			hull.append(c + Vector2(cos(a) * r * 0.42, sin(a) * r * 0.11 - r * 0.18))
		draw_colored_polygon(hull, glow)
		draw_circle(c + Vector2(0, -r * 0.3), r * 0.15, glow)
		draw_arc(c, r * 0.98, 0, TAU, 48, Color(0.7, 1.0, 0.75, 0.5 if on else 0.15), 2.0)
