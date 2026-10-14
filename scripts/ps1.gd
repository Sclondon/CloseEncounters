class_name Ps1
## Materials for the PlayStation-era look (from Cryptlins' ps1.gd), on the bent world (see
## shaders/bend.gdshaderinc), and the Blender models (models/*.glb, from tools/build_models.py)
## dressed in them. Materials of one colour are shared.

const LIT: Shader = preload("res://shaders/ps1.gdshader")
const FLAT: Shader = preload("res://shaders/ps1_flat.gdshader")
const GLASS: Shader = preload("res://shaders/glass.gdshader")
# The world is drawn this many pixels high and blown up
const LINES := 300.0

static var _shared := {}
static var _scenes := {}


static func mat(c: Color, glow := 0.0, rim := 0.0) -> ShaderMaterial:
	var key := "%s/%s/%s" % [c.to_html(), glow, rim]
	if _shared.has(key):
		return _shared[key]
	var m := own(c, glow, rim)
	_shared[key] = m
	return m


## A material of its own, for something that flashes
static func own(c: Color, glow := 0.0, rim := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIT
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("rim", rim)
	return m


static func flat(c: Color) -> ShaderMaterial:
	var key := "flat/" + c.to_html()
	if _shared.has(key):
		return _shared[key]
	var m := ShaderMaterial.new()
	m.shader = FLAT
	m.set_shader_parameter("tint", c)
	_shared[key] = m
	return m


## A ball of radius 1 with few enough faces to see them
static func ball() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


static func part(parent: Node, mesh: Mesh, material: Material, at: Vector3, size := Vector3.ONE, turn := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.extra_cull_margin = 70.0
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	mi.scale = size
	mi.rotation = turn
	parent.add_child(mi)
	return mi


## One of the Blender models, its materials swapped for these. `tints` recolours materials by name
## (the "shirt" of a person, the "walls" of a house). `own` gives it materials nobody else shares,
## so that it can be flashed (see `flash`).
static func model(name: String, tints := {}, own_mats := false) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load("res://models/%s.glb" % name)
	var n: Node3D = (_scenes[name] as PackedScene).instantiate()
	_dress(n, tints, own_mats)
	return n


## The mesh of a model alone (its first mesh), dressed, for a MultiMesh of scenery
static func model_mesh(name: String, tints := {}) -> Mesh:
	var n := model(name, tints)
	var mi := _first_mesh(n)
	var mesh: Mesh = mi.mesh.duplicate()
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, mi.get_surface_override_material(i))
	n.free()
	return mesh


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var found := _first_mesh(c)
		if found != null:
			return found
	return null


static func _dress(n: Node, tints: Dictionary, own_mats: bool) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		# Godot decides what is on screen before the world is bent: far things, which the bend
		# drops into view, would otherwise only pop in once they were close
		mi.extra_cull_margin = 70.0
		mi.visibility_range_end = 170.0
		for i in mi.mesh.get_surface_count():
			var was := mi.mesh.surface_get_material(i)
			var c := Color.WHITE
			var glow := 0.0
			var label := ""
			if was is BaseMaterial3D:
				var sm: BaseMaterial3D = was
				c = sm.albedo_color
				label = sm.resource_name
				if sm.emission_enabled:
					c = sm.emission
					glow = 1.6
			else:
				label = was.resource_name if was != null else ""
			if tints.has(label):
				c = tints[label]
			var m: Material
			# (Blender numbers names that repeat across its scene: "dome", "dome_001", ...)
			if label == "glass" and String(mi.name).begins_with("dome"):
				m = ShaderMaterial.new()
				m.shader = GLASS
			elif own_mats:
				m = own(c, glow, 0.3)
			else:
				m = mat(c, glow, 0.3)
			mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_dress(c, tints, own_mats)


## A see-through copy of a model in one colour, fading from `alpha` (for afterimages)
static func ghost_of(name: String, c: Color, alpha: float) -> Node3D:
	var n := model(name)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ghost.gdshader")
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("alpha", alpha)
	n.set_meta("ghost", m)
	_ghost(n, m)
	return n


static func _ghost(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for i in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_ghost(c, m)


## Lights up every material of a model dressed with `own_mats` (black to put it out)
static func flash(n: Node, c: Color) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m != null and m.shader == LIT:
				m.set_shader_parameter("flash", c)
	for child in n.get_children():
		flash(child, c)
