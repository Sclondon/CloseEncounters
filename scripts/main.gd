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
## Modes: "title" (the saucer flies itself behind the title), "play", "over". Tests set
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
const STOCK := {"cow": 22, "sheep": 16, "pig": 14, "chicken": 26, "farmer": 10, "person": 14, "hay_bale": 14,
	"scarecrow": 8, "outhouse": 6, "tractor": 6, "car": 8, "pickup": 5}
const CAMERA_OFFSET := Vector3(0, 17.0, 13.0)

@export var start_mode := "title"
var autopilot := false
## Tests run without the title screen's script check and must never save bests
var testing := false
## Leaves the camera where a test put it
var hold_camera := false

var mode := "title"
var view: SubViewport
var screen: TextureRect
var screen_mat: ShaderMaterial
var camera: Camera3D
var world: World
var ufo: Ufo
var sfx: Sfx
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
var _stock_wait := 0.0
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
var stars: Control
var shield_bar: Control
var banner: Label
var banner_time := 0.0
var title_box: Control
var over_box: Control
var over_label: Label
var hint_label: Label
var font: Font
var _popups: Array[Label3D] = []

# Touch: a stick wherever the left thumb lands, and a beam button on the right
var stick_finger := -1
var stick_from := Vector2.ZERO
var stick := Vector2.ZERO
var beam_finger := -1
var beam_button: Control
var stick_ring: Control
var touched := false
## Where and when each finger came down, to tell a swipe (a quick flick: a dodge) from a hold
var _touch_from := {}
const SWIPE_TIME := 0.3
const SWIPE_LENGTH := 70.0


func _ready() -> void:
	randomize()
	# (the game pauses the tree itself, and has to go on listening for the key that unpauses it)
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://fonts/SpecialElite-Regular.ttf")
	_input_map()
	sfx = Sfx.new()
	add_child(sfx)
	_build_view()
	world = World.new()
	view.add_child(world)
	world.build()
	ufo = Ufo.new()
	view.add_child(ufo)
	_build_hud()
	_load_best()
	for kind: String in STOCK:
		for i in STOCK[kind]:
			_spawn(kind, true)
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

func start() -> void:
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
	ufo = Ufo.new()
	view.add_child(ufo)
	heat = 0.0
	calm = 0.0
	score = 0
	taken = 0
	time_alive = 0.0
	_last_level = 0
	_spawn_wait = 2.0
	_jet_wait = 8.0
	title_box.visible = false
	over_box.visible = false
	_banner("BEAM THEM UP", 2.5)
	sfx.play("whoosh", 1.2)


func heat_level() -> int:
	return mini(int(heat), int(MAX_HEAT))


func multiplier() -> int:
	return 1 + heat_level()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and mode == "play" and not autopilot:
		get_tree().paused = not get_tree().paused
		_banner("PAUSED" if get_tree().paused else "", 999.0 if get_tree().paused else 0.0)
	if get_tree().paused:
		return
	var steer := Vector2.ZERO
	var beam := false
	if mode == "play" and not autopilot:
		steer = _read_steer()
		beam = Input.is_action_pressed("beam") or beam_finger >= 0
		if Input.is_action_just_pressed("dodge"):
			# (the way it is steered, or else the way it is going, or else away up the screen)
			var way := steer if steer.length() > 0.2 else Vector2(ufo.velocity.x, ufo.velocity.z)
			_dodge(way if way.length() > 0.5 else Vector2(0, -1))
	elif not ufo.dead:
		var pilot := _pilot(delta)
		steer = pilot[0]
		beam = pilot[1]
	ufo.tick(delta, steer, beam)
	ufo.mend_rate = 6.0 if heat_level() == 0 else 0.0
	if mode == "title":
		heat = 0.0
		ufo.hull = 100.0
	# The beam takes hold of whatever is under it
	for t in things:
		if t.state == "gone":
			continue
		if ufo.in_beam(t.position, t.size() * 0.4):
			if t.state == "walk" or t.state == "falling":
				if t.state == "walk" and t.info.has("voice") and randf() < 0.6:
					sfx.play(t.info["voice"], randf_range(0.9, 1.1), -4.0)
				t.state = "lifted"
				t.lift = clampf(t.position.y / (Ufo.ALTITUDE - 0.9), 0.0, 1.0)
			t.held = true
		t.tick(delta, ufo)
	things = things.filter(func(t: Thing) -> bool: return t.state != "gone")
	for s in shots:
		s.tick(delta, ufo, self)
	for s in shots:
		if s.done:
			s.queue_free()
	shots = shots.filter(func(s: Shot) -> bool: return not s.done)
	_jets(delta)
	if mode == "play":
		time_alive += delta
		_heat(delta)
		_forces(delta)
	_restock(delta)
	_sounds()
	_camera(delta)
	_hud(delta)
	if ufo.dead and mode == "play":
		_crash(delta)
	if mode == "over" and Input.is_action_just_pressed("start") and _over_wait <= 0.0:
		start()
	if mode == "title" and Input.is_action_just_pressed("start"):
		start()
	if _over_wait > 0.0:
		_over_wait -= delta


## A dash out of the way of what is coming, if one is ready
func _dodge(way: Vector2) -> void:
	if ufo.dodge(way.normalized()):
		sfx.play("whoosh", 1.7, -2.0)
		puff(ufo.position, Color(0.6, 0.9, 0.7), 1.2)


func _read_steer() -> Vector2:
	var v := Input.get_vector("left", "right", "up", "down")
	if stick_finger >= 0:
		v = stick
	return v.limit_length(1.0)


func _heat(delta: float) -> void:
	calm += delta
	if calm > COOL_AFTER and heat > 0.0:
		heat = maxf(heat - COOL_RATE * delta, 0.0)
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
			if t.is_enemy() and not t.leaving:
				have[t.kind] = int(have.get(t.kind, 0)) + 1
				if int(have[t.kind]) > int(wanted.get(t.kind, 0)):
					t.leaving = true


## Keeps the police and army up to strength for the heat, bringing them in from out of sight
func _forces(delta: float) -> void:
	_spawn_wait -= delta
	for t in things:
		if t.leaving and t.ground().distance_to(ufo.ground()) > 70.0:
			_remove(t)
	if _spawn_wait > 0.0 or ufo.dead:
		return
	var wanted: Dictionary = FORCES[heat_level()]
	for kind: String in wanted:
		var have := 0
		for t in things:
			if t.kind == kind and not t.leaving:
				have += 1
		if have < int(wanted[kind]):
			var angle := randf_range(-PI * 0.8, PI * 0.8) + PI
			var at := ufo.ground() + Vector3(sin(angle), 0, cos(angle)) * 48.0
			at.x = clampf(at.x, -World.SIZE, World.SIZE)
			at.z = clampf(at.z, -World.SIZE, World.SIZE)
			var t := _spawn(kind, false, at)
			t.heading = atan2(ufo.position.x - at.x, ufo.position.z - at.z)
			_spawn_wait = 2.5
			if kind == "police_car" and have == 0:
				_banner("SIRENS!", 1.2)
			return


func _jets(delta: float) -> void:
	if mode == "play" and heat_level() >= 5 and not ufo.dead:
		_jet_wait -= delta
		if _jet_wait <= 0.0:
			_jet_wait = randf_range(7.0, 10.0)
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


func _restock(delta: float) -> void:
	_stock_wait -= delta
	if _stock_wait > 0.0:
		return
	_stock_wait = 1.5
	var have := {}
	for t in things:
		have[t.kind] = int(have.get(t.kind, 0)) + 1
	for kind: String in STOCK:
		if int(have.get(kind, 0)) < int(STOCK[kind]):
			_spawn(kind, false)
			return


func _spawn(kind: String, anywhere: bool, at := Vector3.INF) -> Thing:
	var t := Thing.new()
	var road := []
	if at == Vector3.INF:
		if Thing.KINDS[kind]["move"] == "road":
			road = world.road_spot(Vector3(9999, 0, 9999) if anywhere else ufo.ground())
			at = road[0]
		else:
			at = world.spot_for(kind, Vector3(9999, 0, 9999) if anywhere else ufo.ground())
	view.add_child(t)
	t.setup(self, kind, at)
	if not road.is_empty():
		t.road_axis = road[1]
		t.road_dir = road[2]
		t.heading = (0.0 if road[2] > 0.0 else PI) if road[1] == "z" else (PI / 2 if road[2] > 0.0 else -PI / 2)
		t.rotation.y = t.heading
	things.append(t)
	return t


func _remove(t: Thing) -> void:
	t.state = "gone"
	things.erase(t)
	t.queue_free()


## Something reached the saucer
func abducted(t: Thing) -> void:
	var points := t.points() * multiplier()
	if mode == "play":
		score += points
		taken += 1
		heat = minf(heat + float(t.info["heat"]), MAX_HEAT)
		calm = 0.0
	ufo.alien.feel("cheer", 0.9)
	sfx.play("bloop", 1.0 + randf() * 0.2)
	if mode == "play":
		_popup("+%d" % points, ufo.position + Vector3(0, 1.5, 0), Color(0.6, 1.0, 0.6))
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
			_popup("CRUSHED +%d" % points, other.position + Vector3(0, 3, 0), Color(1.0, 0.8, 0.3))
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
			if t.state == "gone" or (t.is_enemy() and mode == "title") or t.info["move"] == "road":
				continue
			var d := t.ground().distance_to(ufo.ground())
			var worth := float(t.points()) / (1.0 + float(t.info["weight"])) - d * 2.0
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

func _camera(delta: float) -> void:
	if hold_camera:
		return
	var focus := Vector3(ufo.position.x, 0.0, ufo.position.z)
	if ufo.crashed or ufo.dead:
		focus = Vector3(ufo.position.x, 0.0, ufo.position.z)
	var goal := focus + CAMERA_OFFSET
	if mode == "title":
		goal = focus + Vector3(0, 11.0, 15.0)
	camera.position = camera.position.lerp(goal, minf(delta * 4.0, 1.0)) if camera.position != Vector3.ZERO else goal
	# (the saucer sits a little above the middle of the picture, with more to see ahead of it)
	var look_at_point := camera.position - CAMERA_OFFSET + Vector3(0, 4.0, -1.5)
	if mode == "title":
		look_at_point = camera.position - Vector3(0, 11.0, 15.0) + Vector3(0, 4.0, -6.0)
	camera.look_at(look_at_point)
	_shake = maxf(_shake - delta, 0.0)
	if _shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
	# The world bends away from the ground under the camera's middle
	var under := camera.position - CAMERA_OFFSET if mode != "title" else camera.position - Vector3(0, 11.0, 15.0)
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(under.x, 0.0, under.z - 1.0))
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

	score_label = _label(40)
	score_label.position = Vector2(24, 14)
	root.add_child(score_label)
	mult_label = _label(26, Color(0.6, 1.0, 0.6))
	mult_label.position = Vector2(26, 62)
	root.add_child(mult_label)

	stars = Stars.new()
	stars.main = self
	stars.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stars.position = Vector2(-150, 14)
	stars.size = Vector2(300, 64)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stars)

	shield_bar = Shield.new()
	shield_bar.main = self
	shield_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shield_bar.position = Vector2(-264, 20)
	shield_bar.size = Vector2(240, 54)
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
	title_box.add_child(_button("PLAY", start))

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


func _show_title() -> void:
	mode = "title"
	title_box.visible = true
	over_box.visible = false
	hint_label.text = "Move: WASD, arrows, stick or drag on the left    Beam: hold Space, A, or the button    Dodge: Shift, B, or swipe"


func _banner(text: String, seconds: float) -> void:
	banner.text = text
	banner_time = seconds


func _hud(delta: float) -> void:
	var playing := mode == "play"
	score_label.visible = playing or mode == "over"
	mult_label.visible = playing
	stars.visible = playing
	shield_bar.visible = playing
	score_label.text = "%d" % score
	mult_label.text = "x%d" % multiplier()
	stars.queue_redraw()
	shield_bar.queue_redraw()
	stick_ring.queue_redraw()
	beam_button.visible = touched and playing
	beam_button.queue_redraw()
	if banner_time > 0.0:
		banner_time -= delta
		banner.modulate.a = clampf(banner_time * 2.0, 0.0, 1.0)
	else:
		banner.text = ""


func _layout_touch() -> void:
	if beam_button == null:
		return
	var size := get_viewport().get_visible_rect().size
	var r := minf(size.x, size.y) * 0.14
	beam_button.size = Vector2(r * 2, r * 2)
	beam_button.position = Vector2(size.x - r * 2.6, size.y - r * 2.6)


func _unhandled_input(event: InputEvent) -> void:
	if mode != "play" or autopilot:
		return
	if get_tree().paused:
		if event is InputEventScreenTouch and event.pressed:
			get_tree().paused = false
			_banner("", 0.0)
		return
	if event is InputEventScreenTouch:
		touched = true
		var e: InputEventScreenTouch = event
		var size := get_viewport().get_visible_rect().size
		var on_beam := beam_button.get_global_rect().grow(30).has_point(e.position)
		var now := Time.get_ticks_msec() / 1000.0
		if not e.pressed and _touch_from.has(e.index):
			var from: Array = _touch_from[e.index]
			_touch_from.erase(e.index)
			var flick: Vector2 = e.position - from[0]
			if now - float(from[1]) < SWIPE_TIME and flick.length() > SWIPE_LENGTH:
				_dodge(flick)
		if e.pressed:
			_touch_from[e.index] = [e.position, now]
			if on_beam or e.position.x > size.x * 0.6:
				beam_finger = e.index
			elif stick_finger < 0:
				stick_finger = e.index
				stick_from = e.position
				stick = Vector2.ZERO
		else:
			if e.index == beam_finger:
				beam_finger = -1
			if e.index == stick_finger:
				stick_finger = -1
				stick = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var e: InputEventScreenDrag = event
		if e.index == stick_finger:
			var reach := minf(get_viewport().get_visible_rect().size.y * 0.12, 90.0)
			var off := e.position - stick_from
			# (the stick's middle follows a thumb that goes past its rim)
			if off.length() > reach:
				stick_from = e.position - off.normalized() * reach
				off = off.normalized() * reach
			stick = off / reach


# ------------------------------------------------------------------ bests

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://best.cfg") == OK:
		best = int(cfg.get_value("best", "score", 0))


func _save_best() -> void:
	if testing:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("best", "score", best)
	cfg.save("user://best.cfg")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play" and not autopilot and not testing:
		get_tree().paused = true
		_banner("PAUSED", 999.0)


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


## The saucer's shield, as a bar
class Shield extends Control:
	var main: Node

	func _draw() -> void:
		var hull: float = main.ufo.hull
		draw_string(main.font, Vector2(0, 18), "SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.9, 1.0))
		var r := Rect2(0, 26, size.x, 20)
		draw_rect(r, Color(0, 0, 0, 0.6))
		var c := Color(0.4, 0.9, 1.0) if hull > 35.0 else Color(1.0, 0.3, 0.2)
		if hull <= 35.0 and fmod(Time.get_ticks_msec() / 250.0, 2.0) < 1.0:
			c = c.lightened(0.4)
		draw_rect(Rect2(r.position, Vector2(r.size.x * hull / 100.0, r.size.y)), c)
		draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)


## Where the thumb is on the touch stick
class StickRing extends Control:
	var main: Node

	func _draw() -> void:
		if main.stick_finger < 0:
			return
		var reach := minf(main.get_viewport().get_visible_rect().size.y * 0.12, 90.0)
		draw_arc(main.stick_from, reach, 0, TAU, 32, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(main.stick_from + main.stick * reach, reach * 0.4, Color(0.6, 1.0, 0.6, 0.4))


class BeamButton extends Control:
	var main: Node

	func _draw() -> void:
		var r := size.x * 0.5
		var on: bool = main.beam_finger >= 0
		draw_circle(Vector2(r, r), r, Color(0.3, 1.0, 0.45, 0.55 if on else 0.25))
		draw_arc(Vector2(r, r), r, 0, TAU, 40, Color(0.7, 1.0, 0.75, 0.8), 3.0)
		draw_string(main.font, Vector2(0, r + 12), "BEAM", HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color(1, 1, 1, 0.9))
