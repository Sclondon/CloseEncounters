class_name Holograms
extends Node
## Little hologram pictures of the models, for the log: each drawn once, off screen, in green light
## (shaders/hologram.gdshader), a model a frame or two, and kept. `icon` hands back its picture at
## once (blank until it is drawn, then filled in where it is shown).

const SIZE := 96
const SHADER := preload("res://shaders/hologram.gdshader")
const FLICKER := preload("res://shaders/hologram_flicker.gdshader")
const GREEN := Color(0.35, 1.0, 0.55)

var _view: SubViewport
var _camera: Camera3D
var _pictures := {}
var _queue: Array[String] = []
var _drawing: Node3D
var _waiting := 0
var _material: ShaderMaterial
var _flicker: ShaderMaterial


func _ready() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(SIZE, SIZE)
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
	_view.add_child(_camera)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_flicker = ShaderMaterial.new()
	_flicker.shader = FLICKER


## The picture of a kind of thing (by its kind in Thing.KINDS)
func icon(kind: String) -> Texture2D:
	if _pictures.has(kind):
		return _pictures[kind]
	var blank := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var picture := ImageTexture.create_from_image(blank)
	_pictures[kind] = picture
	_queue.append(kind)
	return picture


## A TextureRect showing the hologram of `kind`, `size` across, flickering
func view(kind: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(kind)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size = Vector2(size, size)
	r.material = _flicker
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _process(_delta: float) -> void:
	if _drawing != null:
		_waiting -= 1
		if _waiting > 0:
			return
		var kind: String = _drawing.get_meta("kind")
		(_pictures[kind] as ImageTexture).set_image(_view.get_texture().get_image())
		_drawing.queue_free()
		_drawing = null
	if _queue.is_empty():
		return
	var kind: String = _queue.pop_front()
	var lit := kind.begins_with("item:")
	if lit:
		var model_name: String = ITEM_MODELS.get(kind.trim_prefix("item:"), "pod")
		# (an item whose model is not built yet shows as the turret's)
		if not ResourceLoader.exists("res://models/%s.glb" % model_name):
			model_name = "item_turret"
		_drawing = Ps1.model(model_name)
		_drawing.set_meta("kind", kind)
		_view.add_child(_drawing)
		_frame(_drawing, true, item_colours.get(kind.trim_prefix("item:"), GREEN))
		return
	# (a kind of thing, or one of the ships, by its name in Ufo.SHIPS)
	var info: Dictionary = Thing.KINDS.get(kind, Ufo.SHIPS.get(kind, Thing.KINDS.get("fighter_" + kind, {})))
	if info.is_empty():
		return
	var name: String = info.get("model", kind)
	if name != "pine" and not ResourceLoader.exists("res://models/%s.glb" % name):
		return
	_drawing = Ps1.model(name, info.get("tints", {}))
	_drawing.set_meta("kind", kind)
	_view.add_child(_drawing)
	_frame(_drawing, true)



## The camera on a model to be drawn: seen from the front and a little to its right and above, all of
## it in the picture; as a hologram (green light) or in its own colours
func _frame(model: Node3D, hologram: bool, tint := GREEN) -> void:
	model.rotation.y = -0.6
	var box := AABB()
	var light := _material
	if tint != GREEN:
		light = _material.duplicate() as ShaderMaterial
		light.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if hologram:
			mi.material_override = light
			mi.set_surface_override_material(0, null)
		else:
			# (its own colours, in a plain lit material: the game's own bends with the world, which
			# would carry it out of this little picture)
			_plain(mi)
		var part := mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
	var middle := box.get_center()
	var across := maxf(box.size.y, maxf(box.size.x, box.size.z))
	_camera.size = across * 1.15
	_camera.position = middle + Vector3(0, across * 0.35, across * 2.0)
	_camera.look_at(middle)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_waiting = 2

## An item (an upgrade) as a little 3D model, as Risk of Rain 2 shows its items: a hologram in the
## item's own colour (`item_colours`, filled in from main.gd UPGRADES); by the upgrade's name
const ITEM_MODELS := {"engine": "item_engine", "beam": "item_beam", "shield": "item_shield", "dash": "item_dash",
	"laser": "item_laser", "turret": "item_turret", "missiles": "item_missiles", "cloak": "item_cloak", "fleet": "ufo", "patch": "item_shield",
	"magnet": "item_magnet", "wide": "item_wide", "scanner": "item_scanner", "jammer": "item_jammer", "coolant": "item_coolant", "nanobots": "item_nanobots", "gold": "item_gold", "emp": "item_emp", "lucky": "item_lucky", "armor": "item_armor", "second_wind": "item_second_wind", "swivel": "item_swivel", "starbits": "item_starbits"}


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
