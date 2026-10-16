class_name Holograms
extends Node
## Little hologram pictures of the models, for the log: each drawn once, off screen, in green light
## (shaders/hologram.gdshader), a model a frame or two, and kept. `icon` hands back its picture at
## once (blank until it is drawn, then filled in where it is shown).

const SIZE := 96
const SHADER := preload("res://shaders/hologram.gdshader")
const FLICKER := preload("res://shaders/hologram_flicker.gdshader")

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
	_camera = Camera3D.new()
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
	if not Thing.KINDS.has(kind):
		return
	var info: Dictionary = Thing.KINDS[kind]
	var name: String = info.get("model", kind)
	if name != "pine" and not ResourceLoader.exists("res://models/%s.glb" % name):
		return
	_drawing = Ps1.model(name, info.get("tints", {}))
	_drawing.set_meta("kind", kind)
	_view.add_child(_drawing)
	# (seen from the front and a little to its right and above, all of it in the picture)
	_drawing.rotation.y = -0.6
	var box := AABB()
	for mi: MeshInstance3D in _drawing.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _material
		mi.set_surface_override_material(0, null)
		var part := mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
	var middle := box.get_center()
	var across := maxf(box.size.y, maxf(box.size.x, box.size.z))
	_camera.size = across * 1.15
	_camera.position = middle + Vector3(0, across * 0.35, across * 2.0)
	_camera.look_at(middle)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_waiting = 2
