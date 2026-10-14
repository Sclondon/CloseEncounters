class_name World
extends Node3D
## The farm country: one big square of fields with roads across it, farms dotted about, a small
## town in one corner and an army camp in another, and woods all round the edge. The ground is one
## mesh painted by shaders/ground.gdshader; trees and fences are MultiMeshes; buildings are models.
## It also says where new animals, people and cars can be put (see `spot_for`).

const SIZE := 118.0
const ROADS_X: Array[float] = [0.0, 70.0]
const ROADS_Z: Array[float] = [0.0, -70.0]
const TOWN := Rect2(40, -110, 70, 70)
const CAMP := Rect2(-110, -110, 60, 50)
const FARMS: Array[Vector2] = [Vector2(-40, 32), Vector2(32, 38), Vector2(-82, -14), Vector2(96, 30),
	Vector2(-30, -42), Vector2(24, 96), Vector2(-70, 86), Vector2(30, -30), Vector2(96, 98), Vector2(-96, 40)]

## Each farm's pen (the middle of it), where its animals are put
var pens: Array[Vector3] = []
var farmyards: Array[Vector3] = []
var houses: Array[Vector3] = []
var _blocked: Array[Vector3] = []
var rng := RandomNumberGenerator.new()


func build() -> void:
	rng.seed = 1977
	_ground()
	_town()
	_camp()
	for f in FARMS:
		_farm(Vector3(f.x, 0, f.y))
	_trees()


func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(320, 320)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ground.gdshader")
	m.set_shader_parameter("roads_x", Vector4(ROADS_X[0], ROADS_X[1], 9999, 9999))
	m.set_shader_parameter("roads_z", Vector4(ROADS_Z[0], ROADS_Z[1], 9999, 9999))
	m.set_shader_parameter("town", Vector4(TOWN.position.x, TOWN.position.y, TOWN.end.x, TOWN.end.y))
	m.set_shader_parameter("camp", Vector4(CAMP.position.x, CAMP.position.y, CAMP.end.x, CAMP.end.y))
	m.set_shader_parameter("edge", SIZE)
	mi.material_override = m
	mi.extra_cull_margin = 200.0
	add_child(mi)


func _put(name: String, at: Vector3, turn := 0.0, size := 1.0, tints := {}) -> Node3D:
	var n := Ps1.model(name, tints)
	n.position = at
	n.rotation.y = turn
	n.scale = Vector3.ONE * size
	add_child(n)
	return n


func _block(at: Vector3, radius: float) -> void:
	_blocked.append(Vector3(at.x, radius, at.z))


func on_road(p: Vector3, margin := 4.0) -> bool:
	for x in ROADS_X:
		if absf(p.x - x) < 3.0 + margin:
			return true
	for z in ROADS_Z:
		if absf(p.z - z) < 3.0 + margin:
			return true
	return false


func _free(p: Vector3, radius: float) -> bool:
	if on_road(p, radius) or absf(p.x) > SIZE - 2.0 or absf(p.z) > SIZE - 2.0:
		return false
	for b in _blocked:
		if Vector2(p.x - b.x, p.z - b.z).length() < radius + b.y:
			return false
	return true


func _farm(at: Vector3) -> void:
	var turn := rng.randi_range(0, 3) * PI / 2
	var basis := Basis(Vector3.UP, turn)
	_put("barn", at + basis * Vector3(-6, 0, -6), turn, 0.6)
	_block(at + basis * Vector3(-6, 0, -6), 6.0)
	_put("farmhouse", at + basis * Vector3(9, 0, -8), turn, 0.85)
	_block(at + basis * Vector3(9, 0, -8), 5.0)
	if rng.randf() < 0.6:
		_put("silo", at + basis * Vector3(-12, 0, -12), 0.0, 0.48)
		_block(at + basis * Vector3(-12, 0, -12), 2.0)
	# A pen of fence to the front of the barn
	var pen := at + basis * Vector3(-2, 0, 10)
	pens.append(pen)
	farmyards.append(at)
	_block(at, 14.0)
	var w := 6
	var d := 4
	for i in w:
		for side: float in [-1.0, 1.0]:
			_fence(pen + basis * Vector3((i - (w - 1) * 0.5) * 3.0, 0, side * d * 1.5), turn)
	for i in d:
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and i == 1:
				continue # (a gap for a gate)
			_fence(pen + basis * Vector3(side * w * 1.5, 0, (i - (d - 1) * 0.5) * 3.0), turn + PI / 2)


var _fences: Array[Transform3D] = []


func _fence(at: Vector3, turn: float) -> void:
	_fences.append(Transform3D(Basis(Vector3.UP, turn), at))


func _town() -> void:
	var paint: Array[Color] = [Color(0.92, 0.9, 0.82), Color(0.75, 0.82, 0.9), Color(0.95, 0.85, 0.6), Color(0.8, 0.9, 0.75), Color(0.9, 0.7, 0.65)]
	for x in range(48, 110, 14):
		for z in range(-104, -42, 14):
			var p := Vector3(x + rng.randf_range(-1, 1), 0, z + rng.randf_range(-1, 1))
			if on_road(p, 3.5):
				continue
			# (each faces the nearer road)
			var turn := 0.0 if absf(p.z - ROADS_Z[1]) < absf(p.x - ROADS_X[1]) else PI / 2 * signf(ROADS_X[1] - p.x)
			if turn == 0.0 and p.z > ROADS_Z[1]:
				turn = PI
			_put("house", p, turn + PI, 1.0, {"walls": paint[rng.randi() % paint.size()]})
			houses.append(p)
			_block(p, 5.0)
	_block(Vector3(TOWN.get_center().x, 0, TOWN.get_center().y), 2.0)


func _camp() -> void:
	for i in 6:
		var p := Vector3(CAMP.position.x + 10 + (i % 3) * 16, 0, CAMP.position.y + 12 + (i / 3) * 18)
		_put("tent", p, PI / 2 * (i % 2))
		_block(p, 4.0)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector3(CAMP.position.x + 3 + corner.x * (CAMP.size.x - 6), 0, CAMP.position.y + 3 + corner.y * (CAMP.size.y - 6))
		_put("floodlight", p, atan2(CAMP.get_center().x - p.x, CAMP.get_center().y - p.z))
		_block(p, 1.0)


func _trees() -> void:
	var trees: Array[Transform3D] = []
	var pines: Array[Transform3D] = []
	# Along the hedges between fields
	var tries := 0
	while trees.size() < 170 and tries < 4000:
		tries += 1
		var cell := Vector2(rng.randi_range(-6, 5), rng.randi_range(-6, 5)) * 22.0
		var along := rng.randf_range(0, 22)
		var p := Vector3(cell.x + along, 0, cell.y) if rng.randf() < 0.5 else Vector3(cell.x, 0, cell.y + along)
		if not _free(p, 2.5) or TOWN.has_point(Vector2(p.x, p.z)):
			continue
		_block(p, 1.5)
		trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.75, 1.05)), p))
	# The town's own trees, and the woods all round
	for i in 14:
		var p := Vector3(rng.randf_range(TOWN.position.x, TOWN.end.x), 0, rng.randf_range(TOWN.position.y, TOWN.end.y))
		if _free(p, 2.5):
			trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
	while pines.size() < 420:
		var p := Vector3(rng.randf_range(-150, 150), 0, rng.randf_range(-150, 150))
		var out := maxf(absf(p.x), absf(p.z))
		if out < SIZE + 1.0 and not (out > SIZE - 8.0 and rng.randf() < 0.4):
			continue
		if on_road(p, 1.0) and out < SIZE + 6.0:
			continue
		pines.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.5)), p))
	_scatter("tree", trees)
	_scatter("pine", pines)
	_scatter("fence", _fences)


func _scatter(name: String, where: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Ps1.model_mesh(name)
	mm.instance_count = where.size()
	for i in where.size():
		mm.set_instance_transform(i, where[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.extra_cull_margin = 50.0
	add_child(mmi)


## A place for a new thing of this kind, out of sight of `away` (the saucer) if it can be
func spot_for(kind: String, away: Vector3) -> Vector3:
	for attempt in 30:
		var p := _somewhere(kind)
		if p.distance_to(away) > 40.0 or attempt > 25:
			return p
	return _somewhere(kind)


func _somewhere(kind: String) -> Vector3:
	match kind:
		"cow", "sheep", "pig":
			return pens[rng.randi() % pens.size()] + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-4, 4))
		"chicken", "farmer", "tractor", "hay_bale", "outhouse":
			var yard := farmyards[rng.randi() % farmyards.size()]
			return yard + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-3, 14))
		"person":
			var house := houses[rng.randi() % houses.size()]
			return house + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
		"scarecrow":
			for i in 40:
				var p := Vector3(rng.randf_range(-SIZE, SIZE), 0, rng.randf_range(-SIZE, SIZE))
				if _free(p, 3.0) and not TOWN.has_point(Vector2(p.x, p.z)) and not CAMP.has_point(Vector2(p.x, p.z)):
					return p
	return Vector3(rng.randf_range(-SIZE, SIZE), 0, rng.randf_range(-SIZE, SIZE))


## A place on a road for a car, and the way it should drive: [where, axis, direction]
func road_spot(away: Vector3) -> Array:
	for attempt in 20:
		var along_z := rng.randf() < 0.5
		var lane := rng.randf() < 0.5
		var dir := 1.0 if lane else -1.0
		var p: Vector3
		if along_z:
			p = Vector3(ROADS_X[rng.randi() % ROADS_X.size()] + 1.5 * dir, 0, rng.randf_range(-SIZE, SIZE))
		else:
			p = Vector3(rng.randf_range(-SIZE, SIZE), 0, ROADS_Z[rng.randi() % ROADS_Z.size()] - 1.5 * dir)
		if p.distance_to(away) > 40.0 or attempt == 19:
			return [p, "z" if along_z else "x", dir]
	return [Vector3.ZERO, "z", 1.0]
