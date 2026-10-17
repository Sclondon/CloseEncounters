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
	{"police_car": 2, "moto_cop": 1},
	{"helicopter": 1, "police_car": 2, "agent_car": 1, "moto_cop": 1},
	{"chinook": 1, "jeep": 2, "police_car": 1},
	{"chinook": 1, "tank": 2, "jeep": 2},
]
## How long after a new star the heat goes up only slowly (see `add_heat`)
const NEW_STAR := 8.0
var _new_star := 0.0
## How many of each thing the farm keeps about (taken ones are replaced, somewhere else)
const CAMERA_OFFSET := Vector3(0, 20.5, 24.5)
const WIDE_OFFSET := Vector3(0, 14.5, 30.0)
## (tests try others)
var camera_offset := CAMERA_OFFSET
## Each run opens with the ship coming down from space: this long, from this high
const INTRO := 4.5
const INTRO_HEIGHT := 320.0

@export var start_mode := "title"
var autopilot := false
## The strongest things the autopilot goes for (tests/balance.gd lets it take whatever the beam can)
var pilot_tier := 1
## The dev room (`?dev` on the address): every ship unlocked to try, scores not reported or kept
var dev := false
var _kept_unlocked: Array[String] = []
var _dev_typed := ""
var _dev_taps := 0
var _dev_tapped := 0.0
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
## The threat levels, by `_threat` (how seriously they take the ship), for the results
const THREATS := ["LOW", "GUARDED", "ELEVATED", "HIGH", "SEVERE"]
var _last_call := -100.0
var _patrol_wait := 1.0
var _pull_wait := 0.0
var _spark_wait := 0.0
var _circle_at := Vector3.INF
var _circle_time := 0.0
var _circle_done := false
## The traders parked about the country, and what has been bought from them this run
var shops: Array[Shop] = []
var upgrades := {"engine": 0, "beam": 0, "shield": 0, "dash": 0, "laser": 0, "turret": 0, "missiles": 0, "cloak": 0, "magnet": 0, "wide": 0, "scanner": 0, "jammer": 0, "coolant": 0, "nanobots": 0, "gold": 0, "emp": 0, "lucky": 0, "armor": 0, "second_wind": 0, "swivel": 0, "starbits": 0, "sling": 0, "fleet": 0}
var _hot_wait := 0.0
## The level reached this run (see `_levels`), levels still to pick for, and the picker
var level := 0
var _levels_due := 0
var _picker: VBoxContainer
var _picker_dim: ColorRect
var _picker_title: Label
var _picks: VBoxContainer
var _pick_one: Label
## The Moon Market's trading saucer, while the market is open (see MarketShip)
var _market: MarketShip
## Things the world has asked for, waiting to be put down: [kind, where, extra]
var _to_spawn: Array = []
const SPAWN_A_FRAME := 6
## What traders sell, one pod each: three of these are set out in front of each trader
## The beam's colours as BEAM items stack: green, blue, purple
const BEAM_COLOURS := [Color(0.55, 1.0, 0.65), Color(0.4, 0.7, 1.0), Color(0.78, 0.45, 1.0)]
const GOODS: Array[String] = ["engine", "beam", "shield", "dash", "patch", "laser", "turret", "missiles", "cloak", "magnet", "wide", "scanner", "jammer", "coolant", "nanobots", "gold", "emp", "lucky", "armor", "second_wind", "swivel", "starbits", "sling", "fleet"]
const UPGRADES := {
	"engine": {"title": "ENGINE", "about": "faster", "price": 300, "colour": Color(1.0, 0.55, 0.15)},
	"beam": {"title": "BEAM", "about": "lifts faster, then heavier things", "price": 400, "colour": Color(0.4, 1.0, 0.5)},
	"shield": {"title": "SHIELD", "about": "more shield", "price": 300, "colour": Color(0.3, 0.6, 1.0)},
	"patch": {"title": "PATCH", "about": "shield refilled", "price": 0, "colour": Color(0.4, 1.0, 1.0)},
	"dash": {"title": "DASH", "about": "an extra dash charge", "price": 250, "colour": Color(0.75, 0.4, 1.0)},
	"laser": {"title": "LASER", "about": "a ray that burns things down", "price": 500, "colour": Color(1.0, 0.3, 0.45)},
	"turret": {"title": "AUTO TURRET", "about": "shoots by itself", "price": 500, "colour": Color(1.0, 0.5, 0.3)},
	"missiles": {"title": "MISSILES", "about": "homing missiles, from the fleet too", "price": 600, "colour": Color(1.0, 0.75, 0.25)},
	"cloak": {"title": "CLOAK", "about": "vanish for a few seconds", "price": 550, "colour": Color(0.6, 0.6, 1.0)},
	"magnet": {"title": "MAGNET", "about": "small things drift to the beam", "price": 400, "colour": Color(0.9, 0.3, 0.3)},
	"wide": {"title": "WIDE BEAM", "about": "a broader beam", "price": 400, "colour": Color(0.5, 1.0, 0.8)},
	"scanner": {"title": "SCANNER", "about": "the radar sees further", "price": 300, "colour": Color(0.3, 0.9, 0.6)},
	"jammer": {"title": "JAMMER", "about": "they stop looking sooner", "price": 450, "colour": Color(0.9, 0.85, 0.3)},
	"coolant": {"title": "COOLANT", "about": "the heat cools quicker", "price": 450, "colour": Color(0.6, 1.0, 0.98)},
	"nanobots": {"title": "NANOBOTS", "about": "the shield mends itself", "price": 450, "colour": Color(0.4, 0.75, 1.0)},
	"gold": {"title": "GOLD", "about": "everything taken is worth more", "price": 500, "colour": Color(1.0, 0.82, 0.25)},
	"emp": {"title": "EMP", "about": "a dash stuns the police near; bigger each, and paralyses people too from the second", "price": 450, "colour": Color(0.55, 0.85, 1.0)},
	"lucky": {"title": "LUCKY CHARM", "about": "power-ups turn up more often", "price": 300, "colour": Color(0.35, 0.95, 0.4)},
	"armor": {"title": "ARMOR", "about": "the ship takes less damage", "price": 450, "colour": Color(0.7, 0.72, 0.78)},
	"swivel": {"title": "SWIVEL MOUNT", "about": "lean the beam out further", "price": 350, "colour": Color(0.55, 0.95, 1.0)},
	"starbits": {"title": "STAR BIT BLASTER", "about": "sprays star bits by itself: fast, wild, weak", "price": 500, "colour": Color(1.0, 0.75, 0.95)},
	"sling": {"title": "GRAVITY SLING", "about": "now and then flings a meteor down on the police: a big splash", "price": 700, "colour": Color(1.0, 0.55, 0.2)},
	"second_wind": {"title": "SECOND WIND", "about": "shrug off one fatal hit", "price": 600, "colour": Color(1.0, 0.55, 0.25)},
	"fleet": {"title": "FLEET", "about": "a little helper saucer", "price": 450, "colour": Color(1.0, 0.9, 0.3)},
}
## Upgrades are items that stack, as in Risk of Rain: each pick one more of it, up to this many
const MAX_UPGRADE := 10
## The most little saucers the fleet stacks to (more stacks after that make them keener, see Drone)
const FLEET_MOST := 6
## The defence laser (see `_laser`): how far it reaches before upgrades (+2 m a level), and the hits
## that blow each of the police and army up (one less is only a moment's stun)
const LASER_REACH := 7.0
const LASER_HITS := {"police_car": 2, "patrol_car": 2, "jeep": 3, "patrol_jeep": 3, "tank": 5, "helicopter": 4, "chinook": 6, "agent_car": 3, "moto_cop": 1, "helicarrier": 14, "railgun": 5, "laser_truck": 4}
var _laser_wait := 0.0
## The mini fleet: a little saucer for each level of FLEET (see Drone)
var fleet: Array[Drone] = []
## Where phone lines have been cut this run (a call near one cannot get through)
var _cuts: Array[Vector3] = []
const LINE_REACH := 150.0
var _spotted_for := 0.0
## Something has the ship in sight (a searchlight on it, a dish tracking it): seconds this stays
## true, and where the last to see it is (the HUD's eye, see `Eye`). While it lasts the heat cools
## only at SEEN_COOL of its rate
var seen := 0.0
var seen_from := Vector3.INF
const SEEN_COOL := 0.35
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
## Co-op: how long a downed ship waits on the ground for a friend to beam it up (-1 before it is down)
const RESCUE_WAIT := 20.0
## Where lengths of the railway have been beamed away (a train coming to one comes off the rails)
var torn_track: Array[Vector3] = []
## Where hydrants have been knocked off, each a fountain of water ever after (see `_geysering`)
var geysers: Array[Vector3] = []
var _geyser_wait := 0.0
var _rescue_wait := -1.0
var _hurt := 0.0
var _over_wait := 0.0
var _last_level := 0
var _pilot_target: Thing
## How long it has been after its target (it gives up on one it cannot get, see `_pilot`), and the way
## it roams when there is nothing near worth taking
var _pilot_for := 0.0
var _pilot_roam := Vector2(0.6, -0.8)
var _pilot_roam_for := 0.0
var _pilot_wander := Vector3.ZERO

# The HUD
var hud: CanvasLayer
## The HUD's top control: drawn smaller on a desktop screen (see _fit)
var _hud_root: Control
## The log's little holograms of the models (see Holograms)
var holograms: Holograms
## Multiplayer: the room (Net), the other saucers (Coop), and the seed of the world shared in it
var net: Net
var coop: Coop
var coop_seed := 0
## Level-ups come with the score (off for the preview film)
var levels_on := true
## Where the moon is in the sky in a run (see _camera)
var _moon_dir := Vector3.ZERO
const DESKTOP_HUD := 0.78
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
var eye: Control
var shield_bar: Control
var heat_note: Label
var item_bar: Control
var dash_orb: Control
var threat_marks: Control
var heat_note_time := 0.0
var title_box: Control
var over_box: Control
var _again: Button
## OK and REPLAY under the results
var _over_row: HBoxContainer
var _replay_button: Button
## REPLAY pressed: the flight up off the wreck goes on into a new run, not home to the moon
var _replay := false
## The results typing out (see _wreck_burning)
var _over_typing := 0.0
## The wrecked ship left lying while the camera pulls away from it to the moon (see quit_to_menu)
var _wreck_ship: Ufo
## Going home from a wreck (no ship to follow on the way up: it lies wrecked)
var _from_wreck := false
const RESULTS_SPEED := 45.0
var over_label: Label
## The title screen's parts, laid out for the screen's shape (`_layout_title`)
var _title_label: Label
var _title_gap: Control
var _arrows: Array[Button] = []
var _title_row: HBoxContainer
## QUIT, on its own row under the title's other buttons
var _quit_row: HBoxContainer
## The gap above the title's second row of buttons
var _title_drop: Control
## The log (a field guide): every ship, every kind of thing there is to take (with how many of each
## have been taken, ever), and every kind of hunter met; filled in as they are, and kept with the best
var _log_box: Control
## The log's list, scrolled by a finger (see `_input`)
var _log_scroll: ScrollContainer
## The log tossed: how fast it was going as the finger let go, and whether it is still running on
var _log_speed := 0.0
var _log_flinging := false
var _log_dragged_at := 0.0
var _log_list: VBoxContainer
var _log_head: Label
var _log_back: Button
var _log_taken := {}
## This run's takings by kind: [how many, points], for the results (see _results)
var _run_taken := {}
## The police and army destroyed this run, by kind: {kind: how many}
var _run_killed := {}
var _log_met: Array[String] = []
## The items (upgrades) ever had, for the log
var _log_items: Array[String] = []
## The hunters, as the log names them (the jets are not things: they are only flown over)
const HUNTERS := {
	"police_car": "POLICE CAR", "patrol_car": "POLICE PATROL", "jeep": "ARMY JEEP",
	"patrol_jeep": "ARMY PATROL", "tank": "TANK", "jet": "FIGHTER JET", "officer": "POLICE OFFICER",
	"helicopter": "POLICE HELICOPTER", "agent_car": "MEN IN BLACK", "agent": "AGENT", "chinook": "ARMY CHINOOK",
	"moto_cop": "MOTORCYCLE COP", "helicarrier": "HELICARRIER", "railgun": "RAIL GUN", "laser_truck": "LASER TRUCK",
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
	net = Net.new()
	add_child(net)
	coop = Coop.new()
	coop.game = self
	coop.net = net
	add_child(coop)
	net.room_changed.connect(_show_lobby)
	net.started.connect(_coop_started)
	net.failed.connect(func(why: String) -> void: _lobby_say(why))
	net.closed.connect(_coop_closed)
	holograms = Holograms.new()
	for what: String in UPGRADES:
		holograms.item_colours[what] = (UPGRADES[what]["colour"] as Color).lerp(Color.WHITE, 0.2)
	add_child(holograms)
	_build_hud()
	_apply_options()
	if start_mode == "play":
		start()
	else:
		_show_title()
		if not testing:
			_boot_landing()
	get_viewport().size_changed.connect(_fit)
	_fit()


func _input_map() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
		"beam": [KEY_SPACE, KEY_J, KEY_Z], "dodge": [KEY_SHIFT, KEY_X, KEY_K], "laser": [KEY_L, KEY_TAB, KEY_C], "cloak": [KEY_V, KEY_Q], "start": [KEY_ENTER, KEY_SPACE], "pause": [KEY_ESCAPE, KEY_P],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k: int in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for pair: Array in [["beam", JOY_BUTTON_A], ["beam", JOY_BUTTON_RIGHT_SHOULDER], ["dodge", JOY_BUTTON_B], ["dodge", JOY_BUTTON_LEFT_SHOULDER], ["laser", JOY_BUTTON_Y], ["cloak", JOY_BUTTON_X], ["start", JOY_BUTTON_A], ["start", JOY_BUTTON_START], ["pause", JOY_BUTTON_START]]:
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
	_sky_mat.set_shader_parameter("moon_map", load("res://textures/moon_lroc.jpg"))
	_sky_mat.set_shader_parameter("star_map", load("res://textures/starmap_nasa.jpg"))
	_sky_mat.set_shader_parameter("bright_stars", _bright_stars())
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


## The picture is always PICTURES[picture] lines high (or wide, held upright), whatever the shape of the screen
func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	view.size = Vector2i((size * float(PICTURES[picture]) / minf(size.x, size.y)).round())
	# (an upright phone sees more of the world above and below, not less to the sides)
	camera.keep_aspect = Camera3D.KEEP_WIDTH if size.x < size.y else Camera3D.KEEP_HEIGHT
	camera.fov = _fov()
	# (on a big wide screen, a desktop's, the HUD is drawn smaller: sized for thumbs, it is too big
	# there; a phone on its side keeps it full size)
	var css := Vector2(DisplayServer.window_get_size()) / maxf(DisplayServer.screen_get_scale(), 1.0)
	var k := DESKTOP_HUD if size.x >= size.y and css.y >= 560.0 else 1.0
	if hud != null and _hud_root != null:
		hud.scale = Vector2(k, k)
		_hud_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hud_root.position = Vector2.ZERO
		_hud_root.size = size / k
	_layout_touch()
	_layout_title(size / k)
	if _sky_mat != null and ufo != null:
		_hang_sky()


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
	boosts.clear()
	_boost_wait = 20.0
	coop.clear()
	_run_taken.clear()
	_run_killed.clear()
	laser_mode = false
	_five_for = 0.0
	_nuke_wait = 0.0
	for n: Array in _nukes:
		(n[2] as Node3D).queue_free()
		if n[3] != null:
			(n[3] as Node3D).queue_free()
	_nukes.clear()
	for o: Array in _orbitals:
		(o[2] as Node).queue_free()
	_orbitals.clear()
	for m: Array in _missiles:
		(m[0] as Node).queue_free()
	_missiles.clear()
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
	upgrades = {"engine": 0, "beam": 0, "shield": 0, "dash": 0, "laser": 0, "turret": 0, "missiles": 0, "cloak": 0, "magnet": 0, "wide": 0, "scanner": 0, "jammer": 0, "coolant": 0, "nanobots": 0, "gold": 0, "emp": 0, "lucky": 0, "armor": 0, "second_wind": 0, "swivel": 0, "starbits": 0, "sling": 0, "fleet": 0}
	level = 0
	_levels_due = 0
	_rescue_wait = -1.0
	torn_track.clear()
	geysers.clear()
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
	seen = 0.0
	seen_from = Vector3.INF
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
	# (a run flown home from, carried on with: its score, level, items and what it had taken)
	if from_launch and not _saved_run.is_empty() and _saved_run.get("ship", "") == ship and not coop.active():
		score = int(_saved_run["score"])
		level = int(_saved_run["level"])
		_threat = int(_saved_run.get("threat", 0))
		for what: String in (_saved_run["upgrades"] as Dictionary):
			if upgrades.has(what):
				upgrades[what] = int(_saved_run["upgrades"][what])
		_run_taken = (_saved_run["taken"] as Dictionary).duplicate(true)
		_run_killed = (_saved_run["killed"] as Dictionary).duplicate()
		_apply_upgrades()
		ufo.second_winds = upgrades["second_wind"]
		_saved_run = {}
		_save_best()
		_heat_note("RUN CONTINUED", 2.5)


## A run flown home from (TO THE MOON from the pause), kept to carry on with from the title: its ship,
## score, level, items and what it had taken (see `quit_to_menu` and `start`)
var _saved_run := {}



## A new country for a new run (not in the tests, which want the same one each time): everything
## made so far forgotten, and the world made again round where the run starts. `now` makes it all at
## once; otherwise a chunk a frame, as on the way down from the moon.
func _new_world(now: bool) -> void:
	if testing and coop_seed == 0:
		return
	_to_spawn.clear()
	for t in things.duplicate():
		if t.state != "walk" and not t.is_enemy():
			_remove(t)
	# (in a multiplayer game, the country everyone shares: the seed the leader started with)
	world.reseed(coop_seed if coop_seed != 0 else randi_range(1, 1 << 30))
	_facility_wait = 0.0
	if now:
		world.update(World.START, 0.0, true)

## Coming down from space, `k` of the way (0 to 1): out of the stars until the planet is under the
## ship, the shield coming up on the way, the pilot facing the camera as it swings round (see
## `_intro_camera`) and the dust streaming past (see Dust)
## After REPLAY: the new ship comes down into the picture from above it, this long, and how much of
## that is left; `_arrive` is how far above its place it still is
const ARRIVE := 1.4
const ARRIVE_FROM := 16.0
var _arrive_t := 0.0


func _arrive() -> float:
	var k := clampf(_arrive_t / ARRIVE, 0.0, 1.0)
	return ARRIVE_FROM * k * k


func _descend(k: float) -> void:
	# (slowly at first, from where the climb off the moon stopped, and slowing again to its height)
	ufo.descent = INTRO_HEIGHT * (1.0 - smoothstep(0.0, 1.0, k)) + _arrive()
	ufo.bubble_fade = smoothstep(0.4, 0.9, k)
	ufo.rotation.y = lerp_angle(_facing(_away()), 0.0, smoothstep(0.3, 1.0, k))
	dust.fade = 1.0 - smoothstep(0.4, 0.6, k)


## How seriously they take the ship, from its score: 1 at the start, 3 from DANGER_FULL points on.
## Everything that hunts it is that much keener (see where it is used)
const DANGER_FULL := 12000.0 * Thing.WORTH


func danger() -> float:
	return 1.0 + 2.0 * clampf(score / DANGER_FULL, 0.0, 1.0)


func heat_level() -> int:
	return mini(int(heat), int(MAX_HEAT))


func multiplier() -> int:
	return (1 + heat_level()) * (2 if boosts.has("double") else 1)


## The log, tossed, running on and slowing to a stop
func _fling_log(delta: float) -> void:
	if not _log_flinging or _log_scroll == null:
		return
	_log_scroll.scroll_vertical += int(_log_speed * delta)
	_log_speed *= exp(-2.6 * delta)
	if absf(_log_speed) < 30.0:
		_log_flinging = false


func _process(delta: float) -> void:
	_fling_log(delta)
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
		_arrive_t = maxf(_arrive_t - delta, 0.0)
		_descend(1.0 - intro / INTRO)
		ufo.hull_model.rotation.y += delta * 6.0 * pow(intro / INTRO, 2.0)
	elif mode == "play" and not autopilot:
		steer = _read_steer()
		beam = Input.is_action_pressed("beam") or beam_finger != NO_FINGER
		ufo.beam_aim = _beam_aim()
		if Input.is_action_just_pressed("cloak"):
			use_cloak()
		if Input.is_action_just_pressed("laser"):
			toggle_laser()
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
	# (switched over to the laser: the beam's button fires it instead)
	if laser_mode and upgrades["laser"] > 0:
		_cut(delta, beam and mode == "play")
		beam = false
	elif _cut_ray != null and _cut_ray.visible:
		_cut(delta, false)
	ufo.tick(delta, steer, beam)
	if is_instance_valid(_stand_in):
		# (the ship parked on the moon while the camera comes down onto it after a crash)
		_stand_in.tick(delta, Vector2.ZERO, false)
	if not ufo.dead:
		var held := ufo.position
		ufo.position = world.push_out(ufo.position, 2.6, ufo.altitude - 1.0)
		ufo.position.y = held.y
		if mode == "play" and ufo.position.distance_to(held) > 0.01:
			var was := ufo.hull
			ufo.bump(ufo.position - held)
			if ufo.hull < was:
				sfx.play("boom", 1.6)
				_shake = maxf(_shake, 0.5)
	# (NANOBOTS mend it always, a little, more the more stacked)
	ufo.mend_rate = (2.0 if heat_level() == 0 else 0.0) + 0.7 * upgrades["nanobots"]
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
					_heat_note(why_not(t), 2.5)
				continue
			if t.cash > 0.0 and t.state == "walk":
				_rob(t, delta)
				t.tick(delta, ufo)
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
					coop.tell("take", t.position, t.kind)
				t.state = "lifted"
				# (a building keeps how much of it is already gone: see Thing._dismantle)
				if not t.piecemeal():
					t.lift = clampf(t.position.y / (ufo.altitude - 0.9), 0.0, 1.0)
			t.held = true
		t.tick(delta, ufo)
	things = things.filter(func(t: Thing) -> bool: return t.state != "gone")
	_pull_scenery(delta)
	_beam_shadows()
	_shops(delta)
	_rivals(delta)
	_rival_hunt(delta)
	_rival_bumps()
	_nuking(delta)
	_surface_fx(delta)
	_launch_missiles(delta)
	_magnet(delta)
	_boosts(delta)
	_geysering(delta)
	_whirl(delta)
	_star_bits(delta)
	_sling(delta)
	_rocket_launches(delta)
	_trains(delta)
	_airliners(delta)
	_watchers(delta)
	_crop_circles(delta)
	for s in shots:
		s.tick(delta, ufo, self)
	_laser(delta)
	_cool_scorches(delta)
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
	_title_flicker(delta)
	if mode == "over":
		_wreck_burning(delta)
	if ufo.dead and mode == "play":
		_crash(delta)
	if mode == "over" and Input.is_action_just_pressed("start") and _over_wait <= 0.0 and _over_row.visible:
		quit_to_menu()
	if mode == "title" and Input.is_action_just_pressed("start"):
		_play_pressed()
	elif mode == "title" and Input.is_action_just_pressed("left"):
		_pick_mode(-1)
	elif mode == "title" and Input.is_action_just_pressed("right"):
		_pick_mode(1)
	if _over_wait > 0.0:
		_over_wait -= delta


## A dash out of the way of what is coming, if one is ready
func _dodge(way: Vector2) -> void:
	if ufo.dodge(way.normalized()):
		sfx.play("whoosh", 1.7, -2.0)
		_emp()
	elif not ufo.dead and mode == "play":
		# (no charge left: the engine fizzles, the ship shudders, smokes and spits sparks)
		_shake = maxf(_shake, 0.25)
		ufo._kick = 0.6
		sfx.play("static", 0.7, -6.0)
		for i in 3:
			ufo.puffs.puff(ufo.global_position + Vector3(randf_range(-1.5, 1.5), -0.3, randf_range(-1.5, 1.5)), Color(0.2, 0.2, 0.22, 0.7), randf_range(0.5, 0.8), Vector3(0, 1.8, 0), 0.9)
		for i in 6:
			ufo.puffs.spark(ufo.global_position + Vector3(0, -0.2, 0), Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-1, 1)) * randf_range(3.0, 5.0))


func _read_steer() -> Vector2:
	var v := Input.get_vector("left", "right", "up", "down")
	if stick_finger != NO_FINGER:
		v = stick
	return v.limit_length(1.0)



## Heat for something the ship did: less the more stars there already are (each takes more to earn
## than the last), and little for a while after a new star, so that each is a stage of its own
## rather than a rush from one to five
func add_heat(amount: float) -> void:
	# (a HEAT FREEZE: none of it while it lasts)
	if boosts.has("freeze"):
		return
	# (each star harder to reach than the last, steeply: five stars takes a long, hot run)
	var l := float(heat_level())
	var damp := 0.6 / (1.0 + 1.8 * l + 0.9 * l * l)
	if _new_star > 0.0:
		damp *= 0.25
	heat = minf(heat + amount * damp, MAX_HEAT)

func _heat(delta: float) -> void:
	_new_star = maxf(_new_star - delta, 0.0)
	calm += delta
	# (the more the ship has taken, the longer it takes them to give up looking)
	# (a JAMMER: they give up looking sooner, see `cooling`; COOLANT: the heat drains away quicker)
	var cool: float = (1.0 + 0.4 * upgrades["coolant"]) * (1.6 if hidden else 1.0)
	# (watched, it cools slowly: shake them off and it cools at the full rate)
	seen = maxf(seen - delta, 0.0)
	if seen > 0.0:
		cool *= SEEN_COOL
	if cooling():
		heat = maxf(heat - COOL_RATE * cool / danger() * delta, 0.0)
	var threat := int((danger() - 1.0) * 2.0)
	if threat > _threat:
		_threat = threat
		_heat_note("THREAT LEVEL RAISED: THEY ARE TAKING YOU SERIOUSLY", 2.5)
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


## Whether the heat is cooling now: long enough since the ship last did anything
func cooling() -> bool:
	var jam: float = 1.0 + 0.35 * upgrades["jammer"]
	return calm > COOL_AFTER * sqrt(danger()) / jam and heat > 0.0


## A searchlight locked on to the ship (once there is heat) keeps it in sight: no more heat for
## that, but the heat cools only slowly while it lasts (see `seen`)
func held(by: Thing) -> void:
	if mode != "play" or ufo.cloak > 0.0:
		return
	seen = 0.6
	seen_from = by.position


## A patrol's searchlight sweeping across the ship (or a dish tracking it): the heat goes up fast,
## and does not cool while it does
func spotted(by: Thing, delta: float, why := "SPOTTED!") -> void:
	if mode != "play" or ufo.cloak > 0.0:
		return
	seen = 0.6
	if by != null:
		seen_from = by.position
	if _spotted_for <= 0.0:
		_heat_note(why, 1.4)
		sfx.play("star", 1.3)
		add_heat(0.35)
	_spotted_for = 0.6
	add_heat(0.5 * delta)
	calm = 0.0


## A substation under the beam: its power runs up the beam into the shield, until it goes dark
## A bank (or Fort Knox) with the beam held on it: its money sucked out of it and up the beam, a
## little at a time over its `hold` seconds, bills (or gold) streaming up; then it is cleaned out
func _rob(t: Thing, delta: float) -> void:
	var hold: float = t.info.get("hold", 5.0)
	var full: float = t.info.get("cash", 1000.0)
	var take := minf(t.cash, full / hold * delta)
	t.cash -= take
	t.robbed += take
	var gold: bool = t.info.get("gold", false)
	var tint := Color(1.0, 0.82, 0.25) if gold else Color(0.45, 0.9, 0.4)
	if randf() < delta * 30.0:
		var from := t.position + Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.5), randf_range(-1.5, 1.5))
		ufo.puffs.puff(from, tint, randf_range(0.25, 0.4), (ufo.position - from).normalized() * 9.0, 0.7)
	if t.robbed >= full * 0.1 or t.cash <= 0.0:
		var got := int(t.robbed * Thing.WORTH) * multiplier()
		score += got
		_popup("+$%d" % got, t.position + Vector3(0, 4.0, 0), tint)
		sfx.play("ding", randf_range(1.2, 1.5), -6.0)
		add_heat(0.12 if gold else 0.06)
		t.robbed = 0.0
	if t.cash <= 0.0:
		Ps1.flash(t.model, Color(-0.4, -0.4, -0.4))
		log_line("FORT KNOX CLEANED OUT" if gold else "BANK ROBBED", int(full * Thing.WORTH))
		_heat_note("FORT KNOX CLEANED OUT!" if gold else "BANK ROBBED!", 2.5)
		add_heat(1.5 if gold else 0.6)
		sfx.play("cool", 1.3)


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
		_heat_note("POWER SIPHONED: SUBSTATION DARK", 2.5)
		sfx.play("cool", 0.7)


## Those who watch the sky: linger in range of one and it gives the ship away
func _watchers(delta: float) -> void:
	for t in things:
		var reach: float = t.info.get("watch", 0.0)
		if reach <= 0.0 or t.state != "walk":
			continue
		if not ufo.dead and t.ground().distance_to(ufo.ground()) < reach:
			t.watching += delta
			if t.broadcast != null:
				t.broadcast.keep(false)
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
			var bonus := int(25 * Thing.WORTH) * links * multiplier()
			score += bonus
			log_line("CROP CIRCLES JOINED", bonus)
		_circle_done = false
	var r := minf(1.0 + (_circle_time - 0.05) * 1.0, full)
	world.grow_circle(r)
	if r >= full and not _circle_done and mode == "play":
		coop.tell("circle", _circle_at, "", full)
		_circle_done = true
		var points := int(60 * Thing.WORTH) * multiplier()
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
## Ramming what flies at the ship's height (helicopters, Chinooks, the helicarrier): both take a hit
## and the ship bounces off; dashing into one hits it twice, and with RAM_DASH or more DASH items the
## dash leaves the ship unhurt
const RAM_DASH := 2
const RAM_HURT := 9.0
var _ram_wait := 0.0


func _ramming(delta: float) -> void:
	_ram_wait -= delta
	if _ram_wait > 0.0 or ufo.dead or mode != "play":
		return
	for t: Thing in things.duplicate():
		if t.state != "walk" or not t.is_enemy() or t.info["move"] != "hover":
			continue
		var off := ufo.position - t.position
		if absf(off.y) > 3.0 + t.size() * 0.2 or Vector2(off.x, off.z).length() > ufo.radius + t.size() * 0.5:
			continue
		_ram_wait = 0.7
		var dashing := ufo.dodging()
		sfx.play("clang", 0.7, 2.0)
		_shake = maxf(_shake, 0.35)
		boom((ufo.position + t.position) * 0.5, 1.6)
		for i in (2 if dashing else 1):
			if t.state == "walk":
				_laser_hit(t, t.global_position)
		if not (dashing and upgrades["dash"] >= RAM_DASH):
			ufo.hurt(RAM_HURT, t.position)
			_hurt = 1.0
		ufo.bump(off)
		return


## Somewhere to run to: over the mountains the police and army on the ground cannot follow. None of them
## are sent there and those after the ship give up after a few seconds; but helicopters and jets still
## come, and the heat only cools a little quicker
var hidden := false
var _hidden_for := 0.0
const HIDE_LOSES := 4.0


func _hideout(delta: float) -> void:
	var was := hidden
	hidden = mode == "play" and not ufo.dead and World.in_haven(ufo.ground())
	_hidden_for = _hidden_for + delta if hidden else 0.0
	if hidden and not was and heat_level() >= 1:
		_heat_note("A HIDDEN VALLEY: THE CARS CAN'T FOLLOW", 2.5)
	if hidden and _hidden_for > HIDE_LOSES and _hidden_for - delta <= HIDE_LOSES:
		var lost := false
		for t: Thing in things:
			if t.is_enemy() and t.state == "walk" and not t.leaving and t.info["move"] != "hover":
				t.leaving = true
				lost = true
		if lost:
			_heat_note("YOU LOST THEM", 2.0)


func _forces(delta: float) -> void:
	_spawn_wait -= delta
	_hideout(delta)
	_ramming(delta)
	for t in things:
		if t.leaving and t.ground().distance_to(ufo.ground()) > 70.0:
			_remove(t)
	if _spawn_wait > 0.0 or ufo.dead:
		return
	var wanted: Dictionary = FORCES[heat_level()].duplicate()
	# (five stars held long enough: the heavy stuff, see ESCALATE)
	if heat_level() >= 5 and _five_for > ESCALATE:
		for k: String in ESCALATION:
			wanted[k] = ESCALATION[k]
	# (over the mountains only what flies comes after the ship)
	if hidden:
		for k: String in wanted.keys():
			if Thing.KINDS[k]["move"] != "hover":
				wanted.erase(k)
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


## The jets that fly over at five stars, each kind its own height, speed and shots
const JETS := {
	"jet": {"height": 15.0, "speed": 45.0, "shots": 2, "spacing": 6.0, "shot": "missile"},
	"stealth": {"height": 22.0, "speed": 60.0, "shots": 3, "spacing": 5.0, "shot": "missile"},
	"warthog": {"height": 11.0, "speed": 30.0, "shots": 8, "spacing": 2.5, "shot": "bullet"},
}


func _jets(delta: float) -> void:
	if mode == "play" and heat_level() >= 5 and not ufo.dead:
		_jet_wait -= delta
		if _jet_wait <= 0.0:
			# Fighter jets from four stars, twice as often at five
			_jet_wait = randf_range(7.0, 10.0) if heat_level() >= 5 else randf_range(13.0, 18.0)
			# (a fighter, a stealth bomber high and fast with three missiles, or a warthog low and slow
			# strafing with its cannon: see JETS)
			var kind: String = JETS.keys().pick_random()
			var spec: Dictionary = JETS[kind]
			var jet := Ps1.model(kind)
			jet.position = ufo.ground() + Vector3(randf_range(-20, 20), float(spec["height"]), -90.0)
			jet.set_meta("fired", 0)
			jet.set_meta("kind", kind)
			view.add_child(jet)
			jets.append(jet)
			if not "jet" in _log_met:
				_log_met.append("jet")
			sfx.play("whoosh", 0.7, 3.0)
	for jet in jets:
		var spec: Dictionary = JETS[jet.get_meta("kind", "jet")]
		jet.position.z += delta * float(spec["speed"])
		var fired: int = jet.get_meta("fired")
		if fired < int(spec["shots"]) and jet.position.z > ufo.position.z - 30.0 + fired * float(spec["spacing"]):
			jet.set_meta("fired", fired + 1)
			var s := _shot(spec["shot"], jet.position + Vector3(0, -1, 0), ufo.position)
			if spec["shot"] == "missile":
				s.velocity = Vector3(0, -0.2, 1).normalized() * 17.0
	for jet in jets.duplicate():
		if jet.position.z > ufo.position.z + 80.0:
			jets.erase(jet)
			jet.queue_free()


## The railway's trains: every so often, while the ship is near a line, a train comes along it from
## off one side, a locomotive pulling boxcars and a caboose, its whistle blowing (each car a thing to
## take); gone again when far off (see `_cull`)
const TRAIN := ["locomotive", "boxcar", "boxcar", "boxcar", "caboose"]
const TRAIN_GAP := 8.6
var _train_wait := 6.0
var _airliner_wait := 30.0


func _trains(delta: float) -> void:
	_train_wait -= delta
	if _train_wait > 0.0 or mode != "play" or intro > 0.0:
		return
	_train_wait = randf_range(35.0, 60.0)
	var here := ufo.ground()
	var row := roundi(here.z / World.CHUNK)
	for m in range(row - 3, row + 4):
		if not World.has_rail(m) or absf(World.rail_z(m) - here.z) > 110.0:
			continue
		var dir := 1.0 if randf() < 0.5 else -1.0
		var front := Vector3(here.x - dir * 80.0, 0, World.rail_z(m))
		for i in TRAIN.size():
			var car := spawn_car(TRAIN[i], front - Vector3(dir * TRAIN_GAP * i, 0, 0), "x", dir)
			car.home = car.position
		sfx.play("bugle", 0.55, -6.0)
		return


## Now and then an airliner high over everything, out of reach, its lights blinking, crossing the sky
func _airliners(delta: float) -> void:
	_airliner_wait -= delta
	if _airliner_wait > 0.0 or mode != "play" or intro > 0.0:
		return
	_airliner_wait = randf_range(40.0, 80.0)
	var plane := Ps1.model("plane")
	plane.scale = Vector3.ONE * 2.2
	var a := randf() * TAU
	var way := Vector3(cos(a), 0, sin(a))
	var from := ufo.ground() - way * 140.0 + Vector3(randf_range(-30, 30), 42.0, randf_range(-60, -20))
	plane.position = from
	plane.rotation.y = atan2(way.x, way.z)
	view.add_child(plane)
	var blink := OmniLight3D.new()
	blink.light_color = Color(1.0, 0.2, 0.2)
	blink.omni_range = 6.0
	plane.add_child(blink)
	var tw := plane.create_tween()
	tw.tween_property(plane, "position", from + way * 280.0, 280.0 / 24.0)
	tw.parallel().tween_method(func(t: float) -> void: blink.light_energy = 3.0 if fmod(t, 1.0) < 0.15 else 0.0, 0.0, 12.0, 280.0 / 24.0)
	tw.tween_callback(plane.queue_free)


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
		_heat_note("TRADED WITH %s" % shop.keeper_name.to_upper(), 2.5)
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
	_ship_stats()
	ufo.hull_max = float(spec["hull"]) + 15.0 * upgrades["shield"]
	ufo.dash_level = upgrades["dash"]
	ufo.armor = upgrades["armor"]
	# (the beam green, blue from the second BEAM, purple from the fourth)
	ufo.colour_beam(BEAM_COLOURS[mini(upgrades["beam"] / 2, BEAM_COLOURS.size() - 1)])
	# (WIDE BEAM: a seventh broader a stack, its light with it)
	var wide: float = 1.0 + 0.15 * upgrades["wide"]
	ufo.beam_foot = float(spec["beam_foot"]) * wide
	# (SWIVEL MOUNT: the beam leans a third further out from under the ship a stack)
	ufo.beam_reach = Ufo.BEAM_REACH * (1.0 + 0.35 * upgrades["swivel"])
	ufo.beam.scale = Vector3(wide, 1.0, wide)
	if upgrades["turret"] > 0:
		ufo.arm_laser()
	_build_fleet()


## The ship's speed and beam from its items, and any boost under way
func _ship_stats() -> void:
	var spec: Dictionary = Ufo.SHIPS[ship]
	# (each a little at first: a level of anything is felt, and the fourth makes it strong)
	ufo.speed = float(spec["speed"]) * (1.0 + 0.07 * upgrades["engine"]) * (1.5 if boosts.has("overdrive") else 1.0)
	ufo.lift_rate = float(spec["lift"]) * (1.0 + 0.12 * upgrades["beam"]) * (1.8 if boosts.has("super") else 1.0)
	ufo.tier = mini(int(spec["tier"]) + int(upgrades["beam"]) / 2 + (1 if boosts.has("super") else 0), 4)


# ------------------------------------------------------------------ boosts

## Power-ups lying about the country, glowing canisters to beam up, each for a while (seconds; none
## for one that works at once)
const BOOSTS := {
	"double": {"title": "DOUBLE POINTS", "colour": Color(1.0, 0.82, 0.25), "time": 15.0},
	"overdrive": {"title": "OVERDRIVE", "colour": Color(1.0, 0.45, 0.2), "time": 15.0},
	"freeze": {"title": "HEAT FREEZE", "colour": Color(0.55, 0.95, 1.0), "time": 12.0},
	"super": {"title": "SUPER BEAM", "colour": Color(0.85, 0.4, 1.0), "time": 12.0},
	"repair": {"title": "SHIELD CELL", "colour": Color(0.35, 0.6, 1.0), "time": 0.0},
}
## Those under way: {name: seconds left}
var boosts := {}
var _boost_wait := 20.0
var boost_label: Label
## A canister put down somewhere near every so often, while there are few about
const BOOST_EVERY := Vector2(22.0, 40.0)
const BOOST_MOST := 2


func _boosts(delta: float) -> void:
	for b: String in boosts.keys():
		boosts[b] -= delta
		if boosts[b] <= 0.0:
			boosts.erase(b)
			_ship_stats()
			_heat_note("%s OVER" % BOOSTS[b]["title"], 1.2)
	if mode != "play" or intro > 0.0:
		return
	_boost_wait -= delta
	if _boost_wait > 0.0:
		return
	_boost_wait = randf_range(BOOST_EVERY.x, BOOST_EVERY.y) / (1.0 + 0.35 * upgrades["lucky"])
	var about := 0
	for t: Thing in things:
		if t.kind == "canister" and t.state == "walk":
			about += 1
	if about >= BOOST_MOST + upgrades["lucky"]:
		return
	var what: String = BOOSTS.keys().pick_random()
	var a := randf() * TAU
	var at: Vector3 = world.off_road(ufo.ground() + Vector3(cos(a), 0, sin(a)) * randf_range(16.0, 28.0), 1.0)
	var c := spawn("canister", at, {"tints": {"pod_glow": BOOSTS[what]["colour"]}})
	if c != null:
		c.set_meta("boost", what)
		# (a glowing ring on the ground under it, and a halo round it, in its colour)
		var tint: Color = BOOSTS[what]["colour"]
		var ring := CylinderMesh.new()
		ring.top_radius = 1.1
		ring.bottom_radius = 1.1
		ring.height = 0.04
		ring.radial_segments = 16
		Ps1.part(c, ring, Ps1.mat(tint, 1.4), Vector3(0, 0.05, 0))
		var halo := StandardMaterial3D.new()
		halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		halo.albedo_color = Color(tint.r, tint.g, tint.b, 0.3)
		halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var glow := QuadMesh.new()
		glow.size = Vector2(2.4, 2.4)
		Ps1.part(c.model, glow, halo, Vector3(0, 0.5, 0))


## A canister beamed up: its boost on (or, taken again, on for longer)
func _boost(what: String) -> void:
	var spec: Dictionary = BOOSTS[what]
	if what == "repair":
		ufo.hull = ufo.hull_max
	else:
		boosts[what] = float(boosts.get(what, 0.0)) + float(spec["time"])
		_ship_stats()
	_heat_note("%s!" % spec["title"], 1.6)
	_power_burst(spec["colour"])
	sfx.play("fanfare", 1.3, -6.0)
	ufo.sparkle()


# ------------------------------------------------------------------ levelling up

## The score that brings level `n`: each further off than the last (600, 2400, 5400, 9600...)
static func level_at(n: int) -> int:
	return int(round(600.0 * Thing.WORTH * pow(float(n), 2.0) / 50.0)) * 50




## The score the level-ups go by: one's own, and in a multiplayer game everyone's together (each
## picks their own upgrade at each, as in 8 Bit Evil Returns)
func team_score() -> int:
	var all := score
	if coop != null and coop.active():
		for s in coop.others:
			all += (coop.others[s] as RemoteSaucer).score
	return all
## A level for every LEVEL_AT reached: one at a time, a pick of three upgrades
func _levels() -> void:
	if not levels_on:
		return
	while team_score() >= level_at(level + 1):
		level += 1
		_levels_due += 1
	if _levels_due > 0 and not _picker.visible and not ufo.dead:
		_levels_due -= 1
		_level_up()


## LEVEL UP: the game holds still while one of three upgrades is picked (and the shield patched up
## is one of them when it is low). Tests and the autopilot take the first.
## The items' rarities, as in Risk of Rain: common (green), uncommon (blue) and rare (red). The rarer
## an item, the less often the Moon Market has it; its rarity is the colour of its frame
const RARITY_COLOURS: Array[Color] = [Color(0.4, 1.0, 0.5), Color(0.35, 0.65, 1.0), Color(1.0, 0.3, 0.3)]
const RARITY_NAMES: Array[String] = ["COMMON", "UNCOMMON", "RARE"]
const RARITY_ODDS: Array[float] = [6.0, 2.5, 0.8]
const UNCOMMON: Array[String] = ["laser", "turret", "starbits", "cloak", "nanobots", "gold", "armor"]
const RARE: Array[String] = ["missiles", "emp", "fleet", "second_wind", "sling"]


func rarity(what: String) -> int:
	return 2 if what in RARE else (1 if what in UNCOMMON else 0)


func _level_up() -> void:
	var offers: Array = GOODS.filter(func(g: String) -> bool: return g != "patch" and upgrades[g] < MAX_UPGRADE)
	# (three different ones, the rarer the less often: see RARITY)
	var picked: Array = []
	while picked.size() < 3 and not offers.is_empty():
		var total := 0.0
		for g: String in offers:
			total += RARITY_ODDS[rarity(g)]
		var roll := randf() * total
		for g: String in offers:
			roll -= RARITY_ODDS[rarity(g)]
			if roll <= 0.0:
				picked.append(g)
				offers.erase(g)
				break
	offers = picked
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
	_picker_title.text = "MOON MARKET"
	# (the market's trading saucer coming down out of the sky behind it)
	if not is_instance_valid(_market):
		_market = MarketShip.new()
		_market.main = self
		view.add_child(_market)
	_picker_title.add_theme_font_size_override("font_size", 110 if _upright() else 56)
	_pick_one.add_theme_font_size_override("font_size", 50 if _upright() else 26)
	_picks.add_theme_constant_override("separation", 50 if _upright() else 30)
	_picker.custom_minimum_size = Vector2(1200 if _upright() else 660, 0)
	for what: String in offers:
		var spec: Dictionary = UPGRADES[what]
		var heading := "%s" % spec["title"] if what == "patch" else "%s  x%d" % [spec["title"], upgrades[what] + 1]
		var b := _button("%s\n%s" % [heading, spec["about"]], func() -> void: _pick(what))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# (big for thumbs, an upright phone's the biggest)
		var big := _upright()
		b.custom_minimum_size = Vector2(1180, 250) if big else Vector2(600, 118)
		b.add_theme_font_size_override("font_size", 70 if big else 34)
		b.add_theme_color_override("font_color", (spec["colour"] as Color).lerp(Color.WHITE, 0.35))
		# (the item itself beside its name, a little 3D model of it)
		b.icon = holograms.turning("item:" + what)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 210 if big else 96)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 30 if big else 18)
		# (framed in the colour of its rarity: green, blue or red)
		var tier_colour := RARITY_COLOURS[rarity(what)]
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := b.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			box.border_color = tier_colour
			box.set_border_width_all(5 if big else 4)
			box.shadow_color = Color(tier_colour, 0.35)
			b.add_theme_stylebox_override(state, box)
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
	if is_instance_valid(_market):
		_market.leave()
	_picker.visible = false
	if _picker_dim != null:
		_picker_dim.visible = false
	get_tree().paused = false

## An upgrade: one more level of it (up to MAX_UPGRADE), for nothing (see `_level_up`)
func buy(what: String) -> bool:
	if upgrades[what] >= MAX_UPGRADE:
		return false
	upgrades[what] += 1
	if not what in _log_items:
		_log_items.append(what)
	_apply_upgrades()
	_heat_note("%s x%d" % [UPGRADES[what]["title"], upgrades[what]], 2.5)
	if what == "second_wind":
		ufo.second_winds += 1
	if what == "shield":
		ufo.hull = minf(ufo.hull + 15.0, ufo.hull_max)
	if what == "turret" and upgrades[what] == 1:
		_banner("AUTO TURRET ARMED: IT FIRES BY ITSELF", 2.5)
	elif what == "laser" and upgrades[what] == 1:
		_banner("LASER: SWITCH THE BEAM OVER TO IT AND FIRE", 3.0)
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
	_heat_note("SHIELD PATCHED", 2.5)
	sfx.play("bloop", 1.2)


## The defence laser: a turret under the hull that fires by itself, a shot every `laser_reload`
## seconds. It shoots down the shells and missiles coming at the ship first, then jets, and then,
## once there is heat, the nearest of the police and army: a hit stuns one (it holds its fire a
## while), and LASER_HITS blow it up, scored and heating things up as a crush does. Each level it
## fires sooner and reaches further.
func _laser(delta: float) -> void:
	_laser_wait -= delta
	var level: int = upgrades["turret"]
	if level == 0 or ufo.dead or mode != "play" or intro > 0.0 or _laser_wait > 0.0:
		return
	var reach := LASER_REACH + 2.5 * level
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
		# (the police and army by how far off they are on the ground, not up to the ship)
		nearest = 14.0 + 3.0 * level
		for t in things:
			if t.is_enemy() and t.state == "walk" and not t.leaving and t.ground().distance_to(ufo.ground()) < nearest:
				nearest = t.ground().distance_to(ufo.ground())
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
		_laser_hit(target, at)
	else:
		# A jet, out of the sky
		jets.erase(target)
		target.queue_free()
		boom(at, 3.0)
		sfx.play("boom", 0.9)
		var points := int(250 * Thing.WORTH) * multiplier()
		score += points
		add_heat(0.25)
		calm = 0.0
		log_line("JET SHOT DOWN", points)
		_count_kill("jet")



## One of the police or army hit by a laser (the turret's or the ship's): LASER_HITS of them blow it
## up, scored and heating things up as a crush does; fewer only stun it a while, red and sparking
func _laser_hit(t: Thing, at: Vector3) -> void:
	var hits := int(t.get_meta("zapped", 0)) + 1
	if hits >= int(LASER_HITS.get(t.kind, 2)):
		var points := t.points() / 2 * multiplier()
		score += points
		add_heat(0.25)
		calm = 0.0
		boom(at, 2.2)
		sfx.play("boom", 1.3, _near_db(t))
		log_line("%s BLOWN UP" % Thing.alien_name(t.kind), points, t.kind)
		_count_kill(t.kind)
		_remove(t)
		return
	t.set_meta("zapped", hits)
	t.reload = maxf(t.reload, 0.0) + 2.0
	t.burst = 0
	Ps1.flash(t.model, Color(1.2, 0.15, 0.2))
	# (held weakly: it may be blown up before the flash is over)
	var held: WeakRef = weakref(t)
	create_tween().tween_callback(func() -> void:
		var still: Thing = held.get_ref()
		if still != null:
			Ps1.flash(still.model, Color.BLACK)).set_delay(0.2)






# ------------------------------------------------------------------ the newer items' effects

## SCANNER: the radar's reach, a third further a stack
func radar_range() -> float:
	return Radar.RANGE * (1.0 + 0.33 * upgrades["scanner"])


## MAGNET: while beaming, small things near the beam's foot drift into it (wider and quicker a stack)
func _magnet(delta: float) -> void:
	var n: int = upgrades["magnet"]
	if n <= 0 or not ufo.beaming or ufo.dead:
		return
	var foot := ufo.beam_axis(0.0)
	var reach := ufo.beam_foot + 3.0 + 2.0 * n
	for t in things:
		if t.state != "walk" or t.is_enemy() or t.fixed() and t.info["move"] == "still" or float(t.info["weight"]) > 2.0:
			continue
		var off := Vector3(foot.x - t.position.x, 0, foot.z - t.position.z)
		var d := off.length()
		if d < reach and d > ufo.beam_foot * 0.5:
			t.position += off / d * minf((1.0 + 0.8 * n) * delta, d)


## EMP: a dash stuns the police and army near (further a stack)
func _emp() -> void:
	var n: int = upgrades["emp"]
	if n <= 0:
		return
	# (bigger and bigger with each EMP stacked)
	var reach := 9.0 + 5.0 * n
	_emp_blast(reach)
	sfx.play("static", 0.6, 2.0)
	_shake = maxf(_shake, 0.2 + 0.05 * n)
	for t in things:
		if t.state != "walk" or t.position.distance_to(ufo.position) > reach:
			continue
		if t.is_enemy():
			t.reload = maxf(t.reload, 0.0) + 2.5 + 0.5 * n
			t.burst = 0
			t.stunned = maxf(t.stunned, 0.8 + 0.4 * n)
		elif n >= 2 and t.info["move"] in ["flee", "believer", "graze", "peck", "guard"]:
			# (from the second EMP on, people and animals caught in it are paralysed a while too)
			t.stunned = maxf(t.stunned, 1.0 + 0.8 * n)
		else:
			continue
		for i in 3:
			ufo.puffs.spark(t.global_position + Vector3(0, 1.0, 0), Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2)), Color(0.55, 0.85, 1.0))


## The EMP's blast: a shell of crackling electricity swelling out to `reach` and fading (emp.gdshader)
func _emp_blast(reach: float) -> void:
	var shell := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 24
	ball.rings = 12
	shell.mesh = ball
	var m := ShaderMaterial.new()
	m.shader = EMP_SHADER
	m.set_shader_parameter("seed", randf() * 100.0)
	shell.material_override = m
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.position = ufo.position
	shell.scale = Vector3.ONE * 0.5
	view.add_child(shell)
	var grow := create_tween().set_parallel(true)
	grow.tween_property(shell, "scale", Vector3.ONE * reach, 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	grow.tween_method(func(k: float) -> void: m.set_shader_parameter("fade", k), 1.0, 0.0, 0.7)
	grow.chain().tween_callback(shell.queue_free)
	# (and a second, quicker flash inside it)
	ufo.puffs.puff(ufo.global_position, Color(0.75, 0.92, 1.0, 0.7), 2.5, Vector3.ZERO, 0.2)

# ------------------------------------------------------------------ the cloak

## The CLOAK item: gone from sight for a few seconds (longer the more stacked); no searchlight can
## spot it, nobody shoots at it, and shots go through. The beam put on breaks it. It recharges
## (quicker the more stacked).
func cloak_for() -> float:
	return 3.0 + 1.0 * upgrades["cloak"]


func cloak_recharge() -> float:
	return maxf(22.0 - 2.5 * upgrades["cloak"], 8.0)


func use_cloak() -> void:
	if upgrades["cloak"] <= 0 or mode != "play" or ufo.dead or ufo.cloak > 0.0 or ufo.cloak_wait > 0.0:
		return
	ufo.cloak = cloak_for()
	ufo.cloak_wait = cloak_for() + cloak_recharge()
	sfx.play("whoosh", 2.2, -4.0)
	_heat_note("CLOAKED", 1.2)

# ------------------------------------------------------------------ missiles

## The missile launcher (the MISSILES item): now and then, by itself, a homing missile off the ship,
## and one off each of the fleet, after the nearest of the police and army; whatever one hits is blown
## up. Oftener the more stacked.
const MISSILE_REACH := 45.0
const MISSILE_SPEED := 22.0
var _missile_wait := 0.0
## Each missile in the air: [node, target, velocity]
var _missiles: Array = []


func missile_reload() -> float:
	return maxf(7.0 - 1.0 * upgrades["missiles"], 2.0)


func _launch_missiles(delta: float) -> void:
	for m: Array in _missiles.duplicate():
		_fly_missile(m, delta)
	if upgrades["missiles"] <= 0 or ufo.dead or mode != "play" or intro > 0.0:
		return
	_missile_wait -= delta
	if _missile_wait > 0.0:
		return
	var target := _missile_target(ufo.position)
	if target == null:
		return
	_missile_wait = missile_reload()
	_fire_missile(ufo.global_position + Vector3(0, -0.7, 0), target)
	for d: Drone in fleet:
		if d.is_up():
			var t := _missile_target(d.global_position)
			if t != null:
				_fire_missile(d.global_position, t)


## The nearest of the police and army within reach of `from`, or null
func _missile_target(from: Vector3) -> Thing:
	var best: Thing = null
	var near := MISSILE_REACH
	for t in things:
		if t.is_enemy() and t.state == "walk" and not t.leaving and t.position.distance_to(from) < near:
			near = t.position.distance_to(from)
			best = t
	return best


func _fire_missile(from: Vector3, target: Thing) -> void:
	var m := Node3D.new()
	Ps1.part(m, CylinderMesh.new(), Ps1.flat(Color(0.92, 0.92, 0.88)), Vector3.ZERO, Vector3(0.18, 0.7, 0.18), Vector3(PI / 2, 0, 0))
	Ps1.part(m, Ps1.ball(), Ps1.own(Color(1.0, 0.7, 0.25), 2.5), Vector3(0, 0, -0.4), Vector3.ONE * 0.16)
	view.add_child(m)
	m.global_position = from
	var up := Vector3(randf_range(-0.4, 0.4), 1.0, randf_range(-0.4, 0.4)).normalized()
	_missiles.append([m, target, up * MISSILE_SPEED * 0.5])
	sfx.play("whoosh", 1.8, -6.0)


func _fly_missile(m: Array, delta: float) -> void:
	var node: Node3D = m[0]
	var target: Thing = m[1] if is_instance_valid(m[1]) and (m[1] as Thing).state == "walk" else null
	var v: Vector3 = m[2]
	var goal := target.global_position + Vector3(0, 0.8, 0) if target != null else node.global_position + v
	# (turning toward its target, quicker the nearer it is)
	v = v.lerp((goal - node.global_position).normalized() * MISSILE_SPEED, minf(delta * 4.0, 1.0))
	m[2] = v
	node.global_position += v * delta
	if v.length() > 0.1:
		node.look_at(node.global_position + v, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.FORWARD)
	if randf() < delta * 25.0:
		ufo.puffs.puff(node.global_position, Color(0.75, 0.75, 0.78, 0.6), 0.25, Vector3(0, 0.6, 0), 0.6)
	var hit := target != null and node.global_position.distance_to(goal) < 1.0
	if hit or node.global_position.y < 0.0 or target == null and node.global_position.distance_to(ufo.position) > MISSILE_REACH * 2.0:
		if hit:
			# (blown up outright)
			target.set_meta("zapped", 99)
			_laser_hit(target, goal)
		else:
			boom(node.global_position, 1.5)
		node.queue_free()
		_missiles.erase(m)
# ------------------------------------------------------------------ the ship's own laser

## Switched over to the laser (see `toggle_laser`): the beam's button fires it instead, where the
## beam would fall
var laser_mode := false
var _cut_wait := 0.0
var _cut_ray: MeshInstance3D
var _cut_mat: StandardMaterial3D
## The touch switch for it, over the beam's mark
var laser_button: Control
var cloak_button: Control


## The beam switched over to the laser, or back (only once a LASER is had)
func toggle_laser() -> void:
	if upgrades["laser"] <= 0 or mode != "play":
		laser_mode = false
		return
	laser_mode = not laser_mode
	sfx.play("zap" if laser_mode else "bloop", 0.8 if laser_mode else 1.2, -6.0)
	_heat_note("LASER" if laser_mode else "BEAM", 0.8)


## Holding the beam's button with the laser switched over: a red-hot ray from under the ship to where
## the beam would fall, cutting what it touches. The police and army there are hit (and blown up
## after a few hits); cars and oil drums blow up; anyone else there runs. Hotter (quicker hits) a
## level.
func _cut(delta: float, firing: bool) -> void:
	if _cut_ray == null:
		_cut_ray = MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = 1.0
		rod.bottom_radius = 1.0
		rod.height = 1.0
		rod.radial_segments = 6
		_cut_ray.mesh = rod
		_cut_mat = StandardMaterial3D.new()
		_cut_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cut_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cut_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_cut_mat.albedo_color = Color(1.0, 0.3, 0.45, 0.9)
		_cut_ray.material_override = _cut_mat
		_cut_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cut_ray.top_level = true
		view.add_child(_cut_ray)
	_cut_ray.visible = firing and not ufo.dead
	if not _cut_ray.visible:
		_last_scorch = Vector3.INF
		return
	var aim := _beam_aim()
	var from := ufo.global_position + Vector3(0, -0.6, 0)
	# (aimed over a much wider spread than the beam's lean: the thumb sweeps it well out from under the ship)
	var foot := ufo.ground() + Vector3(aim.x, 0, aim.y) * ufo.beam_reach * 3.5
	var along := foot - from
	var wide := 0.12 + 0.05 * sin(Time.get_ticks_msec() * 0.05)
	_cut_ray.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, along.normalized())) * Basis.from_scale(Vector3(wide, along.length(), wide)), (from + foot) * 0.5)
	# (a trail of burns along the ground where it has been)
	if _last_scorch == Vector3.INF or Vector2(foot.x - _last_scorch.x, foot.z - _last_scorch.z).length() > 0.4:
		_scorch(foot, randf_range(1.2, 1.6))
		_last_scorch = foot
	if randf() < delta * 30.0:
		ufo.puffs.spark(foot + Vector3(0, 0.1, 0), Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)), Color(1.0, 0.5, 0.4))
	if randf() < delta * 8.0:
		ufo.puffs.puff(foot + Vector3(0, 0.15, 0), Color(0.2, 0.18, 0.17, 0.4), 0.22, Vector3(0, 1.2, 0), 0.7)
	_cut_wait -= delta
	if _cut_wait > 0.0:
		return
	_cut_wait = maxf(0.55 - 0.07 * upgrades["laser"], 0.15)
	sfx.play("zap", randf_range(0.9, 1.1), -10.0)
	for t in things.duplicate():
		if t.state != "walk" or t.hiding:
			continue
		if Vector2(t.position.x - foot.x, t.position.z - foot.z).length() > 1.8 + t.size() * 0.3:
			continue
		if t.is_enemy():
			_laser_hit(t, t.global_position + Vector3(0, 1.0, 0))
		elif t.info.get("explosive", false) or t.kind in VEHICLES:
			explode(t)
		else:
			_burn(t)


## What the laser cannot burn: the land itself
const FIREPROOF := ["hill", "butte", "mesa", "peak", "crag", "devils_tower", "runway", "pod", "canister", "rival"]


## The laser on something: it burns, a LASER's worth a cut (more for each LASER item), until it has
## taken as much as its size (its size squared) and goes up in smoke. Only things up to a size the
## laser's level allows: bigger ones are only scorched (a house wants a second LASER, a church a third)
func _burn(t: Thing) -> void:
	if t.kind in FIREPROOF:
		return
	var level: int = upgrades["laser"]
	if t.info["move"] in ["flee", "graze", "peck"]:
		t.panic = 2.5
	if t.size() > laser_burns():
		return
	var burnt: float = float(t.get_meta("burnt", 0.0)) + level
	if burnt < ceilf(t.size() * t.size()):
		t.set_meta("burnt", burnt)
		Ps1.flash(t.model, Color(1.0, 0.35, 0.1))
		var held: WeakRef = weakref(t)
		create_tween().tween_callback(func() -> void:
			var still: Thing = held.get_ref()
			if still != null:
				Ps1.flash(still.model, Color.BLACK)).set_delay(0.12)
		return
	_vaporise(t)


## Caught in an explosion: `hurt` of damage on what it has taken (as the laser's, see `_burn`),
## shaken and lit up, and brought down once that reaches its size squared
func _blast(t: Thing, hurt: float) -> void:
	var taken: float = float(t.get_meta("burnt", 0.0)) + hurt
	if taken >= ceilf(t.size() * t.size()):
		_vaporise(t, "BLOWN APART")
		return
	t.set_meta("burnt", taken)
	Ps1.flash(t.model, Color(1.0, 0.45, 0.1))
	for i in 2 + int(t.size()):
		ufo.puffs.puff(t.position + Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)) * t.size() * 0.4 + Vector3(0, t.size() * 0.4, 0),
			Color(0.16, 0.14, 0.13, 0.6), 0.4 + t.size() * 0.15, Vector3(0, randf_range(1.0, 2.0), 0), 1.6)
	var held: WeakRef = weakref(t)
	create_tween().tween_callback(func() -> void:
		var still: Thing = held.get_ref()
		if still != null:
			Ps1.flash(still.model, Color.BLACK)).set_delay(0.18)


## The biggest thing the laser can burn down, at its level
func laser_burns() -> float:
	return 1.5 + upgrades["laser"]


## Burnt down by the laser: a blast as big as it was, smoke and sparks, a scorch where it stood
## A prison broken (taken, burnt or blown up): the inmates near it run free, and the police near
## break off to go after them (and the heat drops a star)
func _prison_break(at: Vector3) -> void:
	var freed := 0
	for th: Thing in things:
		if th.state != "walk":
			continue
		if th.kind == "inmate" and th.ground().distance_to(at) < 40.0:
			th.set_meta("free", at)
			freed += 1
		elif th.info.get("police", false) and th.ground().distance_to(ufo.ground()) < 150.0:
			th.leaving = true
	heat = maxf(heat - 1.0, 0.0)
	_heat_note("PRISON BREAK! THE COPS ARE BUSY", 3.0)
	sfx.play("ring", 0.8)


## Where the ship comes down shot: whatever it lands on is wrecked with it (buildings and things
## gone in a blast, the scenery under it flattened)
func _crush_under_wreck() -> void:
	var at := ufo.ground()
	var reach: float = ufo.radius + 1.5
	for th: Thing in things.duplicate():
		if th.state != "walk" or th.is_enemy() or th.info["move"] != "still":
			continue
		if th.ground().distance_to(at) > reach + th.size() * 0.5:
			continue
		boom(th.position + Vector3(0, 1.0, 0), 1.0 + th.size())
		for i in 4:
			ufo.puffs.puff(th.position + Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1)) * th.size(), Color(0.3, 0.27, 0.24, 0.7), 0.6 + th.size() * 0.3, Vector3(0, 1.5, 0), 1.5)
		if th.kind == "prison":
			_prison_break(th.position)
		_remove(th)
	# (trees, crops and the like under it)
	for i in 40:
		if world.pull(at, reach, 4).is_empty():
			break


func _vaporise(t: Thing, how := "BURNT DOWN") -> void:
	if t.kind == "hydrant":
		geysers.append(t.home)
	if t.kind == "track":
		torn_track.append(t.home)
	var at := t.position
	var big := t.size()
	coop.tell("boom", at, "", 1.5 + big)
	boom(at + Vector3(0, 0.3 + big * 0.3, 0), 1.5 + big)
	for i in 3 + int(big * 2.0):
		var off := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * big * 0.5
		ufo.puffs.puff(at + off + Vector3(0, 0.4, 0), Color(0.14, 0.12, 0.11, 0.6), 0.35 + big * 0.2, Vector3(0, randf_range(1.0, 2.2), 0), 1.4)
	for i in 4 + int(big * 3.0):
		ufo.puffs.spark(at + Vector3(0, 0.6, 0), Vector3(randf_range(-1, 1), randf_range(0.6, 1.6), randf_range(-1, 1)) * randf_range(3.0, 7.0), Color(1.0, 0.6, 0.25))
	_scorch(at, 0.8 + big * 0.8)
	sfx.play("boom", clampf(1.8 - big * 0.25, 0.7, 1.6), _near_db(t) - 2.0)
	_shake = maxf(_shake, 0.08 * big)
	var points := maxi(t.points() / 2, 5) * multiplier()
	score += points
	add_heat(0.05 + 0.04 * big)
	calm = 0.0
	log_line("%s %s" % [Thing.alien_name(t.kind), how], points, t.kind)
	if t.kind == "prison":
		_prison_break(at)
	_remove(t)


# The laser's trail: burns on the ground where its foot has passed, glowing, cooling to soot and
# fading away
const SCORCH_HOT := 1.8
const SCORCH_KEEP := 7.0
const SCORCH_FADE := 2.5
const SCORCH_MOST := 140
## [mark, its material, its age]
var _scorches: Array = []
var _scorch_mesh: QuadMesh
var _last_scorch := Vector3.INF
const SCORCH_SHADER := preload("res://shaders/scorch.gdshader")
const EMP_SHADER := preload("res://shaders/emp.gdshader")


func _scorch(at: Vector3, across: float) -> void:
	if _scorch_mesh == null:
		_scorch_mesh = QuadMesh.new()
		_scorch_mesh.orientation = PlaneMesh.FACE_Y
		_scorch_mesh.subdivide_width = 3
		_scorch_mesh.subdivide_depth = 3
	if _scorches.size() >= SCORCH_MOST:
		var oldest: Array = _scorches.pop_front()
		(oldest[0] as Node).queue_free()
	var m := ShaderMaterial.new()
	m.shader = SCORCH_SHADER
	var mi := Ps1.part(view, _scorch_mesh, m, Vector3(at.x, 0.08 + randf() * 0.03, at.z), Vector3(across, 1.0, across), Vector3(0, randf() * TAU, 0))
	_scorches.append([mi, m, 0.0])


func _cool_scorches(delta: float) -> void:
	var keep: Array = []
	for s: Array in _scorches:
		s[2] += delta
		var age: float = s[2]
		if age > SCORCH_KEEP + SCORCH_FADE:
			(s[0] as Node).queue_free()
			continue
		var hot := 1.0 - smoothstep(0.0, SCORCH_HOT, age)
		var c := Color(0.07, 0.055, 0.05).lerp(Color(1.0, 0.45, 0.15), hot)
		c.a = 0.85 * (1.0 - smoothstep(SCORCH_KEEP, SCORCH_KEEP + SCORCH_FADE, age))
		(s[1] as ShaderMaterial).set_shader_parameter("tint", c)
		keep.append(s)
	_scorches = keep

## Seconds between the laser's shots, at its level
func laser_reload() -> float:
	return maxf(4.6 - 0.6 * upgrades["turret"], 0.9)


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
	while fleet.size() < mini(int(upgrades["fleet"]), FLEET_MOST):
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
		if not s in unlocked and s != Ufo.LAST:
			left.append(s)
	if left.is_empty():
		# (every other ship found: now the Moon Market's own saucer is held out there)
		return Ufo.LAST if not Ufo.LAST in unlocked else held
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
	coop.tell("pull", xf.origin, found[0])
	t.state = "lifted"


## The beam has taken hold of something: anyone near enough to see it reaches for a phone
## How many of the people who see the ship take something go and call the police about it
const CALLERS := 0.35

func _witnessed(taken_thing: Thing) -> void:
	if mode != "play":
		return
	for t in things:
		if t != taken_thing and t.info.get("caller", false) and t.state == "walk" and t.calling <= 0.0 \
				and t.ground().distance_to(ufo.ground()) < 26.0:
			# (not everyone runs for a phone: each decides once, the first time they see the ship,
			# whether they are the calling sort; the rest only run and hide)
			if not t.has_meta("calls"):
				t.set_meta("calls", randf() < CALLERS)
			if not t.get_meta("calls"):
				continue
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
## Five stars held this long and they bring out a helicarrier, rail guns and laser trucks; longer, and
## laser satellites strike from orbit (see `_orbital`)
const ESCALATE := 50.0
const ESCALATION := {"helicarrier": 1, "railgun": 1, "laser_truck": 2}
const ORBITAL_AFTER := 80.0
const ORBITAL_EVERY := 11.0
const ORBITAL_FUSE := 2.2
const ORBITAL_REACH := 5.0
var _orbital_wait := 0.0
## Each orbital strike on its way: [where, seconds left, its ring]
var _orbitals: Array = []
var _nuke_wait := 0.0
## Each strike on its way: [where, seconds left, its ring, its missile]
var _nukes: Array = []
var _nuke_flash: ColorRect


## Laser satellites: a red ring where the ship is going, and a moment later a beam of red light
## straight down from orbit onto it
func _orbital(delta: float) -> void:
	_orbital_wait -= delta
	if _five_for > ORBITAL_AFTER and _orbital_wait <= 0.0 and not ufo.dead:
		_orbital_wait = ORBITAL_EVERY / sqrt(danger())
		var at := ufo.ground() + Vector3(ufo.velocity.x, 0, ufo.velocity.z) * 1.2
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = ORBITAL_REACH - 0.4
		torus.outer_radius = ORBITAL_REACH
		ring.mesh = torus
		ring.material_override = Ps1.flat(Color(1.0, 0.15, 0.2))
		ring.position = at + Vector3(0, 0.1, 0)
		ring.scale = Vector3(1, 0.05, 1)
		view.add_child(ring)
		_orbitals.append([at, ORBITAL_FUSE, ring])
		_heat_note("ORBITAL LASER LOCKED ON!", 2.0)
		sfx.play("zap", 0.5, 2.0)
	for o: Array in _orbitals.duplicate():
		o[1] -= delta
		var ring: MeshInstance3D = o[2]
		ring.visible = fmod(o[1], 0.25) > 0.1
		if o[1] > 0.0:
			continue
		_orbitals.erase(o)
		ring.queue_free()
		var at: Vector3 = o[0]
		# (the beam: a column of red light from the sky, there and gone)
		var beam := MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = ORBITAL_REACH * 0.7
		rod.bottom_radius = ORBITAL_REACH * 0.7
		rod.height = 80.0
		beam.mesh = rod
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/beam.gdshader")
		m.set_shader_parameter("tint", Color(1.0, 0.2, 0.25))
		m.set_shader_parameter("power", 2.0)
		beam.material_override = m
		beam.position = at + Vector3(0, 40.0, 0)
		view.add_child(beam)
		var tw := create_tween()
		tw.tween_property(beam, "scale", Vector3(0.05, 1.0, 0.05), 0.5).set_delay(0.25)
		tw.tween_callback(beam.queue_free)
		boom(at + Vector3(0, 0.5, 0), 3.0)
		sfx.play("boom", 0.6, 3.0)
		_shake = maxf(_shake, 0.4)
		if ufo.ground().distance_to(at) < ORBITAL_REACH + ufo.radius * 0.5 and not ufo.dodging():
			ufo.hurt(28.0, at + Vector3(0, 60.0, 0))
			_hurt = 1.0


func _nuking(delta: float) -> void:
	if mode != "play" or intro > 0.0:
		return
	_orbital(delta)
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
		_heat_note("NUCLEAR STRIKE AUTHORISED", 2.5)
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
		if t.state != "walk" or t.kind in World.LANDFORMS:
			continue
		if Vector2(t.position.x - at.x, t.position.z - at.z).length() < NUKE_REACH:
			if t.obstacle != Vector4.ZERO:
				world.remove_obstacle(t.chunk, t.obstacle)
			_remove(t)
	var d := Vector2(ufo.position.x - at.x, ufo.position.z - at.z).length()
	if d < NUKE_REACH and not ufo.dead and not ufo.dodging():
		ufo.hurt(lerpf(90.0, 25.0, d / NUKE_REACH), at)
		var away := Vector3(ufo.position.x - at.x, 0, ufo.position.z - at.z)
		ufo.knock = (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 20.0


# ------------------------------------------------------------------ saucers going by on the title

## Seconds till the next saucer streaks across the moon's sky behind the title, and those going by:
## [node, from, to, seconds in, seconds it takes]
var _flyby_wait := 6.0
var _flybys: Array = []


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
	var far := randf_range(45.0, 65.0)
	var high := randf_range(7.0, 14.0)
	var from := camera.global_position + basis * Vector3(-across * far * 0.9, high, -far)
	var to := camera.global_position + basis * Vector3(across * far * 0.9, high + randf_range(-3.0, 4.0), -far * randf_range(0.8, 1.2))
	var tints := {"lights": Color.from_hsv(randf(), 0.6, 1.0), "lights_under": Color.from_hsv(randf(), 0.5, 1.0)}
	var ship_key: String = ["saucer", "orb", "triangle", "cigar", "bell"][randi() % 5]
	var spec: Dictionary = Ufo.SHIPS[ship_key]
	var node := Ps1.model(spec["model"], tints)
	# (someone at the controls)
	var pilot := Alien.new()
	pilot.look_seed = randi()
	pilot.scale = Vector3.ONE * float(spec["alien_size"])
	pilot.position.y = float(spec["alien_y"])
	node.add_child(pilot)
	node.scale = Vector3.ONE * randf_range(0.8, 1.3)
	view.add_child(node)
	_flybys.append([node, from, to, 0.0, randf_range(5.0, 8.0)])
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
	var title: String = Thing.alien_name(t.kind)
	_heat_note("A RIVAL TOOK: " + title, 2.0)
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
				score += int(500 * Thing.WORTH) * multiplier()
				log_line("RIVAL RAMMED", int(500 * Thing.WORTH))
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
	# (a hydrant knocked off: water bursting up out of the main where it stood)
	if t.kind == "hydrant" and t.state != "walk":
		geysers.append(t.home)
	# (a length of track taken up the beam, not just left behind: a gap in the line, see Thing "rail")
	if t.kind == "track" and t.state != "walk":
		torn_track.append(t.home)
	t.state = "gone"
	# (gone, it no longer stands in the way)
	if t.obstacle != Vector4.ZERO:
		world.remove_obstacle(t.chunk, t.obstacle)
		t.obstacle = Vector4.ZERO
	things.erase(t)
	t.queue_free()


## Something reached the saucer
func abducted(t: Thing) -> void:
	if t.kind == "prison":
		_prison_break(t.home)
	if t.kind == "canister":
		_boost(str(t.get_meta("boost", "double")))
		ufo.alien.feel("cheer", 0.9)
		t.state = "gone"
		t.queue_free()
		return
	if t.kind == "pod":
		_bought(t)
		sfx.play("bloop", 1.3)
		ufo.alien.feel("cheer", 0.9)
		t.state = "gone"
		t.queue_free()
		return
	ufo.gulp(t.size() * t.base_size * 0.7)
	_score_pop = 1.0
	coin.last_kind = t.kind
	# (everything taken mends the shield a little, the heavier the more: a chicken a point, a barn a few)
	ufo.hull = minf(ufo.hull + 1.0 + float(t.info["weight"]) * 0.5, ufo.hull_max)
	(_sparks as ScoreSparks).burst(score_label.position + Vector2(score_label.size.x - 40.0, score_label.size.y * 0.5), 14)
	# (GOLD: everything taken worth a tenth more a stack)
	var points := int(t.points() * multiplier() * (1.0 + 0.1 * upgrades["gold"]))
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
		var title: String = Thing.alien_name(t.kind)
		log_line(title, points, t.kind)
		_log_taken[t.kind] = int(_log_taken.get(t.kind, 0)) + 1
		# (the run's takings by category, for the results)
		var group := Thing.category(t.kind)
		var had: Array = _run_taken.get(group, [0, 0])
		_run_taken[group] = [int(had[0]) + 1, int(had[1]) + points]
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
			_count_kill(other.kind)
			_remove(other)
			break


## Everything on wheels or tracks (it blows up if dropped hard: see `landed`)
const VEHICLES: Array[String] = ["car", "pickup", "rv", "tractor", "police_car", "patrol_car", "agent_car", "jeep", "patrol_jeep", "tank"]
## How far an explosion reaches: the police and army in it are destroyed, and everyone else runs
const BLAST_REACH := 7.0


## How much an explosion does to what stands in it (buildings, trees, fences...): BLAST_DAMAGE at its
## middle, less out to its edge, added up toward the thing's size squared, as the laser burns (see
## `_burn`): a car blown up beside a shed takes it down, a house wants two or three
const BLAST_DAMAGE := 9.0
## How hard an explosion throws what is loose round it (m/s at its middle)
const BLAST_SHOVE := 12.0


## `t` blows up where it lies: a fireball, the police and army near it destroyed (scored), other cars
## going up after it one by one, buildings and the like round it damaged or brought down, whatever is
## loose thrown back, people and animals running for it, and the heat up a little
func explode(t: Thing) -> void:
	if t.kind == "prison":
		_prison_break(t.position)
	coop.tell("boom", t.position, "", 4.5)
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
	if t.is_enemy():
		_count_kill(t.kind)
	add_heat(0.3)
	calm = 0.0
	_remove(t)
	var middle := Vector3(at.x, 0, at.z)
	for other: Thing in things.duplicate():
		if other.state != "walk" or not is_instance_valid(other):
			continue
		var d := other.ground().distance_to(middle)
		# (from its near side: a big building is hit though its middle is well off)
		var edge := maxf(d - other.size() * 0.5, 0.0)
		if d < BLAST_REACH and other.is_enemy() and not other.fixed():
			var got := other.points() / 2 * multiplier()
			score += got
			boom(other.position + Vector3(0, 1, 0), 2.5)
			log_line("%s CAUGHT IN THE BLAST" % other.kind.replace("_", " ").to_upper(), got)
			_count_kill(other.kind)
			_remove(other)
			continue
		if edge < BLAST_REACH * 0.8 and (other.kind in VEHICLES or other.info.get("explosive", false)):
			# (another car, or a drum: it goes up a moment later, and may set off the next)
			other.set_meta("blasted", true)
			var held: WeakRef = weakref(other)
			create_tween().tween_callback(func() -> void:
				var still: Thing = held.get_ref()
				if still != null and still.state == "walk":
					explode(still)).set_delay(randf_range(0.2, 0.45))
			continue
		if edge < BLAST_REACH and other.info["move"] == "still" and not other.kind in FIREPROOF:
			_blast(other, BLAST_DAMAGE * (1.0 - edge / BLAST_REACH))
			continue
		if d < BLAST_REACH * 1.6:
			other.panic = 6.0
			var away := other.ground() - middle
			if away.length() > 0.05 and other.info["move"] != "still":
				other.shove = (other.shove + away.normalized() * BLAST_SHOVE * (1.0 - d / (BLAST_REACH * 1.6))).limit_length(BLAST_SHOVE)


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
	var lead := mark + going * (muzzle.distance_to(mark) / 18.0)
	match gun:
		"shotgun":
			for i in 5:
				_shot("pellet", muzzle, lead + Vector3(randf_range(-2.2, 2.2), randf_range(-1, 1), randf_range(-2.2, 2.2)))
			sfx.play("bang", 1.2, _near_db(from))
		"pistol":
			_shot("bullet", muzzle, lead + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
			sfx.play("pop", 1.0, _near_db(from))
		"laser":
			# (a laser truck's: a red bolt, very fast)
			_shot("laser", muzzle, lead + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)))
			sfx.play("zap", 0.7, _near_db(from))
		"railgun":
			# (a rail gun's slug: hardly any time to dodge it)
			_shot("slug", muzzle, mark + going * (muzzle.distance_to(mark) / 70.0))
			sfx.play("boom", 2.0, _near_db(from))
			_shake = maxf(_shake, 0.15)
		"rifle":
			# (a hunter's: one careful shot, close to the mark)
			_shot("bullet", muzzle, lead + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
			sfx.play("bang", 0.8, _near_db(from))
		"ray":
			_shot("ray", muzzle, lead + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2)))
			sfx.play("zap", 1.5, _near_db(from))
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
	# (co-op: down but not out while a friend still flies; their beam over the wreck lifts it back up,
	# see Coop and `revived`)
	if _rescue_wait < 0.0 and coop.active() and coop.friend_up():
		_rescue_wait = RESCUE_WAIT
		boom(ufo.position, 2.0)
		sfx.play("boom", 0.8, 0.0)
		_shake = 0.4
	if _rescue_wait > 0.0:
		_rescue_wait -= delta
		if randf() < delta * 8.0:
			puff(ufo.position + Vector3(0, 0.6, 0), Color(0.18, 0.18, 0.2), 1.0)
		_heat_note("DOWN! A FRIEND CAN BEAM YOU UP  %d" % ceili(_rescue_wait), 0.3)
		if _rescue_wait > 0.0 and coop.friend_up():
			return
		_rescue_wait = 0.0
	boom(ufo.position, 4.0)
	sfx.play("boom", 0.7, 4.0)
	_shake = 0.6
	_wreck_site()
	_crush_under_wreck()
	mode = "over"
	_over_wait = 2.6
	var is_best := score > best and not dev
	if is_best:
		best = score
		_save_best()
	_report(score)
	# (the run over for good: nothing kept to carry on with)
	_saved_run = {}
	over_label.text = _results(is_best)
	_fill_over_items()
	_fit_results(get_viewport().get_visible_rect().size / hud.scale.x)
	over_label.visible_characters = 0
	_over_typing = 0.0
	# (the panel up once the wreck has been seen to, see `_wreck_burning`)
	_over_show = 2.2
	_banner("", 0.0)




## Co-op: beamed back up off the ground by a friend, flying again with half a shield
func revived() -> void:
	_rescue_wait = -1.0
	ufo.revive()
	sfx.play("ding", 1.3, 0.0)
	_heat_note("RESCUED!", 2.0)
	coop.tell("revive", ufo.position, "up")


## One of the police or army (or a jet) destroyed, for the results
func _count_kill(kind: String) -> void:
	if mode == "play":
		_run_killed[kind] = int(_run_killed.get(kind, 0)) + 1


## The results: what was taken, category by category (in the log's order), how many and for how
## much; then the total
func _results(is_best: bool) -> String:
	# (how seriously they had come to take the ship: see `danger`)
	var lines: Array[String] = ["THREAT LEVEL  %s" % THREATS[clampi(_threat, 0, THREATS.size() - 1)], "", "ANALYZED"]
	for group: String in Thing.CATEGORIES:
		if _run_taken.has(group):
			lines.append("   %s x%d  %d" % [group, int(_run_taken[group][0]), int(_run_taken[group][1])])
	if lines.size() == 3:
		lines.append("   NOTHING")
	# (the hunters destroyed, kind by kind)
	if not _run_killed.is_empty():
		lines.append("")
		lines.append("DESTROYED")
		for kind: String in _run_killed:
			lines.append("   %s x%d" % [HUNTERS.get(kind, kind.replace("_", " ").to_upper()), int(_run_killed[kind])])
	# (the items had show under it all as their pictures: see `_fill_over_items`)
	lines.append("")
	lines.append("TOTAL  %d" % score)
	lines.append("BEST  %d%s" % [best, "  (NEW!)" if is_best and score > 0 else ""])
	return "\n".join(lines)

## The results sized for the screen: big for thumbs on an upright phone, and smaller again, a step at
## a time, until all of them (a long run's many lines too) fit its height
func _fit_results(size: Vector2) -> void:
	var upright := size.x < size.y
	var room := size.y - (220.0 if upright else 80.0)
	var text := 62 if upright else 34
	while true:
		over_label.add_theme_font_size_override("font_size", text)
		_over_head.add_theme_font_size_override("font_size", int(text * 1.75))
		_over_items_head.add_theme_font_size_override("font_size", text)
		over_label.add_theme_constant_override("outline_size", maxi(text / 6, 4))
		var big := upright and text > 44
		for b in _over_row.get_children():
			(b as Button).custom_minimum_size = Vector2(500, 140) if big else Vector2(0, 70)
			(b as Button).add_theme_font_size_override("font_size", 62 if big else 40)
		if over_box.get_combined_minimum_size().y <= room or text <= 22:
			break
		text -= 4


## The items had this run, under the results: each its hologram and how many
var _over_items: VBoxContainer
## The results' heading
var _over_head: Label
## How far the results are bobbed from their place just now
var _over_bob := 0.0
var _over_items_head: Label
var _over_icons: HFlowContainer


func _fill_over_items() -> void:
	for old in _over_icons.get_children():
		old.queue_free()
	var big := _upright()
	_over_items_head.add_theme_font_size_override("font_size", over_label.get_theme_font_size("font_size"))
	for what: String in ItemBar.ORDER:
		var n: int = upgrades.get(what, 0)
		if n <= 0:
			continue
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.add_child(holograms.view("item:" + what, 130.0 if big else 54.0))
		var count := _label(54 if big else 24, (UPGRADES[what]["colour"] as Color).lerp(Color.WHITE, 0.35))
		count.text = "x%d" % n
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(count)
		_over_icons.add_child(cell)


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
	_dirt_mound()
	_dirt_mound()



## The ground heaped up where the ship went in: a ring of dirt round its rim (piled highest on the side
## it dug into), clods thrown out, and a dark scar under it
func _dirt_mound() -> void:
	var r: float = ufo.radius
	var dirt := Color(0.3, 0.22, 0.14)
	var dark := Color(0.17, 0.12, 0.08)
	_wreck_bits.append(Ps1.part(view, Ps1.ball(), Ps1.flat(dark), wreck + Vector3(0, -0.15, 0), Vector3(r * 2.6, 0.35, r * 2.6)))
	# (the low side: where the tilt puts the rim into the ground)
	var low := (ufo.body.global_basis.y * Vector3(1, 0, 1)).normalized() * -1.0
	for i in 16:
		var a := TAU * i / 16.0 + randf_range(-0.1, 0.1)
		var way := Vector3(cos(a), 0, sin(a))
		var deep := 0.5 + 0.5 * maxf(way.dot(low), 0.0)
		var at := wreck + way * r * randf_range(0.85, 1.05)
		var size := Vector3(randf_range(1.1, 1.6), randf_range(0.5, 0.9) * deep * 1.6, randf_range(1.1, 1.6)) * (0.6 + 0.4 * deep)
		_wreck_bits.append(Ps1.part(view, Ps1.ball(), Ps1.flat(dirt.lerp(dark, randf() * 0.4)), at, size, Vector3(0, randf() * TAU, 0)))
	for i in 10:
		var a := randf() * TAU
		var at := wreck + Vector3(cos(a), 0, sin(a)) * r * randf_range(1.4, 2.6)
		_wreck_bits.append(Ps1.part(view, Ps1.ball(), Ps1.flat(dirt), at + Vector3(0, 0.05, 0), Vector3.ONE * randf_range(0.2, 0.45), Vector3(randf(), randf(), randf()) * TAU))


# The men in black: if the crash is watched long enough, a black car comes in; one agent bags the
# pilot and carries it off to the car, the other walks to the crowd and flashes them with the
# memory eraser (they forget and wander off); then they drive away
const MIB_COME := 10.0
const MIB_PACE := 0.6
var _wreck_bits: Array[Node3D] = []
var _mib_car: Node3D
var _mib_a: Node3D
var _mib_b: Node3D
var _mib_bag: Node3D
var _mib_stop := Vector3.ZERO
var _mib_from := Vector3.ZERO
var _mib_crowd := Vector3.INF
var _mib_flashed := false
## Whether the agents have got out of the car yet (once: each gets back in by itself later)
var _mib_out := false


func _men_in_black() -> void:
	# (drawn out: their time runs at MIB_PACE of the clock's)
	var t := (_wreck_t - MIB_COME) * MIB_PACE
	if t < 0.0 or not is_instance_valid(_wreck_pilot):
		return
	var body := _wreck_pilot.position
	if _mib_car == null:
		# (in from off to the side, stopping beside the pilot's body)
		var side := Vector3(-_pilot_way.z, 0, _pilot_way.x) if _pilot_way != Vector3.ZERO else Vector3.RIGHT
		_mib_stop = Vector3(body.x, 0, body.z) + side * 5.0
		_mib_from = _mib_stop + side * 55.0 + Vector3(0, 0, -20)
		_mib_car = Ps1.model("car", Thing.KINDS["agent_car"]["tints"])
		view.add_child(_mib_car)
		_wreck_bits.append(_mib_car)
		var suit: Dictionary = Thing.KINDS["agent"]["tints"]
		_mib_a = Ps1.model("person", suit)
		_mib_b = Ps1.model("person", suit)
		for n in [_mib_a, _mib_b]:
			n.visible = false
			view.add_child(n)
			_wreck_bits.append(n)
		# (the crowd come to look: where they stand together)
		var sum := Vector3.ZERO
		var n_crowd := 0
		for th: Thing in things:
			if th.state == "walk" and th.info.get("caller", false) and th.ground().distance_to(wreck) < 25.0:
				sum += th.ground()
				n_crowd += 1
		_mib_crowd = sum / n_crowd if n_crowd > 0 else Vector3.INF
		sfx.play("whoosh", 0.6, -4.0)
	# In: the car slowing to a stop
	if t < 3.0:
		var k := 1.0 - pow(1.0 - t / 3.0, 3.0)
		_place(_mib_car, _mib_from.lerp(_mib_stop, k), _mib_stop - _mib_from)
		return
	var door_a := _mib_stop + (body - _mib_stop).normalized() * 1.6
	var crowd_spot := _mib_crowd + (_mib_stop - _mib_crowd).normalized() * 3.0 if _mib_crowd != Vector3.INF else door_a + Vector3(2, 0, 0)
	# Out of the car, to the body and to the crowd
	if t >= 3.3 and not _mib_out:
		_mib_out = true
		_mib_a.visible = true
		_mib_b.visible = true
		sfx.play("thud", 1.4, -8.0)
	if t >= 3.3 and t < 5.6:
		var k := (t - 3.3) / 2.3
		_walk_to(_mib_a, door_a, body + (door_a - body).normalized() * 0.9, k, t)
		_walk_to(_mib_b, door_a + Vector3(0.8, 0, 0.4), crowd_spot, k, t)
	# The bag: up over the body from the feet, zipped shut
	if t >= 5.6 and t < 7.0:
		if _mib_bag == null:
			_mib_bag = Ps1.part(view, Ps1.ball(), Ps1.flat(Color(0.04, 0.04, 0.05)), Vector3.ZERO, Vector3.ONE)
			_wreck_bits.append(_mib_bag)
			sfx.play("whoosh", 2.0, -8.0)
		var k := smoothstep(0.0, 1.0, (t - 5.6) / 1.2)
		var along := _pilot_way if _pilot_way != Vector3.ZERO else Vector3.FORWARD
		_mib_bag.position = Vector3(body.x, 0.25, body.z)
		_mib_bag.rotation = Vector3(0, atan2(along.x, along.z), 0)
		_mib_bag.scale = Vector3(0.42, 0.32, 1.05 * maxf(k, 0.05)) * _wreck_pilot.scale.x
		if k > 0.9:
			_wreck_pilot.visible = false
	# Back to the car with the bag on a shoulder (and in with it)
	if t >= 7.2 and t < 9.6:
		var k := (t - 7.2) / 2.4
		_walk_to(_mib_a, body + (door_a - body).normalized() * 0.9, door_a, k, t)
		if _mib_bag != null:
			_mib_bag.position = _mib_a.position + Vector3(0, 1.5, 0)
			_mib_bag.rotation = Vector3(0, _mib_a.rotation.y + PI / 2, 0)
	if t >= 9.8 and _mib_bag != null and _mib_bag.visible:
		_mib_a.visible = false
		_mib_bag.visible = false
		sfx.play("thud", 1.4, -8.0)
	_mib_helicopter(t)
	# The flash, once the wreck has gone and the meteor lies in its place: the crowd's memories gone
	if t >= MIB_FLASH and not _mib_flashed:
		_mib_flashed = true
		_neuralyze(_mib_b.position + Vector3(0, 1.6, 0))
	if t >= MIB_FLASH + 0.6 and t < MIB_FLASH + 3.0:
		_walk_to(_mib_b, crowd_spot, door_a + Vector3(0.8, 0, 0.4), (t - MIB_FLASH - 0.6) / 2.4, t)
	if t >= MIB_FLASH + 3.2 and _mib_b.visible:
		_mib_b.visible = false
		sfx.play("thud", 1.4, -8.0)
	# Away, on the way they were going
	var off := MIB_FLASH + 3.8
	if t >= off and t < off + 3.6:
		var k := pow((t - off) / 3.6, 2.0)
		var away := _mib_stop + (_mib_stop - _mib_from).normalized() * 70.0
		_place(_mib_car, _mib_stop.lerp(away, k), away - _mib_stop)
	elif t >= off + 3.6:
		_mib_car.visible = false
	_news(t - off - 5.0)


# The news, once the men in black have gone: two vans pull up by the meteorite, a reporter and a
# camera crew get out, and the camera's light comes on
var _news_vans: Array[Node3D] = []
var _news_crew: Array[Node3D] = []
var _news_light: OmniLight3D


func _news(t: float) -> void:
	if t < 0.0:
		return
	if _news_vans.is_empty():
		for i in 2:
			var van := Ps1.model("rv", {"paint": Color(0.92, 0.92, 0.9)})
			van.scale = Vector3.ONE * 0.85
			view.add_child(van)
			_wreck_bits.append(van)
			_news_vans.append(van)
			var person := Ps1.model("person", {"shirt": [Color(0.75, 0.15, 0.2), Color(0.2, 0.3, 0.6)][i]})
			person.visible = false
			view.add_child(person)
			_wreck_bits.append(person)
			_news_crew.append(person)
		_news_light = OmniLight3D.new()
		_news_light.omni_range = 9.0
		_news_light.light_energy = 0.0
		view.add_child(_news_light)
		_wreck_bits.append(_news_light)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var stop := wreck + Vector3(side * 9.0, 0, 7.0 + i * 2.0)
		var from := stop + Vector3(side * 50.0, 0, 30.0)
		var k := 1.0 - pow(1.0 - clampf((t - i * 1.2) / 3.5, 0.0, 1.0), 3.0)
		_place(_news_vans[i], from.lerp(stop, k), stop - from)
		if t > 4.5 + i:
			var crew := _news_crew[i]
			if not crew.visible:
				crew.visible = true
				sfx.play("thud", 1.3, -10.0)
			var to := wreck + Vector3(side * 3.5, 0, 5.0)
			_walk_to(crew, stop, to, (t - 4.5 - i) / 2.5, t)
			if t > 7.5 + i:
				crew.rotation.y = atan2(wreck.x - crew.position.x, wreck.z - crew.position.z)
	# (the camera's light, on the reporter)
	if t > 8.5:
		_news_light.position = wreck + Vector3(2.0, 2.2, 6.5)
		_news_light.light_energy = 3.0 + 0.3 * sin(t * 30.0)


# Their helicopter: in over the wreck, a cable down to it, and away with it hanging under; then a
# second, a black one, bringing a meteorite in on its own cable and lowering it into the crater in
# the wreck's place (the story everyone will remember), and off again
const MIB_HELI := 6.0
## When the second comes in (on the heels of the first going), is over the crater, and has set the
## meteorite down
const MIB_ROCK := 12.5
const ROCK_OVER := 16.5
const ROCK_DOWN := 18.6
const MIB_FLASH := 19.6
const HELI_UP := 9.0
var _mib_heli: Node3D
var _mib_cable: MeshInstance3D
var _mib_meteor: Node3D
var _wreck_lifted := false
var _heli_from := Vector3.ZERO
var _heli_away := Vector3.ZERO


func _mib_helicopter(t: float) -> void:
	if t < MIB_HELI:
		return
	var over := Vector3(wreck.x, HELI_UP, wreck.z)
	if _mib_heli == null:
		_mib_heli = Ps1.model("chinook")
		view.add_child(_mib_heli)
		_wreck_bits.append(_mib_heli)
		_heli_from = over + Vector3(-70, 22, -50)
		_heli_away = over + Vector3(80, 30, -60)
		_mib_cable = Ps1.part(view, BoxMesh.new(), Ps1.flat(Color(0.12, 0.12, 0.13)), over, Vector3(0.08, 0.01, 0.08))
		_mib_cable.visible = false
		_wreck_bits.append(_mib_cable)
	# (rotors turning all the while, and their beat)
	for r: Node3D in _mib_heli.find_children("rotor*", "Node3D", true, false):
		r.rotation.y += 0.9
	if fmod(t, 0.5) < 0.02:
		sfx.play("whoosh", 0.45, -14.0)
	var at := over
	if t < MIB_HELI + 4.0:
		var k := smoothstep(0.0, 1.0, (t - MIB_HELI) / 4.0)
		at = _heli_from.lerp(over, k)
		_mib_heli.rotation.y = atan2(over.x - _heli_from.x, over.z - _heli_from.z)
	elif t >= MIB_HELI + 6.5:
		# (away, the wreck swinging under it)
		var k := pow(clampf((t - MIB_HELI - 6.5) / 5.0, 0.0, 1.0), 1.6)
		at = over.lerp(_heli_away, k)
		_mib_heli.rotation.y = lerp_angle(_mib_heli.rotation.y, atan2(_heli_away.x - over.x, _heli_away.z - over.z), 0.05)
		if k >= 1.0:
			_mib_heli.visible = false
			ufo.visible = false
			_mib_cable.visible = false
	_mib_heli.position = at + Vector3(0, sin(t * 2.0) * 0.2, 0)
	# The cable, down to the wreck, then taking it up
	var hook := _mib_heli.position + Vector3(0, -1.2, 0)
	if t >= MIB_HELI + 4.0 and _mib_heli.visible:
		var drop := clampf((t - MIB_HELI - 4.0) / 1.2, 0.0, 1.0)
		var bottom := hook.lerp(wreck + Vector3(0, 1.0, 0), drop)
		if t >= MIB_HELI + 5.5:
			# (lifting: the wreck hangs a little under the hook, the fire out)
			if not _wreck_lifted:
				_wreck_lifted = true
				sfx.play("clang", 0.7, -4.0)
			var lift := smoothstep(0.0, 1.0, (t - MIB_HELI - 5.5) / 1.6)
			var hang := hook + Vector3(0, -3.2, 0)
			ufo.position = (wreck + Vector3(0, 0.6, 0)).lerp(hang, lift)
			ufo.body.rotation.x = lerpf(0.5, 0.15 * sin(t * 1.7), lift)
			bottom = ufo.position + Vector3(0, 0.6, 0)
		_mib_cable.visible = true
		_mib_cable.position = (hook + bottom) * 0.5
		_mib_cable.scale = Vector3(0.08, maxf(hook.y - bottom.y, 0.05), 0.08)
	_mib_rock(t)


var _rock_heli: Node3D
var _rock_cable: MeshInstance3D
var _rock_hung: Node3D
var _rock_from := Vector3.ZERO
var _rock_away := Vector3.ZERO
## How far under the hook the rock's top hangs while it is carried
const ROCK_HANG := 4.0


## The second helicopter: in with the meteorite hanging under it, down over the crater, the rock
## let down into it on the cable, the cable let go and wound up, and away
func _mib_rock(t: float) -> void:
	if t < MIB_ROCK:
		return
	var over := Vector3(wreck.x, HELI_UP + 1.5, wreck.z)
	if _rock_heli == null:
		_rock_heli = Ps1.model("helicopter", {"police_blue": Color(0.07, 0.07, 0.08), "white": Color(0.2, 0.2, 0.22)})
		_rock_heli.scale = Vector3.ONE * 1.2
		view.add_child(_rock_heli)
		_wreck_bits.append(_rock_heli)
		# (in from the other side to the first, which is still leaving)
		_rock_from = over + Vector3(75, 24, 40)
		_rock_away = over + Vector3(-80, 30, 50)
		_rock_cable = Ps1.part(view, BoxMesh.new(), Ps1.flat(Color(0.12, 0.12, 0.13)), over, Vector3(0.09, 0.01, 0.09))
		_wreck_bits.append(_rock_cable)
		# (the rock as it hangs: the meteorite without the rubble it will lie in, see below)
		_rock_hung = Node3D.new()
		view.add_child(_rock_hung)
		_wreck_bits.append(_rock_hung)
		Ps1.part(_rock_hung, Ps1.ball(), Ps1.mat(Color(0.06, 0.06, 0.07)), Vector3(0, -0.75, 0), Vector3(2.1, 1.45, 1.75))
		for glow: Vector3 in [Vector3(0.55, -0.45, 0.45), Vector3(-0.6, -0.9, 0.35), Vector3(0.1, -1.1, -0.65)]:
			Ps1.part(_rock_hung, Ps1.ball(), Ps1.mat(Color(0.4, 1.0, 0.5), 1.6), glow, Vector3(0.75, 0.6, 0.75))
	for r: Node3D in _rock_heli.find_children("rotor*", "Node3D", true, false):
		r.rotation.y += 0.9
	var at := over
	if t < ROCK_OVER:
		var k := smoothstep(0.0, 1.0, (t - MIB_ROCK) / (ROCK_OVER - MIB_ROCK))
		at = _rock_from.lerp(over, k)
		_rock_heli.rotation.y = atan2(over.x - _rock_from.x, over.z - _rock_from.z)
		# (nose down coming in, levelling off over the crater)
		_rock_heli.rotation.x = 0.25 * (1.0 - k)
	elif t >= ROCK_DOWN + 1.2:
		var k := pow(clampf((t - ROCK_DOWN - 1.2) / 5.0, 0.0, 1.0), 1.6)
		at = over.lerp(_rock_away, k)
		_rock_heli.rotation.y = lerp_angle(_rock_heli.rotation.y, atan2(_rock_away.x - over.x, _rock_away.z - over.z), 0.05)
		_rock_heli.rotation.x = 0.2 * minf(k * 4.0, 1.0)
		if k >= 1.0:
			_rock_heli.visible = false
	else:
		_rock_heli.rotation.x = 0.0
	_rock_heli.position = at + Vector3(0, sin(t * 2.3) * 0.18, 0)
	var hook := _rock_heli.position + Vector3(0, 0.3, 0)
	# The rock: hanging under it, swinging a little, let down into the crater, and let go
	var ground_top := wreck + Vector3(0, 1.4, 0)
	var top: Vector3
	if t < ROCK_OVER:
		top = hook + Vector3(sin(t * 1.3) * 0.3, -ROCK_HANG, 0)
	elif t < ROCK_DOWN:
		var k := smoothstep(0.0, 1.0, (t - ROCK_OVER) / (ROCK_DOWN - ROCK_OVER))
		top = (hook + Vector3(0, -ROCK_HANG, 0)).lerp(ground_top, k)
	else:
		top = ground_top
	if _mib_meteor == null:
		_rock_hung.position = top
		_rock_hung.rotation.y = t * 0.3
		if t >= ROCK_DOWN:
			# (down: in its bed of rubble, a thud, dust and a shake)
			_rock_hung.visible = false
			_mib_meteor = Ps1.model("meteorite")
			_mib_meteor.position = wreck + Vector3(0, -0.2, 0)
			_mib_meteor.rotation.y = _rock_hung.rotation.y
			_mib_meteor.scale = Vector3.ONE * 1.6
			view.add_child(_mib_meteor)
			_wreck_bits.append(_mib_meteor)
			for i in 10:
				var a := randf() * TAU
				ufo.puffs.puff(wreck + Vector3(cos(a), 0, sin(a)) * randf_range(1.2, 2.4) + Vector3(0, 0.3, 0), Color(0.35, 0.28, 0.2, 0.7), randf_range(0.7, 1.2), Vector3(cos(a) * 1.5, 0.9, sin(a) * 1.5), 1.6)
			sfx.play("thud", 0.6, 2.0)
			sfx.play("clang", 0.9, -8.0)
			_shake = maxf(_shake, 0.12)
	# The cable: down to the rock, then wound back up once it is let go
	var bottom := top
	if t >= ROCK_DOWN + 0.2:
		var wind := clampf((t - ROCK_DOWN - 0.2) / 0.9, 0.0, 1.0)
		bottom = ground_top.lerp(hook, wind)
	_rock_cable.visible = _rock_heli.visible and hook.y - bottom.y > 0.06
	_rock_cable.position = (hook + bottom) * 0.5
	_rock_cable.scale = Vector3(0.09, maxf(hook.y - bottom.y, 0.05), 0.09)


## A model put at `at` (on the ground), facing `way`
func _place(n: Node3D, at: Vector3, way: Vector3) -> void:
	n.position = Vector3(at.x, 0, at.z)
	if Vector2(way.x, way.z).length() > 0.01:
		n.rotation.y = atan2(way.x, way.z)


## A figure `k` of the way walking from one place to another, bobbing as it goes
func _walk_to(n: Node3D, from: Vector3, to: Vector3, k: float, t: float) -> void:
	k = clampf(k, 0.0, 1.0)
	_place(n, from.lerp(to, smoothstep(0.0, 1.0, k)), to - from)
	if k < 1.0:
		n.position.y = absf(sin(t * 9.0)) * 0.08


## The memory eraser: a white flash, and everyone come to look forgets what they saw, and wanders off
func _neuralyze(at: Vector3) -> void:
	_blob(at, Color(1, 1, 1), 1.4, 0.15)
	var light := OmniLight3D.new()
	light.light_energy = 6.0
	light.omni_range = 20.0
	light.position = at
	view.add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.5)
	tw.tween_callback(light.queue_free)
	sfx.play("zap", 2.2, -2.0)
	for th: Thing in things:
		if th.state == "walk" and th.info.get("caller", false) and th.ground().distance_to(at) < 30.0:
			th.set_meta("forgot", true)
			Ps1.flash(th.model, Color(1.5, 1.5, 1.5))
			var held: WeakRef = weakref(th)
			create_tween().tween_callback(func() -> void:
				var still: Thing = held.get_ref()
				if still != null:
					Ps1.flash(still.model, Color.BLACK)).set_delay(0.3)


## The wreck and its pilot gone (a new run, or back to the title)
func _clear_wreck() -> void:
	wreck = Vector3.INF
	_over_show = 0.0
	for n in _wreck_bits:
		if is_instance_valid(n):
			n.queue_free()
	_wreck_bits.clear()
	_mib_car = null
	_mib_a = null
	_mib_b = null
	_mib_bag = null
	_mib_flashed = false
	_mib_out = false
	if over_box != null:
		over_box.position.y -= _over_bob
	_over_bob = 0.0
	_news_vans.clear()
	_news_crew.clear()
	_news_light = null
	_mib_heli = null
	_mib_cable = null
	_mib_meteor = null
	_wreck_lifted = false
	_rock_heli = null
	_rock_cable = null
	_rock_hung = null
	if is_instance_valid(_wreck_pilot):
		_wreck_pilot.queue_free()
	_wreck_pilot = null
	_pilot_way = Vector3.ZERO
	_pilot_down = false
	if is_instance_valid(_wreck_ship):
		_wreck_ship.queue_free()
	_wreck_ship = null



## The crashed pilot's run: how long before it is gunned down, the way it is running, and whether it is
## down
const PILOT_SHOT := 5.2
var _pilot_way := Vector3.ZERO
var _pilot_down := false


## Away from the police and army about the wreck (or, with none, from the crowd come to look)
func _flee_way(from: Vector3) -> Vector3:
	var away := Vector3.ZERO
	for t in things:
		if t.state == "walk" and (t.is_enemy() or t.info.get("caller", false)):
			var off := Vector3(from.x - t.position.x, 0, from.z - t.position.z)
			if off.length() < 60.0 and off.length() > 0.1:
				away += off.normalized() / maxf(off.length(), 3.0)
	if away.length() < 0.001:
		var a := randf() * TAU
		away = Vector3(cos(a), 0, sin(a))
	return away.normalized()


## The pilot gunned down where it runs: a burst of shots at it from the nearest police or army (or out
## of the dark, with none near), and it drops flat and lies still
func _gun_down(pilot: Node3D) -> void:
	_pilot_down = true
	var from := pilot.position + Vector3(-_pilot_way.x, 0, -_pilot_way.z) * 14.0 + Vector3(0, 1.2, 0)
	var nearest := 60.0
	for t in things:
		if t.state == "walk" and t.is_enemy() and t.position.distance_to(pilot.position) < nearest:
			nearest = t.position.distance_to(pilot.position)
			from = t.muzzle()
	var tw := create_tween()
	for i in 5:
		tw.tween_callback(func() -> void:
			if is_instance_valid(pilot):
				_shot("bullet", from, pilot.position + Vector3(randf_range(-0.3, 0.3), 0.6, randf_range(-0.3, 0.3)))
				sfx.play("pop", randf_range(0.9, 1.1), -2.0)
				ufo.puffs.spark(pilot.position + Vector3(0, 0.6, 0), Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2)), Color(0.4, 1.0, 0.5)))
		tw.tween_interval(0.12)
	# (struck: thrown forward and down, flat on the ground, still)
	tw.tween_callback(func() -> void:
		if is_instance_valid(pilot):
			pilot.feel("dead")
			sfx.play("thud", 0.8))
	tw.tween_property(pilot, "rotation:x", PI / 2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pilot, "position", pilot.position + _pilot_way * 1.4 + Vector3(0, -0.05, 0), 0.35)
## The wreck burning: smoke and fire off it, sparks now and then, the pilot staggering about by it;
## and the score panel up after a moment
func _wreck_burning(delta: float) -> void:
	if wreck == Vector3.INF:
		return
	_wreck_t += delta
	# (the results bobbing slowly up and down, hanging there like a hologram)
	var bob := sin(_wreck_t * 1.1) * 7.0
	over_box.position.y += bob - _over_bob
	_over_bob = bob
	if randf() < delta * 9.0 and not _wreck_lifted:
		ufo.puffs.puff(wreck + Vector3(randf_range(-1.5, 1.5), 1.2, randf_range(-1.5, 1.5)), Color(0.15, 0.15, 0.17, 0.8), randf_range(0.8, 1.4), Vector3(0.3, 2.5, 0.1), 2.2)
	if randf() < delta * 5.0 and not _wreck_lifted:
		ufo.puffs.puff(wreck + Vector3(randf_range(-1.2, 1.2), 0.9, randf_range(-1.2, 1.2)), Color(1.0, 0.5, 0.12, 0.85), randf_range(0.5, 0.9), Vector3(0, 2.0, 0), 0.5)
	if randf() < delta * 1.5 and not _wreck_lifted:
		for i in 4:
			ufo.puffs.spark(wreck + Vector3(0, 1.0, 0), Vector3(randf_range(-1, 1), randf_range(0.5, 1.4), randf_range(-1, 1)) * randf_range(3.0, 6.0))
	if _wreck_t > 2.6 and _wreck_t < PILOT_SHOT and is_instance_valid(_wreck_pilot):
		# (up and running for it, away from whoever is about, bobbing, stumbling)
		if _pilot_way == Vector3.ZERO:
			_pilot_way = _flee_way(_wreck_pilot.position)
			_wreck_pilot.feel("hurt", 9.0)
		_wreck_pilot.position += _pilot_way * delta * 3.2
		_wreck_pilot.position.y = 0.25 + absf(sin(_wreck_t * 11.0)) * 0.22
		_wreck_pilot.rotation = Vector3(0.25, atan2(_pilot_way.x, _pilot_way.z), sin(_wreck_t * 11.0) * 0.18)
	elif _wreck_t >= PILOT_SHOT and not _pilot_down and is_instance_valid(_wreck_pilot):
		_gun_down(_wreck_pilot)
	_men_in_black()
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
			# (a typewriter: a key struck for each letter, the bell at the end of a line)
			var ch := over_label.text[over_label.visible_characters - 1]
			if ch == "\n":
				sfx.play("ding", 1.0, -10.0)
			elif ch != " ":
				sfx.play("key", randf_range(0.9, 1.15), -8.0)
		_over_row.visible = over_label.visible_characters >= over_label.text.length()
		_over_items.visible = _over_row.visible and _over_icons.get_child_count() > 0
		_replay_button.visible = not coop.active()



## Lines for the log waiting their turn (see _type_log): [text, points, kind, how many]
var _log_queue: Array = []


## A line for the log under the score, queued: each is typed out in turn, after the one before it,
## so none is lost when many come at once; the same thing taken again while it waits is folded into
## it ("EAR STALK x3")
func log_line(text: String, points: int, kind := "") -> void:
	if not _log_queue.is_empty():
		var last: Array = _log_queue[-1]
		if last[0] == text and last[2] == kind:
			last[1] += points
			last[3] += 1
			return
	_log_queue.append([text, points, kind, 1])


## The line put up: typed out a letter at a time (`points` after it, if any), a little hologram of
## the `kind` of thing before it
func _log_now(text: String, points: int, kind := "") -> void:
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
	# (the next line waiting goes up once the newest is typed out)
	var count := log_box.get_child_count()
	var newest: Label = log_box.get_child(count - 1) if count > 0 else null
	if not _log_queue.is_empty() and (newest == null or newest.visible_characters < 0 or newest.visible_characters >= newest.text.length()):
		var next: Array = _log_queue.pop_front()
		_log_now(next[0] if int(next[3]) == 1 else "%s x%d" % [next[0], next[3]], next[1], next[2])
	for line: Label in log_box.get_children():
		if line.visible_characters >= 0 and line.visible_characters < line.text.length():
			# (typed quicker the more lines are waiting behind it)
			_typing += delta * LOG_SPEED * (1.0 + 0.6 * _log_queue.size())
			var more := int(_typing)
			_typing -= more
			line.visible_characters = mini(line.visible_characters + more, line.text.length())
			# (a typewriter, as the results are: a key struck for each letter, the bell at the line's end)
			if more > 0:
				if line.visible_characters >= line.text.length():
					sfx.play("ding", 1.1, -14.0)
				elif line.text[line.visible_characters - 1] != " ":
					sfx.play("key", randf_range(0.95, 1.2), -12.0)
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
	if OS.has_feature("web") and points > 0 and not testing and not dev:
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % points)


# ------------------------------------------------------------------ the autopilot

## Flies the saucer behind the title, and for the tests: to the nearest thing worth taking, beam
## on over it until it is in, away from anything shooting when the shield is low
func _pilot(delta: float) -> Array:
	if _pilot_target != null and (not is_instance_valid(_pilot_target) or _pilot_target.state == "gone"):
		_pilot_target = null
	# (after the same one too long without it coming up: it cannot be got, so on to another)
	_pilot_for += delta
	if _pilot_target != null and _pilot_for > 8.0 and _pilot_target.state != "lifted":
		_pilot_target.set_meta("pilot_skip", true)
		_pilot_target = null
	if _pilot_target == null:
		_pilot_for = 0.0
		var best_score := -INF
		for t in things:
			# (it never catches up with a car)
			if t.state == "gone" or (t.is_enemy() and mode == "title") or t.info["move"] == "road" or t.tier() > mini(pilot_tier, ufo.tier) or (t.fixed() and pilot_tier <= 1) or t.kind in ["rival", "pod"] or t.has_meta("pilot_skip"):
				continue
			var d := t.ground().distance_to(ufo.ground())
			if d > 60.0:
				continue
			var worth := sqrt(float(t.points())) / (1.0 + float(t.info["weight"])) - d * 0.3
			if worth > best_score:
				best_score = worth
				_pilot_target = t
	if _pilot_target == null:
		if mode != "play":
			return [Vector2.ZERO, false]
		# (nothing near worth taking: on across the country, turning now and then, to find some)
		_pilot_roam_for -= delta
		if _pilot_roam_for <= 0.0:
			_pilot_roam_for = randf_range(6.0, 12.0)
			_pilot_roam = _pilot_roam.rotated(randf_range(-1.2, 1.2))
		return [_pilot_roam, false]
	var to := _pilot_target.ground() - ufo.ground()
	var flat := Vector2(to.x, to.z)
	var over := flat.length() < 1.2 or _pilot_target.state == "lifted"
	var steer := flat.normalized() * clampf(flat.length() / 2.0, 0.0, 1.0)
	return [steer, over or flat.length() < 2.4]


# ------------------------------------------------------------------ effects

## An explosion at `at`, about `size` across (see Boom: a cartoon one, as in The Wind Waker)
func boom(at: Vector3, size: float) -> void:
	var b := Boom.new()
	b.size = size * 0.8
	b.position = at
	view.add_child(b)


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
	camera.position = ufo.position - Vector3(0, _arrive(), 0) + _chase(away).slerp(normal_from, settle)
	var normal_way := (Vector3(0, -ufo.altitude * (1.0 - _look_up()), 0) - normal_from).normalized()
	var way := away.slerp(normal_way, settle)
	camera.look_at(camera.position + way, Vector3.UP if absf(way.y) < 0.99 else Vector3.FORWARD)
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(ufo.position.x, 0.0, ufo.position.z - 1.0))
	RenderingServer.global_shader_parameter_set("saucer_pos", ufo.position)
	_sky_mat.set_shader_parameter("space", 1.0 - smoothstep(0.3, 0.85, k))
	camera.environment.fog_density = 0.006 * smoothstep(0.55, 1.0, k)


## On the moon: low beside the chair, the ship and Earth in the picture; in the launch it rises


## The moon in the sky over the world, as Earth is over the moon: still, at one place in the sky,
## and the camera moving under it (it comes into the picture as the descent swings round, and goes
## out of it on the way home). Where it is: up in the top right of the picture as the game's
## camera sees it in play, worked out once (again if the screen's shape changes).
## (where it shows in the picture in play, a phone's and a wide screen's; and how far off its ball is,
## within the camera's reach)
const MOON_BALL_FAR := 230.0
var _moon_ball: MeshInstance3D
const MOON_UPRIGHT := Vector2(0.72, 0.17)
const MOON_WIDE := Vector2(0.3, 0.15)

func _place_moon(_delta: float) -> void:
	if _moon_dir == Vector3.ZERO:
		_moon_dir = _moon_in_play()
	# (no disc in the sky shader: a real ball, far off along that way, kept there as the camera moves)
	_sky_mat.set_shader_parameter("moon_fade", 0.0)
	if _moon_ball == null:
		_moon_ball = MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = MOON_BALL_FAR * 0.049
		ball.height = ball.radius * 2.0
		ball.radial_segments = 48
		ball.rings = 24
		_moon_ball.mesh = ball
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/moon_ball.gdshader")
		m.set_shader_parameter("map", load("res://textures/moon_lroc.jpg"))
		_moon_ball.material_override = m
		_moon_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.add_child(_moon_ball)
		# (a soft glow round it, on a square just behind it, turned to the camera with it)
		var glow := MeshInstance3D.new()
		var square := QuadMesh.new()
		square.size = Vector2.ONE * ball.radius * 6.0
		glow.mesh = square
		var gm := ShaderMaterial.new()
		gm.shader = load("res://shaders/moon_glow.gdshader")
		glow.material_override = gm
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = Vector3(0, 0, -ball.radius * 1.05)
		_moon_ball.add_child(glow)
	_moon_ball.visible = true
	# (turned round with the stars through the trip from the moon: see _sky_spin)
	var way := Basis(Vector3.UP, -PI * (1.0 - _sky_spin())) * _moon_dir
	_moon_ball.global_position = camera.global_position + way * MOON_BALL_FAR
	# (its near side to us)
	_moon_ball.look_at(camera.global_position, Vector3.UP, true)





## The best-known bright stars, drawn crisp over the star map (see sky.gdshader `bright_stars`):
## right ascension and declination (degrees) and magnitude. The Big Dipper, Orion, Cassiopeia, and
## the brightest of the rest
const BRIGHT_STARS := [
	[165.9, 61.75, 1.8], [165.5, 56.4, 2.4], [178.5, 53.7, 2.4], [183.9, 57.0, 3.3], [193.5, 55.96, 1.8], [200.98, 54.9, 2.2], [206.9, 49.3, 1.9],
	[88.8, 7.4, 0.5], [81.3, 6.35, 1.6], [85.2, -1.94, 1.8], [84.05, -1.2, 1.7], [83.0, -0.3, 2.2], [86.9, -9.67, 2.1], [78.6, -8.2, 0.1],
	[2.3, 59.1, 2.3], [10.1, 56.5, 2.2], [14.2, 60.7, 2.4], [21.45, 60.2, 2.7], [28.6, 63.7, 3.4],
	[37.95, 89.26, 2.0], [101.3, -16.7, -1.5], [279.2, 38.8, 0.0], [213.9, 19.2, -0.1], [79.2, 46.0, 0.1],
	[68.98, 16.5, 0.9], [310.4, 45.3, 1.3], [297.7, 8.9, 0.8], [152.1, 11.97, 1.4], [114.8, 5.2, 0.4], [116.3, 28.0, 1.1],
]



## The stars as turned by `_hang_sky`, and how far round the trip from the moon has carried them:
## on the moon the whole sky is half a turn round from Earth's, and it swings round through the
## lift-off and the descent (back again on the way home), so the moon left behind is behind
var _sky_base := Basis.IDENTITY


func _sky_spin() -> float:
	match mode:
		"title":
			return 0.0
		"launch":
			return 0.5 * smoothstep(LIFT, LAUNCH, _launch_t)
		"landing":
			return 0.5 * smoothstep(LIFT, LAUNCH, _launch_t)
		"return":
			return 1.0 - 0.5 * (intro / INTRO)
	if intro > 0.0:
		return 0.5 + 0.5 * smoothstep(0.0, 1.0, 1.0 - intro / INTRO)
	return 1.0


func _turn_sky() -> void:
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("sky_turn", _sky_base * Basis(Vector3.UP, PI * (1.0 - _sky_spin())))

## The bright stars as directions in the star map's own terms and brightnesses, for the sky shader
func _bright_stars() -> PackedVector4Array:
	var out := PackedVector4Array()
	for st: Array in BRIGHT_STARS:
		var ra := deg_to_rad(float(st[0]))
		var dec := deg_to_rad(float(st[1]))
		out.append(Vector4(sin(ra) * cos(dec), sin(dec), -cos(ra) * cos(dec), clampf(1.0 - float(st[2]) / 4.0, 0.2, 1.4)))
	out.resize(40)
	return out

## Where the Big Dipper stands in the picture in play (a phone's and a wide screen's)
const DIPPER_UPRIGHT := Vector2(0.56, 0.12)
const DIPPER_WIDE := Vector2(0.74, 0.19)


## The stars turned, once (and again if the screen's shape changes), so that the Big Dipper hangs over
## the fields in play, in the strip of sky over the curve of the world (Orion is too tall to fit it);
## the same turn everywhere, on
## the moon and in space too, so nothing in the sky ever jumps
func _hang_sky() -> void:
	var w := _moon_in_play(DIPPER_UPRIGHT if _upright() else DIPPER_WIDE)
	# (the Dipper's middle in the map's own terms: right ascension 184 degrees, declination 56)
	var ra := deg_to_rad(184.0)
	var dec := deg_to_rad(56.0)
	var s := Vector3(sin(ra) * cos(dec), sin(dec), -cos(ra) * cos(dec))
	var world := Basis(Vector3.UP.cross(w).normalized(), w.cross(Vector3.UP.cross(w)).normalized(), w)
	var stars := Basis(Vector3.UP.cross(s).normalized(), s.cross(Vector3.UP.cross(s)).normalized(), s)
	_sky_base = stars * world.transposed()
## Where in the sky the top right of the picture is, from the camera as it is in play
func _moon_in_play(at := Vector2.ZERO) -> Vector3:
	var was := camera.global_transform
	var was_fov := camera.fov
	var off := _camera_offset()
	var look := Vector3(0, ufo.altitude * _look_up(), 0)
	camera.global_transform = Transform3D(Basis.IDENTITY, off).looking_at(look, Vector3.UP)
	camera.fov = _fov()
	var v := camera.get_viewport().get_visible_rect().size
	if at == Vector2.ZERO:
		at = MOON_UPRIGHT if _upright() else MOON_WIDE
	var d := camera.project_ray_normal(v * at)
	camera.global_transform = was
	camera.fov = was_fov
	return d
func _moon_camera(delta: float) -> void:
	var site := MoonSet.SITE
	# (the moon's ball still placed: on the moon it is turned round behind, with the stars)
	_place_moon(delta)
	# (close on the pilot up on the ship, Earth over its shoulder, in the middle of the picture between
	# the title above and the buttons below, on a phone or a wide screen alike)
	var at := site + Vector3(0.13, 2.0, 2.31)
	var look := site + Vector3(6.15, 2.0, -5.68)
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
	# (nothing to see through on the moon: the point at the camera itself, so that nothing is ever
	# "between" them; a point far off would have the ship under the camera taken for in the way)
	RenderingServer.global_shader_parameter_set("saucer_pos", camera.position)
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
		# (the results never over the wreck in the middle of the screen: on a phone just above it; on
		# a wide screen beside it, on the left, in the middle of the height, all of it on the screen)
		if upright:
			# (on a phone: across the screen, in the middle of its height, all of it on the screen: see
			# `_fit_results`)
			over_box.set_anchors_preset(Control.PRESET_CENTER)
			over_box.custom_minimum_size = Vector2(1120, 0)
			over_box.offset_left = -560.0
			over_box.offset_right = 560.0
			over_box.grow_vertical = Control.GROW_DIRECTION_BOTH
			over_box.offset_top = 0.0
			over_box.offset_bottom = 0.0
		else:
			over_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			over_box.custom_minimum_size = Vector2(520, 0)
			over_box.offset_left = 40.0
			over_box.offset_right = 560.0
			over_box.grow_vertical = Control.GROW_DIRECTION_BOTH
			over_box.offset_top = 0.0
			over_box.offset_bottom = 0.0
	# (the results' text and buttons sized for thumbs on an upright phone)
	if over_label != null:
		_fit_results(size)
	if upright:
		title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title_box.offset_left = 40.0
		title_box.offset_right = -40.0
		title_box.offset_top = 150.0
		# (low: the last row of buttons just above the bottom of the screen)
		title_box.offset_bottom = -36.0
		title_box.custom_minimum_size = Vector2.ZERO
	else:
		# (on a wide screen too: the name over the ship and the buttons under it, all centred on it)
		title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title_box.offset_left = 30.0
		title_box.offset_right = -30.0
		title_box.offset_top = 24.0
		title_box.offset_bottom = -10.0
		title_box.custom_minimum_size = Vector2.ZERO
	_title_gap.visible = true
	# (the name on one line, glowing: as big as it fits across the box, up to a modest size)
	var room := size.x - 80.0 - 24.0
	var name_size := 76 if upright else 56
	while name_size > 24 and font.get_string_size(_title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x * TitleArt.SPREAD > room:
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
	# (as many as there are across an upright phone: smaller, the more of them)
	var n := _title_row.get_child_count()
	var crowded := upright and n > 3
	for b in _title_row.get_children():
		var w := minf(250.0, (1180.0 - 20.0 * (n - 1)) / n) if upright else 170.0
		(b as Button).custom_minimum_size = Vector2(w, 110) if upright else Vector2(w, 60)
		(b as Button).add_theme_font_size_override("font_size", 42 if crowded else (52 if upright else 32))
		if crowded:
			for state in ["normal", "hover", "pressed", "focus"]:
				var box := (b as Button).get_theme_stylebox(state).duplicate() as StyleBoxFlat
				box.content_margin_left = 12
				box.content_margin_right = 12
				(b as Button).add_theme_stylebox_override(state, box)
	for b in _quit_row.get_children():
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
	_log_scroll = scroll
	_log_list = VBoxContainer.new()
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_log_list)
	_log_back = _button("BACK", close_log)
	box.add_child(_log_back)
	_log_head = head


var _log_made := ""
func open_log() -> void:
	if mode != "title":
		return
	# (made afresh only when something new is in it since it was last made: it is a lot to build)
	var now := str([_log_taken, _log_met, _log_items, _upright()])
	if now != _log_made:
		_log_made = now
		_fill_log()
	title_box.visible = false
	_log_box.visible = true


func close_log() -> void:
	_log_box.visible = false
	title_box.visible = mode == "title"



# ------------------------------------------------------------------ modes and the saucers

## How the next run is played: alone, or with others (see Net); picked with the arrows by PLAY
const MODES := ["single", "host", "join"]
## (what the big button says for each: PLAY alone, or HOST or JOIN a multiplayer room)
const MODE_TITLES := {"single": "PLAY", "host": "HOST", "join": "JOIN"}
var play_mode := "single"


func _pick_mode(step: int) -> void:
	play_mode = MODES[posmod(MODES.find(play_mode) + step, MODES.size())]
	sfx.play("click", 1.2, -6.0)
	_show_ship()


## The saucers: a hologram of each, to pick from (those not yet found greyed out, LOCKED)
func open_saucers() -> void:
	if mode != "title":
		return
	for old in _log_list.get_children():
		old.queue_free()
	var big := _upright()
	_log_head.text = "SAUCERS"
	_log_head.add_theme_font_size_override("font_size", 110 if big else 56)
	_log_back.custom_minimum_size = Vector2(420, 140) if big else Vector2(260, 70)
	_log_back.add_theme_font_size_override("font_size", 72 if big else 40)
	var grid := GridContainer.new()
	grid.columns = 2 if big else 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_list.add_child(grid)
	for s: String in Ufo.ORDER:
		var spec: Dictionary = Ufo.SHIPS[s]
		var have := s in unlocked
		var b := _button("", func() -> void: _choose_ship(s))
		b.custom_minimum_size = Vector2(300, 300) if big else Vector2(220, 200)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# (the saucer as a hologram, flickering and scanning as the log's do, filling the tile over its
		# name, which sits along the bottom)
		var tile := VBoxContainer.new()
		tile.set_anchors_preset(Control.PRESET_FULL_RECT)
		tile.offset_left = 8.0
		tile.offset_right = -8.0
		tile.offset_top = 8.0
		tile.offset_bottom = -8.0
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tile)
		var holo := holograms.view(s, 60.0)
		holo.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_child(holo)
		var name_l := _label(40 if big else 26, Color(1.0, 0.95, 0.5) if s == ship else Color(0.85, 1.0, 0.86))
		name_l.text = spec["title"] if have else "%s  LOCKED" % spec["title"]
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(name_l)
		if not have:
			b.disabled = true
			b.modulate = Color(0.45, 0.45, 0.45)
		grid.add_child(b)
	title_box.visible = false
	_log_box.visible = true


func _choose_ship(s: String) -> void:
	if not s in unlocked:
		return
	ship = s
	var at := ufo.ground()
	ufo.queue_free()
	_make_ufo(at)
	_park_ufo()
	_show_ship()
	_save_best()
	close_log()


# ------------------------------------------------------------------ the multiplayer lobby

var _lobby_box: VBoxContainer
var _lobby_dim: ColorRect
var _lobby_text: Label
var _lobby_code: LineEdit
var _lobby_host: Button
var _lobby_join: Button
var _lobby_start: Button
var _lobby_leave: Button


## The big button on the title: PLAY, off at once alone; HOST, a multiplayer room of our own; JOIN,
## a friend's, by its code
func _play_pressed() -> void:
	if mode != "title" or (_lobby_box != null and _lobby_box.visible):
		return
	match play_mode:
		"host":
			# (straight into a room of our own, its code to give friends)
			open_lobby()
			_lobby_say("Making a room...")
			net.create(ship)
		"join":
			open_lobby()
		_:
			begin_launch()


func _build_lobby(root: Control) -> void:
	_lobby_dim = ColorRect.new()
	_lobby_dim.color = Color(0.01, 0.04, 0.02, 0.8)
	_lobby_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby_dim.visible = false
	root.add_child(_lobby_dim)
	_lobby_box = _panel(root)
	_lobby_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_lobby_box.offset_top = 0.0
	_lobby_box.offset_bottom = 0.0
	_lobby_box.custom_minimum_size = Vector2(620, 0)
	_lobby_box.offset_left = -310.0
	_lobby_box.offset_right = 310.0
	var head := _label(56, Color(0.75, 1.0, 0.78))
	head.text = "MULTIPLAYER"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glow(head, Color(0.25, 1.0, 0.4, 0.4))
	_lobby_box.add_child(head)
	_lobby_text = _label(30, Color(0.85, 1.0, 0.86))
	_lobby_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_box.add_child(_lobby_text)
	_lobby_host = _button("HOST A ROOM", func() -> void:
		_lobby_say("Making a room...")
		net.create(ship))
	_lobby_box.add_child(_lobby_host)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_lobby_code = LineEdit.new()
	_lobby_code.placeholder_text = "CODE"
	_lobby_code.max_length = 4
	_lobby_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_code.custom_minimum_size = Vector2(220, 70)
	_lobby_code.add_theme_font_override("font", font)
	_lobby_code.add_theme_font_size_override("font_size", 40)
	_lobby_code.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			_lobby_code.text = up
			_lobby_code.caret_column = up.length())
	row.add_child(_lobby_code)
	_lobby_join = _button("JOIN", func() -> void:
		if _lobby_code.text.length() == 4:
			_lobby_say("Joining %s..." % _lobby_code.text)
			net.join(_lobby_code.text, ship))
	row.add_child(_lobby_join)
	_lobby_box.add_child(row)
	_lobby_start = _button("START", func() -> void:
		# (the country everyone will share: its seed goes out as the room's stage)
		net.pick_stage("s%d" % randi_range(1, 1 << 30))
		net.start_game())
	_lobby_box.add_child(_lobby_start)
	_lobby_leave = _button("BACK", close_lobby)
	_lobby_box.add_child(_lobby_leave)
	_lobby_box.visible = false


func open_lobby() -> void:
	title_box.visible = false
	_lobby_box.visible = true
	_lobby_dim.visible = true
	_show_lobby()


## Out of the lobby (and out of any room) and back to the title
func close_lobby() -> void:
	if net.active():
		net.leave()
	_lobby_box.visible = false
	_lobby_dim.visible = false
	title_box.visible = mode == "title"


func _lobby_say(text: String) -> void:
	if _lobby_text != null:
		_lobby_text.text = text


## The lobby as it stands: not in a room yet (host or join), or in one (its code, who is in it,
## and START for whoever made it)
func _show_lobby() -> void:
	if _lobby_box == null:
		return
	var inside := net.active()
	# (JOIN: only the code to type; HOST goes straight into a room of its own)
	_lobby_host.visible = false
	_lobby_code.get_parent().visible = not inside
	_lobby_start.visible = inside and net.slot == 0
	_lobby_leave.text = "LEAVE" if inside else "BACK"
	if not inside:
		_lobby_say("Type the code of a friend's room.")
		return
	var names: Array[String] = []
	for p: Dictionary in net.players:
		names.append("P%d  %s%s" % [int(p["slot"]) + 1, Ufo.SHIPS.get(str(p.get("hero", "saucer")), Ufo.SHIPS["saucer"])["title"], "  (away)" if p.get("away", false) else ""])
	var waiting := "Press START when everyone is in." if net.slot == 0 else "Waiting for P1 to start..."
	_lobby_say("ROOM  %s\n\n%s\n\n%s" % [net.code, "\n".join(names), waiting])


## The leader started: off everyone goes, over the same country
func _coop_started(_players: Array, stage: String) -> void:
	coop_seed = int(stage.trim_prefix("s")) if stage.begins_with("s") else 1
	_lobby_box.visible = false
	_lobby_dim.visible = false
	coop.clear()
	begin_launch()


## The room gone from under us (the host left, it idled out, or the connection never came back)
func _coop_closed(_reason: String) -> void:
	coop.clear()
	coop_seed = 0
	if mode == "play":
		_heat_note("THE OTHERS ARE GONE", 2.5)
	elif _lobby_box != null and _lobby_box.visible:
		_show_lobby()
		_lobby_say("The room closed.")


## Something that happened on another player's device (see Coop.tell)
func coop_event(what: String, at: Vector3, kind: String, size: float) -> void:
	match what:
		"take":
			var best: Thing = null
			var near := 5.0
			for t in things:
				if t.kind == kind and t.state == "walk" and t.position.distance_to(at) < near:
					near = t.position.distance_to(at)
					best = t
			if best != null:
				ufo.puffs.puff(best.position + Vector3(0, 0.5, 0), Color(0.6, 1.0, 0.7, 0.6), 0.6, Vector3(0, 3.0, 0), 0.6)
				_remove(best)
		"pull":
			world.pull(at, 1.2, 9)
		"revive":
			# (a friend's beam over our wreck: back up we go)
			if kind == str(coop.net.slot) and ufo.dead and ufo.crashed and mode == "play" and _rescue_wait > 0.0:
				revived()
			elif kind != str(coop.net.slot):
				ufo.puffs.puff(at + Vector3(0, 1.0, 0), Color(0.6, 1.0, 0.7, 0.7), 1.4, Vector3(0, 4.0, 0), 0.8)
		"circle":
			world.crop_circle(at, size)
		"boom":
			boom(at + Vector3(0, 0.8, 0), size)

## The log written out afresh: everything there is to take, then the hunters (the saucers have their
## own list, SAUCERS); what
## has not been come across yet is ???
func _fill_log() -> void:
	for old in _log_list.get_children():
		old.queue_free()
	var big := _upright()
	_log_head.text = "LOG"
	_log_head.add_theme_font_size_override("font_size", 110 if big else 56)
	_log_back.custom_minimum_size = Vector2(420, 140) if big else Vector2(260, 70)
	_log_back.add_theme_font_size_override("font_size", 72 if big else 40)
	var specimens: Array = []
	var have := 0
	for kind: String in Thing.KINDS:
		var info: Dictionary = Thing.KINDS[kind]
		if kind in ["pod", "canister"] or info.get("enemy", false) or info.has("unlock") or HUNTERS.has(kind):
			continue
		var count := int(_log_taken.get(kind, 0))
		have += 1 if count > 0 else 0
		# (how many taken, and what one is worth before any bonus)
		specimens.append([Thing.alien_name(kind), "x%d   $%d" % [count, int(info.get("points", 0) * Thing.WORTH)], count > 0, kind])
	_log_section("SPECIMENS  %d/%d" % [have, specimens.size()], specimens, big)
	var hunters: Array = []
	for h: String in HUNTERS:
		hunters.append([Thing.alien_name(h), "$%d" % int(Thing.KINDS[h].get("points", 0) * Thing.WORTH) if Thing.KINDS.has(h) else "", h in _log_met, h])
	_log_section("HUNTERS  %d/%d" % [_log_met.size(), HUNTERS.size()], hunters, big)
	var items: Array = []
	# (common first, then uncommon, then rare; in their usual order within each)
	for what: String in by_rarity(ItemBar.ORDER):
		var spec: Dictionary = UPGRADES[what]
		items.append([spec["title"], "%s\nWORTH $%d" % [spec["about"], int(spec.get("price", 0))], what in _log_items, "item:" + what])
	_log_section("ITEMS  %d/%d" % [_log_items.size(), ItemBar.ORDER.size()], items, big)


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
		if tile.size() > 3 and str(tile[3]).begins_with("item:"):
			# (an item's tile the colour of its rarity, green, blue or red)
			var rare := RARITY_COLOURS[rarity(str(tile[3]).trim_prefix("item:"))]
			frame.bg_color = Color(rare.r * 0.3, rare.g * 0.3, rare.b * 0.3, 0.85 if known else 0.45)
			frame.border_color = rare if known else rare.darkened(0.55)
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(8)
		frame.set_content_margin_all(8)
		cell.add_theme_stylebox_override("panel", frame)
		var l := _label((46 if big else 20) if known else (70 if big else 30), Color(0.9, 0.95, 0.88) if known else Color(0.35, 0.45, 0.4))
		l.text = ("%s\n%s" % [tile[0], tile[1]]).strip_edges() if known else "?"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if known and tile.size() > 3:
			# (a little hologram of it over its name)
			var stack := VBoxContainer.new()
			stack.alignment = BoxContainer.ALIGNMENT_CENTER
			var holo := holograms.view(tile[3], 110.0 if big else 56.0)
			holo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			stack.add_child(holo)
			stack.add_child(l)
			cell.add_child(stack)
		else:
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


## How far up toward the ship the camera looks in play, from the ground under it (a fraction of its
## height)
func _look_up() -> float:
	return 0.3 if _upright() else 0.45


## Further up and back for a ship that flies higher
func _camera_offset() -> Vector3:
	# (on a wide screen, lower and further back, looking out more than down, for the curve of the
	# world and the night sky over it to show at the top of the picture)
	var from := camera_offset if _upright() or camera_offset != CAMERA_OFFSET else WIDE_OFFSET
	return from + Vector3(0, 1.3, 0.5) * (ufo.altitude - 8.0)


func _camera(delta: float) -> void:
	_turn_sky()
	if hold_camera:
		return
	if _warm_frames > 0:
		_warm_camera()
		return
	if mode in ["title", "launch", "landing"]:
		_moon_camera(delta)
		return
	var focus := Vector3(ufo.position.x, 0.0, ufo.position.z)
	if (ufo.crashed or ufo.dead) and wreck != Vector3.INF:
		# (on the crash site, even once the wreck has been carried off)
		focus = Vector3(wreck.x, 0.0, wreck.z)
	if intro > 0.0 and (mode == "play" or mode == "return"):
		_intro_camera()
		_place_moon(delta)
		return
	_sky_mat.set_shader_parameter("space", 0.0)
	_turn_sky()
	_place_moon(delta)
	camera.environment.fog_density = 0.006
	camera.fov = _fov()
	var goal := focus + _camera_offset()
	if mode == "title":
		goal = focus + Vector3(0, 11.0, 15.0)
	camera.position = camera.position.lerp(goal, minf(delta * 4.0, 1.0)) if camera.position != Vector3.ZERO else goal
	# (looking at the ground under the ship, where the beam will fall and the reticle shows, the ship
	# itself a little above the middle of the picture)
	var look_at_point := camera.position - _camera_offset()
	# (looking partway up to the ship, for the night sky and the moon to show over the curve of the
	# world, a wide screen's lower camera the more)
	look_at_point.y += ufo.altitude * _look_up()
	if mode == "title":
		look_at_point = camera.position - Vector3(0, 11.0, 15.0) + Vector3(0, 4.0, -6.0)
	camera.look_at(look_at_point)
	_shake = maxf(_shake - delta, 0.0)
	if _shake > 0.0 and screen_shake:
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
	# (every word on the screen a hologram, as the buttons are: see holo_button.gdshader)
	if _holo_mat == null:
		_holo_mat = ShaderMaterial.new()
		_holo_mat.shader = load("res://shaders/holo_button.gdshader")
	l.material = _holo_mat
	return l


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var root := Control.new()
	_hud_root = root
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
	dash_orb = DashOrb.new()
	dash_orb.main = self
	dash_orb.position = Vector2(6, 322)
	dash_orb.size = Vector2(146, 146)
	dash_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dash_orb)
	# (warnings at the screen's edge for shots coming from off it, see ThreatMarks)
	threat_marks = ThreatMarks.new()
	threat_marks.main = self
	threat_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(threat_marks)

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
	# (the eye, just left of the stars: whether anything has the ship in sight, see Eye)
	eye = Eye.new()
	eye.main = self
	eye.position = Vector2(-64, 0)
	eye.size = Vector2(60, 60)
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_child(eye)

	# (the items had, small, in a row just under the stars: see ItemBar)
	item_bar = ItemBar.new()
	item_bar.main = self
	item_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	item_bar.position = Vector2(-260, 80)
	item_bar.size = Vector2(520, 46)
	item_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item_bar)
	# (the heat's news, just under the stars: the farmers armed, the police coming, spotted...)
	heat_note = _label(28, Color(1.0, 0.6, 0.4))
	heat_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heat_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heat_note.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heat_note.position = Vector2(-260, 132)
	heat_note.size = Vector2(520, 40)
	_glow(heat_note, Color(1.0, 0.4, 0.2, 0.45))
	root.add_child(heat_note)
	# (the boosts under way, each with the seconds it has left, under the heat's news)
	boost_label = _label(26, Color(0.85, 0.95, 1.0))
	boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boost_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boost_label.position = Vector2(-260, 172)
	boost_label.size = Vector2(520, 36)
	boost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boost_label)

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
	laser_button = LaserButton.new()
	laser_button.main = self
	laser_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	laser_button.visible = false
	root.add_child(laser_button)
	cloak_button = CloakButton.new()
	cloak_button.main = self
	cloak_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloak_button.visible = false
	root.add_child(cloak_button)

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
	# (the label keeps the room in the column; the name itself is drawn over it, letter by letter:
	# see TitleArt)
	_title_label.self_modulate = Color(1, 1, 1, 0)
	var art := TitleArt.new()
	art.main = self
	art.label = _title_label
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.material = bloom
	_title_label.add_child(art)
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
	_arrows = [_button("<", func() -> void: _pick_mode(-1)), _button(">", func() -> void: _pick_mode(1))]
	_play_button = _button("PLAY", _play_pressed)
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
	_title_row.add_child(_button("SAUCERS", open_saucers))
	_title_row.add_child(_button("LOG", open_log))
	_title_row.add_child(_button("OPTIONS", open_options))
	# (the scores and QUIT are the arcade's: only inside it, or for QUIT, off the web)
	if _in_arcade():
		_title_row.add_child(_button("SCORES", open_scores))
	title_box.add_child(_title_row)
	# (QUIT on a row of its own under the others)
	_quit_row = HBoxContainer.new()
	_quit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if _in_arcade() or not OS.has_feature("web"):
		_quit_row.add_child(_button("QUIT", quit_game))
		title_box.add_child(_quit_row)
	# The level-up picker: the level, and three upgrades to choose between (see `_level_up`)
	# (the game dimmed behind it, for the choices to read)
	_picker_dim = ColorRect.new()
	_picker_dim.color = Color(0, 0, 0, 0.55)
	# (with a hole where the market's saucer hangs: see market_dim.gdshader and ProjectorBeam)
	var dim_mat := ShaderMaterial.new()
	dim_mat.shader = load("res://shaders/market_dim.gdshader")
	_picker_dim.material = dim_mat
	_picker_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker_dim.visible = false
	root.add_child(_picker_dim)
	# (the market saucer's beam throwing the market onto the screen, under the market itself)
	var projector := ProjectorBeam.new()
	projector.main = self
	projector.set_anchors_preset(Control.PRESET_FULL_RECT)
	projector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projector.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(projector)
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
	_pick_one = _label(26, Color(0.6, 1.0, 0.65))
	var pick_one := _pick_one
	pick_one.text = ""
	pick_one.visible = false
	pick_one.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker.add_child(pick_one)
	_picks = VBoxContainer.new()
	_picks.add_theme_constant_override("separation", 30)
	_picks.alignment = BoxContainer.ALIGNMENT_CENTER
	_picker.add_child(_picks)
	_build_log(root)
	_build_lobby(root)


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
	_pause_box.add_child(_button("OPTIONS", open_options))
	_pause_box.add_child(_button("TO THE MOON", quit_to_menu))
	# (and QUIT, as on the title: inside the arcade, or off the web)
	if _in_arcade() or not OS.has_feature("web"):
		_pause_box.add_child(_button("QUIT", quit_game))
	_pause_box.visible = false
	# (centred both ways whatever its size: see `_fit_pause`)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_pause_box.set_offset(side, 0.0)
	_pause_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_options(root)

	over_box = _panel(root)
	# (it grows upward from just above the middle of the screen, so it sits over the wreck, not on it)
	over_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# (a heading over it all, in the middle)
	_over_head = _label(60, Color(0.7, 1.0, 0.72))
	_over_head.text = "RESULTS"
	_over_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glow(_over_head, Color(0.3, 1.0, 0.45, 0.55))
	over_box.add_child(_over_head)
	over_label = _label(34, Color(0.55, 1.0, 0.62))
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_glow(over_label, Color(0.25, 1.0, 0.4, 0.5))
	over_box.add_child(over_label)
	# (the items had, as their pictures with their counts, under a heading)
	_over_items = VBoxContainer.new()
	_over_items.add_theme_constant_override("separation", 6)
	_over_items_head = _label(34, Color(0.55, 1.0, 0.62))
	_over_items_head.text = "ITEMS"
	_glow(_over_items_head, Color(0.25, 1.0, 0.4, 0.5))
	_over_items.add_child(_over_items_head)
	_over_icons = HFlowContainer.new()
	_over_icons.add_theme_constant_override("h_separation", 14)
	_over_icons.add_theme_constant_override("v_separation", 8)
	_over_items.add_child(_over_icons)
	_over_items.visible = false
	over_box.add_child(_over_items)
	_over_row = HBoxContainer.new()
	_over_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_over_row.add_theme_constant_override("separation", 20)
	over_box.add_child(_over_row)
	_again = _button("TO THE MOON", func() -> void:
		if _over_wait <= 0.0:
			quit_to_menu())
	_over_row.add_child(_again)
	# (straight into another run: up off the wreck into the stars, and down onto a new country)
	_replay_button = _button("REPLAY", func() -> void:
		if _over_wait <= 0.0 and mode == "over":
			_replay = true
			quit_to_menu())
	_over_row.add_child(_replay_button)
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


## The hologram look shared by every button (see `_button`)
var _holo_mat: ShaderMaterial


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 40)
	b.custom_minimum_size = Vector2(260, 70)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# (a hologram: well rounded, room round the text, a soft green glow round it, and scanlines and a
	# flicker over it, see holo_button.gdshader)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.26, 0.15, 0.72)
	normal.border_color = Color(0.55, 1.0, 0.65)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(24)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	normal.shadow_color = Color(0.3, 1.0, 0.45, 0.28)
	normal.shadow_size = 10
	normal.anti_aliasing = true
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.42, 0.24, 0.85)
	hover.shadow_color = Color(0.4, 1.0, 0.55, 0.45)
	if _holo_mat == null:
		_holo_mat = ShaderMaterial.new()
		_holo_mat.shader = load("res://shaders/holo_button.gdshader")
	b.material = _holo_mat
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


## TO THE MOON (the pause's, or after a crash): the run given up (no score is sent), and the ship flies home: up off the farm into
## the stars (the descent backwards, see `_going_home`), then down onto the moon (the flight off it
## backwards), and the pilot back in the chair on the title
func quit_to_menu() -> void:
	# (flown home alive, alone: the run kept, to carry on with from the title, see `_saved_run`)
	if mode == "play" and not ufo.dead and not coop.active() and not testing:
		_saved_run = {"ship": ship, "score": score, "level": level, "upgrades": upgrades.duplicate(),
			"taken": _run_taken.duplicate(true), "killed": _run_killed.duplicate(), "threat": _threat}
		_save_best()
	# (out of any multiplayer room: the others fly on without us)
	if net != null and net.active():
		net.leave()
	coop.clear()
	coop_seed = 0
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
		if _replay:
			_replay = false
			start(true)
			return
		_show_title()
		return
	if ufo.dead:
		# (from a wreck: the camera pulls up away from the crash site, out into space, and on to the
		# moon, where a new ship comes in to land; the wreck stays lying where it is till then)
		_wreck_ship = ufo
		_from_wreck = true
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
	if _replay:
		# (REPLAY: up in the stars, where the climb off the moon would have stopped, and so down
		# again from here as from a launch, onto a new country)
		_replay = false
		_from_wreck = false
		_clear_wreck()
		_new_world(false)
		# (the new ship coming down into the picture from above it, the camera holding still for it)
		_arrive_t = ARRIVE
		start(true)
		sfx.play("whoosh", 1.1, -2.0)
		return
	intro = 0.0
	dust.fade = 0.0
	# (after a crash as after quitting: the same flight home, a new ship coming down onto the moon)
	var wrecked := _from_wreck
	_from_wreck = false
	ufo.queue_free()
	if wrecked:
		# (after a crash there is no ship coming home: a ship of ours already down on the moon, the
		# pilot lounging, and the camera comes down onto it by the landing's way, an unseen ship
		# leading it)
		_make_ufo(Vector3.ZERO)
		_park_ufo(true)
		_stand_in = ufo
	_make_ufo(Vector3.ZERO)
	_park_ufo(false)
	if wrecked:
		ufo.visible = false
	_clear_wreck()
	mode = "landing"
	_launch_t = LAUNCH


## After a crash: the ship already parked on the moon while the camera comes down onto it (see
## _going_home), there to take over from the unseen one it followed
var _stand_in: Ufo


## Down on the moon again: on its legs, the canopy opening and the pilot climbing out and back up
## into the chair
func _home() -> void:
	mode = "title"
	if is_instance_valid(_stand_in):
		# (after a crash: the parked ship, the pilot already lounging, is the one now)
		ufo.queue_free()
		ufo = _stand_in
		_stand_in = null
		_show_ship()
		title_box.visible = true
		_title_in = 0.0
		title_box.modulate.a = 0.0
		over_box.visible = false
		_save_best()
		return
	ufo.position = MoonSet.SITE + MoonSet.SHIP_AT
	ufo.rotation.y = MoonSet.SHIP_TURN
	ufo._legs.visible = true
	ufo.climb_out()
	_show_ship()
	title_box.visible = true
	_title_in = 0.0
	title_box.modulate.a = 0.0
	over_box.visible = false
	_save_best()


## The turn that faces the pilot (who looks along the ship's +z) back up `way`, at the camera behind
func _facing(way: Vector3) -> float:
	return atan2(-way.x, -way.z)


## The way the camera looks over the ship from lift-off until the descent is well under way: the
## way the title's camera looks, made level, so that the ship's climb sinks the moon and Earth out of
## the bottom of the picture and leaves only stars
func _away() -> Vector3:
	var way := Vector3(6.02, 0, -7.99)
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
	# (no label over it: the button itself says what it will do)
	ship_label.visible = false
	if ship in unlocked:
		_play_button.text = "CONTINUE" if play_mode == "single" and _saved_run.get("ship", "") == ship else MODE_TITLES[play_mode]
		_play_button.disabled = false
	else:
		_play_button.text = "LOCKED"
		_play_button.disabled = true


## At start-up: down out of the stars onto the moon, as after a crash (only the landing, none of the
## climb off Earth): the ship already parked there with the pilot lounging, and the camera coming
## down onto it behind an unseen ship that leads it (see `_going_home` and `_home`)
func _boot_landing() -> void:
	title_box.visible = false
	_stand_in = ufo
	_make_ufo(Vector3.ZERO)
	_park_ufo(false)
	ufo.visible = false
	mode = "landing"
	_launch_t = LAUNCH


func _show_title() -> void:
	mode = "title"
	alien_seed = randi()
	ufo.queue_free()
	_clear_wreck()
	_make_ufo(Vector3.ZERO)
	_park_ufo()
	_show_ship()
	title_box.visible = true
	# (it flickers on like a hologram warming up, see `_title_flicker`)
	_title_in = 0.0
	title_box.modulate.a = 0.0
	over_box.visible = false
	# (what the last run added to the log, kept)
	_save_best()


## The lounge on the title, in the pause and after a crash; Tanks! once the heat is up; else Night Visitors
func _choose_music() -> void:
	if testing:
		return
	if mode == "launch" and _launch_t >= BLAST:
		# (the radio blown away at lift-off: its song gone with it)
		music.play("")
	elif mode != "play" or get_tree().paused:
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


# ------------------------------------------------------------------ options

## The options, kept with the bests: the music's and the sounds' loudness (0 to 10), how sharp the
## picture is (see PICTURES), the PlayStation's dither, the screen shaking, and the frame rate
var music_volume := 8
var effects_volume := 8
var picture := 1
## How many lines the picture is drawn in (see `_fit`) for LOW, MEDIUM and HIGH
const PICTURES := [220.0, Ps1.LINES, 420.0]
const PICTURE_NAMES := ["LOW", "MEDIUM", "HIGH"]
var dither := true
var screen_shake := true
var frame_rate := 0
## (0: as fast as the screen goes)
const FRAME_RATES := [30, 60, 0]
var _options_box: Control
var _options_list: GridContainer
var _options_head: Label
var _options_back: Button
## Where OPTIONS was opened from: the title ("title") or the pause ("pause")
var _options_from := "title"
## Each option's row: [its name's label, what changes it (a slider or a button)], for `_fit_options`
var _option_rows: Array = []


func _build_options(root: Control) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.02, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	root.add_child(dim)
	_options_box = dim
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(middle)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	middle.add_child(box)
	_options_head = _label(56, Color(0.7, 1.0, 0.72))
	_options_head.text = "OPTIONS"
	_options_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glow(_options_head, Color(0.3, 1.0, 0.45, 0.55))
	box.add_child(_options_head)
	_options_list = GridContainer.new()
	_options_list.columns = 2
	_options_list.add_theme_constant_override("h_separation", 28)
	_options_list.add_theme_constant_override("v_separation", 16)
	box.add_child(_options_list)
	_slider_row("MUSIC", func() -> int: return music_volume, func(v: int) -> void: music_volume = v)
	_slider_row("EFFECTS", func() -> int: return effects_volume, func(v: int) -> void:
		effects_volume = v
		sfx.play("click", 1.0))
	_choice_row("PICTURE", func() -> String: return PICTURE_NAMES[picture], func() -> void: picture = (picture + 1) % PICTURES.size())
	_choice_row("DITHER", func() -> String: return "ON" if dither else "OFF", func() -> void: dither = not dither)
	_choice_row("SHAKE", func() -> String: return "ON" if screen_shake else "OFF", func() -> void: screen_shake = not screen_shake)
	_choice_row("FRAMES", func() -> String: return "%d FPS" % frame_rate if frame_rate > 0 else "MAX", func() -> void:
		frame_rate = FRAME_RATES[(FRAME_RATES.find(frame_rate) + 1) % FRAME_RATES.size()])
	_options_back = _button("BACK", close_options)
	box.add_child(_options_back)


func _option_name(text: String) -> Label:
	var l := _label(40, Color(0.75, 1.0, 0.78))
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_options_list.add_child(l)
	return l


## A loudness, 0 to 10, on a slider
func _slider_row(text: String, now: Callable, set_to: Callable) -> void:
	var l := _option_name(text)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 10
	s.step = 1
	s.value = now.call()
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.25, 0.14, 0.85)
	track.border_color = Color(0.55, 1.0, 0.6)
	track.set_border_width_all(3)
	track.set_corner_radius_all(8)
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Color(0.35, 0.9, 0.45, 0.9)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := _knob(40)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	s.value_changed.connect(func(v: float) -> void:
		set_to.call(int(v))
		_apply_options())
	s.set_meta("now", now)
	_options_list.add_child(s)
	_option_rows.append([l, s])


## A choice between a few, stepped through by pressing it
func _choice_row(text: String, now: Callable, step: Callable) -> void:
	var l := _option_name(text)
	var b := _button(now.call(), func() -> void: pass)
	b.pressed.connect(func() -> void:
		step.call()
		b.text = now.call()
		_apply_options())
	b.size_flags_horizontal = Control.SIZE_FILL
	b.set_meta("now", now)
	_options_list.add_child(b)
	_option_rows.append([l, b])


## A round knob for the sliders
func _knob(across: int) -> ImageTexture:
	var img := Image.create(across, across, false, Image.FORMAT_RGBA8)
	var c := (across - 1) * 0.5
	for y in across:
		for x in across:
			var d := Vector2(x - c, y - c).length()
			if d <= c:
				img.set_pixel(x, y, Color(0.55, 1.0, 0.6) if d > c - 4.0 else Color(0.85, 1.0, 0.86))
	return ImageTexture.create_from_image(img)


func open_options() -> void:
	if mode == "title":
		if not title_box.visible:
			return
		_options_from = "title"
		title_box.visible = false
	elif get_tree().paused and _pause_box.visible:
		_options_from = "pause"
		_pause_box.visible = false
	else:
		return
	for row: Array in _option_rows:
		var c: Control = row[1]
		if c is HSlider:
			(c as HSlider).set_value_no_signal((c.get_meta("now") as Callable).call())
		else:
			(c as Button).text = (c.get_meta("now") as Callable).call()
	_fit_options()
	_options_box.visible = true
	_options_back.call_deferred("grab_focus")
	_forget_fingers()


func close_options() -> void:
	if not _options_box.visible:
		return
	_options_box.visible = false
	if _options_from == "pause":
		_pause_box.visible = get_tree().paused
		if _pause_box.visible:
			_resume_button.call_deferred("grab_focus")
	else:
		title_box.visible = mode == "title"
	_save_best()


## The options sized for thumbs on an upright phone, smaller across a wide screen
func _fit_options() -> void:
	var big := _upright()
	_options_head.add_theme_font_size_override("font_size", 130 if big else 56)
	for row: Array in _option_rows:
		(row[0] as Label).add_theme_font_size_override("font_size", 72 if big else 36)
		var c: Control = row[1]
		c.custom_minimum_size = Vector2(620, 130) if big else Vector2(300, 60)
		if c is Button:
			c.add_theme_font_size_override("font_size", 66 if big else 32)
	_options_back.custom_minimum_size = Vector2(560, 150) if big else Vector2(260, 70)
	_options_back.add_theme_font_size_override("font_size", 80 if big else 40)


## The options put into effect: the loudness of the music's and the sounds' buses, the picture's
## lines, the dither and the frame rate (the shaking is read where the camera shakes)
func _apply_options() -> void:
	for bus: Array in [[Music.BUS, music_volume], [Sfx.BUS, effects_volume]]:
		var i := AudioServer.get_bus_index(bus[0])
		if i < 0:
			continue
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(int(bus[1]) / 10.0, 0.001)))
		AudioServer.set_bus_mute(i, int(bus[1]) == 0)
	if view != null:
		_fit()
	if screen_mat != null:
		screen_mat.set_shader_parameter("dither", dither)
	Engine.max_fps = frame_rate


## The pause sized for thumbs on an upright phone, smaller across a wide screen
func _fit_pause() -> void:
	var big := _upright()
	_pause_box.add_theme_constant_override("separation", 40 if big else 18)
	_pause_box.custom_minimum_size = Vector2(760 if big else 400, 0)
	for c in _pause_box.get_children():
		if c is Button:
			(c as Button).custom_minimum_size = Vector2(700, 150) if big else Vector2(360, 76)
			(c as Button).add_theme_font_size_override("font_size", 72 if big else 40)
		elif c is Label:
			(c as Label).add_theme_font_size_override("font_size", 130 if big else 64)


func set_paused(on: bool) -> void:
	if mode != "play" or (_picker != null and _picker.visible):
		return
	get_tree().paused = on
	_pause_box.visible = on
	if on:
		_fit_pause()
	if not on and _options_box != null:
		_options_box.visible = false
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
	score_label.visible = playing
	if intro > 0.0:
		score_label.visible = false
	mult_label.visible = playing
	coin.visible = playing
	log_box.visible = playing
	_type_log(delta)
	stars.visible = playing
	item_bar.visible = playing
	item_bar.queue_redraw()
	heat_note.position.y = 80.0 + maxf((item_bar as ItemBar).rows, 1) * 48.0 + 4.0
	boost_label.position.y = heat_note.position.y + 40.0
	boost_label.visible = playing and not boosts.is_empty()
	if boost_label.visible:
		var parts: Array[String] = []
		for b: String in boosts:
			parts.append("%s %d" % [BOOSTS[b]["title"], ceili(boosts[b])])
		boost_label.text = "   ".join(parts)
	_layout_touch()
	shield_bar.visible = playing
	radar.visible = playing
	dash_orb.visible = playing
	dash_orb.queue_redraw()
	threat_marks.visible = playing
	threat_marks.size = get_viewport().get_visible_rect().size / hud.scale.x
	threat_marks.queue_redraw()
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
	beam_button.position = mark_at / hud.scale.x - beam_button.size * 0.5
	stick_ring.visible = playing and stick_finger != NO_FINGER
	beam_button.queue_redraw()
	# (the laser's switch, once there is a laser: up over the beam's resting mark)
	laser_button.visible = beam_button.visible and upgrades["laser"] > 0
	if laser_button.visible:
		var r := minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) * 0.13
		laser_button.size = Vector2.ONE * r * 0.95 / hud.scale.x
		laser_button.position = (_beam_home() + Vector2(-r * 0.3, -r * 1.85)) / hud.scale.x - laser_button.size * 0.5
		laser_button.queue_redraw()
	cloak_button.visible = beam_button.visible and upgrades["cloak"] > 0
	if cloak_button.visible:
		var rc := minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) * 0.13
		cloak_button.size = Vector2.ONE * rc * 0.95 / hud.scale.x
		cloak_button.position = (_beam_home() + Vector2(-rc * 1.85, -rc * 0.35)) / hud.scale.x - cloak_button.size * 0.5
		cloak_button.queue_redraw()
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
	# (placed in screen pixels, whatever the HUD's scale)
	var k := hud.scale.x if hud != null else 1.0
	beam_button.size = Vector2(r * 2, r * 2) / k
	beam_button.position = (_beam_home() - Vector2(r, r)) / k


## Touches are read here, before the interface sees them (as Liquid Metal does), so nothing on the
## screen can swallow them; only a finger that comes down on the pause button is left to it
func _input(event: InputEvent) -> void:
	# The dev room, on the title: D, E, V typed, or seven quick taps on the game's name
	if mode == "title" and title_box.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			_dev_typed = (_dev_typed + OS.get_keycode_string(event.keycode)).right(3).to_upper()
			if _dev_typed == "DEV":
				_dev_typed = ""
				toggle_dev()
		var tap: bool = event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed
		if tap and _title_label != null and screen_rect(_title_label).grow(20).has_point(event.position):
			var now := Time.get_ticks_msec() / 1000.0
			_dev_taps = _dev_taps + 1 if now - _dev_tapped < 0.6 else 1
			_dev_tapped = now
			if _dev_taps >= 7:
				_dev_taps = 0
				toggle_dev()
	if _touch_debug and (event is InputEventScreenTouch or event is InputEventMouseButton or (event is InputEventScreenDrag and Engine.get_process_frames() % 12 == 0)):
		_debug_line("%s | %s%s" % [event.as_text(), mode, " PAUSED" if get_tree().paused else ""])
	# Five quick taps on the alien coin turn the touch readout on or off (to see what a phone sends)
	if event is InputEventScreenTouch and event.pressed and coin.visible and screen_rect(coin).grow(24).has_point(event.position):
		var now := Time.get_ticks_msec() / 1000.0
		_coin_taps = _coin_taps + 1 if now - _coin_tapped < 0.6 else 1
		_coin_tapped = now
		if _coin_taps >= 5:
			_coin_taps = 0
			_touch_debug = not _touch_debug
			if _debug_label != null:
				_debug_label.visible = _touch_debug
			_debug_line("touch readout on")
	# (the log and the saucers scrolled by a finger dragged anywhere over them, as a phone's lists are)
	# and tossed: let go mid-swipe and it runs on, slowing (see `_fling_log`)
	if _log_box != null and _log_box.visible and _log_scroll != null:
		if event is InputEventScreenDrag:
			var moved := (event as InputEventScreenDrag).relative.y / hud.scale.y
			_log_scroll.scroll_vertical -= int(moved)
			var now := Time.get_ticks_msec() / 1000.0
			var dt := clampf(now - _log_dragged_at, 1.0 / 120.0, 0.1)
			_log_dragged_at = now
			_log_speed = lerpf(_log_speed, -moved / dt, 0.5)
			_log_flinging = false
		elif event is InputEventScreenTouch:
			if (event as InputEventScreenTouch).pressed:
				_log_speed = 0.0
				_log_flinging = false
			else:
				# (a finger still moving as it lets go tosses the list on)
				_log_flinging = Time.get_ticks_msec() / 1000.0 - _log_dragged_at < 0.08
	if mode != "play" or autopilot:
		return
	if get_tree().paused:
		return
	if event is InputEventScreenTouch and event.pressed and cloak_button != null and cloak_button.visible \
			and screen_rect(cloak_button).grow(10).has_point(event.position):
		# (a tap on the cloak's button)
		use_cloak()
		return
	if event is InputEventScreenTouch and event.pressed and laser_button != null and laser_button.visible \
			and screen_rect(laser_button).grow(10).has_point(event.position):
		# (a tap on the laser's switch: the beam over to the laser, or back)
		toggle_laser()
		return
	if event is InputEventScreenTouch and event.pressed and _pause_button.visible \
			and screen_rect(_pause_button).grow(8).has_point(event.position):
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
		_saved_run = cfg.get_value("run", "saved", {})
		for had: String in cfg.get_value("log", "items", []):
			if UPGRADES.has(had) and not had in _log_items:
				_log_items.append(had)
		for key: String in ["music_volume", "effects_volume", "picture", "dither", "screen_shake", "frame_rate"]:
			if cfg.has_section_key("options", key):
				set(key, cfg.get_value("options", key))
		picture = clampi(picture, 0, PICTURES.size() - 1)
		for met: String in cfg.get_value("log", "met", []):
			if HUNTERS.has(met) and not met in _log_met:
				_log_met.append(met)
	# (the dev room straight away with ?dev on the page's address, outside the arcade: see `toggle_dev`)
	if OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search")).contains("dev"):
		dev = true
		_kept_unlocked.assign(unlocked)
		unlocked.assign(Ufo.ORDER)

func _save_best() -> void:
	if testing:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("best", "score", best)
	cfg.set_value("best", "ship", ship)
	cfg.set_value("best", "unlocked", _kept_unlocked if dev else unlocked)
	cfg.set_value("log", "taken", _log_taken)
	cfg.set_value("run", "saved", _saved_run)
	cfg.set_value("log", "met", _log_met)
	cfg.set_value("log", "items", _log_items)
	for key: String in ["music_volume", "effects_volume", "picture", "dither", "screen_shake", "frame_rate"]:
		cfg.set_value("options", key, get(key))
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


## The eye beside the heat's stars: wide open, red and throbbing while anything has the ship in sight
## (a searchlight on it, a dish tracking it), with a little point on its rim the way the one watching
## is; shut while nothing does, blue once the heat is cooling. Only while there is heat or a watcher.
class Eye extends Control:
	var main: Node
	## How far open it is (0 shut, 1 open), easing between
	var _open := 0.0

	func _process(delta: float) -> void:
		var want := 1.0 if main.seen > 0.0 else 0.0
		_open = move_toward(_open, want, delta * 6.0)
		visible = main.stars.visible and (main.heat > 0.0 or _open > 0.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var t := Time.get_ticks_msec() / 1000.0
		const W := 26.0
		const H := 15.0
		var cool: bool = main.cooling()
		var shut := Color(0.45, 0.85, 1.0) if cool else Color(0.7, 0.72, 0.75)
		var red := Color(1.0, 0.25, 0.15)
		var tone := shut.lerp(red, _open)
		draw_circle(c, W + 4.0, Color(0, 0, 0, 0.55))
		if _open > 0.0:
			# (a halo throbbing round it, as an alarm does)
			var beat := 0.5 + 0.5 * sin(t * 9.0)
			draw_circle(c, W + 4.0 + beat * 5.0 * _open, Color(red.r, red.g, red.b, 0.18 * _open))
		# (the lids: an almond, as open as it is)
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for k in 17:
			var x := -W + k * W * 2.0 / 16.0
			var curve := 1.0 - pow(x / W, 2.0)
			top.append(c + Vector2(x, -H * curve * _open))
			bottom.append(c + Vector2(x, H * curve * maxf(_open, 0.0)))
		if _open > 0.05:
			var shape := top.duplicate()
			var back := bottom.duplicate()
			back.reverse()
			shape.append_array(back)
			draw_colored_polygon(shape, Color(0.95, 0.92, 0.85, _open))
			# (the iris and the pupil, darting a little toward whoever is watching)
			var look := _toward() * 4.0
			draw_circle(c + look, 9.0 * _open, red)
			draw_circle(c + look, 4.0 * _open, Color(0.05, 0.02, 0.02))
			draw_polyline(bottom, tone, 2.5)
			draw_polyline(top, tone, 3.0)
		else:
			# (shut: the lid's curve, sagging, and four lashes hanging off it)
			var lid := PackedVector2Array()
			for k in 17:
				var x := -W + k * W * 2.0 / 16.0
				lid.append(c + Vector2(x, -3.0 + H * 0.6 * (1.0 - pow(x / W, 2.0))))
			draw_polyline(lid, tone, 4.0)
			for x: float in [-15.0, -5.0, 5.0, 15.0]:
				var at := c + Vector2(x, -3.0 + H * 0.6 * (1.0 - pow(x / W, 2.0)))
				draw_line(at, at + Vector2(x * 0.3, 8.0), tone, 3.0)
		# (a point on the rim, toward the one watching)
		if _open > 0.5 and main.seen_from != Vector3.INF:
			var way := _toward()
			var side := Vector2(-way.y, way.x)
			var tip := c + way * (W + 14.0)
			var foot := c + way * (W + 4.0)
			draw_colored_polygon(PackedVector2Array([tip, foot + side * 7.0, foot - side * 7.0]), red)

	## The way to the one watching, on the screen (north up, as on the radar)
	func _toward() -> Vector2:
		if main.seen_from == Vector3.INF:
			return Vector2.ZERO
		var off: Vector3 = main.seen_from - main.ufo.position
		var flat := Vector2(off.x, off.z)
		return flat.normalized() if flat.length() > 0.1 else Vector2.ZERO


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
		elif t.kind == "rival" and t.ground().distance_to(here) < radar_range():
			marks.append([t.ground(), Color(1.0, 0.4, 0.9), 5.0])
		elif t.is_enemy() and t.ground().distance_to(here) < radar_range():
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
			var flat: Vector2 = Vector2(off.x, off.z) / main.radar_range() * r
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


## The level orb, left of the cash, the same size as the shield's glass: it fills toward the next
## level-up with little hologram icons of what was taken, each dropping in from the top and
## tumbling down to settle on the others (round bodies under gravity, kept inside the glass and off
## each other); at a level-up they all fly out and it starts again. The level it is working toward
## shows faint behind them. Five quick taps on it turn the touch readout on (see _input).
class Coin extends Control:
	const ICONS := 30
	## (the same size as the shield's glass: 52 across scaled 1.4)
	const R := 64.0
	const BODY := 9.0
	const GRAVITY := 600.0
	var font: Font
	var main: Node
	## The kind of thing most lately taken (its icon is the next to drop in)
	var last_kind := "cow"
	## Each icon: [where (from the middle), velocity, its picture, spin]
	var _icons: Array = []
	var _level := 0
	var _out := 0.0

	func _process(delta: float) -> void:
		if not visible:
			return
		var lv: int = main.level
		var from: int = main.level_at(lv)
		var to: int = main.level_at(lv + 1)
		var want := int(clampf(float(main.team_score() - from) / maxf(to - from, 1), 0.0, 1.0) * ICONS)
		if lv != _level:
			# (a level-up: everything in the glass flies out, and it begins again)
			_level = lv
			for b: Array in _icons:
				b[1] = Vector2(randf_range(-260, 260), randf_range(-520, -320))
			_out = 0.8
		if _out > 0.0:
			_out -= delta
			for b: Array in _icons:
				b[1].y += GRAVITY * delta
				b[0] += b[1] * delta
			if _out <= 0.0:
				_icons.clear()
			queue_redraw()
			return
		# (one at a time, a moment apart, so each can be seen to drop)
		if _icons.size() < want and (_icons.is_empty() or (_icons[-1][0] as Vector2).y > -R * 0.4):
			_icons.append([Vector2(randf_range(-R * 0.3, R * 0.3), -R + BODY), Vector2(randf_range(-40, 40), 60), main.holograms.icon(last_kind), randf_range(-3, 3)])
		elif _icons.size() > want:
			_icons.clear()
		# the bodies falling, rolling off each other, kept in the glass
		for step in 2:
			var dt := delta * 0.5
			for b: Array in _icons:
				b[1].y += GRAVITY * dt
				b[1] *= 1.0 - minf(dt * 1.5, 1.0)
				b[0] += b[1] * dt
			for i in _icons.size():
				var a: Array = _icons[i]
				for j in range(i + 1, _icons.size()):
					var b: Array = _icons[j]
					var d: Vector2 = b[0] - a[0]
					var gap := d.length()
					if gap < BODY * 2.0 and gap > 0.01:
						var push := d / gap * (BODY * 2.0 - gap) * 0.5
						a[0] -= push
						b[0] += push
						var along: float = ((b[1] as Vector2) - (a[1] as Vector2)).dot(d / gap)
						if along < 0.0:
							a[1] += d / gap * along * 0.5
							b[1] -= d / gap * along * 0.5
				var p: Vector2 = a[0]
				if p.length() > R - BODY:
					var n := p.normalized()
					a[0] = n * (R - BODY)
					var into := (a[1] as Vector2).dot(n)
					if into > 0.0:
						a[1] -= n * into * 1.4
		for b: Array in _icons:
			b[3] *= 1.0 - minf(delta * 2.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, R + 8.0, Color(0.6, 1.0, 0.7, 0.18))
		draw_circle(c, R, Color(0.02, 0.08, 0.04, 0.8))
		draw_string(font, Vector2(0, c.y + 10.0), "LV %d" % (main.level + 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.75, 1.0, 0.78, 0.45))
		for b: Array in _icons:
			var tex: Texture2D = b[2]
			# (each in a little glass ball of its own)
			var side := BODY * 1.6
			draw_set_transform(c + (b[0] as Vector2), float(b[3]), Vector2.ONE)
			draw_circle(Vector2.ZERO, BODY, Color(0.05, 0.25, 0.12, 0.9))
			draw_texture_rect(tex, Rect2(-side * 0.5, -side * 0.5, side, side), false)
			draw_arc(Vector2.ZERO, BODY, 0, TAU, 16, Color(0.6, 1.0, 0.7, 0.85), 1.5)
			draw_circle(Vector2(-BODY * 0.35, -BODY * 0.4), BODY * 0.22, Color(1, 1, 1, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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


## The Moon Market's trading saucer, painted like a carnival: there at once behind the market in a puff of confetti
## while it is open, bobbing and turning there (the game paused all the while), and away up again
## after the pick. Held at a place in the picture, the top middle, a way off. Lit from above by a stage
## spotlight (and left out of the dark the market lays over the picture), a puff of confetti as it arrives, and
## its beam (drawn over the picture by ProjectorBeam) throwing the market itself onto the screen
class MarketShip extends Node3D:
	var main: Node
	var _t := 0.0
	var _leaving := -1.0
	var _model: Node3D
	var _light: SpotLight3D
	## Where it shows in the picture (before the lift that makes up for the world's bend)
	var seen := Vector3.ZERO
	var _landed := false
	## The confetti and the puff: [piece, its way, its spin (none for a puff), its age]
	var _bits: Array = []
	const DROP := 0.15
	const AWAY := 30.0
	const CONFETTI := [Color(1.0, 0.25, 0.3), Color(1.0, 0.85, 0.2), Color(0.3, 0.75, 1.0), Color(0.45, 1.0, 0.5), Color(1.0, 0.5, 0.9), Color(1.0, 0.6, 0.2)]

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_model = Ps1.model("market")
		_model.scale = Vector3.ONE * 1.4
		add_child(_model)
		_light = SpotLight3D.new()
		_light.top_level = true
		_light.light_color = Color(1.0, 0.92, 0.75)
		_light.spot_angle = 16.0
		_light.spot_range = 24.0
		_light.light_energy = 0.0
		_light.spot_angle = 22.0
		add_child(_light)
		_place()

	func leave() -> void:
		if _leaving < 0.0:
			_leaving = 0.0
			main.sfx.play("whoosh", 1.2, -4.0)

	## How lit it is: up as it settles, down as it goes
	func lit() -> float:
		var on := smoothstep(DROP * 0.6, DROP + 0.3, _t)
		return on * (1.0 - clampf(_leaving / 0.5, 0.0, 1.0)) if _leaving >= 0.0 else on

	func _process(delta: float) -> void:
		_t += delta
		if _leaving >= 0.0:
			_leaving += delta
			if _leaving > 1.2:
				queue_free()
				return
		_place()
		if not _landed:
			_landed = true
			_confetti()
		_fall(delta)

	## How far down the world's bend draws a point (see bend.gdshaderinc)
	func _sag(p: Vector3) -> float:
		var cam: Camera3D = main.camera
		var focus: Vector3 = cam.position - main._camera_offset() + Vector3(0, 0, -1.0)
		var bend: float = ProjectSettings.get_setting("shader_globals/bend_k")["value"]
		var d := p.z - focus.z
		d = d if d < 0.0 else d * 0.45
		var s := p.x - focus.x
		return bend * (d * d + 0.3 * s * s)

	func _place() -> void:
		var cam: Camera3D = main.camera
		var size := Vector2(main.view.size)
		var at := cam.project_position(size * (Vector2(0.5, 0.17) if main._upright() else Vector2(0.84, 0.3)), AWAY)
		# (down from high above, slowing and settling with a little bounce; bobbing; and at the end
		# up and away the quicker)
		var k := clampf(_t / DROP, 0.0, 1.0)
		var drop := (1.0 - k) * (1.0 - k) * 3.0 - sin(k * PI) * 0.3
		var rise := _leaving * _leaving * 30.0 if _leaving > 0.0 else 0.0
		at.y += drop + rise + sin(_t * 2.2) * 0.35
		seen = at
		# (lifted by as much as the world's bend would drop it)
		at.y += _sag(at)
		global_position = at
		_model.rotation = Vector3(0.18, _t * 0.9, 0.0)
		var on := lit()
		# The spotlight, straight down on it from above, a little toward the camera
		var toward := (cam.global_position - at).normalized()
		_light.global_position = at + Vector3(0, 12.0, 0) + toward * 3.0
		_light.look_at(at, Vector3.FORWARD)
		_light.light_energy = 14.0 * on

	## A puff of confetti as it arrives
	func _confetti() -> void:
		main.sfx.play("pop", 1.3, -2.0)
		main.sfx.play("fanfare", 1.5, -8.0)
		var paper := BoxMesh.new()
		paper.size = Vector3(0.5, 0.04, 0.32)
		for i in 170:
			var bit := MeshInstance3D.new()
			bit.mesh = paper
			bit.material_override = Ps1.flat(CONFETTI[i % CONFETTI.size()])
			bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bit.top_level = true
			add_child(bit)
			bit.global_position = global_position + Vector3(randf_range(-3, 3), randf_range(-0.5, 1.0), randf_range(-2, 2))
			var way := Vector3(randf_range(-1, 1), randf_range(0.1, 1.2), randf_range(-0.6, 0.6)).normalized() * randf_range(10.0, 26.0)
			_bits.append([bit, way, Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)), 0.0])
		# (and a puff of white smoke, swelling and gone)
		for i in 6:
			var puff := MeshInstance3D.new()
			puff.mesh = Ps1.ball()
			puff.material_override = Ps1.flat(Color(0.95, 0.95, 1.0))
			puff.top_level = true
			add_child(puff)
			puff.global_position = global_position + Vector3(randf_range(-2, 2), randf_range(-0.8, 0.8), randf_range(-1.5, 1.5))
			_bits.append([puff, Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)), Vector3.ZERO, 0.0])

	func _fall(delta: float) -> void:
		var keep: Array = []
		for b: Array in _bits:
			var n: MeshInstance3D = b[0]
			b[3] = float(b[3]) + delta
			var age: float = b[3]
			if b[2] == Vector3.ZERO:
				# (a puff: swelling, then shrinking away, in half a second)
				if age > 0.55:
					n.queue_free()
					continue
				n.scale = Vector3.ONE * (1.0 + age * 5.0) * (1.0 - smoothstep(0.25, 0.55, age))
				n.global_position += (b[1] as Vector3) * delta
				keep.append(b)
				continue
			var way: Vector3 = b[1]
			way.y -= 9.0 * delta
			way *= 1.0 - minf(1.5 * delta, 0.5)
			b[1] = way
			n.global_position += way * delta
			n.rotation += (b[2] as Vector3) * delta
			if age > 3.4:
				n.scale = Vector3.ONE * maxf(1.0 - (age - 3.4) * 2.0, 0.0)
			if age > 3.9:
				n.queue_free()
				continue
			keep.append(b)
		_bits = keep


## The market saucer's beam, drawn over the picture as if it threw the market onto the screen: a fan
## of light from under the saucer down onto the panel, the panel washed in it, scanlines drifting
## down through it
class ProjectorBeam extends Control:
	var main: Node

	func _process(_delta: float) -> void:
		queue_redraw()
		# (the hole in the market's dark, kept round the saucer wherever it is)
		var dim := main._picker_dim.material as ShaderMaterial
		var ship: MarketShip = main._market
		var cam: Camera3D = main.camera
		if dim == null:
			return
		if is_instance_valid(ship) and not cam.is_position_behind(ship.seen):
			dim.set_shader_parameter("hole", cam.unproject_position(ship.seen) / Vector2(main.view.size) * size)
			dim.set_shader_parameter("radius", size.x * (0.2 if main._upright() else 0.1))
		else:
			dim.set_shader_parameter("radius", 0.0)

	## Where a point of the 3D world shows on the screen, in this control's terms
	func _on_screen(p: Vector3) -> Vector2:
		return main.camera.unproject_position(p) / Vector2(main.view.size) * size

	func _draw() -> void:
		var ship: MarketShip = main._market
		var panel: Control = main._picker
		if not is_instance_valid(ship) or not panel.visible:
			return
		var on: float = ship.lit()
		if on <= 0.01:
			return
		var cam: Camera3D = main.camera
		# (the stage light on it, a soft cone from the top of the screen down onto it)
		if not cam.is_position_behind(ship.seen):
			var mid := _on_screen(ship.seen)
			var wide_at := size.x * (0.17 if main._upright() else 0.08)
			var bright := Color(1.0, 0.97, 0.88, 0.22 * on)
			var soft := Color(1.0, 0.97, 0.88, 0.08 * on)
			draw_polygon(PackedVector2Array([Vector2(mid.x - 18, 0), Vector2(mid.x + 18, 0), mid + Vector2(wide_at, 0), mid + Vector2(-wide_at, 0)]),
				PackedColorArray([bright, bright, soft, soft]))
		var under: Vector3 = ship.seen + Vector3(0, -1.0, 0)
		if cam.is_position_behind(under):
			return
		var top: Vector2 = cam.unproject_position(under) / Vector2(main.view.size) * size
		var whole := panel.get_global_rect()
		var box := Rect2(get_global_transform().affine_inverse() * whole.position, whole.size).grow(18.0)
		var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.031)
		var warm := Color(1.0, 0.9, 0.6)
		var hot := Color(warm, 0.42 * on * flick)
		var faint := Color(warm, 0.1 * on * flick)
		var dim := Color(warm, 0.03 * on)
		# (the panel's edge facing the saucer: its top over it on a phone, its side beside it on a wide
		# screen; and the panel's far edge, for the light washing across it)
		var a: Vector2
		var b: Vector2
		var far_a: Vector2
		var far_b: Vector2
		var tl := box.position
		var tr := box.position + Vector2(box.size.x, 0)
		var bl := box.position + Vector2(0, box.size.y)
		var br := box.end
		if top.y < box.position.y:
			a = tl; b = tr; far_a = bl; far_b = br
		elif top.x > box.end.x:
			a = tr; b = br; far_a = tl; far_b = bl
		else:
			a = bl; b = tl; far_a = br; far_b = tr
		var across := (b - a).normalized() * 10.0
		# (the fan of light, from the saucer's belly to that edge)
		draw_polygon(PackedVector2Array([top - across, top + across, b, a]), PackedColorArray([hot, hot, faint, faint]))
		# (the panel lit by it, brightest at the near edge)
		draw_polygon(PackedVector2Array([a, b, far_b, far_a]), PackedColorArray([faint, faint, dim, dim]))
		# (scanlines drifting out along it)
		var t := Time.get_ticks_msec() / 1000.0
		for i in 6:
			var k := fmod(t * 0.35 + i / 6.0, 1.0)
			draw_line(top.lerp(a, k), top.lerp(b, k), Color(warm, 0.14 * on * (1.0 - k * 0.6)), 2.0)
		draw_circle(top, 14.0, Color(1.0, 0.95, 0.8, 0.6 * on))


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


## Where a HUD control is on the screen, in screen pixels (the HUD may be drawn smaller: see _fit)
func screen_rect(c: Control) -> Rect2:
	return Rect2(c.get_global_transform_with_canvas().origin, c.size * c.get_global_transform_with_canvas().get_scale())


## The laser's switch, over the beam's mark on a touch screen: a round button with a red bolt, lit
## while the beam is switched over to the laser
class LaserButton extends Control:
	var main: Node

	func _draw() -> void:
		var r := size.x * 0.5
		var c := Vector2(r, r)
		var on: bool = main.laser_mode
		draw_circle(c, r, Color(1.0, 0.3, 0.4, 0.35 if on else 0.12))
		draw_arc(c, r - 2.0, 0, TAU, 32, Color(1.0, 0.55, 0.6, 0.95 if on else 0.5), 3.0)
		var bolt := PackedVector2Array([c + Vector2(-r * 0.15, -r * 0.55), c + Vector2(r * 0.25, -r * 0.55), c + Vector2(0, -r * 0.05),
			c + Vector2(r * 0.3, -r * 0.05), c + Vector2(-r * 0.2, r * 0.6), c + Vector2(0, r * 0.1), c + Vector2(-r * 0.3, r * 0.1)])
		draw_colored_polygon(bolt, Color(1.0, 0.4, 0.5) if on else Color(1.0, 0.6, 0.65, 0.6))


## The cloak's button, by the laser's on a touch screen: an eye, lit while cloaked, dim while it
## recharges
class CloakButton extends Control:
	var main: Node

	func _draw() -> void:
		var r := size.x * 0.5
		var c := Vector2(r, r)
		var on: bool = main.ufo.cloak > 0.0
		var ready: bool = main.ufo.cloak_wait <= 0.0
		var tint := Color(0.6, 0.6, 1.0)
		draw_circle(c, r, Color(tint, 0.35 if on else (0.14 if ready else 0.05)))
		draw_arc(c, r - 2.0, 0, TAU, 32, Color(tint.lightened(0.3), 0.95 if on or ready else 0.3), 3.0)
		# (an eye: two arcs and the pupil)
		var eye := Color(tint.lightened(0.4), 1.0 if on or ready else 0.35)
		draw_arc(c + Vector2(0, r * 0.35), r * 0.6, PI * 1.2, PI * 1.8, 12, eye, 3.0)
		draw_arc(c - Vector2(0, r * 0.35), r * 0.6, PI * 0.2, PI * 0.8, 12, eye, 3.0)
		draw_circle(c, r * 0.16, eye)
		if not ready and not on:
			# (how much of the recharge is left, round the rim)
			var left: float = main.ufo.cloak_wait / maxf(main.cloak_for() + main.cloak_recharge(), 0.01)
			draw_arc(c, r - 2.0, -PI / 2, -PI / 2 + TAU * (1.0 - left), 32, Color(tint.lightened(0.3), 0.9), 3.0)


## The items had, under the heat's stars: a little tile for each, in its colour with a 3D model of it, and
## how many are stacked in its corner (from the second on)
class ItemBar extends Control:
	## The items, in the order they show
	const ORDER := ["engine", "beam", "shield", "dash", "laser", "turret", "missiles", "cloak", "magnet", "wide", "scanner", "jammer", "coolant", "nanobots", "gold", "emp", "lucky", "armor", "second_wind", "swivel", "starbits", "sling", "fleet"]
	const TILE := 40.0
	## How many rows of items there are (the heat's news goes under them)
	var rows := 0
	var main: Node

	func _draw() -> void:
		var had: Array[String] = []
		for what: String in ORDER:
			if int(main.upgrades.get(what, 0)) > 0:
				had.append(what)
		# (as many to a row as fit the width, rows centred, wrapping onto the next)
		var step := TILE + 6.0
		var per := maxi(int((size.x + 6.0) / step), 1)
		rows = ceili(had.size() / float(per))
		for i in had.size():
			var what: String = had[i]
			var row := i / per
			var in_row := mini(had.size() - row * per, per)
			var x := (size.x - in_row * step + 6.0) * 0.5 + (i % per) * step
			var y := row * (TILE + 8.0)
			var colour: Color = main.UPGRADES[what]["colour"]
			var box := Rect2(x, y, TILE, TILE)
			draw_rect(box, Color(0.02, 0.06, 0.04, 0.8))
			# (its background tinted the colour of its rarity)
			var rare: Color = main.RARITY_COLOURS[main.rarity(what)]
			draw_rect(box.grow(-2.0), Color(rare.r * 0.35, rare.g * 0.35, rare.b * 0.35, 0.75))
			draw_rect(box.grow(-3.0), colour * Color(1, 1, 1, 0.1))
			# (its frame the colour of its rarity)
			draw_rect(box, main.RARITY_COLOURS[main.rarity(what)], false, 2.5)
			# (the item itself, a little 3D model of it, as Risk of Rain 2 shows its items)
			draw_texture_rect(main.holograms.item(what), box.grow(-1.0), false)
			var n: int = main.upgrades[what]
			if n > 1:
				draw_string_outline(main.font, Vector2(x + TILE * 0.45, y + TILE + 2.0), "x%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
				draw_string(main.font, Vector2(x + TILE * 0.45, y + TILE + 2.0), "x%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))


## The name on the title: its letters spread wide and each bobbing on its own, glowing green (see
## _build_hud; the label under it only keeps its room)
class TitleArt extends Control:
	## How much wider than the font's own spacing the letters stand
	const SPREAD := 1.22

	var main: Node
	var label: Label

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var font: Font = main.font
		var fs: int = label.get_theme_font_size("font_size")
		var text: String = label.text
		var plain := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var extra := plain * (SPREAD - 1.0) / maxf(text.length() - 1, 1)
		var c := size * 0.5
		# the letters
		var x := c.x - (plain + extra * (text.length() - 1)) * 0.5
		var base := c.y + fs * 0.35
		var outline := maxi(fs / 4, 6)
		for i in text.length():
			var ch := text[i]
			var adv := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var y := base + sin(t * 2.2 + i * 0.55) * fs * 0.07
			if ch != " ":
				draw_string_outline(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline * 2, Color(0.25, 1.0, 0.4, 0.18))
				draw_string_outline(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0.3, 1.0, 0.45, 0.55))
				draw_string(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.85, 1.0, 0.86))
			x += adv + extra


## The dash, under the radar and the same size as it and the shield: a glass orb holding an
## arrow for each charge (one, and one for each DASH item), lit green once charged and filling as it charges
class DashOrb extends Control:
	var main: Node

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 4.0
		draw_circle(c, r + 4.0, Color(0.6, 1.0, 0.7, 0.18))
		draw_circle(c, r, Color(0.02, 0.08, 0.04, 0.8))
		var n: int = main.ufo.charges()
		var charge: float = main.ufo.charge
		_liquid(c, r - 2.0, clampf(charge / maxf(n, 1), 0.0, 1.0))
		# (smaller arrows, the more there are, all in the orb)
		var k := r / 46.0 * minf(3.0 / n, 1.0)
		var across := 22.0 * (n - 1) + 23.0
		for i in n:
			var ax := c.x + (-across * 0.5 + i * 22.0) * k
			var ay := c.y
			var fill := clampf(charge - i, 0.0, 1.0)
			var tip := [Vector2(ax, ay - 16 * k), Vector2(ax + 16 * k, ay), Vector2(ax, ay + 16 * k), Vector2(ax + 7 * k, ay + 16 * k), Vector2(ax + 23 * k, ay), Vector2(ax + 7 * k, ay - 16 * k)]
			# (bright over the liquid behind them: near white when ready, grey while filling)
			var lit := Color(0.92, 1.0, 0.9) if fill >= 1.0 else Color(0.5, 0.55, 0.52).lerp(Color(0.8, 0.9, 0.82), fill)
			draw_polyline(PackedVector2Array(tip + [tip[0]]), Color(0.0, 0.08, 0.03, 0.85), 5.0)
			if fill >= 1.0:
				draw_colored_polygon(PackedVector2Array([tip[0], tip[5], tip[4], tip[1]]), lit)
				draw_colored_polygon(PackedVector2Array([tip[1], tip[4], tip[3], tip[2]]), lit)
			draw_polyline(PackedVector2Array(tip + [tip[0]]), lit, 2.0)
		draw_arc(c, r, 0, TAU, 48, Color(0.6, 1.0, 0.7, 0.9), 3.0)
		draw_arc(c + Vector2(-r * 0.3, -r * 0.35), r * 0.45, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.5), 3.0)

	## Green liquid in the orb up to `level` (0 to 1) of it, its surface lapping, bubbles rising
	## through it while it fills, glowing once it is full
	func _liquid(c: Vector2, r: float, level: float) -> void:
		if level <= 0.03:
			return
		var t := Time.get_ticks_msec() / 1000.0
		var dy := r - 2.0 * r * level
		if level >= 0.99:
			draw_circle(c, r, Color(0.15, 0.6, 0.28, 0.45 + 0.08 * sin(t * 4.0)))
			return
		var half := sqrt(maxf(r * r - dy * dy, 0.0))
		# (the surface laps less the shallower it is, so it never dips through the bottom of the orb)
		var wave := minf(2.2, (r - dy) * 0.2) * clampf((half - 2.0) / 20.0, 0.0, 1.0)
		var points := PackedVector2Array()
		const WAVE := 12
		for i in WAVE + 1:
			var x := -half + 2.0 * half * i / WAVE
			points.append(c + Vector2(x, dy + sin(x * 0.12 + t * 3.0) * wave))
		# (filled in strips across, row by row, under the surface: the orb's own width at each)
		var y := dy + wave
		while y < r:
			var w := sqrt(maxf(r * r - y * y, 0.0))
			draw_line(c + Vector2(-w, y), c + Vector2(w, y), Color(0.13, 0.55, 0.24, 0.5), 2.0)
			y += 2.0
		draw_polyline(points.slice(0, WAVE + 1), Color(0.6, 1.0, 0.65, 0.85), 2.0)
		# (bubbles rising through it)
		for i in 4:
			var k := fmod(t * 0.6 + i * 0.27, 1.0)
			var bx := c.x + sin(i * 2.3 + t) * half * 0.6
			var by := c.y + r - k * (r - dy)
			if Vector2(bx, by).distance_to(c) < r - 3.0:
				draw_arc(Vector2(bx, by), 2.5 + i % 2, 0, TAU, 8, Color(0.75, 1.0, 0.8, 0.7), 1.5)


## Whether the railway is broken at `p` (a length of its track beamed away or blown up there)
func track_torn(p: Vector3) -> bool:
	for gap in torn_track:
		if absf(gap.x - p.x) < 4.0 and absf(gap.z - p.z) < 3.0:
			return true
	return false


## The knocked-off hydrants' water, spouting up for good: the beam over one drinks it in, a trickle
## of points and the ship cooled (the heat let off a little)
func _geysering(delta: float) -> void:
	if geysers.is_empty():
		return
	var here := ufo.ground()
	geysers = geysers.filter(func(g: Vector3) -> bool: return g.distance_to(here) < 160.0)
	_geyser_wait -= delta
	for g in geysers:
		if g.distance_to(here) > 60.0:
			continue
		var drinking := ufo.beaming and not ufo.dead and Vector2(g.x - here.x, g.z - here.z).length() < ufo.beam_foot + 1.0
		if randf() < delta * 22.0:
			var up := Vector3(randf_range(-0.6, 0.6), randf_range(7.0, 10.0), randf_range(-0.6, 0.6))
			if drinking:
				up = Vector3(ufo.position.x - g.x, ufo.position.y + 2.0, ufo.position.z - g.z) * 1.4
			ufo.puffs.puff(g + Vector3(0, 0.4, 0), Color(0.65, 0.85, 1.0, 0.75), randf_range(0.25, 0.45), up, 0.9)
		if drinking and _geyser_wait <= 0.0:
			_geyser_wait = 0.25
			score += int(5 * Thing.WORTH) * multiplier()
			heat = maxf(heat - 0.04, 0.0)
			if randf() < 0.3:
				_popup("+WATER", g + Vector3(0, 3.0, 0), Color(0.6, 0.85, 1.0))


## A power-up's burst: bright motes of its colour bursting out and whirling round the saucer in a
## ring, rising and fading
var _whirling: Array = []
func _power_burst(tint: Color) -> void:
	for i in 26:
		var mote := Ps1.part(view, Ps1.ball(), Ps1.own(tint.lightened(randf_range(0.0, 0.4)), 2.5), ufo.position, Vector3.ONE * randf_range(0.18, 0.32))
		_whirling.append({"node": mote, "angle": i * TAU / 26.0, "radius": 0.5, "out": randf_range(2.8, 4.2),
			"y": randf_range(-0.6, 0.6), "speed": randf_range(4.0, 6.5) * (1.0 if i % 2 else -1.0), "age": 0.0, "life": randf_range(1.2, 1.8)})


func _whirl(delta: float) -> void:
	for w: Dictionary in _whirling.duplicate():
		w["age"] += delta
		var k: float = w["age"] / w["life"]
		var node: Node3D = w["node"]
		if k >= 1.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_whirling.erase(w)
			continue
		w["angle"] += w["speed"] * delta
		w["radius"] = lerpf(w["radius"], w["out"], minf(delta * 6.0, 1.0))
		node.position = ufo.position + Vector3(cos(w["angle"]) * w["radius"], w["y"] + k * 2.0, sin(w["angle"]) * w["radius"])
		node.scale = Vector3.ONE * 0.3 * (1.0 - k * k)


## The title's buttons and name coming on: flashing and flickering like a hologram warming up, steadier
## and brighter over TITLE_IN seconds, then on for good
const TITLE_IN := 0.9
var _title_in := -1.0
func _title_flicker(delta: float) -> void:
	if _title_in < 0.0:
		return
	_title_in += delta
	var k := _title_in / TITLE_IN
	if k >= 1.0 or mode != "title":
		_title_in = -1.0
		title_box.modulate = Color.WHITE
		return
	# (off and on, the gaps shortening; a brief flare of bright now and then)
	var lit := randf() < 0.25 + k * 0.75
	title_box.modulate = Color(1.0, 1.0, 1.0, (0.35 + 0.65 * k) if lit else 0.05 * k)
	if lit and randf() < 0.12:
		title_box.modulate = Color(1.6, 1.8, 1.6, 1.0)


## The STAR BIT BLASTER: star bits sprayed by themselves at whatever the defence laser would aim
## at, far quicker than it fires, but wild and weak: each one that hits does a small fraction of a
## laser hit (STAR_BIT_HIT, a little more with each level; enough of them add up to one, see
## `_laser_hit`) and knocks what it hits back away from the ship (STAR_BIT_SHOVE), and now and then
## one knocks a shell or a missile out of the air. They are jewels, every colour of the rainbow,
## each running through them as it flies.
const STAR_BIT_EVERY := 0.11
const STAR_BIT_SPEED := 30.0
const STAR_BIT_HIT := 0.06
## How hard a star bit knocks what it hits away (m/s, added up and dying away; at most STAR_BIT_SHOVE_MAX)
const STAR_BIT_SHOVE := 3.2
const STAR_BIT_SHOVE_MAX := 9.0
var _star_bit_wait := 0.0
var _star_bit_mesh: ArrayMesh
## In the air: {node, velocity, life}
var _star_bits_out: Array = []

func _star_bits(delta: float) -> void:
	_fly_star_bits(delta)
	var level: int = upgrades["starbits"]
	_star_bit_wait -= delta
	if level == 0 or ufo.dead or mode != "play" or intro > 0.0 or _star_bit_wait > 0.0:
		return
	# (on the ground round about, not as the crow flies from up where the ship is)
	var reach := 20.0 + 3.0 * level
	var target: Node3D
	var nearest := reach
	for s in shots:
		if s.kind in ["shell", "missile"] and not s.done and s.position.distance_to(ufo.position) < nearest:
			nearest = s.position.distance_to(ufo.position)
			target = s
	if target == null:
		for t in things:
			if t.is_enemy() and t.state == "walk" and not t.leaving and t.ground().distance_to(ufo.ground()) < nearest:
				nearest = t.ground().distance_to(ufo.ground())
				target = t
	if target == null:
		return
	_star_bit_wait = STAR_BIT_EVERY / (1.0 + 0.2 * (level - 1))
	var from := ufo.position + Vector3(0, -0.4, 0)
	var at := target.global_position + (Vector3(0, 0.8, 0) if target is Thing else Vector3.ZERO)
	# (wild: thrown well off where it is aimed)
	var way := (at - from).normalized().rotated(Vector3.UP, randf_range(-0.3, 0.3))
	way = way.rotated(way.cross(Vector3.UP).normalized() if absf(way.y) < 0.98 else Vector3.RIGHT, randf_range(-0.2, 0.2))
	var bit := MeshInstance3D.new()
	bit.mesh = _star_bit()
	var hue := randf()
	bit.material_override = Ps1.own(Color.from_hsv(hue, 0.9, 1.0), 1.1, 0.6)
	bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bit.position = from
	bit.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	view.add_child(bit)
	_star_bits_out.append({"node": bit, "velocity": way * STAR_BIT_SPEED, "life": 1.2, "hue": hue, "spin": Vector3(randf_range(-12, 12), randf_range(-12, 12), 0)})
	if randf() < 0.3:
		sfx.play("ding", randf_range(2.2, 2.8), -18.0)


func _fly_star_bits(delta: float) -> void:
	var hit_power: float = STAR_BIT_HIT * (1.0 + 0.15 * (int(upgrades["starbits"]) - 1))
	for b: Dictionary in _star_bits_out.duplicate():
		var node: MeshInstance3D = b["node"]
		b["life"] -= delta
		# (a jewel running through the colours of the rainbow as it flies)
		(node.material_override as ShaderMaterial).set_shader_parameter("tint", Color.from_hsv(fposmod(float(b["hue"]) + float(b["life"]) * 1.4, 1.0), 0.9, 1.0))
		node.position += (b["velocity"] as Vector3) * delta
		node.rotation += (b["spin"] as Vector3) * delta
		var done: bool = b["life"] <= 0.0 or node.position.y < 0.1
		if not done:
			for s in shots:
				if s.kind in ["shell", "missile"] and not s.done and s.position.distance_to(node.position) < 1.2:
					done = true
					if randf() < 0.2:
						s.done = true
						boom(s.position, 0.8)
					break
		if not done:
			for t in things:
				if t.is_enemy() and t.state == "walk" and t.ground().distance_to(Vector3(node.position.x, 0, node.position.z)) < t.size() * 0.6 + 0.5 and node.position.y < 3.0:
					done = true
					ufo.puffs.spark(node.position, Vector3(randf_range(-2, 2), 3.0, randf_range(-2, 2)), (node.material_override as ShaderMaterial).get_shader_parameter("tint"))
					var away := t.ground() - ufo.ground()
					away.y = 0.0
					if away.length() > 0.01:
						t.shove = (t.shove + away.normalized() * STAR_BIT_SHOVE).limit_length(STAR_BIT_SHOVE_MAX)
					var dealt: float = float(t.get_meta("star_bits", 0.0)) + hit_power
					if dealt >= 1.0:
						dealt -= 1.0
						_laser_hit(t, node.position)
					if is_instance_valid(t):
						t.set_meta("star_bits", dealt)
					break
		if done:
			node.queue_free()
			_star_bits_out.erase(b)


## A star bit: a little five-pointed star, puffed out front and back and cut in facets like a jewel
## (made once)
func _star_bit() -> ArrayMesh:
	if _star_bit_mesh != null:
		return _star_bit_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# (flat: no facet shares its corners' normals with the next)
	st.set_smooth_group(0xFFFFFFFF)
	var rim: Array[Vector3] = []
	for i in 10:
		var a := i * TAU / 10.0
		var r := 0.46 if i % 2 == 0 else 0.2
		rim.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for face: float in [1.0, -1.0]:
		var tip := Vector3(0, 0, 0.18 * face)
		for i in 10:
			var a: Vector3 = rim[i]
			var b: Vector3 = rim[(i + 1) % 10]
			for v: Vector3 in ([tip, a, b] if face > 0.0 else [tip, b, a]):
				st.add_vertex(v)
	# (each facet its own way, so they catch the light one by one as it tumbles)
	st.generate_normals()
	_star_bit_mesh = st.commit()
	return _star_bit_mesh


## Shots coming at the ship from off the screen (most of all from the sides on a phone): a pulsing
## red arrow at the edge where each will come in, bigger and brighter the closer it is
class ThreatMarks extends Control:
	var main: Node
	const MARGIN := 44.0
	const REACH := 50.0

	func _draw() -> void:
		var cam: Camera3D = main.camera
		var ufo: Ufo = main.ufo
		if cam == null or ufo == null or ufo.dead:
			return
		var scale_k: float = main.hud.scale.x
		var view := get_viewport().get_visible_rect().size / scale_k

		var mid := view * 0.5
		var t := Time.get_ticks_msec() / 1000.0
		for s: Shot in main.shots:
			if s.done:
				continue
			var to := ufo.position - s.position
			var far := to.length()
			if far > REACH or to.dot(s.velocity) <= 0.0:
				continue
			var behind := cam.is_position_behind(s.position)
			var p := cam.unproject_position(s.position) / scale_k
			if not behind and Rect2(Vector2.ZERO, view).grow(-12.0).has_point(p):
				continue
			var way := (p - mid) * (-1.0 if behind else 1.0)
			if way.length() < 1.0:
				way = Vector2.DOWN
			way = way.normalized()
			# (to the edge of the screen, MARGIN in from it, along the way it lies)
			var room := mid - Vector2(MARGIN, MARGIN)
			var k := minf(room.x / maxf(absf(way.x), 0.001), room.y / maxf(absf(way.y), 0.001))
			var at := mid + way * k
			var near := 1.0 - far / REACH
			var big := 14.0 + 16.0 * near
			var c: Color = Shot.SPECS[s.kind]["colour"]
			var warn := Color(1.0, 0.25, 0.2).lerp(c, 0.25)
			warn.a = (0.45 + 0.55 * near) * (0.7 + 0.3 * sin(t * 14.0))
			var side := Vector2(-way.y, way.x)
			draw_colored_polygon(PackedVector2Array([at + way * big, at - way * big * 0.5 + side * big * 0.75, at - way * big * 0.5 - side * big * 0.75]), warn)
			draw_circle(at - way * big * 1.1, big * 0.28, warn)


## Items in this order (common, uncommon, rare), each keeping its place among those of its rarity
func by_rarity(list: Array) -> Array:
	var out: Array = []
	for tier in 3:
		for what: String in list:
			if rarity(what) == tier:
				out.append(what)
	return out


## The nearest rival saucer still flying within `reach` of `p` (on the ground), or null
func rival_near(p: Vector3, reach: float) -> Thing:
	var best: Thing = null
	for t in things:
		if t.kind == "rival" and t.state == "walk" and not t.downed and not t.leaving:
			var d := t.ground().distance_to(p)
			if d < reach:
				reach = d
				best = t
	return best


## The police and army against rival saucers: any of them armed and near enough to one shoots at it
## now and then (as well as at the ship), until it is shot down (see Thing.downed, `rival_crashed`)
const RIVAL_SHOTS := {"pistol": "bullet", "rifle": "bullet", "shotgun": "pellet", "mg": "tracer", "laser": "laser", "railgun": "slug"}
## Shots in the air at rivals: {node, velocity, life, damage, target}
var _rival_fire: Array = []

func _rival_hunt(delta: float) -> void:
	for f: Dictionary in _rival_fire.duplicate():
		var s: Shot = f["node"]
		var target: Thing = f["target"]
		f["life"] -= delta
		s.position += (f["velocity"] as Vector3) * delta
		var hit := is_instance_valid(target) and target.state == "walk" and s.position.distance_to(target.position) < 2.6
		if hit:
			target.rival_hp -= float(f["damage"])
			Ps1.flash(target.model, Color(1.0, 0.6, 0.4))
			ufo.puffs.spark(s.position, Vector3(randf_range(-3, 3), randf_range(0, 3), randf_range(-3, 3)))
			if target.rival_hp <= 0.0 and not target.downed:
				target.downed = true
				_heat_note("THE POLICE SHOT DOWN A RIVAL!", 2.5)
				sfx.play("boom", 1.4, _near_db(target))
		if hit or f["life"] <= 0.0:
			s.queue_free()
			_rival_fire.erase(f)
	if mode != "play":
		return
	for r in things:
		if r.kind != "rival" or r.state != "walk" or r.downed or r.leaving:
			continue
		for t in things:
			if not t.is_enemy() or t.state != "walk" or t.stunned > 0.0:
				continue
			var gun: String = t.info.get("gun", "")
			if gun == "" or not RIVAL_SHOTS.has(gun) or t.ground().distance_to(r.ground()) > float(Thing.GUNS[gun]["range"]) + 10.0:
				continue
			var wait: float = float(t.get_meta("rival_wait", randf_range(0.5, 1.5))) - delta
			if wait > 0.0:
				t.set_meta("rival_wait", wait)
				continue
			t.set_meta("rival_wait", randf_range(1.3, 2.4))
			var kind: String = RIVAL_SHOTS[gun]
			var s := Shot.new()
			view.add_child(s)
			var from := t.muzzle()
			var at := r.position + Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 0.4), randf_range(-1.2, 1.2))
			s.setup(kind, from, at)
			_rival_fire.append({"node": s, "velocity": s.velocity, "life": s.life, "damage": s.damage, "target": r})
			sfx.play("pop", 1.1, _near_db(t) - 4.0)


## A rival saucer shot down came to the ground: its wreck there, in a ring of heaped dirt, to be
## beamed up like any crashed saucer (only the wreck: the dirt stays)
func rival_crashed(r: Thing) -> void:
	var at := Vector3(r.position.x, 0, r.position.z)
	boom(at + Vector3(0, 1.0, 0), 3.5)
	sfx.play("boom", 0.8, _near_db(r))
	world.crash_dirt(at, randf() * TAU)
	var wreck := spawn("crash_site", at, {"turn": randf() * TAU, "tints": r.info.get("tints", {})})
	if wreck != null:
		wreck.set_meta("rival", true)

	_remove(r)


## The GRAVITY SLING: every so often (sooner the more stacked), with the police or army about, a
## meteor slung down out of the sky onto the thick of them, blazing, and a blast where it lands:
## everything of theirs within SLING_SPLASH (more with each) is hit twice by it (most are blown up,
## see `_laser_hit`), and the ground scorched
const SLING_SPLASH := 6.0
const SLING_FALL := 1.3
var _sling_wait := 8.0
## Meteors on their way down: {node, from, to, age}
var _slung: Array = []

func _sling(delta: float) -> void:
	for f: Dictionary in _slung.duplicate():
		f["age"] += delta
		var k: float = minf(f["age"] / SLING_FALL, 1.0)
		var node: Node3D = f["node"]
		node.position = (f["from"] as Vector3).lerp(f["to"], k * k)
		node.rotation += Vector3(4.0, 3.0, 0.0) * delta
		if randf() < delta * 40.0:
			ufo.puffs.puff(node.position, Color(1.0, randf_range(0.35, 0.75), 0.15, 0.9), randf_range(0.6, 1.0), Vector3.UP * 0.5, 0.5)
		if k >= 1.0:
			_sling_impact(f["to"])
			node.queue_free()
			_slung.erase(f)
	var level: int = upgrades["sling"]
	_sling_wait -= delta
	if level == 0 or ufo.dead or mode != "play" or intro > 0.0 or _sling_wait > 0.0:
		return
	# (the one of theirs with the most of them round it, near enough)
	var best: Thing = null
	var most := 0
	for t in things:
		if not t.is_enemy() or t.state != "walk" or t.ground().distance_to(ufo.ground()) > 45.0:
			continue
		var round_it := 0
		for o in things:
			if o.is_enemy() and o.state == "walk" and o.ground().distance_to(t.ground()) < SLING_SPLASH:
				round_it += 1
		if round_it > most:
			most = round_it
			best = t
	if best == null:
		return
	_sling_wait = maxf(16.0 - 3.0 * level, 6.0)
	var to := best.ground()
	var rock := Ps1.model("meteorite")
	rock.scale = Vector3.ONE * (1.2 + 0.2 * level)
	var glow := MeshInstance3D.new()
	glow.mesh = Ps1.ball()
	glow.material_override = Ps1.own(Color(1.0, 0.5, 0.15), 3.0)
	glow.scale = Vector3.ONE * 1.6
	rock.add_child(glow)
	view.add_child(rock)
	var from := to + Vector3(randf_range(-25, 25), 70.0, randf_range(-25, 25))
	rock.position = from
	_slung.append({"node": rock, "from": from, "to": to, "age": 0.0})
	sfx.play("whoosh", 0.5, 0.0)
	_heat_note("GRAVITY SLING!", 1.2)


func _sling_impact(at: Vector3) -> void:
	var level: int = maxi(upgrades["sling"], 1)
	var splash := SLING_SPLASH + 1.5 * (level - 1)
	boom(at + Vector3(0, 1.0, 0), 4.0 + level)
	sfx.play("boom", 0.6, 4.0)
	_shake = maxf(_shake, 0.5)
	_scorch(at, splash * 1.4)
	for t in things.duplicate():
		if t.is_enemy() and t.state == "walk" and t.ground().distance_to(at) < splash:
			_laser_hit(t, t.position + Vector3(0, 1.0, 0))
			if is_instance_valid(t) and t.state == "walk":
				_laser_hit(t, t.position + Vector3(0, 1.0, 0))
		elif t.state == "walk" and t.ground().distance_to(at) < splash * 2.0 and t.info["move"] in ["flee", "graze", "peck"]:
			# (anything else near it runs for it)
			t.panic = maxf(t.panic, 6.0)


## Rockets on their pads (see world.gd `_spaceport`): the ship coming within LAUNCH_NEAR sets the
## countdown going, T-10 called over the pad each second, then ignition (smoke billowing out of the
## flame trench) and lift-off, slow then faster, a column of fire and smoke under it, until it is gone
## up into the sky. Beamed up before then, it is the ship's.
const LAUNCH_NEAR := 70.0
const COUNTDOWN := 10.0

func _rocket_launches(delta: float) -> void:
	if mode != "play":
		return
	for t: Thing in things.duplicate():
		if t.kind != "rocket" or t.state != "walk":
			continue
		var count: float = t.get_meta("count", COUNTDOWN)
		if not t.has_meta("count"):
			if not ufo.dead and t.ground().distance_to(ufo.ground()) < LAUNCH_NEAR:
				t.set_meta("count", COUNTDOWN)
				_heat_note("A ROCKET IS COUNTING DOWN!", 2.0)
			continue
		var was := ceili(count)
		count -= delta
		t.set_meta("count", count)
		if count > 0.0:
			if ceili(count) != was:
				_popup("T-%d" % ceili(count), t.position + Vector3(0, 20.0, 0), Color(1.0, 0.85, 0.4))
				sfx.play("key", 0.6, _near_db(t) + 4.0)
			if count < 3.0 and randf() < delta * 20.0:
				# (ignition: smoke rolling out across the pad)
				var a := randf() * TAU
				puff(t.ground() + Vector3(cos(a) * 3.0, 0.8, sin(a) * 3.0), Color(0.85, 0.85, 0.82), randf_range(2.0, 3.5))
			if count < 3.0 and ceili(count) != was and was == 3:
				sfx.play("boom", 0.4, _near_db(t) + 6.0)
				_shake = maxf(_shake, 0.3)
			continue
		# Lift-off: up it goes, faster and faster, on a column of fire and smoke
		if not t.has_meta("rising"):
			t.set_meta("rising", 0.0)
			_popup("LIFT OFF!", t.position + Vector3(0, 20.0, 0), Color(1.0, 0.6, 0.3))
			if t.obstacle != Vector4.ZERO:
				world.remove_obstacle(t.chunk, t.obstacle)
				t.obstacle = Vector4.ZERO
		var speed: float = t.get_meta("rising") + delta * 9.0
		t.set_meta("rising", speed)
		t.position.y += speed * delta
		var foot := t.position
		if randf() < delta * 40.0:
			ufo.puffs.puff(foot + Vector3(randf_range(-0.6, 0.6), -0.5, randf_range(-0.6, 0.6)), Color(1.0, randf_range(0.4, 0.8), 0.15, 0.9), randf_range(1.0, 1.8), Vector3(0, -6.0, 0), 0.4)
		if randf() < delta * 25.0:
			puff(foot + Vector3(randf_range(-1, 1), -2.0, randf_range(-1, 1)), Color(0.8, 0.8, 0.78), randf_range(2.0, 3.0))
		if t.position.y > 220.0:
			_remove(t)


## The dev room on or off (D-E-V typed on the title, or seven taps on its name): every ship to try
## while it is on, the ships really found kept aside; nothing from it saved or sent to the scoreboard
func toggle_dev() -> void:
	dev = not dev
	if dev:
		_kept_unlocked.assign(unlocked)
		unlocked.assign(Ufo.ORDER)
	else:
		unlocked.assign(_kept_unlocked)
		if not ship in unlocked:
			ship = "saucer"
	_show_ship()
	sfx.play("ding", 0.8 if dev else 0.5, 0.0)
	# (said over the ship parked on the moon, where it shows on the title)
	_popup("DEV ROOM: EVERY SHIP" if dev else "DEV ROOM OFF", ufo.position + Vector3(0, 3.0, 0), Color(1.0, 0.85, 0.4))
