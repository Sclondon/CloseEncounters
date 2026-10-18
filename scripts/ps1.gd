class_name Ps1
## Materials for the PlayStation-era look (from Cryptlins' ps1.gd), on the bent world (see
## shaders/bend.gdshaderinc), and the Blender models (models/*.glb, from tools/build_models.py)
## dressed in them. Materials of one colour are shared.

const LIT: Shader = preload("res://shaders/ps1.gdshader")
## The simple textures some materials are drawn with, by name (see ps1.gdshader `pattern`): carried
## on each corner of a merged model in its second UV
const PATTERNS := {"walls": 1, "roof": 2, "brick": 3, "wood": 4}
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
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	mi.scale = size
	mi.rotation = turn
	parent.add_child(mi)
	return mi


## One of the Blender models, its materials swapped for these. `tints` recolours materials by name
## (the "shirt" of a person, the "walls" of a house). `own` gives it a material nobody else shares,
## so that it can be flashed (see `flash`).
##
## Each mesh of it is merged into ONE surface, its materials' colours written on its corners (and
## how much each glows in their alpha), so it is drawn in one go rather than one go a colour: on a
## phone the number of things drawn is what counts. The ships keep their surfaces apart (their
## lights flash on their own), and so does glass.
static func model(name: String, tints := {}, own_mats := false) -> Node3D:
	if name == "pine":
		return _grown_pine(own_mats)
	if name in GROWN:
		return _grown(name, own_mats)
	if not _scenes.has(name):
		_scenes[name] = load("res://models/%s.glb" % name)
	var n: Node3D = (_scenes[name] as PackedScene).instantiate()
	_dress(n, tints, own_mats, not name in KEEP_SURFACES)
	return n



## The pines are grown, not modelled (GameCommon's PineTree, as in Phone Home): the plainer of its
## two trees, a pine's height, in the game's greens. Made once.
static var _pine: ArrayMesh


static func pine_mesh() -> ArrayMesh:
	if _pine != null:
		return _pine
	var shape := PineTree.new()
	shape.height = 6.4
	shape.trunk_radius = 0.24
	shape.spread = 0.56
	shape.whorls = 11
	shape.branches = 7
	shape.droop = 0.4
	shape.seed = 7
	# (in the game's own greens, a shade lighter than the generator's, for a pine to read at night)
	shape.bark = Color(0.35, 0.24, 0.15)
	shape.needles_inner = Color(0.12, 0.3, 0.14)
	shape.needles_outer = Color(0.2, 0.42, 0.18)
	shape.tips = Color(0.3, 0.52, 0.24)
	var grown := shape.simple().mesh()
	var arrays := grown.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in colours.size():
		var c := colours[i]
		c.a = 1.0
		colours[i] = c
	arrays[Mesh.ARRAY_COLOR] = colours
	_pine = ArrayMesh.new()
	_pine.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _pine


## The leafy trees are grown too (GameCommon's LeafyTree), each its own kind, about the size its
## Blender model was, in the game's colours: a lumpy crown of leaf clumps ragged with tufts, and in
## UV2.y how much each corner sways in the wind (see bend.gdshaderinc; ps1.gdshader draws leaves on it)
const GROWN := ["tree", "aspen", "cottonwood", "willow", "pinyon"]
static var _grown_meshes := {}


static func is_grown(name: String) -> bool:
	return name == "pine" or name in GROWN


static func grown_mesh(name: String) -> ArrayMesh:
	if _grown_meshes.has(name):
		return _grown_meshes[name]
	var shape: LeafyTree
	match name:
		"tree":
			shape = LeafyTree.oak()
			shape.height = 6.2
			shape.spread = 0.62
		"aspen":
			shape = LeafyTree.aspen()
			shape.height = 6.8
		"cottonwood":
			shape = LeafyTree.cottonwood()
			shape.height = 8.0
		"willow":
			shape = LeafyTree.willow()
			shape.height = 6.0
		_:
			shape = LeafyTree.pinyon()
			shape.height = 3.0
	shape.seed = 11
	var grown := shape.mesh()
	# (its colours are sRGB; the PS1 shader takes a model's corner colours as linear, see _merged)
	var arrays := grown.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in colours.size():
		var c := colours[i].srgb_to_linear()
		c.a = 1.0
		colours[i] = c
	arrays[Mesh.ARRAY_COLOR] = colours
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_grown_meshes[name] = made
	return made


static func _grown(name: String, own_mats: bool) -> Node3D:
	var n := Node3D.new()
	n.name = name
	var mi := MeshInstance3D.new()
	mi.mesh = grown_mesh(name)
	mi.material_override = own(Color.WHITE, 0.0, 0.3) if own_mats else mat(Color.WHITE, 0.0, 0.3)
	mi.extra_cull_margin = CULL_MARGIN
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = DRAW_TO
	n.add_child(mi)
	return n


static func _grown_pine(own_mats: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "pine"
	var mi := MeshInstance3D.new()
	mi.mesh = pine_mesh()
	mi.material_override = own(Color.WHITE, 0.0, 0.3) if own_mats else mat(Color.WHITE, 0.0, 0.3)
	mi.extra_cull_margin = CULL_MARGIN
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = DRAW_TO
	n.add_child(mi)
	return n

## Models whose surfaces stay apart
const KEEP_SURFACES: Array[String] = ["ufo", "orb", "triangle", "foo", "cigar", "bell", "tictac", "saturn", "diamond", "jelly", "tug", "frigate", "trek", "meteor", "carnival"]
## How far off anything is drawn, and how far past the edge of the view (the bend drops far things
## into view after Godot has decided what is on screen)
const DRAW_TO := 115.0
const CULL_MARGIN := 32.0
static var _merges := {}


## The mesh of a model alone (its first mesh), dressed, for a MultiMesh of scenery: placed as it
## stands in the model (a joined model's mesh sits about its first part, off the ground; without
## this the scenery sank into the ground by as much)
static func model_mesh(name: String, tints := {}) -> Mesh:
	var n := model(name, tints)
	var mi := _first_mesh(n)
	var xf := Transform3D.IDENTITY
	var up: Node = mi
	while up != n and up is Node3D:
		xf = (up as Node3D).transform * xf
		up = up.get_parent()
	var mesh := ArrayMesh.new()
	for i in mi.mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.append_from(mi.mesh, i, xf)
		st.commit(mesh)
		mesh.surface_set_material(i, mi.material_override if mi.material_override != null else mi.get_surface_override_material(i))
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


## What each surface of a mesh is painted: [colour, glow, the material's name]
static func _paints(mesh: Mesh, tints: Dictionary) -> Array:
	var paints := []
	for i in mesh.get_surface_count():
		var was := mesh.surface_get_material(i)
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
		elif was != null:
			label = was.resource_name
		if tints.has(label):
			c = tints[label]
		paints.append([c, glow, label])
	return paints


static func _dress(n: Node, tints: Dictionary, own_mats: bool, merge: bool) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		mi.extra_cull_margin = CULL_MARGIN
		# (no shadows but from what is in the beam: see Thing._beam_layer)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = DRAW_TO
		var paints := _paints(mi.mesh, tints)
		var glass := false
		for paint: Array in paints:
			glass = glass or paint[2] == "glass"
		if merge and not glass:
			mi.mesh = _merged(mi.mesh, paints)
			mi.material_override = own(Color.WHITE, 0.0, 0.3) if own_mats else mat(Color.WHITE, 0.0, 0.3)
		else:
			for i in paints.size():
				var c: Color = paints[i][0]
				var glow: float = paints[i][1]
				var m: Material
				# (Blender numbers names that repeat across its scene: "dome", "dome_001", ...)
				if paints[i][2] == "glass" and String(mi.name).begins_with("dome"):
					m = ShaderMaterial.new()
					m.shader = GLASS
				elif paints[i][2] == "glass":
					# (any other glass: a pale pane you can see through, as a phone booth's)
					m = _pane()
				elif own_mats:
					m = own(c, glow, 0.3)
				else:
					m = mat(c, glow, 0.3)
				mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_dress(c, tints, own_mats, merge)


## A mesh's surfaces as one, each corner carrying its surface's colour (linear) and, in alpha, how
## much it glows (1 none, 0.5 a light): see ps1.gdshader. Made once for each mesh and paint.
static func _merged(mesh: Mesh, paints: Array) -> ArrayMesh:
	var key := "%d/%s" % [mesh.get_instance_id(), str(paints)]
	if _merges.has(key):
		return _merges[key]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var kinds := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv = arrays[Mesh.ARRAY_TEX_UV]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var base := verts.size()
		var c: Color = paints[i][0]
		var lin := c.srgb_to_linear()
		lin.a = 0.5 if float(paints[i][1]) > 0.0 else 1.0
		verts.append_array(v)
		normals.append_array(nrm)
		for k in v.size():
			colours.append(lin)
			uvs.append(uv[k] if uv is PackedVector2Array and k < uv.size() else Vector2.ZERO)
			kinds.append(Vector2(PATTERNS.get(paints[i][2], 0), 0))
		if idx is PackedInt32Array and idx.size() > 0:
			for k in idx:
				indices.append(base + k)
		else:
			for k in v.size():
				indices.append(base + k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = kinds
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_merges[key] = out
	return out

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
		if mi.material_override != null:
			mi.material_override = m
		for i in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_ghost(c, m)


## Lights up every material of a model dressed with `own_mats` (black to put it out)
static func flash(n: Node, c: Color) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var whole := mi.material_override as ShaderMaterial
		if whole != null and whole.shader == LIT:
			whole.set_shader_parameter("flash", c)
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m != null and m.shader == LIT:
				m.set_shader_parameter("flash", c)
	for child in n.get_children():
		flash(child, c)


## See-through glass: a pale blue pane, mostly clear
## (bent with the world like the model round it: see pane.gdshader)
static func _pane() -> ShaderMaterial:
	if _shared.has("pane"):
		return _shared["pane"]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/pane.gdshader")
	_shared["pane"] = m
	return m
