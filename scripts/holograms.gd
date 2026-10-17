class_name Holograms
extends Node
## Little hologram pictures of the models, for the log and the Moon Market: each drawn once, off
## screen, in green light (shaders/hologram.gdshader), and kept. Each is drawn from ANGLES sides at
## once, the model set out that many times in a row each turned a little further, so that it can be
## shown turning slowly round (`turning`, `view`) at no cost; `icon` is the first of them, still.
## Both are handed back at once (blank until drawn, then filled in where they are shown).

const SIZE := 72
const ANGLES := 16
## Seconds for a model to turn once round
const TURN := 9.0
const SHADER := preload("res://shaders/hologram.gdshader")
const FLICKER := preload("res://shaders/hologram_flicker.gdshader")
const GREEN := Color(0.35, 1.0, 0.55)

var _view: SubViewport
var _camera: Camera3D
## Still pictures, the row of all sides, and the turning ones (a window onto the row), by kind
var _pictures := {}
var _strips := {}
var _turning := {}
var _queue: Array[String] = []
var _drawing: Node3D
var _waiting := 0
var _material: ShaderMaterial
var _flicker: ShaderMaterial
var _side := -1


func _ready() -> void:
	# (turning in the Moon Market too, which pauses the game)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = SubViewport.new()
	_view.size = Vector2i(SIZE * ANGLES, SIZE)
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	# (a light for the items, drawn in their own colours: see `item`)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.4
	_view.add_child(sun)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.background_mode = Environment.BG_CLEAR_COLOR
	_camera = Camera3D.new()
	_camera.environment = env
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_view.add_child(_camera)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_flicker = ShaderMaterial.new()
	_flicker.shader = FLICKER


## The picture of a kind of thing (by its kind in Thing.KINDS), still
func icon(kind: String) -> Texture2D:
	if _pictures.has(kind):
		return _pictures[kind]
	_pictures[kind] = ImageTexture.create_from_image(Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8))
	_strips[kind] = ImageTexture.create_from_image(Image.create(SIZE * ANGLES, SIZE, false, Image.FORMAT_RGBA8))
	_queue.append(kind)
	return _pictures[kind]


## The picture of a kind of thing turning slowly round
func turning(kind: String) -> Texture2D:
	icon(kind)
	if not _turning.has(kind):
		var t := AtlasTexture.new()
		t.atlas = _strips[kind]
		t.region = Rect2(0, 0, SIZE, SIZE)
		_turning[kind] = t
	return _turning[kind]


## A TextureRect showing the hologram of `kind`, `size` across, flickering and turning slowly round
func view(kind: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = turning(kind)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size = Vector2(size, size)
	r.material = _flicker
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _process(_delta: float) -> void:
	# (the turning pictures all on to the next side together, ANGLES to a turn)
	var side := int(Time.get_ticks_msec() / 1000.0 / TURN * ANGLES) % ANGLES
	if side != _side:
		_side = side
		for kind: String in _turning:
			(_turning[kind] as AtlasTexture).region = Rect2(side * SIZE, 0, SIZE, SIZE)
	if _drawing != null:
		_waiting -= 1
		if _waiting > 0:
			return
		var kind: String = _drawing.get_meta("kind")
		var row := _view.get_texture().get_image()
		# (nothing drawn with no screen to draw on, as in the tests)
		if row != null and not row.is_empty():
			(_strips[kind] as ImageTexture).set_image(row)
			(_pictures[kind] as ImageTexture).set_image(row.get_region(Rect2i(0, 0, SIZE, SIZE)))
		_drawing.queue_free()
		_drawing = null
	if _queue.is_empty():
		return
	var kind: String = _queue.pop_front()
	var model_name := ""
	var tints := {}
	var tint := GREEN
	if kind.begins_with("item:"):
		model_name = ITEM_MODELS.get(kind.trim_prefix("item:"), "pod")
		# (an item whose model is not built yet shows as the turret's)
		if not ResourceLoader.exists("res://models/%s.glb" % model_name):
			model_name = "item_turret"
		tint = item_colours.get(kind.trim_prefix("item:"), GREEN)
	else:
		# (a kind of thing, or one of the ships, by its name in Ufo.SHIPS)
		var info: Dictionary = Thing.KINDS.get(kind, Ufo.SHIPS.get(kind, Thing.KINDS.get("fighter_" + kind, {})))
		if info.is_empty():
			return
		model_name = info.get("model", kind)
		tints = info.get("tints", {})
		if not Ps1.is_grown(model_name) and not ResourceLoader.exists("res://models/%s.glb" % model_name):
			return
	_drawing = Node3D.new()
	_drawing.set_meta("kind", kind)
	_view.add_child(_drawing)
	_frame(model_name, tints, tint)


## The model set out ANGLES times in a row, each turned a little further round about its middle,
## and the camera on the row: each in its own square of the picture, seen from the front and a
## little above, all of it in, as a hologram in `tint`
func _frame(model_name: String, tints: Dictionary, tint: Color) -> void:
	var light := _material
	if tint != GREEN:
		light = _material.duplicate() as ShaderMaterial
		light.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var box := AABB()
	var models: Array[Node3D] = []
	for k in ANGLES:
		var model := Ps1.model(model_name, tints)
		models.append(model)
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = light
			if k == 0:
				var part := mi.transform * mi.get_aabb()
				var up := mi.get_parent() as Node3D
				while up != null and up != model:
					part = up.transform * part
					up = up.get_parent() as Node3D
				box = part if box.size == Vector3.ZERO else box.merge(part)
	var middle := box.get_center()
	# (room for it however it is turned: as wide as its widest way across, and as tall)
	var across := maxf(box.size.y, Vector2(box.size.x, box.size.z).length())
	var step := across * 1.15
	for k in ANGLES:
		var pivot := Node3D.new()
		pivot.position = Vector3(k * step, 0, 0)
		pivot.rotation.y = -0.6 + k * TAU / ANGLES
		_drawing.add_child(pivot)
		models[k].position = Vector3(-middle.x, 0, -middle.z)
		pivot.add_child(models[k])
	var centre := Vector3((ANGLES - 1) * step * 0.5, middle.y, 0)
	_camera.size = step
	_camera.position = centre + Vector3(0, across * 0.35, across * 2.0)
	_camera.look_at(centre)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_waiting = 2

## An item (an upgrade) as a little 3D model, as Risk of Rain 2 shows its items: a hologram in the
## item's own colour (`item_colours`, filled in from main.gd UPGRADES); by the upgrade's name
const ITEM_MODELS := {"engine": "item_engine", "beam": "item_beam", "shield": "item_shield", "dash": "item_dash",
	"laser": "item_laser", "turret": "item_turret", "missiles": "item_missiles", "cloak": "item_cloak", "fleet": "ufo", "patch": "item_shield",
	"magnet": "item_magnet", "wide": "item_wide", "scanner": "item_scanner", "jammer": "item_jammer", "coolant": "item_coolant", "nanobots": "item_nanobots", "gold": "item_gold", "emp": "item_emp", "lucky": "item_lucky", "armor": "item_armor", "second_wind": "item_second_wind", "swivel": "item_swivel", "starbits": "item_starbits", "sling": "item_sling"}


## Each item's colour, by its name
var item_colours := {}


func item(what: String) -> Texture2D:
	return icon("item:" + what)


## A model's mesh dressed in plain lit materials of the colours the game gives it: from the corners'
## colours of a merged model, or each surface's tint
func _plain(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var was: Material = mi.material_override if mi.material_override != null else mi.get_surface_override_material(i)
		var m := StandardMaterial3D.new()
		m.roughness = 0.8
		if was is ShaderMaterial and (was as ShaderMaterial).get_shader_parameter("tint") is Color and mi.material_override == null:
			m.albedo_color = (was as ShaderMaterial).get_shader_parameter("tint")
		else:
			m.vertex_color_use_as_albedo = true
		mi.set_surface_override_material(i, m)
	mi.material_override = null
