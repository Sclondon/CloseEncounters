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
## Modes: "title" (the pilot lounging on the moon), "launch" (off into space), "play", "over",
## "return" and "landing" (going home to the moon, see `quit_to_menu`). Tests set
## `autopilot` to fly it themselves and `start_mode` to skip the title.

const MAX_HEAT := 5.0
## Heat cools only after this long without taking anything, and then at this many stars a second
const COOL_AFTER := 5.0
const COOL_RATE := 0.07
## Who comes for you at each level of heat, each a stage of its own: one star, only the farmers
## with their guns (see Thing "flee"); two, police cars, who must pull up and get out to shoot (see
## Thing "police"); three, a police helicopter keeping its searchlight on you and the men in black;
## four, the army's jeeps, firing on the move, and a Chinook; five, tanks, and fighter jets overhead
## (see `_jets`)
const FORCES: Array[Dictionary] = [
	{},
	{},
	{"police_car": 2},
	{"helicopter": 1, "police_car": 2, "agent_car": 1},
	{"chinook": 1, "jeep": 2, "police_car": 1},
	{"chinook": 1, "tank": 2, "jeep": 2},
]
## How long after a new star the heat goes up only slowly (see `add_heat`)
const NEW_STAR := 8.0
var _new_star := 0.0
## How many of each thing the farm keeps about (taken ones are replaced, somewhere else)
const CAMERA_OFFSET := Vector3(0, 25.8, 19.8)
const WIDE_OFFSET := Vector3(0, 14.5, 30.0)
## (tests try others)
var camera_offset := CAMERA_OFFSET
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
## Dust streaming past the ship as it climbs off the moon and comes down to Earth
var dust: Dust
## Motes of dust in the air round the ship as it flies
var motes: Dust
var clouds: Clouds
## How far into the flight off the moon
var _launch_t := 0.0
const LAUNCH := 6.4
## When in the flight off the moon the engine starts up, the blast throws everything about, and the
## ship lifts off
const ENGINE := 0.9
const BLAST := 1.8
const LIFT := 2.5
## How high the ship climbs off the moon before the run starts (Earth well below the picture by then)
const CLIMB := 400.0
## How long the ship takes climbing off the farm into the stars on its way home (see `quit_to_menu`)
const RETURN_UP := 2.6
var _return_t := 0.0
## The camera rides behind the ship in the flight off the moon and the start of the descent: this far
## back along the way it is going and this far up, looking on ahead of it
const CHASE_BACK := 12.0
const CHASE_UP := 3.0
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
var upgrades := {"engine": 0, "beam": 0, "shield": 0, "dash": 0, "laser": 0, "fleet": 0}
var _hot_wait := 0.0
## The level reached this run (see `_levels`), levels still to pick for, and the picker
var level := 0
var _levels_due := 0
var _picker: VBoxContainer
var _picker_dim: ColorRect
var _picker_title: Label
var _picks: VBoxContainer
## Things the world has asked for, waiting to be put down: [kind, where, extra]
var _to_spawn: Array = []
const SPAWN_A_FRAME := 6
## What traders sell, one pod each: three of these are set out in front of each trader
const GOODS: Array[String] = ["engine", "beam", "shield", "dash", "patch", "laser", "fleet"]
const UPGRADES := {
	"engine": {"title": "ENGINE", "about": "+12% speed", "price": 300, "colour": Color(1.0, 0.55, 0.15)},
	"beam": {"title": "BEAM", "about": "lifts faster, and stronger: one more kind of thing it can take", "price": 400, "colour": Color(0.4, 1.0, 0.5)},
	"shield": {"title": "SHIELD", "about": "+25 shield, and patched up", "price": 300, "colour": Color(0.3, 0.6, 1.0)},
	"patch": {"title": "PATCH", "about": "the shield filled up again", "price": 0, "colour": Color(0.4, 1.0, 1.0)},
	"dash": {"title": "DASH", "about": "recharges faster, and leaves two more afterimages", "price": 250, "colour": Color(0.75, 0.4, 1.0)},
	"laser": {"title": "LASER", "about": "fires by itself: shoots down shells and missiles, then jets, then the police and army; quicker and further each level", "price": 500, "colour": Color(1.0, 0.3, 0.45)},
	"fleet": {"title": "FLEET", "about": "one more little saucer that beams up small things nearby, and gets in the way of shots", "price": 450, "colour": Color(1.0, 0.9, 0.3)},
}
const MAX_UPGRADE := 4
## The defence laser (see `_laser`): how far it reaches before upgrades (+2 m a level), and the hits
## that blow each of the police and army up (one less is only a moment's stun)
const LASER_REACH := 14.0
const LASER_HITS := {"police_car": 2, "patrol_car": 2, "jeep": 3, "patrol_jeep": 3, "tank": 5, "helicopter": 4, "chinook": 6, "agent_car": 3}
var _laser_wait := 0.0
## The mini fleet: a little saucer for each level of FLEET (see Drone)
var fleet: Array[Drone] = []
## Where phone lines have been cut this run (a call near one cannot get through)
var _cuts: Array[Vector3] = []
const LINE_REACH := 150.0
var _spotted_for := 0.0
## Things further than this from the saucer are let go (their chunk has gone, or soon will)
const CULL := 216.0
var _jet_wait := 8.0
var _shake := 0.0
## The wreck of the ship, shot down (INF while flying), how long it has burned, its pilot, and when the
## score panel comes up
var wreck := Vector3.INF
var _wreck_t := 0.0
var _wreck_pilot: Node3D
var _over_show := 0.0
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
## How wide the score's box is, right-aligned beside the pause button
const SCORE_WIDTH := 360.0
## The score's bounce when something is swallowed (1 just then, down to 0), and its sparkles
var _score_pop := 0.0
var _sparks: Control
## How wide the log of what was taken is, right-aligned under the score
const LOG_WIDTH := 640.0
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
var heat_note: Label
var heat_note_time := 0.0
var title_box: Control
var over_box: Control
var _again: Button
## The results typing out (see _wreck_burning)
var _over_typing := 0.0
## The wrecked ship left lying while the camera pulls away from it to the moon (see quit_to_menu)
var _wreck_ship: Ufo
const RESULTS_SPEED := 45.0
var over_label: Label
## The title screen's parts, laid out for the screen's shape (`_layout_title`)
var _title_label: Label
var _title_gap: Control
var _arrows: Array[Button] = []
var _title_row: HBoxContainer
## The gap above the title's second row of buttons
var _title_drop: Control
## The log (a field guide): every ship, every kind of thing there is to take (with how many of each
## have been taken, ever), and every kind of hunter met; filled in as they are, and kept with the best
var _log_box: Control
var _log_list: VBoxContainer
var _log_head: Label
var _log_back: Button
var _log_taken := {}
## This run's takings by kind: [how many, points], for the results (see _results)
var _run_taken := {}
var _log_met: Array[String] = []
## The hunters, as the log names them (the jets are not things: they are only flown over)
const HUNTERS := {
	"police_car": "POLICE CAR", "patrol_car": "POLICE PATROL", "jeep": "ARMY JEEP",
	"patrol_jeep": "ARMY PATROL", "tank": "TANK", "jet": "FIGHTER JET", "officer": "POLICE OFFICER",
	"helicopter": "POLICE HELICOPTER", "agent_car": "MEN IN BLACK", "agent": "AGENT", "chinook": "ARMY CHINOOK",
}
## The first few frames draw the farm under a black cover, so its shaders are ready before the
## ship comes down to it (else the arrival stutters while they are made)
const WARM_FRAMES := 12
var _warm_frames := WARM_FRAMES
## One of each effect, drawn under the cover in the first frames so that its shader is made before
## it is first needed (on the web, making one stalls a frame: see `_warm_effects`)
var _warm: Node3D
var _cover: ColorRect
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
## Where the beam thumb came down (dragging it from there aims the beam, see `_beam_aim`)
var _beam_from := Vector2.INF
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
	# (the ground takes the beam's shadows: see Ufo.beam_light)
	world.ground.set_layer_mask_value(Thing.BEAM_LAYER, true)
	_load_best()
	moon_set = MoonSet.new()
	view.add_child(moon_set)
	dust = Dust.new()
	motes = Dust.motes()
	clouds = Clouds.new()
	view.add_child(clouds)
	view.add_child(motes)
	view.add_child(dust)
	_make_ufo(Vector3.ZERO)
	world.update(World.START, 0.0, true)
	_spawn_some(true)
	_warm_models()
	_warm_effects()
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
	camera.fov = _fov()
	_layout_touch()
	_layout_title(size)


## How wide the camera sees in a run: across an upright phone, or up and down a wide screen
func _fov() -> float:
	return 50.0 if _upright() else 42.0


# ------------------------------------------------------------------ the run

func start(from_launch := false) -> void:
	var again := mode == "over"
	if not ship in unlocked:
		return
	if again:
		_new_world(true)
	mode = "play"
	for t in things.duplicate():
		if t.is_enemy() or t.kind == "rival":
			_remove(t)
	_rival_wait = 50.0
	_run_taken.clear()
	_five_for = 0.0
	_nuke_wait = 0.0
	for n: Array in _nukes:
		(n[2] as Node3D).queue_free()
		if n[3] != null:
			(n[3] as Node3D).queue_free()
	_nukes.clear()
	if _nuke_flash != null:
		_nuke_flash.visible = false
	for s in shots:
		s.queue_free()
	shots.clear()
	for j in jets:
		j.queue_free()
	jets.clear()
	ufo.queue_free()
	_clear_wreck()
	if not from_launch:
		alien_seed = randi()
	upgrades = {"engine": 0, "beam": 0, "shield": 0, "dash": 0, "laser": 0, "fleet": 0}
	level = 0
	_levels_due = 0
	_picker.visible = false
	if _picker_dim != null:
		_picker_dim.visible = false
	_clear_fleet()
	_laser_wait = 0.0
	_cuts.clear()
	_forget_fingers()
	var heading := ufo.rotation.y + ufo.hull_model.rotation.y
	_make_ufo(World.START)
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
	# (up where the descent starts from the first frame, not on the ground for one)
	if intro > 0.0:
		_descend(0.0)
		ufo.position.y = ufo.altitude + ufo.descent
	if from_launch:
		# (the hull turned just as it was in the flight)
		ufo.hull_model.rotation.y = heading - ufo.rotation.y
	sfx.play("whoosh", 0.6, 2.0)



## A new country for a new run (not in the tests, which want the same one each time): everything
## made so far forgotten, and the world made again round where the run starts. `now` makes it all at
## once; otherwise a chunk a frame, as on the way down from the moon.
func _new_world(now: bool) -> void:
	if testing:
		return
	_to_spawn.clear()
	for t in things.duplicate():
		if t.state != "walk" and not t.is_enemy():
			_remove(t)
	world.reseed(randi_range(1, 1 << 30))
	_facility_wait = 0.0
	if now:
		world.update(World.START, 0.0, true)

## Coming down from space, `k` of the way (0 to 1): out of the stars until the planet is under the
## ship, the shield coming up on the way, the pilot facing the camera as it swings round (see
## `_intro_camera`) and the dust streaming past (see Dust)
func _descend(k: float) -> void:
	# (slowly at first, from where the climb off the moon stopped, and slowing again to its height)
	ufo.descent = INTRO_HEIGHT * (1.0 - smoothstep(0.0, 1.0, k))
	ufo.bubble_fade = smoothstep(0.4, 0.9, k)
	ufo.rotation.y = lerp_angle(_facing(_away()), 0.0, smoothstep(0.3, 1.0, k))
	dust.fade = 1.0 - smoothstep(0.4, 0.6, k)


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
	if mode == "return":
		_going_home(delta)
	elif intro > 0.0:
		intro = maxf(intro - delta, 0.0)
		_descend(1.0 - intro / INTRO)
		ufo.hull_model.rotation.y += delta * 6.0 * pow(intro / INTRO, 2.0)
	elif mode == "play" and not autopilot:
		steer = _read_steer()
		beam = Input.is_action_pressed("beam") or beam_finger != NO_FINGER
		ufo.beam_aim = _beam_aim()
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
	if mode == "launch" or mode == "landing":
		_launch(delta)
	ufo.tick(delta, steer, beam)
	if not ufo.dead:
		var held := ufo.position
		ufo.position = world.push_out(ufo.position, 2.6)
		ufo.position.y = held.y
		if mode == "play" and ufo.position.distance_to(held) > 0.01:
			var was := ufo.hull
			ufo.bump(ufo.position - held)
			if ufo.hull < was:
				sfx.play("boom", 1.6)
				_shake = maxf(_shake, 0.5)
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
		if not t.hiding and t.kind != "rival" and ufo.in_beam(t.position, t.reach):
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
					_shake_loose(t, delta)
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
	_beam_shadows()
	_shops(delta)
	_rivals(delta)
	_rival_bumps()
	_nuking(delta)
	_surface_fx(delta)
	_watchers(delta)
	_crop_circles(delta)
	for s in shots:
		s.tick(delta, ufo, self)
	_laser(delta)
	_fleet(delta)
	for s in shots:
		if s.done:
			s.queue_free()
	shots = shots.filter(func(s: Shot) -> bool: return not s.done)
	_jets(delta)
	if mode == "play" and intro <= 0.0:
		_levels()
		time_alive += delta
		_heat(delta)
		_forces(delta)
	if intro <= 0.0:
		_patrols(delta)
	# (on the moon and on the way off it, the world stays ready round where the run starts,
	# rather than loading chunks under a ship flying off across the sky)
	world.update(World.START if mode in ["title", "launch", "landing"] else ufo.position, delta)
	_spawn_some()
	if mode == "play" and not autopilot and not get_tree().paused:
		_pending_fingers()
	_cull(delta)
	_sounds()
	if mode != "launch" and mode != "landing" and intro <= 0.0:
		dust.fade = 0.0
	dust.follow(ufo.position, camera.position, delta)
	# (motes of dust in the air round the ship, coming in as it nears the ground)
	motes.fade = 1.0 - smoothstep(0.0, 0.5, intro / INTRO) if mode == "play" or mode == "over" else 0.0
	motes.follow(ufo.position, camera.position, delta)
	clouds.fade = 0.0 if mode in ["title", "launch", "landing"] else 1.0 - smoothstep(0.0, 0.4, intro / INTRO)
	clouds.follow(ufo.position, camera.position, delta)
	_camera(delta)
	_hud(delta)
	_title_flybys(delta)
	if mode == "over":
		_wreck_burning(delta)
	if ufo.dead and mode == "play":
		_crash(delta)
	if mode == "over" and Input.is_action_just_pressed("start") and _over_wait <= 0.0 and _again.visible:
		quit_to_menu()
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



## Heat for something the ship did: less the more stars there already are (each takes more to earn
## than the last), and little for a while after a new star, so that each is a stage of its own
## rather than a rush from one to five
func add_heat(amount: float) -> void:
	var damp := 1.0 / (1.0 + 0.6 * heat_level())
	if _new_star > 0.0:
		damp *= 0.25
	heat = minf(heat + amount * damp, MAX_HEAT)

func _heat(delta: float) -> void:
	_new_star = maxf(_new_star - delta, 0.0)
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
			_heat_note(["", "THE FARMERS ARE ARMED", "THE POLICE ARE COMING", "POLICE HELICOPTER!", "THE ARMY IS HERE", "TANKS AND THE AIR FORCE"][level], 2.5)
			_new_star = NEW_STAR
			sfx.play("star", 1.0 + level * 0.06)
		else:
			_heat_note("COOLING OFF", 1.5)
			sfx.play("cool")
			# (those no longer wanted at this heat drive off)
		_last_level = level
		var wanted: Dictionary = FORCES[level]
		var have := {}
		for t in things:
			if t.is_enemy() and not t.leaving and not t.info.get("searchlight", false) and not t.info.get("crew", false):
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
	# (on the nearest road, cruising it: none when no road is near)
	var a := randf() * TAU
	var road: Array = world.nearest_road(ufo.ground() + Vector3(sin(a), 0, cos(a)) * randf_range(45.0, 60.0))
	var at: Vector3 = road[0]
	if at.distance_to(ufo.ground()) > 90.0 or at.distance_to(ufo.ground()) < 35.0:
		return
	var b := world.biome_at(at)
	var t := spawn("patrol_jeep" if b in [World.Biome.DESERT, World.Biome.PLAINS, World.Biome.MOUNTAIN] else "patrol_car", at)
	t.road_axis = road[1]
	t.road_dir = 1.0 if randf() < 0.5 else -1.0
	t.heading = (0.0 if t.road_dir > 0.0 else PI) if road[1] == "z" else (PI / 2 if t.road_dir > 0.0 else -PI / 2)


## A patrol's searchlight has the ship in it: the heat goes up fast, and does not cool while it does
func spotted(_by: Thing, delta: float, why := "SPOTTED!") -> void:
	if mode != "play":
		return
	if _spotted_for <= 0.0:
		_heat_note(why, 1.4)
		sfx.play("star", 1.3)
		add_heat(0.35)
	_spotted_for = 0.6
	add_heat(0.5 * delta)
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


## Crop circles: hold the beam still over a field of crops and a circle presses into it at once,
## growing slowly
## as long as the beam stays, and scoring once it is full size; one pressed near another is joined
## to it by a line (see World.crop_circle)
func _crop_circles(delta: float) -> void:
	var here := ufo.ground()
	var over := ufo.beaming and not ufo.dead and ufo.velocity.length() < 5.0 and world.crops_at(here)
	if not over or (_circle_at != Vector3.INF and _circle_at.distance_to(here) > 4.0):
		_circle_at = Vector3.INF
		_circle_time = 0.0
		return
	_circle_time += delta
	if _circle_time < 0.05:
		return
	var full := ufo.beam_foot * 2.2
	if _circle_at == Vector3.INF:
		_circle_at = here
		# (joined by a line pressed through the crop to any other circle near it)
		var links := world.crop_circle(here, 1.0)
		if links > 0 and mode == "play":
			var bonus := 25 * links * multiplier()
			score += bonus
			log_line("CROP CIRCLES JOINED", bonus)
		_circle_done = false
	var r := minf(1.0 + (_circle_time - 0.05) * 1.0, full)
	world.grow_circle(r)
	if r >= full and not _circle_done and mode == "play":
		_circle_done = true
		var points := 60 * multiplier()
		score += points
		add_heat(0.02)
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
	# (a ship that has taken more is sent more after it: more of the lightest on the ground, a step
	# of danger)
	var first := ""
	for k: String in ["police_car", "jeep", "tank"]:
		if wanted.has(k) and first == "":
			first = k
	if first != "":
		wanted[first] = int(wanted[first]) + int((danger() - 1.0) * 1.5)
	for kind: String in wanted:
		var have := 0
		for t in things:
			if t.kind == kind and not t.leaving:
				have += 1
		if have < int(wanted[kind]):
			var angle := randf_range(-PI * 0.8, PI * 0.8) + PI
			# (just out of sight: past the bend ahead, or off the edge of the screen behind)
			var at := ufo.ground() + Vector3(sin(angle), 0, cos(angle)) * 46.0
			# (out of the nearest police station or army base, when there is one)
			var home := _station_for(kind)
			if home != Vector3.INF:
				at = home + Vector3(randf_range(-6, 6), 0, 10.0)
			at = world.push_out(at, 3.0)
			var t := spawn(kind, at)
			t.heading = atan2(ufo.position.x - at.x, ufo.position.z - at.z)
			_spawn_wait = 2.5
			if kind == "police_car" and have == 0:
				_heat_note("SIRENS!", 1.2)
			return


func _jets(delta: float) -> void:
	if mode == "play" and heat_level() >= 5 and not ufo.dead:
		_jet_wait -= delta
		if _jet_wait <= 0.0:
			# Fighter jets from four stars, twice as often at five
			_jet_wait = randf_range(7.0, 10.0) if heat_level() >= 5 else randf_range(13.0, 18.0)
			var jet := Ps1.model("jet")
			jet.position = ufo.ground() + Vector3(randf_range(-20, 20), 15.0, -90.0)
			jet.set_meta("fired", 0)
			view.add_child(jet)
			jets.append(jet)
			if not "jet" in _log_met:
				_log_met.append("jet")
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
	# (one thing to be had: two levels of an upgrade at once, beamed up for nothing)
	var stock: Array = GOODS.filter(func(g: String) -> bool: return g != "patch")
	stock.shuffle()
	var what: String = stock[0]
	var pod := spawn("pod", world.off_road(at + Vector3(0, 0, 6.5), 1.0), {"chunk": c, "turn": 0.0, "tints": {"pod_glow": UPGRADES[what]["colour"]}})
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
	# Each pod's tag: what it is, green if it can be had and red if not
	for s in shops:
		for pod: Thing in s.pods:
			if not is_instance_valid(pod) or pod.state == "gone":
				continue
			var what: String = pod.get_meta("goods")
			var tag: Label3D = pod.get_meta("tag")
			tag.text = "%s +2\n%s" % [UPGRADES[what]["title"], "THE BEST THERE IS" if upgrades[what] >= MAX_UPGRADE else "BEAM IT UP"]
			tag.modulate = Color(0.6, 1.0, 0.65) if why_not(pod) == "" else Color(1.0, 0.45, 0.35)


## Why a pod cannot be taken just now ("" if it can)
func why_not(pod: Thing) -> String:
	var shop: Shop = pod.get_meta("shop")
	if heat_level() >= 1:
		return "%s WON'T TRADE WHILE THEY'RE LOOKING FOR YOU" % shop.keeper_name.to_upper()
	if upgrades[pod.get_meta("goods")] >= MAX_UPGRADE:
		return "NOTHING MORE TO BE HAD THERE"
	return ""


## A trader's pod has come up the beam: two levels of what was in it, and the trader is off
func _bought(pod: Thing) -> void:
	var what: String = pod.get_meta("goods")
	var shop: Shop = pod.get_meta("shop")
	buy(what)
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



## What has been bought, on the ship: faster, a stronger beam, a bigger shield, a quicker dodge, the
## laser under it and the fleet round it
func _apply_upgrades() -> void:
	var spec: Dictionary = Ufo.SHIPS[ship]
	ufo.speed = float(spec["speed"]) * (1.0 + 0.12 * upgrades["engine"])
	ufo.lift_rate = float(spec["lift"]) * (1.0 + 0.2 * upgrades["beam"])
	ufo.tier = mini(int(spec["tier"]) + int(upgrades["beam"]), 4)
	ufo.hull_max = float(spec["hull"]) + 25.0 * upgrades["shield"]
	ufo.dash_level = upgrades["dash"]
	if upgrades["laser"] > 0:
		ufo.arm_laser()
	_build_fleet()


# ------------------------------------------------------------------ levelling up

## The score that brings level `n`: each further off than the last (600, 2400, 5400, 9600...)
static func level_at(n: int) -> int:
	return int(round(600.0 * pow(float(n), 2.0) / 50.0)) * 50


## A level for every LEVEL_AT reached: one at a time, a pick of three upgrades
func _levels() -> void:
	while score >= level_at(level + 1):
		level += 1
		_levels_due += 1
	if _levels_due > 0 and not _picker.visible and not ufo.dead:
		_levels_due -= 1
		_level_up()


## LEVEL UP: the game holds still while one of three upgrades is picked (and the shield patched up
## is one of them when it is low). Tests and the autopilot take the first.
func _level_up() -> void:
	var offers: Array = GOODS.filter(func(g: String) -> bool: return g != "patch" and upgrades[g] < MAX_UPGRADE)
	offers.shuffle()
	offers = offers.slice(0, 3)
	if ufo.hull < ufo.hull_max * 0.6:
		if offers.size() >= 3:
			offers[2] = "patch"
		else:
			offers.append("patch")
	if offers.is_empty():
		return
	if autopilot or testing:
		_pick(offers[0])
		return
	sfx.play("fanfare", 1.2, -2.0)
	for b in _picks.get_children():
		b.queue_free()
	_picker_title.text = "LEVEL %d" % level
	for what: String in offers:
		var spec: Dictionary = UPGRADES[what]
		var heading := "%s" % spec["title"] if what == "patch" else "%s %d" % [spec["title"], upgrades[what] + 1]
		var b := _button("%s\n%s" % [heading, spec["about"]], func() -> void: _pick(what))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(640, 120)
		b.add_theme_font_size_override("font_size", 28)
		b.add_theme_color_override("font_color", (spec["colour"] as Color).lerp(Color.WHITE, 0.35))
		_picks.add_child(b)
	_forget_fingers()
	_picker.visible = true
	_picker_dim.visible = true
	get_tree().paused = true


func _pick(what: String) -> void:
	if what == "patch":
		repair()
	else:
		buy(what)
	_picker.visible = false
	if _picker_dim != null:
		_picker_dim.visible = false
	get_tree().paused = false

## An upgrade: one more level of it (up to MAX_UPGRADE), for nothing (see `_level_up`)
func buy(what: String) -> bool:
	if upgrades[what] >= MAX_UPGRADE:
		return false
	upgrades[what] += 1
	_apply_upgrades()
	log_line("%s UPGRADED TO %d" % [UPGRADES[what]["title"], upgrades[what]], 0)
	if what == "shield":
		ufo.hull = minf(ufo.hull + 25.0, ufo.hull_max)
	if what == "laser" and upgrades[what] == 1:
		_banner("LASER ARMED: IT FIRES BY ITSELF", 2.5)
	elif what == "fleet" and upgrades[what] == 1:
		_banner("A LITTLE SAUCER JOINS YOU", 2.5)
	sfx.play("bloop", 1.4)
	return true


## Patching the shield back up, full (a pick at a level-up)
func repair_price() -> int:
	return int(ceil(ufo.hull_max - ufo.hull))


func repair() -> void:
	var mend := repair_price()
	if mend <= 0:
		return
	ufo.hull = ufo.hull_max
	log_line("SHIELD PATCHED", 0)
	sfx.play("bloop", 1.2)


## The defence laser: a turret under the hull that fires by itself, a shot every `laser_reload`
## seconds. It shoots down the shells and missiles coming at the ship first, then jets, and then,
## once there is heat, the nearest of the police and army: a hit stuns one (it holds its fire a
## while), and LASER_HITS blow it up, scored and heating things up as a crush does. Each level it
## fires sooner and reaches further.
func _laser(delta: float) -> void:
	_laser_wait -= delta
	var level: int = upgrades["laser"]
	if level == 0 or ufo.dead or mode != "play" or intro > 0.0 or _laser_wait > 0.0:
		return
	var reach := LASER_REACH + 2.0 * level
	var target: Node3D
	var nearest := reach
	for s in shots:
		if s.kind in ["shell", "missile"] and not s.done and s.position.distance_to(ufo.position) < nearest:
			nearest = s.position.distance_to(ufo.position)
			target = s
	if target == null:
		for j in jets:
			if j.position.distance_to(ufo.position) < nearest:
				nearest = j.position.distance_to(ufo.position)
				target = j
	if target == null and heat_level() >= 1:
		for t in things:
			if t.is_enemy() and t.state == "walk" and not t.leaving and t.position.distance_to(ufo.position) < nearest:
				nearest = t.position.distance_to(ufo.position)
				target = t
	if target == null:
		return
	_laser_wait = laser_reload()
	if ufo.laser == null:
		ufo.arm_laser()
	var at := target.global_position + (Vector3(0, 1.0, 0) if target is Thing else Vector3.ZERO)
	_zap(ufo.aim_laser(at), at)
	if target is Shot:
		(target as Shot).done = true
		boom(at, 1.0)
		_popup("SHOT DOWN", at + Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.65))
	elif target is Thing:
		var t: Thing = target
		var hits := int(t.get_meta("zapped", 0)) + 1
		if hits >= int(LASER_HITS.get(t.kind, 2)):
			var points := t.points() / 2 * multiplier()
			score += points
			add_heat(0.25)
			calm = 0.0
			boom(at, 2.2)
			sfx.play("boom", 1.3, _near_db(t))
			log_line("%s BLOWN UP" % t.kind.replace("_", " ").to_upper(), points)
			_remove(t)
		else:
			# (stunned: it holds its fire a while, red and sparking)
			t.set_meta("zapped", hits)
			t.reload = maxf(t.reload, 0.0) + 2.0
			t.burst = 0
			Ps1.flash(t.model, Color(1.2, 0.15, 0.2))
			create_tween().tween_callback(func() -> void:
				if is_instance_valid(t):
					Ps1.flash(t.model, Color.BLACK)).set_delay(0.2)
	else:
		# A jet, out of the sky
		jets.erase(target)
		target.queue_free()
		boom(at, 3.0)
		sfx.play("boom", 0.9)
		var points := 250 * multiplier()
		score += points
		add_heat(0.25)
		calm = 0.0
		log_line("JET SHOT DOWN", points)


## Seconds between the laser's shots, at its level
func laser_reload() -> float:
	return 2.4 - 0.4 * upgrades["laser"]


## A bolt of the laser from `from` to `to`: a white-hot core in a pink glow, there and gone, and a
## spark where it lands
func _zap(from: Vector3, to: Vector3) -> void:
	var way := to - from
	var long := way.length()
	if long < 0.1:
		return
	var bolt := Node3D.new()
	view.add_child(bolt)
	bolt.look_at_from_position((from + to) * 0.5, to, Vector3.UP if Vector2(way.x, way.z).length() > 0.1 else Vector3.FORWARD)
	Ps1.part(bolt, BoxMesh.new(), Ps1.flat(Color(1.0, 0.92, 0.96)), Vector3.ZERO, Vector3(0.16, 0.16, long))
	var glow := CylinderMesh.new()
	glow.top_radius = 0.5
	glow.bottom_radius = 0.5
	glow.height = long
	glow.radial_segments = 8
	glow.rings = 1
	glow.cap_top = false
	glow.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/beam.gdshader")
	m.set_shader_parameter("tint", Color(1.0, 0.25, 0.5))
	m.set_shader_parameter("power", 1.6)
	Ps1.part(bolt, glow, m, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
	var tw := create_tween()
	tw.tween_property(bolt, "scale", Vector3(0.05, 0.05, 1.0), 0.18).set_delay(0.06)
	tw.tween_callback(bolt.queue_free)
	_blob(to, Color(1.0, 0.6, 0.75), 0.9, 0.3)
	sfx.play("zap", 1.0, -2.0)


## The mini fleet: each moved, and any shot that meets one stopped there
func _fleet(delta: float) -> void:
	for d in fleet:
		d.of = fleet.size()
		d.tick(delta, ufo)
	for s in shots:
		if s.done:
			continue
		for d in fleet:
			if d.is_up() and s.position.distance_to(d.position) < 0.9:
				s.done = true
				d.hit()
				puff(s.position, Color(1.0, 0.85, 0.5), 0.5)
				sfx.play("clang", 1.6, _near_db(d) - 4.0)
				break


## One little saucer for each level of FLEET, out of the ship
func _build_fleet() -> void:
	while fleet.size() < int(upgrades["fleet"]):
		var d := Drone.new()
		view.add_child(d)
		d.setup(self, fleet.size(), ufo.position + Vector3(0, -1.0, 0))
		fleet.append(d)
		puff(d.position, Color(1.0, 0.9, 0.4), 0.8)


## One of the fleet has brought something home: taken as the ship takes it (out of the list of
## things here, the fleet being moved after the list is gone through)
func drone_took(t: Thing) -> void:
	abducted(t)
	things.erase(t)


func _clear_fleet() -> void:
	for d in fleet:
		d._let_go()
		d.queue_free()
	fleet.clear()


## One of the mini fleet the police and army take for the ship this time, if any (the more of the
## fleet, the likelier)
func _decoy() -> Drone:
	var up: Array[Drone] = []
	for d in fleet:
		if d.is_up():
			up.append(d)
	if up.is_empty() or randf() > minf(0.12 * up.size(), 0.4):
		return null
	return up[randi() % up.size()]


## The ship a secret facility holds: the one it was built round, or, once that one has been found,
## another not yet found (so a facility is always worth the trip while there are ships to find)
func captive(held: String, c: Vector2i) -> String:
	if not held in unlocked:
		return held
	var left: Array[String] = []
	for s in Ufo.ORDER:
		if not s in unlocked:
			left.append(s)
	if left.is_empty():
		return held
	return left[posmod(c.x * 7 + c.y * 13, left.size())]



## Whatever stands under the beam throws a shadow in its light while it is on (not only what it has
## hold of); what it leaves behind stops
var _shadowed: Array[Thing] = []
func _beam_shadows() -> void:
	var now: Array[Thing] = []
	if ufo.beaming and not ufo.dead:
		var foot := ufo.beam_axis(0.0)
		for t in things:
			if t.state == "walk" and t.ground().distance_to(foot) < ufo.beam_foot + 3.0:
				now.append(t)
	for t in _shadowed:
		if is_instance_valid(t) and t.state == "walk" and not t in now:
			t.shade(false)
	for t in now:
		t.shade(true)
	_shadowed = now
## The beam pulls up the scenery under it that it is strong enough for, a piece at a time
func _pull_scenery(delta: float) -> void:
	_pull_wait -= delta
	# (scenery too much for the beam rattles in the ground)
	world.rattle(ufo.beam_axis(0.0), ufo.beam_foot if ufo.beaming and not ufo.dead else 0.0, ufo.tier)
	if not ufo.beaming or ufo.dead or _pull_wait > 0.0:
		return
	_pull_wait = 0.15
	var found := world.pull(ufo.beam_axis(0.0), ufo.beam_foot, ufo.tier)
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
		# (from a phone booth its aerial has been sparking all along to say so; from anywhere else, a
		# word over the caller's head)
		if t.booth == null:
			_popup("NO SIGNAL", t.position + Vector3(0, 3, 0), Color(0.7, 0.8, 1.0))
		sfx.play("static", 1.0, _near_db(t))
		return
	# (the first call brings a star; more ringing in on top of it within a few seconds add little)
	var now := Time.get_ticks_msec() / 1000.0
	add_heat(0.9 if now - _last_call > 6.0 else 0.2)
	_last_call = now
	calm = 0.0
	_heat_note("SOMEONE CALLED THE POLICE", 1.8)
	sfx.play("ring", 0.8)


## A phone pole was taken: the line is down there, and its wires (and the last pole's, to it) go
func line_cut(pole: Thing) -> void:
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







# ------------------------------------------------------------------ the bomb
# Five stars for too long and they give up on catching you: a nuclear strike on where the ship is
# going. A red ring marks the ground, a countdown, a missile out of the sky, then a white flash, a
# fireball and a mushroom cloud. Everything inside is gone; the ship inside takes a terrible blow,
# fatal without a full shield. Again and again, while the five stars last.

const NUKE_AFTER := 30.0
const NUKE_EVERY := 20.0
const NUKE_FUSE := 5.0
const NUKE_REACH := 30.0
var _five_for := 0.0
var _nuke_wait := 0.0
## Each strike on its way: [where, seconds left, its ring, its missile]
var _nukes: Array = []
var _nuke_flash: ColorRect


func _nuking(delta: float) -> void:
	if mode != "play" or intro > 0.0:
		return
	if heat_level() >= 5:
		_five_for += delta
	else:
		_five_for = 0.0
	_nuke_wait -= delta
	if _five_for > NUKE_AFTER and _nuke_wait <= 0.0 and not ufo.dead:
		_nuke_wait = NUKE_EVERY / sqrt(danger())
		var at := ufo.ground() + Vector3(ufo.velocity.x, 0, ufo.velocity.z) * 2.0
		_nukes.append([at, NUKE_FUSE, _nuke_ring(at), null])
		_heat_note("NUCLEAR STRIKE INBOUND!", 3.0)
		log_line("NUCLEAR STRIKE AUTHORISED", 0)
		sfx.play("star", 0.6, 4.0)
	for n: Array in _nukes.duplicate():
		n[1] -= delta
		var ring: MeshInstance3D = n[2]
		ring.visible = fmod(n[1], 0.5) < 0.3 or n[1] < 1.0
		ring.scale = Vector3.ONE * (1.0 + 0.04 * sin(n[1] * 12.0))
		if n[1] < 1.4 and n[3] == null:
			n[3] = _nuke_missile()
		if n[3] != null:
			var k := clampf(1.0 - n[1] / 1.4, 0.0, 1.0)
			(n[3] as Node3D).position = (n[0] as Vector3) + Vector3(0, 90.0 * (1.0 - k * k), 0)
		if n[1] <= 0.0:
			_nukes.erase(n)
			ring.queue_free()
			if n[3] != null:
				(n[3] as Node3D).queue_free()
			_detonate(n[0])
	if _nuke_flash != null and _nuke_flash.visible:
		_nuke_flash.color.a = maxf(_nuke_flash.color.a - delta * 1.6, 0.0)
		_nuke_flash.visible = _nuke_flash.color.a > 0.0


func _nuke_ring(at: Vector3) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = NUKE_REACH - 0.8
	t.outer_radius = NUKE_REACH
	t.rings = 48
	ring.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.15, 0.1)
	m.disable_fog = true
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = at + Vector3(0, 0.2, 0)
	ring.scale = Vector3(1, 0.1, 1)
	# (and the ground inside it washed faintly red)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = NUKE_REACH
	cyl.bottom_radius = NUKE_REACH
	cyl.height = 0.05
	cyl.radial_segments = 48
	disc.mesh = cyl
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(1.0, 0.1, 0.05, 0.14)
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = Vector3(0, -1.0, 0)
	ring.add_child(disc)
	view.add_child(ring)
	return ring


func _nuke_missile() -> Node3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = 0.5
	c.height = 4.0
	mi.mesh = c
	mi.material_override = Ps1.flat(Color(0.85, 0.85, 0.8))
	view.add_child(mi)
	return mi


func _detonate(at: Vector3) -> void:
	sfx.play("boom", 0.4, 8.0)
	sfx.play("boom", 0.6, 6.0)
	_shake = 1.6
	if _nuke_flash == null:
		_nuke_flash = ColorRect.new()
		_nuke_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_nuke_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(_nuke_flash)
	_nuke_flash.color = Color(1.0, 0.97, 0.88, 1.0)
	_nuke_flash.visible = true
	# the fireball, the ring of dust running out along the ground, the stem and the cap
	for i in 10:
		var a := i * TAU / 10.0
		boom(at + Vector3(cos(a), 0.5, sin(a)) * randf_range(4.0, 14.0), 8.0)
	boom(at, 18.0)
	for i in 24:
		var a := i * TAU / 24.0
		ufo.puffs.puff(at + Vector3(cos(a), 0.6, sin(a)) * 6.0, Color(0.45, 0.38, 0.32, 0.9), 3.0, Vector3(cos(a), 0.15, sin(a)) * 22.0, 2.4)
	for i in 14:
		ufo.puffs.puff(at + Vector3(randf_range(-2, 2), i * 2.2, randf_range(-2, 2)), Color(0.55, 0.42, 0.34, 0.75), 2.2 + i * 0.08, Vector3(0, 6.0, 0), 3.0)
	for i in 16:
		var a := i * TAU / 16.0
		ufo.puffs.puff(at + Vector3(cos(a) * 9.0, 32.0, sin(a) * 9.0), Color(0.9, 0.45, 0.2, 0.9), 7.0, Vector3(cos(a) * 3.0, 4.0, sin(a) * 3.0), 4.5)
	# everything in it gone (all but the land itself)
	for t in things.duplicate():
		if t.state != "walk" or t.obstacle != Vector4.ZERO and not t.kind in World.TALL:
			continue
		if Vector2(t.position.x - at.x, t.position.z - at.z).length() < NUKE_REACH:
			if t.obstacle != Vector4.ZERO:
				world.remove_obstacle(t.chunk, t.obstacle)
			_remove(t)
	var d := Vector2(ufo.position.x - at.x, ufo.position.z - at.z).length()
	if d < NUKE_REACH and not ufo.dead and not ufo.dodging():
		ufo.hurt(lerpf(90.0, 25.0, d / NUKE_REACH))
		var away := Vector3(ufo.position.x - at.x, 0, ufo.position.z - at.z)
		ufo.knock = (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 20.0


# ------------------------------------------------------------------ saucers going by on the title

## Seconds till the next saucer streaks across the moon's sky behind the title, and those going by:
## [node, from, to, seconds in, seconds it takes]
var _flyby_wait := 6.0
var _flybys: Array = []
const FLYBY_SHIPS := ["ufo", "orb", "triangle", "cigar", "bell"]


func _title_flybys(delta: float) -> void:
	for f: Array in _flybys.duplicate():
		f[3] += delta
		var k: float = f[3] / f[4]
		var node: Node3D = f[0]
		if k >= 1.0 or mode != "title":
			node.queue_free()
			_flybys.erase(f)
			continue
		var from: Vector3 = f[1]
		var to: Vector3 = f[2]
		node.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 3.0, 0)
		node.rotation.y += delta * 4.0
		node.rotation.z = (to - from).normalized().x * -0.25
	if mode != "title" or testing:
		return
	_flyby_wait -= delta
	if _flyby_wait > 0.0:
		return
	_flyby_wait = randf_range(7.0, 16.0)
	var basis := camera.global_basis
	var across := 1.0 if randf() < 0.5 else -1.0
	var far := randf_range(22.0, 34.0)
	var high := randf_range(3.0, 8.0)
	var from := camera.global_position + basis * Vector3(-across * far * 0.9, high, -far)
	var to := camera.global_position + basis * Vector3(across * far * 0.9, high + randf_range(-2.0, 3.0), -far * randf_range(0.8, 1.2))
	var tints := {"lights": Color.from_hsv(randf(), 0.6, 1.0), "lights_under": Color.from_hsv(randf(), 0.5, 1.0)}
	var node := Ps1.model(FLYBY_SHIPS[randi() % FLYBY_SHIPS.size()], tints)
	node.scale = Vector3.ONE * randf_range(0.8, 1.3)
	view.add_child(node)
	_flybys.append([node, from, to, 0.0, randf_range(3.0, 5.5)])
	sfx.play("whoosh", randf_range(1.2, 1.6), -10.0)


# ------------------------------------------------------------------ what the beam kicks up

## The colour of each kind of ground's bits (see World.surface_at)
const SURFACE := {"water": Color(0.6, 0.8, 1.0, 0.8), "road": Color(0.55, 0.55, 0.56), "crop": Color(0.85, 0.74, 0.4),
	"grass": Color(0.42, 0.7, 0.32), "sand": Color(0.86, 0.62, 0.42), "dirt": Color(0.58, 0.43, 0.3), "rock": Color(0.62, 0.62, 0.65)}
var _surface := "grass"
var _surface_wait := 0.0
var _kick_wait := 0.0


## Small and subtle: under the beam, bits of whatever the ground is (blades of grass, clods, chaff,
## sand, grit, drops of water) jump up and fall back, and the swirl up the beam takes their colour;
## and power lines near the beam spark
func _surface_fx(delta: float) -> void:
	if not ufo.beaming or ufo.dead or mode != "play":
		return
	var foot := ufo.beam_axis(0.0)
	_surface_wait -= delta
	if _surface_wait <= 0.0:
		_surface_wait = 0.3
		_surface = world.surface_at(foot)
		ufo.tornado.tint = (SURFACE[_surface] as Color).lerp(Color(0.75, 1.0, 0.8), 0.25)
	_kick_wait -= delta
	if _kick_wait <= 0.0:
		_kick_wait = 0.07
		var a := randf() * TAU
		var at := foot + Vector3(cos(a), 0.05, sin(a)) * randf() * ufo.beam_foot * 0.8
		var c: Color = SURFACE[_surface]
		if _surface == "water":
			ufo.puffs.chip(at, Vector3(randf_range(-0.6, 0.6), randf_range(2.5, 4.0), randf_range(-0.6, 0.6)), c, 0.06, 7.0, 0.7)
		else:
			ufo.puffs.chip(at, Vector3(randf_range(-0.8, 0.8), randf_range(1.5, 3.2), randf_range(-0.8, 0.8)), c.darkened(randf() * 0.25), randf_range(0.07, 0.12), 5.0, 0.9)
	# (the wires of the phone line, where they pass near the beam: sparks off them)
	for t in things:
		if t.kind != "phone_pole" or t.state != "walk" or t.wire_to == Vector3.INF:
			continue
		var a := Vector2(t.position.x, t.position.z)
		if a.distance_to(Vector2(foot.x, foot.z)) > 30.0:
			continue
		var b := Vector2(t.wire_to.x, t.wire_to.z)
		var ab := b - a
		var k := clampf((Vector2(foot.x, foot.z) - a).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
		var near := a + ab * k
		if near.distance_to(Vector2(foot.x, foot.z)) < ufo.beam_foot + 1.0 and randf() < delta * 10.0:
			ufo.puffs.spark(Vector3(near.x, 6.9, near.y), Vector3(randf_range(-2, 2), randf_range(0.5, 3), randf_range(-2, 2)), Color(0.6, 0.85, 1.0))


## Roofs that shed tiles when the beam cannot lift the building (see _shake_loose)
const TILED := ["house", "farmhouse", "storefront", "diner", "cabin", "police_station", "barn", "church", "city_hall"]


## Too heavy for the beam and rattling in it: a little dust off its foot, and from a roof, now and
## then a tile, torn off and pulled up the beam a way before it falls
func _shake_loose(t: Thing, delta: float) -> void:
	var top := t.size() * t.base_size
	if randf() < delta * 3.0:
		var a := randf() * TAU
		ufo.puffs.puff(t.position + Vector3(cos(a), 0.2, sin(a)) * top * 0.4, Color(0.55, 0.5, 0.45, 0.35), 0.5, Vector3(0, 0.6, 0), 0.9)
	if t.kind in TILED and randf() < delta * 4.0:
		var at := t.position + Vector3(randf_range(-0.3, 0.3) * top, top * 0.9, randf_range(-0.3, 0.3) * top)
		var up := (ufo.position - at).normalized()
		ufo.puffs.chip(at, up * randf_range(3.0, 5.0) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), Color(0.3, 0.3, 0.34), 0.22, 4.0, 1.4)
# ------------------------------------------------------------------ rival saucers

## Seconds till the next rival saucer turns up (see _rivals)
var _rival_wait := 50.0

## Now and then another saucer comes down out of the sky to abduct from your country
func _rivals(delta: float) -> void:
	if mode != "play" or intro > 0.0 or testing:
		return
	_rival_wait -= delta
	if _rival_wait > 0.0:
		return
	_rival_wait = randf_range(70.0, 130.0)
	var a := randf() * TAU
	var at := ufo.ground() + Vector3(cos(a), 0, sin(a)) * 70.0
	spawn_rival(at)


func spawn_rival(at: Vector3) -> Thing:
	var r := spawn("rival", at)
	# (down out of the sky)
	r.position.y = 30.0
	_heat_note("A RIVAL SAUCER!", 2.5)
	log_line("RIVAL SAUCER SIGHTED", 0)
	return r


## Small game near `p` for a rival saucer: an animal or a person out in the open, or null
func rival_prey(p: Vector3, reach: float) -> Thing:
	var best: Thing = null
	for t in things:
		if t.state != "walk" or t.hiding or t.is_enemy() or float(t.info["weight"]) > 3.0:
			continue
		if not t.info["move"] in ["flee", "graze", "peck"]:
			continue
		var d := Vector2(t.position.x - p.x, t.position.z - p.z).length()
		if d < reach:
			reach = d
			best = t
	return best


## A rival saucer got something up its beam: gone, and it is noted
func stolen_by_rival(t: Thing) -> void:
	var title: String = t.info.get("title", t.kind.replace("_", " ").to_upper())
	log_line("RIVAL TOOK " + title, 0)
	_remove(t)


func remove_thing(t: Thing) -> void:
	_remove(t)


## The ship against a rival saucer: bounced off it; or, dashing, the rival knocked flying
func _rival_bumps() -> void:
	if ufo.dead or mode != "play":
		return
	for t in things:
		if t.kind != "rival" or t.state != "walk":
			continue
		var off := ufo.position - t.position
		off.y = 0.0
		var reach := ufo.radius + 2.4
		if off.length() < reach and absf(ufo.position.y - t.position.y) < 3.0:
			var out := off.normalized() if off.length() > 0.01 else Vector3.RIGHT
			ufo.position += out * (reach - off.length())
			if ufo.dodging():
				t.rammed(-out)
				ufo.knock = out * 4.0
				sfx.play("boom", 1.3)
				_shake = maxf(_shake, 0.4)
				score += 500 * multiplier()
				log_line("RIVAL RAMMED", 500)
			else:
				var was := ufo.hull
				ufo.bump(out * 0.5)
				t.knock = -out * 6.0
				if ufo.hull < was:
					sfx.play("boom", 1.6)
					_shake = maxf(_shake, 0.5)
## Buildings people run into and hide in when the ship comes (see Thing.hiding)
const SHELTERS := ["house", "farmhouse", "storefront", "church", "barn", "diner", "cabin", "city_hall"]

## The nearest building still standing within `reach` of `p` that people can hide in, or null
func nearest_shelter(p: Vector3, reach: float) -> Thing:
	var best: Thing = null
	for t in things:
		if t.kind in SHELTERS and t.state == "walk":
			var d := Vector2(t.position.x - p.x, t.position.z - p.z).length()
			if d < reach:
				reach = d
				best = t
	return best

## The nearest phone booth still standing within `reach` of `p`, or null
func nearest_booth(p: Vector3, reach: float) -> Thing:
	var best: Thing = null
	for t in things:
		if t.kind == "phone_booth" and t.state == "walk":
			var d := Vector2(t.position.x - p.x, t.position.z - p.z).length()
			if d < reach:
				reach = d
				best = t
	return best

## A new thing of a kind, standing at `at` (the world calls this as it makes each chunk)
func spawn(kind: String, at: Vector3, extra := {}) -> Thing:
	var t := Thing.new()
	view.add_child(t)
	t.setup(self, kind, at, extra)
	things.append(t)
	if mode == "play" and HUNTERS.has(kind) and not kind in _log_met:
		_log_met.append(kind)
	return t


## A thing the world wants put down as it makes a chunk: put down a few a frame (see _spawn_some),
## so a new chunk never stalls a frame


## Every effect once, in front of the camera under the cover in the first frames, so that the
## shaders they need are made then rather than the first time each turns up (the lift-off, the
## descent, the first beam, the first dodge, ...), when making them stalls the game on the web
func _warm_effects() -> void:
	_warm = Node3D.new()
	view.add_child(_warm)
	var at := Vector3(0, 1.5, 0)
	var puffs := Puffs.new()
	_warm.add_child(puffs)
	puffs.puff(at, Color(0.2, 0.2, 0.2, 0.8), 1.0)
	puffs.spark(at, Vector3.UP)
	var motes := Dust.motes()
	_warm.add_child(motes)
	motes.fade = 1.0
	motes.follow(at, Vector3(0, 100, 0), 0.016)
	var swirl := Tornado.new()
	_warm.add_child(swirl)
	swirl.follow(Vector3(0, 6, 0), 2.7, 1.0, 0.016)
	swirl.follow(Vector3(0, 6, 0), 2.7, 1.0, 2.0)
	var sky := Clouds.new()
	_warm.add_child(sky)
	sky.fade = 1.0
	sky.follow(Vector3.ZERO, Vector3(0, 30, 0), 0.0)
	# (brought down from up in the sky to where the camera looks)
	sky.position = Vector3(0, -Clouds.HEIGHT + 2.0, 0)
	for shader: String in ["reticle", "water", "beam", "shield", "searchlight"]:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/%s.gdshader" % shader)
		var mi := MeshInstance3D.new()
		mi.mesh = SphereMesh.new()
		mi.material_override = m
		mi.position = at + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		_warm.add_child(mi)
	var ghost := Ps1.ghost_of("ufo", Color(0.5, 1.0, 0.65), 0.5)
	ghost.position = at
	_warm.add_child(ghost)
	# (a light throwing shadows on the ground and on something lit by it, as the beam's does)
	var lit := Ps1.model("cow")
	lit.position = Vector3(1, 0, -1)
	_warm.add_child(lit)
	for n in lit.find_children("*", "GeometryInstance3D", true, false) + [lit]:
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).set_layer_mask_value(Thing.BEAM_LAYER, true)
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# (and a ship like the player's, its spot light on the ground: the ground's cull margin is so wide
	# that the ship's spot "lights" it from 200 m up in the descent, and making the ground's shader
	# for that light then stalled the game)
	var stand_in := Ufo.new()
	stand_in.ship = ship
	stand_in.position = Vector3(0, 8, 0)
	_warm.add_child(stand_in)
	var light := SpotLight3D.new()
	light.position = Vector3(0, 8, 0)
	light.rotation.x = -PI / 2
	light.spot_angle = 50.0
	light.spot_range = 20.0
	light.shadow_enabled = true
	light.light_cull_mask = 1 << (Thing.BEAM_LAYER - 1)
	_warm.add_child(light)
	# (the stars thrown out on a swallow, and a cop's question mark)
	var starfall := Starfall.new()
	_warm.add_child(starfall)
	starfall.burst(Vector3(0, 4, 0), 6)
	var wonder := MeshInstance3D.new()
	wonder.mesh = QuadMesh.new()
	var wm := ShaderMaterial.new()
	wm.shader = Thing.WONDER
	wonder.material_override = wm
	wonder.position = Vector3(-1, 2, 0)
	_warm.add_child(wonder)


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
	ufo.gulp(t.size() * t.base_size * 0.7)
	_score_pop = 1.0
	# (everything taken mends the shield a little, the heavier the more: a chicken a point, a barn a few)
	ufo.hull = minf(ufo.hull + 1.0 + float(t.info["weight"]) * 0.5, ufo.hull_max)
	(_sparks as ScoreSparks).burst(score_label.position + Vector2(score_label.size.x - 40.0, score_label.size.y * 0.5), 14)
	var points := t.points() * multiplier()
	if mode == "play":
		score += points
		taken += 1
		add_heat(float(t.info["heat"]))
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
		log_line(title, points)
		_log_taken[t.kind] = int(_log_taken.get(t.kind, 0)) + 1
		var had: Array = _run_taken.get(title, [0, 0])
		_run_taken[title] = [int(had[0]) + 1, int(had[1]) + points]
	t.state = "gone"
	t.queue_free()


## Something let go of hit the ground (dropped from `height`, thrown at `thrown` m/s): an oil drum,
## or a car dropped from high enough or thrown hard, blows up; anything else dropped from high enough
## on the police or army crushes them
func landed(t: Thing, height: float, thrown := 0.0) -> void:
	sfx.play("thud", 1.0, -6.0 + minf(height, 6.0))
	puff(t.position, Color(0.4, 0.35, 0.28), 0.8)
	if mode != "play":
		return
	if t.info.get("explosive", false) and (height >= 1.5 or thrown > 3.0) \
			or t.kind in VEHICLES and (height >= 3.0 or thrown > 6.0):
		explode(t)
		return
	if height < 3.0:
		return
	for other in things:
		if other == t or not other.is_enemy() or other.state != "walk":
			continue
		if other.ground().distance_to(t.ground()) < other.size() + t.size() * 0.5:
			var points := other.points() / 2 * multiplier()
			score += points
			add_heat(0.25)
			calm = 0.0
			boom(other.position + Vector3(0, 1, 0), 2.0)
			log_line("%s CRUSHED" % other.kind.replace("_", " ").to_upper(), points)
			_remove(other)
			break


## Everything on wheels or tracks (it blows up if dropped hard: see `landed`)
const VEHICLES: Array[String] = ["car", "pickup", "rv", "tractor", "police_car", "patrol_car", "agent_car", "jeep", "patrol_jeep", "tank"]
## How far an explosion reaches: the police and army in it are destroyed, and everyone else runs
const BLAST_REACH := 7.0


## `t` blows up where it lies: a fireball, the police and army near it destroyed (scored), people
## and animals running for it, and the heat up a little
func explode(t: Thing) -> void:
	var at := t.position
	boom(at + Vector3(0, 0.8, 0), 4.5)
	boom(at + Vector3(randf_range(-1, 1), 1.8, randf_range(-1, 1)), 3.0)
	for i in 10:
		ufo.puffs.spark(at + Vector3(0, 1, 0), Vector3(randf_range(-1, 1), randf_range(0.6, 1.6), randf_range(-1, 1)) * randf_range(5.0, 11.0), Color(1.0, 0.7, 0.3))
	sfx.play("boom", 0.8, 2.0)
	_shake = 0.35
	var points := t.points() * multiplier()
	score += points
	log_line("%s BLOWN UP" % t.kind.replace("_", " ").to_upper(), points)
	add_heat(0.3)
	calm = 0.0
	_remove(t)
	for other: Thing in things.duplicate():
		if other.state != "walk":
			continue
		var d := other.ground().distance_to(Vector3(at.x, 0, at.z))
		if d < BLAST_REACH and other.is_enemy() and not other.fixed():
			var got := other.points() / 2 * multiplier()
			score += got
			boom(other.position + Vector3(0, 1, 0), 2.5)
			log_line("%s CAUGHT IN THE BLAST" % other.kind.replace("_", " ").to_upper(), got)
			_remove(other)
		elif d < BLAST_REACH * 1.6:
			other.panic = 6.0


func fire(from: Thing, gun: String, target: Ufo) -> void:
	var muzzle := from.muzzle()
	var mark := target.position
	var going := target.velocity
	# (now and then they take one of the mini fleet for the ship, and aim at that instead)
	var decoy := _decoy()
	if decoy != null:
		mark = decoy.position
		going = Vector3.ZERO
	# Aimed where the saucer will be, give or take
	var lead := mark + going * (muzzle.distance_to(mark) / 28.0)
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
			var aim := mark + going * (muzzle.distance_to(mark) / 20.0)
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
	_wreck_site()
	mode = "over"
	_over_wait = 2.6
	var is_best := score > best
	if is_best:
		best = score
		_save_best()
	_report(score)
	over_label.text = _results(is_best)
	over_label.visible_characters = 0
	_over_typing = 0.0
	# (the panel up once the wreck has been seen to, see `_wreck_burning`)
	_over_show = 2.2
	_banner("", 0.0)




## The results, line by line: what was taken, kind by kind (most points first), then the total
func _results(is_best: bool) -> String:
	var kinds: Array = _run_taken.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return int(_run_taken[a][1]) > int(_run_taken[b][1]))
	var lines: Array[String] = []
	for kind: String in kinds.slice(0, 8):
		lines.append("%s x%d  %d" % [kind, int(_run_taken[kind][0]), int(_run_taken[kind][1])])
	if kinds.size() > 8:
		var rest := 0
		for kind: String in kinds.slice(8):
			rest += int(_run_taken[kind][1])
		lines.append("AND %d MORE  %d" % [kinds.size() - 8, rest])
	if lines.is_empty():
		lines.append("NOTHING TAKEN")
	lines.append("")
	lines.append("TOTAL  %d" % score)
	lines.append("BEST  %d%s" % [best, "  (NEW!)" if is_best and score > 0 else ""])
	return "\n".join(lines)

## Shot down: the ship stays where it hit, half in the ground and tipped over, burning and smoking;
## the pilot tumbles out beside it, lies a moment, and gets up; and everyone about on foot comes to
## have a look (see Thing._investigate)
func _wreck_site() -> void:
	wreck = ufo.ground()
	_wreck_t = 0.0
	ufo.position.y = 0.6
	ufo.body.rotation = Vector3(0.5, ufo.body.rotation.y, 0.35)
	ufo.beam.visible = false
	ufo.reticle.visible = false
	ufo.bubble.visible = false
	ufo.spot.visible = false
	ufo.beam_light.visible = false
	# (the pilot out over the rim, to the ground beside it)
	_wreck_pilot = ufo.alien
	var from := _wreck_pilot.global_transform
	_wreck_pilot.get_parent().remove_child(_wreck_pilot)
	view.add_child(_wreck_pilot)
	_wreck_pilot.global_transform = from
	_wreck_pilot.feel("tossed", 2.0)
	var to := wreck + Vector3(ufo.radius + 1.2, 0.25, 1.0)
	var tw := _wreck_pilot.create_tween()
	tw.tween_method(func(k: float) -> void:
		_wreck_pilot.position = from.origin.lerp(to, k) + Vector3(0, sin(k * PI) * 1.6, 0)
		_wreck_pilot.rotation = Vector3(-PI / 2 * k, k * 2.5, 0), 0.0, 1.0, 0.7)
	tw.tween_interval(1.2)
	tw.tween_property(_wreck_pilot, "rotation", Vector3(0, PI * 0.25, 0), 0.4)
	tw.tween_callback(func() -> void: _wreck_pilot.feel("hurt", 6.0))



## The wreck and its pilot gone (a new run, or back to the title)
func _clear_wreck() -> void:
	wreck = Vector3.INF
	_over_show = 0.0
	if is_instance_valid(_wreck_pilot):
		_wreck_pilot.queue_free()
	_wreck_pilot = null
	if is_instance_valid(_wreck_ship):
		_wreck_ship.queue_free()
	_wreck_ship = null

## The wreck burning: smoke and fire off it, sparks now and then, the pilot staggering about by it;
## and the score panel up after a moment
func _wreck_burning(delta: float) -> void:
	if wreck == Vector3.INF:
		return
	_wreck_t += delta
	if randf() < delta * 9.0:
		ufo.puffs.puff(wreck + Vector3(randf_range(-1.5, 1.5), 1.2, randf_range(-1.5, 1.5)), Color(0.15, 0.15, 0.17, 0.8), randf_range(0.8, 1.4), Vector3(0.3, 2.5, 0.1), 2.2)
	if randf() < delta * 5.0:
		ufo.puffs.puff(wreck + Vector3(randf_range(-1.2, 1.2), 0.9, randf_range(-1.2, 1.2)), Color(1.0, 0.5, 0.12, 0.85), randf_range(0.5, 0.9), Vector3(0, 2.0, 0), 0.5)
	if randf() < delta * 1.5:
		for i in 4:
			ufo.puffs.spark(wreck + Vector3(0, 1.0, 0), Vector3(randf_range(-1, 1), randf_range(0.5, 1.4), randf_range(-1, 1)) * randf_range(3.0, 6.0))
	if _wreck_t > 2.6 and is_instance_valid(_wreck_pilot):
		_wreck_pilot.position.y = 0.25 + absf(sin(_wreck_t * 5.0)) * 0.1
		_wreck_pilot.rotation.z = sin(_wreck_t * 2.3) * 0.25
	if _over_show > 0.0:
		_over_show -= delta
		if _over_show <= 0.0:
			over_box.visible = true
	# (the results typed out a letter at a time, with the log's ticking key)
	if over_box.visible and over_label.visible_characters >= 0 and over_label.visible_characters < over_label.text.length():
		_over_typing += delta * RESULTS_SPEED
		var more := int(_over_typing)
		_over_typing -= more
		if more > 0:
			over_label.visible_characters = mini(over_label.visible_characters + more, over_label.text.length())
			if over_label.text[over_label.visible_characters - 1] != " ":
				sfx.play("click", 1.6, -16.0)
		_again.visible = over_label.visible_characters >= over_label.text.length()

## A line for the log under the score: typed out a letter at a time (`points` after it, if any)
func log_line(text: String, points: int) -> void:
	var line := _label(27, Color(0.55, 1.0, 0.62))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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

## The descent: first just as the flight from the moon left it, behind the ship looking up past it
## into the stars (see `_chase`), then swinging up and back as it comes down until the curve of the
## planet fills the picture, and the game's camera
func _intro_camera() -> void:
	camera.fov = _fov()
	var k := 1.0 - intro / INTRO
	var settle := smoothstep(0.3, 1.0, k)
	# (round the ship, not across it, so it keeps its place in the picture as the camera swings)
	var away := _away()
	var normal_from := _camera_offset() - Vector3(0, ufo.altitude, 0)
	camera.position = ufo.position + _chase(away).slerp(normal_from, settle)
	var normal_way := (Vector3(0, -ufo.altitude * (1.0 if _upright() else 0.55), 0) - normal_from).normalized()
	camera.look_at(camera.position + away.slerp(normal_way, settle), Vector3.UP)
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(ufo.position.x, 0.0, ufo.position.z - 1.0))
	RenderingServer.global_shader_parameter_set("saucer_pos", ufo.position)
	_sky_mat.set_shader_parameter("space", 1.0 - smoothstep(0.3, 0.85, k))
	camera.environment.fog_density = 0.006 * smoothstep(0.55, 1.0, k)


## On the moon: low beside the chair, the ship and Earth in the picture; in the launch it rises
## with the ship and then follows it off into space
func _moon_camera(delta: float) -> void:
	var site := MoonSet.SITE
	# (close on the pilot up on the ship, Earth over its shoulder; on a wide screen the pilot to the
	# right of the title, on an upright phone in the middle between the title and the buttons)
	var at := site + Vector3(-1.4, 2.4, 2.25)
	var look := site + Vector3(2.65, 1.7, -6.85)
	if _upright():
		at = site + Vector3(0.13, 2.0, 2.31)
		look = site + Vector3(6.15, 2.0, -5.68)
	var focus := Vector3(site.x + 1.0, 0.0, site.z)
	if (mode == "launch" or mode == "landing") and _launch_t > LIFT - 0.2:
		# (rising with the ship from the title's picture of it and swinging round it, not across it,
		# to behind it: the ship slides from where it stood in the picture to where it rides)
		var k := smoothstep(LIFT - 0.2, LIFT + 1.6, _launch_t)
		var away := _away()
		var from := at - (site + MoonSet.SHIP_AT)
		var way := (look - at).normalized().slerp(away, k)
		at = ufo.position + from.slerp(_chase(away), k)
		# (turned a little more toward the ship halfway round, for it to keep clear of the edges)
		look = at + way + (ufo.position - at).normalized() * sin(k * PI) * 0.5
		# (the bend goes with the ship as it leaves, or it would pull the ship down out of the
		# picture as it flew away from the moon; the moon rolls away below instead)
		focus = focus.lerp(Vector3(ufo.position.x, 0.0, ufo.position.z), smoothstep(LIFT - 0.2, LIFT + 1.0, _launch_t))
	camera.position = at
	camera.look_at(look, Vector3.UP)
	# (wider on a wide screen, for the ground and its cooler and Earth high above both to be seen;
	# the game's own once the ship is away, as the descent has it)
	camera.fov = _fov() if _upright() else 52.0
	if mode == "launch" or mode == "landing":
		camera.fov = lerpf(camera.fov, _fov(), smoothstep(LIFT - 0.2, LIFT + 1.6, _launch_t))
	RenderingServer.global_shader_parameter_set("bend_focus", focus)
	RenderingServer.global_shader_parameter_set("saucer_pos", Vector3(0, -9999, 0))
	_sky_mat.set_shader_parameter("space", 1.0)
	camera.environment.fog_density = 0.0


## Where the camera rides, from the ship, behind it as it goes `way`
func _chase(way: Vector3) -> Vector3:
	return -way * CHASE_BACK + Vector3(0, CHASE_UP, 0)


## The first frames: the farm where the run starts, under the cover, then the cover fades
func _warm_camera() -> void:
	_warm_frames -= 1
	camera.position = Vector3(0, 10.0, 14.0)
	camera.look_at(Vector3(0, 0, -4.0))
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(0, 0, -1.0))
	_sky_mat.set_shader_parameter("space", 0.0)
	camera.environment.fog_density = 0.006
	if _warm_frames == 0 and _warm != null:
		_warm.queue_free()
		_warm = null
	if _warm_frames == 0 and _cover != null:
		var tw := create_tween()
		tw.tween_property(_cover, "modulate:a", 0.0, 0.4)
		tw.tween_callback(_cover.hide)



func _upright() -> bool:
	var size := get_viewport().get_visible_rect().size
	return size.x < size.y


## The title: on an upright phone, the name in the sky at the top and the ship and PLAY on the moon
## at the bottom, big enough for a thumb; on a wide screen, all of it in a column on the left
func _layout_title(size: Vector2) -> void:
	if title_box == null:
		return
	var upright := size.x < size.y
	if over_box != null:
		# (the results sit just above the wreck in the middle of the screen, never over it)
		over_box.offset_top = -size.y * 0.1
		over_box.offset_bottom = -size.y * 0.1
	if upright:
		title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title_box.offset_left = 40.0
		title_box.offset_right = -40.0
		title_box.offset_top = 150.0
		title_box.offset_bottom = -170.0
		title_box.custom_minimum_size = Vector2.ZERO
	else:
		title_box.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		title_box.offset_left = 30.0
		title_box.offset_right = 650.0
		title_box.custom_minimum_size = Vector2(620, 0)
	_title_gap.visible = upright
	# (the name on one line, glowing: as big as it fits across the box, up to a modest size)
	var room := (size.x - 80.0 if upright else 620.0) - 24.0
	var name_size := 76 if upright else 56
	while name_size > 24 and font.get_string_size(_title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > room:
		name_size -= 2
	_title_label.add_theme_font_size_override("font_size", name_size)
	_title_label.add_theme_constant_override("outline_size", maxi(name_size / 4, 6))
	_title_label.add_theme_constant_override("shadow_outline_size", maxi(name_size / 2, 12))
	ship_label.add_theme_font_size_override("font_size", 56 if upright else 34)
	ship_label.custom_minimum_size = Vector2(620 if upright else 420, 0)
	_title_drop.custom_minimum_size = Vector2(0, 40 if upright else 18)
	for b in _arrows:
		b.custom_minimum_size = Vector2(120, 130) if upright else Vector2(70, 70)
		b.add_theme_font_size_override("font_size", 64 if upright else 40)
	_play_button.custom_minimum_size = Vector2(340, 130) if upright else Vector2(260, 70)
	_play_button.add_theme_font_size_override("font_size", 76 if upright else 40)
	for b in _title_row.get_children():
		(b as Button).custom_minimum_size = Vector2(250, 110) if upright else Vector2(170, 60)
		(b as Button).add_theme_font_size_override("font_size", 52 if upright else 32)


## The log: a list to scroll by thumb, and BACK
func _build_log(root: Control) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.02, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	root.add_child(dim)
	_log_box = dim
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40.0
	box.offset_right = -40.0
	box.offset_top = 40.0
	box.offset_bottom = -40.0
	box.add_theme_constant_override("separation", 16)
	dim.add_child(box)
	var head := _label(56, Color(0.7, 1.0, 0.72))
	head.text = "LOG"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_log_list = VBoxContainer.new()
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_log_list)
	_log_back = _button("BACK", close_log)
	box.add_child(_log_back)
	_log_head = head


func open_log() -> void:
	if mode != "title":
		return
	_fill_log()
	title_box.visible = false
	_log_box.visible = true


func close_log() -> void:
	_log_box.visible = false
	title_box.visible = mode == "title"


## The log written out afresh: the ships, then everything there is to take, then the hunters; what
## has not been come across yet is ???
func _fill_log() -> void:
	for old in _log_list.get_children():
		old.queue_free()
	var big := _upright()
	_log_head.add_theme_font_size_override("font_size", 110 if big else 56)
	_log_back.custom_minimum_size = Vector2(420, 140) if big else Vector2(260, 70)
	_log_back.add_theme_font_size_override("font_size", 72 if big else 40)
	var ships: Array = []
	for s: String in Ufo.ORDER:
		ships.append([Ufo.SHIPS[s]["title"], "" if s in unlocked else "LOCKED", s in unlocked])
	_log_section("SHIPS  %d/%d" % [unlocked.size(), Ufo.ORDER.size()], ships, big)
	var specimens: Array = []
	var have := 0
	for kind: String in Thing.KINDS:
		var info: Dictionary = Thing.KINDS[kind]
		if kind == "pod" or info.get("enemy", false) or info.has("unlock") or HUNTERS.has(kind):
			continue
		var count := int(_log_taken.get(kind, 0))
		have += 1 if count > 0 else 0
		specimens.append([info.get("title", kind.replace("_", " ").to_upper()), "x%d" % count, count > 0])
	_log_section("SPECIMENS  %d/%d" % [have, specimens.size()], specimens, big)
	var hunters: Array = []
	for h: String in HUNTERS:
		hunters.append([HUNTERS[h], "", h in _log_met])
	_log_section("HUNTERS  %d/%d" % [_log_met.size(), HUNTERS.size()], hunters, big)


## A heading, and under it a grid of tiles: [name, note, known] each (an unknown one only "?")
func _log_section(text: String, tiles: Array, big: bool) -> void:
	var head := _label(72 if big else 34, Color(0.7, 1.0, 0.72))
	head.text = text
	_log_list.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3 if big else 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_log_list.add_child(grid)
	for tile: Array in tiles:
		var known: bool = tile[2]
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(0, 150 if big else 76)
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.1, 0.25, 0.14, 0.85) if known else Color(0.06, 0.09, 0.08, 0.7)
		frame.border_color = Color(0.55, 1.0, 0.6) if known else Color(0.25, 0.35, 0.3)
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(8)
		frame.set_content_margin_all(8)
		cell.add_theme_stylebox_override("panel", frame)
		var l := _label((46 if big else 20) if known else (70 if big else 30), Color(0.9, 0.95, 0.88) if known else Color(0.35, 0.45, 0.4))
		l.text = ("%s\n%s" % [tile[0], tile[1]]).strip_edges() if known else "?"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(l)
		grid.add_child(cell)


## Whether this is the web build playing inside the arcade's frame
func _in_arcade() -> bool:
	return OS.has_feature("web") and bool(JavaScriptBridge.eval("window.parent !== window", true))


## The arcade's leaderboard for this game (it opens it when it hears OPEN_LEADERBOARD)
func open_scores() -> void:
	JavaScriptBridge.eval("window.parent.postMessage({type: 'OPEN_LEADERBOARD'}, '*')", true)


## Back to the arcade (it closes the game when it hears QUIT_GAME), or off the web, out
func quit_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({type: 'QUIT_GAME'}, '*')", true)
	elif not testing:
		get_tree().quit()


## Further up and back for a ship that flies higher
func _camera_offset() -> Vector3:
	# (on a wide screen, lower and further back, looking out more than down, for the curve of the
	# world and the night sky over it to show at the top of the picture)
	var from := camera_offset if _upright() or camera_offset != CAMERA_OFFSET else WIDE_OFFSET
	return from + Vector3(0, 1.3, 0.5) * (ufo.altitude - 8.0)


func _camera(delta: float) -> void:
	if hold_camera:
		return
	if _warm_frames > 0:
		_warm_camera()
		return
	if mode in ["title", "launch", "landing"]:
		_moon_camera(delta)
		return
	var focus := Vector3(ufo.position.x, 0.0, ufo.position.z)
	if ufo.crashed or ufo.dead:
		focus = Vector3(ufo.position.x, 0.0, ufo.position.z)
	if intro > 0.0 and (mode == "play" or mode == "return"):
		_intro_camera()
		return
	_sky_mat.set_shader_parameter("space", 0.0)
	camera.environment.fog_density = 0.006
	camera.fov = _fov()
	var goal := focus + _camera_offset()
	if mode == "title":
		goal = focus + Vector3(0, 11.0, 15.0)
	camera.position = camera.position.lerp(goal, minf(delta * 4.0, 1.0)) if camera.position != Vector3.ZERO else goal
	# (looking at the ground under the ship, where the beam will fall and the reticle shows, the ship
	# itself a little above the middle of the picture)
	var look_at_point := camera.position - _camera_offset()
	if not _upright():
		# (a wide screen's lower camera looks partway up to the ship, for it not to sit up under the
		# score)
		look_at_point.y += ufo.altitude * 0.45
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

	# Top left: the shield (and the dodge's three arrows beside it), and the radar under it
	shield_bar = Shield.new()
	shield_bar.main = self
	shield_bar.position = Vector2(6, 6)
	shield_bar.scale = Vector2.ONE * 1.4
	shield_bar.size = Vector2(200, 112)
	shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shield_bar)
	radar = Radar.new()
	radar.main = self
	# (the same width as the shield glass, 104 x 1.4, and lined up under it)
	radar.position = Vector2(6, 164)
	radar.size = Vector2(146, 146)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radar)

	# Top right, beside the pause button: the score (its coin before it) and the multiplier under it
	score_label = _label(54, Color(0.75, 1.0, 0.78))
	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.position = Vector2(-96 - SCORE_WIDTH, 10)
	score_label.size = Vector2(SCORE_WIDTH, 66)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_glow(score_label, Color(0.3, 1.0, 0.45, 0.55))
	root.add_child(score_label)
	mult_label = _label(32, Color(0.6, 1.0, 0.6))
	mult_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mult_label.position = Vector2(-96 - SCORE_WIDTH, 72)
	mult_label.size = Vector2(SCORE_WIDTH, 40)
	mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(mult_label)
	# (and under them, everything taken, typed out: see `log_line`)
	log_box = VBoxContainer.new()
	log_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	log_box.position = Vector2(-20 - LOG_WIDTH, 118)
	log_box.custom_minimum_size = Vector2(LOG_WIDTH, 0)
	log_box.add_theme_constant_override("separation", 2)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_box)
	_sparks = ScoreSparks.new()
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_sparks)
	coin = Coin.new()
	coin.font = font
	coin.main = self
	coin.size = Vector2(146, 146)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coin)

	stars = Stars.new()
	stars.main = self
	stars.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stars.position = Vector2(-150, 14)
	stars.size = Vector2(300, 64)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stars)

	# (the heat's news, just under the stars: the farmers armed, the police coming, spotted...)
	heat_note = _label(28, Color(1.0, 0.6, 0.4))
	heat_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heat_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heat_note.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heat_note.position = Vector2(-260, 80)
	heat_note.size = Vector2(520, 40)
	_glow(heat_note, Color(1.0, 0.4, 0.2, 0.45))
	root.add_child(heat_note)

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

	# The title: only the name, the ship (with arrows) and PLAY; laid out for the screen's shape by
	# `_layout_title`
	title_box = _panel(root)
	_title_label = _label(84, Color(0.7, 1.0, 0.72))
	_title_label.text = "CLOSE ENCOUNTERS"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# (glowing: a soft green halo for its outline instead of black, and a wider, fainter one round
	# that; sized with the text in `_layout_title`)
	_title_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.86))
	_title_label.add_theme_color_override("font_outline_color", Color(0.3, 1.0, 0.45, 0.55))
	_glow(_title_label, Color(0.25, 1.0, 0.4, 0.3))
	# (blooming: the glow breathing and a band of light sweeping across it, see title.gdshader)
	var bloom := ShaderMaterial.new()
	bloom.shader = load("res://shaders/title.gdshader")
	_title_label.material = bloom
	title_box.add_child(_title_label)
	_title_gap = Control.new()
	_title_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(_title_gap)
	# (the ship's name, then the arrows to pick another either side of PLAY, then a little lower the
	# LOG (and the arcade's) buttons)
	ship_label = _label(34, Color(0.75, 1.0, 0.78))
	ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_box.add_child(ship_label)
	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 16)
	_arrows = [_button("<", func() -> void: _pick_ship(-1)), _button(">", func() -> void: _pick_ship(1))]
	_play_button = _button("PLAY", begin_launch)
	picker.add_child(_arrows[0])
	picker.add_child(_play_button)
	picker.add_child(_arrows[1])
	title_box.add_child(picker)
	_title_drop = Control.new()
	_title_drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(_title_drop)
	_title_row = HBoxContainer.new()
	_title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_row.add_theme_constant_override("separation", 20)
	_title_row.add_child(_button("LOG", open_log))
	# (the scores and QUIT are the arcade's: only inside it, or for QUIT, off the web)
	if _in_arcade():
		_title_row.add_child(_button("SCORES", open_scores))
	if _in_arcade() or not OS.has_feature("web"):
		_title_row.add_child(_button("QUIT", quit_game))
	title_box.add_child(_title_row)
	# The level-up picker: the level, and three upgrades to choose between (see `_level_up`)
	# (the game dimmed behind it, for the choices to read)
	_picker_dim = ColorRect.new()
	_picker_dim.color = Color(0, 0, 0, 0.55)
	_picker_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker_dim.visible = false
	root.add_child(_picker_dim)
	_picker = _panel(root)
	# (centred both ways whatever its size, and narrow enough for an upright phone)
	_picker.custom_minimum_size = Vector2(660, 0)
	_picker.offset_left = 0.0
	_picker.offset_right = 0.0
	_picker.offset_top = 0.0
	_picker.offset_bottom = 0.0
	_picker.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_picker.grow_vertical = Control.GROW_DIRECTION_BOTH
	_picker.visible = false
	if _picker_dim != null:
		_picker_dim.visible = false
	_picker_title = _label(56, Color(0.75, 1.0, 0.78))
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glow(_picker_title, Color(0.3, 1.0, 0.45, 0.55))
	_picker.add_child(_picker_title)
	var pick_one := _label(26, Color(0.6, 1.0, 0.65))
	pick_one.text = "PICK AN UPGRADE"
	pick_one.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker.add_child(pick_one)
	_picks = VBoxContainer.new()
	_picks.add_theme_constant_override("separation", 14)
	_picks.alignment = BoxContainer.ALIGNMENT_CENTER
	_picker.add_child(_picks)
	_build_log(root)


	# A pause button in the corner, and what pausing shows

	_pause_button = _button("", func() -> void: set_paused(true))
	# (two bars drawn in the middle of it, a pause sign, not the letters II)
	var bars := PauseBars.new()
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_button.add_child(bars)
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
	# (it grows upward from just above the middle of the screen, so it sits over the wreck, not on it)
	over_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	over_label = _label(34, Color(0.55, 1.0, 0.62))
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glow(over_label, Color(0.25, 1.0, 0.4, 0.5))
	over_box.add_child(over_label)
	_again = _button("OK", func() -> void:
		if _over_wait <= 0.0:
			quit_to_menu())
	over_box.add_child(_again)
	over_box.visible = false

	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cover)


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


## On the moon, on its legs, turned to the camera, the canopy open and the pilot lounging on top
## (or, not `lounging`, flying in to land there: see `_going_home`)
func _park_ufo(lounging := true) -> void:
	ufo.parked = true
	ufo.position = MoonSet.SITE + MoonSet.SHIP_AT
	ufo.rotation.y = MoonSet.SHIP_TURN
	# (a ship that points where it flies is parked at an angle, to show its length, nose off away
	# from the title)
	if not ufo._spins:
		ufo.hull_model.rotation.y = -PI / 4.0
	if lounging:
		ufo.lounge(true)
	else:
		ufo._legs.visible = false
	# (the cooler and the radio back where they stood, if a launch blew them away)
	moon_set.tidy()


## Play pressed on the title: the pilot drops in, the canopy shuts, the ship lifts off and flies
## away into space, and the run starts with it coming down from space (see `_launch`)
func begin_launch() -> void:
	if mode != "title" or not ship in unlocked:
		return
	mode = "launch"
	_new_world(false)
	_launch_t = 0.0
	title_box.visible = false
	ufo.lounge(false)
	sfx.play("whoosh", 1.4)


## The flight off the moon (or, `landing`, the same backwards: coming home to it, see
## `quit_to_menu`)
func _launch(delta: float) -> void:
	var back := mode == "landing"
	_launch_t += -delta if back else delta
	var site := MoonSet.SITE + MoonSet.SHIP_AT
	if not back and _launch_t >= BLAST and _launch_t - delta < BLAST:
		# (the engine at full: the chair, the cooler and the radio blown away in a cloud of dust)
		ufo.alien.feel("cheer", 1.0)
		moon_set.blast(ufo.leave_chair())
		sfx.play("whoosh", 0.7, 2.0)
	if not back and _launch_t >= ENGINE and _launch_t - delta < ENGINE:
		sfx.play("bloop", 0.6)
	if _launch_t < ENGINE:
		if back:
			_home()
		return
	# The engine starting up: the ship humming and shaking on its legs, harder and harder, until it
	# lifts
	var shake := smoothstep(ENGINE, LIFT, _launch_t) * (1.0 - smoothstep(LIFT, LIFT + 0.8, _launch_t)) * 0.07
	var rise := 0.0
	if _launch_t > LIFT:
		# then up off the moon, slowly at first, up to speed and slowing to a stop at the top (where
		# the descent starts from) once the moon and Earth have sunk out of the bottom of the picture
		var u := clampf((_launch_t - LIFT) / (LAUNCH - LIFT), 0.0, 1.0)
		rise = CLIMB * u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
	ufo.position = site + Vector3(randf_range(-1, 1) * shake, rise + absf(randf_range(-1, 1)) * shake, randf_range(-1, 1) * shake)
	ufo._legs.visible = _launch_t < LIFT + 0.5
	# (the pilot turned to face the camera as it swings round behind the ship, see `_moon_camera`)
	ufo.rotation.y = lerp_angle(MoonSet.SHIP_TURN, _facing(_away()), smoothstep(LIFT - 0.2, LIFT + 1.6, _launch_t))
	dust.fade = smoothstep(LIFT + 0.5, LIFT + 1.4, _launch_t)
	ufo.hull_model.rotation.y += delta * 6.0 * smoothstep(ENGINE, LIFT + 1.0, _launch_t)
	if not back and _launch_t >= LAUNCH:
		start(true)


## QUIT TO MENU: the run given up (no score is sent), and the ship flies home: up off the farm into
## the stars (the descent backwards, see `_going_home`), then down onto the moon (the flight off it
## backwards), and the pilot back in the chair on the title
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
	_clear_fleet()
	heat = 0.0
	score = 0
	intro = 0.0
	_banner("", 0.0)
	if testing and not intro_in_tests:
		_clear_wreck()
		_show_title()
		return
	if ufo.dead:
		# (from a wreck: the camera pulls up away from the crash site, out into space, and on to the
		# moon, where a new ship comes in to land; the wreck stays lying where it is till then)
		_wreck_ship = ufo
		over_box.visible = false
		_make_ufo(Vector3(wreck.x, _wreck_ship.altitude, wreck.z))
		ufo.visible = false
		ufo.bubble_fade = 0.0
	mode = "return"
	_return_t = 0.0
	ufo.velocity = Vector3.ZERO
	sfx.play("whoosh", 1.4)


## Up off the farm into the stars, the camera swinging round behind the ship as the descent's does,
## backwards; then on to the moon, coming down onto it
func _going_home(delta: float) -> void:
	_return_t += delta
	var k := 1.0 - smoothstep(0.0, 1.0, _return_t / RETURN_UP)
	intro = maxf(INTRO * (1.0 - k), 0.001)
	_descend(k)
	ufo.hull_model.rotation.y += delta * 6.0 * (1.0 - k) * (1.0 - k)
	if _return_t < RETURN_UP:
		return
	intro = 0.0
	dust.fade = 0.0
	ufo.queue_free()
	_make_ufo(Vector3.ZERO)
	_park_ufo(false)
	_clear_wreck()
	mode = "landing"
	_launch_t = LAUNCH


## Down on the moon again: on its legs, the canopy opening and the pilot climbing out and back up
## into the chair
func _home() -> void:
	mode = "title"
	ufo.position = MoonSet.SITE + MoonSet.SHIP_AT
	ufo.rotation.y = MoonSet.SHIP_TURN
	ufo._legs.visible = true
	ufo.climb_out()
	_show_ship()
	title_box.visible = true
	over_box.visible = false
	_save_best()


## The turn that faces the pilot (who looks along the ship's +z) back up `way`, at the camera behind
func _facing(way: Vector3) -> float:
	return atan2(-way.x, -way.z)


## The way the camera looks over the ship from lift-off until the descent is well under way: the
## way the title's camera looks, made level, so that the ship's climb sinks the moon and Earth out of
## the bottom of the picture and leaves only stars
func _away() -> Vector3:
	var way := Vector3(4.05, 0, -9.1) if not _upright() else Vector3(6.02, 0, -7.99)
	return way.normalized()


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
		ship_label.text = spec["title"]
		_play_button.text = "PLAY"
		_play_button.disabled = false
	else:
		ship_label.text = spec["title"]
		_play_button.text = "LOCKED"
		_play_button.disabled = true


func _show_title() -> void:
	mode = "title"
	alien_seed = randi()
	ufo.queue_free()
	_clear_wreck()
	_make_ufo(Vector3.ZERO)
	_park_ufo()
	_show_ship()
	title_box.visible = true
	over_box.visible = false
	# (what the last run added to the log, kept)
	_save_best()


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


## Forgets every finger (a run starting or ending, or the game pausing)
func _forget_fingers() -> void:
	stick_finger = NO_FINGER
	beam_finger = NO_FINGER
	stick = Vector2.ZERO
	_touch_from.clear()
	_mouse_down = []
	_touch_frame_seen = true


func set_paused(on: bool) -> void:
	if mode != "play" or (_picker != null and _picker.visible):
		return
	get_tree().paused = on
	_pause_box.visible = on
	if on:
		_resume_button.call_deferred("grab_focus")
		_forget_fingers()


## An announcement: never in the middle of the screen, always the line under the stars ("" clears it)
func _banner(text: String, seconds: float) -> void:
	_heat_note(text, seconds)


## A line of the heat's news under the stars, for `seconds`
func _heat_note(text: String, seconds: float) -> void:
	heat_note.text = text
	heat_note_time = seconds


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
	score_label.text = "$%d" % score
	mult_label.text = "x%d" % multiplier()
	# (the score bouncing, swelling and settling, when something is swallowed)
	_score_pop = maxf(_score_pop - get_process_delta_time() * 2.5, 0.0)
	var t := 1.0 - _score_pop
	score_label.pivot_offset = Vector2(score_label.size.x, score_label.size.y * 0.5)
	score_label.scale = Vector2.ONE * (1.0 + sin(t * 9.0) * exp(-4.0 * t) * 0.35 * float(_score_pop > 0.0))
	# (the level orb just before the cash, however long it has grown, and level with it)
	var width := font.get_string_size(score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
	coin.position = Vector2(score_label.position.x + score_label.size.x - width - 156.0, 6.0)
	coin.queue_redraw()
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
	heat_note.visible = playing
	if heat_note_time > 0.0:
		heat_note_time -= delta
		heat_note.modulate.a = clampf(heat_note_time * 2.0, 0.0, 1.0)
	else:
		heat_note.text = ""


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




## Where the beam is aimed (see Ufo.beam_aim): the beam thumb dragged from where it came down, a
## fifth of the screen's short side for the beam's full lean; straight down with no thumb on it
func _beam_aim() -> Vector2:
	if beam_finger == NO_FINGER or _beam_at == Vector2.INF:
		_beam_from = Vector2.INF
		return Vector2.ZERO
	if _beam_from == Vector2.INF:
		_beam_from = _beam_at
	var size := get_viewport().get_visible_rect().size
	return ((_beam_at - _beam_from) / (minf(size.x, size.y) * 0.2)).limit_length(1.0)
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
		_beam_at = Vector2.INF
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
		_log_taken = cfg.get_value("log", "taken", {})
		for met: String in cfg.get_value("log", "met", []):
			if HUNTERS.has(met) and not met in _log_met:
				_log_met.append(met)

func _save_best() -> void:
	if testing:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("best", "score", best)
	cfg.set_value("best", "ship", ship)
	cfg.set_value("best", "unlocked", unlocked)
	cfg.set_value("log", "taken", _log_taken)
	cfg.set_value("log", "met", _log_met)
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
		elif t.kind == "rival" and t.ground().distance_to(here) < Radar.RANGE:
			marks.append([t.ground(), Color(1.0, 0.4, 0.9), 5.0])
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


## The level orb, left of the cash: a glass ball filling with little balls as the score climbs toward
## the next level-up, one ball at a time from the bottom (the level it is working toward faint in the
## glass), the same size as the shield's. Five quick
## taps on it turn the touch readout on (see _input)
class Coin extends Control:
	const BALLS := 30
	## (the same size as the shield's glass: 52 across scaled 1.4)
	const R := 64.0
	const BALL := 8.5
	var font: Font
	var main: Node
	## Where each ball sits in the glass, the lowest first
	var _slots: Array[Vector2] = []
	var _shown := 0.0

	func _ready() -> void:
		var step := BALL * 2.05
		var row := 0
		var y := R - BALL - 1.0
		while y > -R + BALL and _slots.size() < BALLS:
			var half := sqrt(maxf((R - BALL - 1.0) ** 2 - y * y, 0.0))
			var x := -half + fmod(row * step * 0.5, step)
			while x <= half and _slots.size() < BALLS:
				_slots.append(Vector2(x, y))
				x += step
			y -= step * 0.87
			row += 1

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var c := size * 0.5
		var lv: int = main.level
		var from: int = main.level_at(lv)
		var to: int = main.level_at(lv + 1)
		var fill := clampf(float(main.score - from) / maxf(to - from, 1), 0.0, 1.0)
		_shown = lerpf(_shown, fill, 0.15)
		draw_circle(c, R + 8.0, Color(0.6, 1.0, 0.7, 0.18))
		draw_circle(c, R, Color(0.02, 0.08, 0.04, 0.8))
		# (the level it is working toward, faint in the glass behind the balls)
		draw_string(font, Vector2(0, c.y + 10.0), "LV %d" % (lv + 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.75, 1.0, 0.78, 0.45))
		var n := int(_shown * BALLS + 0.001)
		for i in mini(n, _slots.size()):
			var s: Vector2 = _slots[i] + Vector2(0, sin(t * 3.0 + i * 1.3) * 0.6)
			draw_circle(c + s, BALL, Color(1.0, 0.85, 0.3))
			draw_circle(c + s + Vector2(-BALL * 0.3, -BALL * 0.3), BALL * 0.35, Color(1.0, 1.0, 0.85, 0.8))
		draw_arc(c, R, 0, TAU, 56, Color(0.6, 1.0, 0.7, 0.9), 4.0)
		draw_arc(c + Vector2(-R * 0.3, -R * 0.35), R * 0.45, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.5), 4.0)


## The shield: a glass orb of blue energy, its level the shield left, sloshing; beside it three
## arrows that light up one by one as the dodge recharges (one dash each)
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
		# three arrows, one for each dash ready: lit green once charged, filling as it charges
		var ready: float = main.ufo.dodge_ready()
		for i in 3:
			var ax := c.x + r + 18.0 + i * 26.0
			var ay := c.y + r * 0.45
			var fill := clampf(ready * 3.0 - i, 0.0, 1.0)
			var tip := [Vector2(ax, ay - 16), Vector2(ax + 16, ay), Vector2(ax, ay + 16), Vector2(ax + 7, ay + 16), Vector2(ax + 23, ay), Vector2(ax + 7, ay - 16)]
			var lit := Color(0.45, 1.0, 0.55) if fill >= 1.0 else Color(0.25, 0.3, 0.28).lerp(Color(0.35, 0.6, 0.4), fill)
			if fill >= 1.0:
				draw_colored_polygon(PackedVector2Array([tip[0], tip[5], tip[4], tip[1]]), lit)
				draw_colored_polygon(PackedVector2Array([tip[1], tip[4], tip[3], tip[2]]), lit)
			draw_polyline(PackedVector2Array(tip + [tip[0]]), Color(0.75, 1.0, 0.78) if fill >= 1.0 else lit, 2.0)


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


## The pause sign on the pause button: two upright bars, in the middle of it
class PauseBars extends Control:
	func _draw() -> void:
		var bar := Vector2(size.x * 0.13, size.y * 0.44)
		var gap := size.x * 0.12
		var c := size * 0.5
		for side: float in [-1.0, 1.0]:
			var x := c.x + side * (gap * 0.5 + bar.x * 0.5) - bar.x * 0.5
			draw_rect(Rect2(x, c.y - bar.y * 0.5, bar.x, bar.y), Color(0.75, 1.0, 0.78))


## Sparkles bursting off the score when something is swallowed (see `abducted`)
class ScoreSparks extends Control:
	## Each: [where, velocity, age]
	var sparks: Array = []

	func burst(at: Vector2, count: int) -> void:
		for i in count:
			var a := randf_range(PI * 0.6, PI * 2.1)
			sparks.append([at, Vector2(cos(a), sin(a)) * randf_range(80.0, 220.0), 0.0])

	func _process(delta: float) -> void:
		for s: Array in sparks:
			s[2] += delta
			s[1] = (s[1] as Vector2) * (1.0 - minf(delta * 2.5, 1.0)) + Vector2(0, 160.0 * delta)
			s[0] = (s[0] as Vector2) + (s[1] as Vector2) * delta
		sparks = sparks.filter(func(s: Array) -> bool: return s[2] < 0.7)
		queue_redraw()

	func _draw() -> void:
		for s: Array in sparks:
			var k: float = 1.0 - s[2] / 0.7
			draw_circle(s[0], 3.0 + 3.0 * k, Color(0.6, 1.0, 0.65, k))
