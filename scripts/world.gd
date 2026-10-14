class_name World
extends Node3D
## The land, without end: square chunks CHUNK across, made as the saucer comes near and dropped
## once it has gone. What is in a chunk comes from where it is (the same chunk is always the same),
## and which part of the West it belongs to:
##
## - FARM: Colorado farm country. Fields, farmsteads with barns, pens of cows, pigs and sheep.
## - PLAINS: the Wyoming high plains. Golden grass and sagebrush, bison, ranches with horses and
##   cowboys, windmills, oil pumpjacks, the odd butte, and Devils Tower.
## - DESERT: Arizona. Red sand, saguaros, prickly pear, mesas and buttes, coyotes, RVs.
## - MESA: New Mexico. Ochre earth and pinyon, adobe villages with water towers, longhorns.
## - MOUNTAIN: the Colorado Rockies. Snow-capped peaks, pine forest, aspens gone gold, log
##   cabins and campers.
##
## Highways run north-south and east-west every ROAD_EVERY, with a town where two cross, and
## here and there a trader's saucer is parked (see Shop).
## Mesas, buttes, peaks and the tower stand taller than the saucer flies: they are `obstacles`,
## and the saucer (and anything on the ground) is pushed out of them (`push_out`).
##
## The ground is one mesh that follows the saucer, painted by shaders/ground.gdshader from a small
## picture of which region each nearby chunk is (`_biome_tex`).

enum Biome { FARM, PLAINS, DESERT, MESA, MOUNTAIN }
const CHUNK := 48.0
## Chunks are made out to this many from the saucer's, and dropped beyond FAR
const NEAR := 3
const FAR := 4
## Roads run along every fifth line of chunks (every 240 m)
const ROAD_EVERY := 5
## Devils Tower stands a little north of where the game starts
const TOWER := Vector3(26, 0, -62)
const BIOME_SPAN := 13

var game: Node
var chunks := {}
var obstacles := {}
var spinners: Array[Node3D] = []
var ground: MeshInstance3D
var _ground_mat: ShaderMaterial
var _biome_img: Image
var _biome_tex: ImageTexture
var _centre := Vector2i(99999, 99999)
var _queue: Array[Vector2i] = []
var _meshes := {}
var _t := 0.0
## Scenery still in the ground, by chunk: [name, its MultiMesh, its index there, where it stands]
var loose := {}


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(324, 324)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	ground = MeshInstance3D.new()
	ground.mesh = plane
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://shaders/ground.gdshader")
	_ground_mat.set_shader_parameter("chunk", CHUNK)
	_ground_mat.set_shader_parameter("road_every", CHUNK * ROAD_EVERY)
	_biome_img = Image.create(BIOME_SPAN, BIOME_SPAN, false, Image.FORMAT_R8)
	_biome_tex = ImageTexture.create_from_image(_biome_img)
	_ground_mat.set_shader_parameter("biomes", _biome_tex)
	ground.material_override = _ground_mat
	ground.extra_cull_margin = 200.0
	add_child(ground)


# ------------------------------------------------------------------ where things are

static func chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x + CHUNK * 0.5) / CHUNK), floori((p.z + CHUNK * 0.5) / CHUNK))


static func centre_of(c: Vector2i) -> Vector3:
	return Vector3(c.x * CHUNK, 0, c.y * CHUNK)


## A number from 0 to 1 that only depends on the three it is given
static func hash3(x: int, z: int, s: int) -> float:
	var h := (x * 374761393 + z * 668265263 + s * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## Smooth noise over the chunks, for regions several chunks across
static func noise(x: float, z: float, s: int) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := lerpf(hash3(ix, iz, s), hash3(ix + 1, iz, s), fx)
	var b := lerpf(hash3(ix, iz + 1, s), hash3(ix + 1, iz + 1, s), fx)
	return lerpf(a, b, fz)


static func biome(c: Vector2i) -> int:
	# Farm country where the game starts, and the plains round the tower
	if c == chunk_of(TOWER) or c == chunk_of(TOWER) + Vector2i(0, -1):
		return Biome.PLAINS
	if absi(c.x) <= 1 and absi(c.y) <= 1:
		return Biome.FARM
	var high := noise(c.x / 5.5, c.y / 5.5, 2) + noise(c.x / 2.0, c.y / 2.0, 3) * 0.15
	var dry := noise(c.x / 4.5 + 40.0, c.y / 4.5, 1) + noise(c.x / 1.7, c.y / 1.7, 4) * 0.1
	if high > 0.72:
		return Biome.MOUNTAIN
	if dry > 0.66:
		return Biome.DESERT
	if dry > 0.52:
		return Biome.MESA
	if dry < 0.4:
		return Biome.FARM
	return Biome.PLAINS


static func has_road(n: int) -> bool:
	return posmod(n, ROAD_EVERY) == 0


func biome_at(p: Vector3) -> int:
	return biome(chunk_of(p))


# ------------------------------------------------------------------ making and dropping chunks

## Keeps the chunks round `focus` made, one a frame (or all at once, `now`)
func update(focus: Vector3, delta: float, now := false) -> void:
	_t += delta
	var c := chunk_of(focus)
	if c != _centre:
		_centre = c
		_recentre()
	# (the ground moves in whole steps of its own grid, so its corners never swim)
	ground.position = Vector3(snappedf(focus.x, 4.0), 0, snappedf(focus.z, 4.0))
	var made := 0
	while not _queue.is_empty() and (now or made < 1):
		var next: Vector2i = _queue.pop_front()
		if not chunks.has(next) and _ring(next - _centre) <= NEAR:
			_make(next)
			made += 1
	for s in spinners:
		if is_instance_valid(s):
			s.rotation.z += delta * 3.0


func _ring(d: Vector2i) -> int:
	return maxi(absi(d.x), absi(d.y))


func _recentre() -> void:
	for c: Vector2i in chunks.keys():
		if _ring(c - _centre) > FAR:
			chunks[c].queue_free()
			chunks.erase(c)
			obstacles.erase(c)
			loose.erase(c)
			if game != null:
				game.forget_chunk(c)
	_queue.clear()
	var wanted: Array[Vector2i] = []
	for x in range(-NEAR, NEAR + 1):
		for z in range(-NEAR, NEAR + 1):
			var c := _centre + Vector2i(x, z)
			if not chunks.has(c):
				wanted.append(c)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - _centre).length_squared() < (b - _centre).length_squared())
	_queue = wanted
	# The picture of the regions round about, for the ground
	var half := BIOME_SPAN / 2
	for x in BIOME_SPAN:
		for z in BIOME_SPAN:
			_biome_img.set_pixel(x, z, Color(biome(_centre + Vector2i(x - half, z - half)) * 40.0 / 255.0, 0, 0))
	_biome_tex.update(_biome_img)
	_ground_mat.set_shader_parameter("biome_corner", Vector2((_centre.x - half) * CHUNK, (_centre.y - half) * CHUNK))


## Pulls up a piece of scenery the beam is over (within `reach` of `p`) that a beam of `tier`
## can take: gives back [kind, where it stood, its tints] and takes it out of the ground, or []
func pull(p: Vector3, reach: float, tier: int) -> Array:
	var c := chunk_of(p)
	for x in range(-1, 2):
		for z in range(-1, 2):
			var here: Array = loose.get(c + Vector2i(x, z), [])
			for i in here.size():
				var entry: Array = here[i]
				var xf: Transform3D = entry[3]
				if Vector2(xf.origin.x - p.x, xf.origin.z - p.z).length() > reach:
					continue
				var name: String = entry[0]
				var kind: String = RECOLOURED[name][0] if RECOLOURED.has(name) else name
				if int(Thing.KINDS[kind].get("tier", 1)) > tier:
					continue
				(entry[1] as MultiMesh).set_instance_transform(entry[2], Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), xf.origin))
				here.remove_at(i)
				return [kind, xf, RECOLOURED[name][1] if RECOLOURED.has(name) else {}]
	return []


## Whether any scenery under `p` is too much for a beam of `tier` (to say so)
func too_heavy_under(p: Vector3, reach: float, tier: int) -> bool:
	for entry: Array in loose.get(chunk_of(p), []):
		var xf: Transform3D = entry[3]
		var name: String = entry[0]
		var kind: String = RECOLOURED[name][0] if RECOLOURED.has(name) else name
		if Vector2(xf.origin.x - p.x, xf.origin.z - p.z).length() < reach and int(Thing.KINDS[kind].get("tier", 1)) > tier:
			return true
	return false


func remove_obstacle(c: Vector2i, block: Vector4) -> void:
	if obstacles.has(c):
		(obstacles[c] as Array).erase(block)


## Pushes a point (and anything `radius` round it) out of the mesas, buttes, peaks and the tower
func push_out(p: Vector3, radius: float) -> Vector3:
	var c := chunk_of(p)
	for x in range(-1, 2):
		for z in range(-1, 2):
			for o: Vector4 in obstacles.get(c + Vector2i(x, z), []):
				var off := Vector2(p.x - o.x, p.z - o.y)
				var reach := o.z + radius
				if off.length() < reach:
					var out := off.normalized() if off.length() > 0.01 else Vector2.RIGHT
					p.x = o.x + out.x * reach
					p.z = o.y + out.y * reach
	return p


# ------------------------------------------------------------------ what is in a chunk

var _node: Node3D
var _rng := RandomNumberGenerator.new()
var _taken: Array[Vector3] = []
var _scatter := {}
var _chunk := Vector2i.ZERO


func _make(c: Vector2i) -> void:
	_chunk = c
	_node = Node3D.new()
	add_child(_node)
	chunks[c] = _node
	obstacles[c] = []
	_rng.seed = int(hash3(c.x, c.y, 77) * 1000000.0) + 1
	_taken.clear()
	_scatter.clear()
	var b := biome(c)
	var road_x := has_road(c.x)
	var road_z := has_road(c.y)
	# (the roads are kept clear)
	if road_x:
		_taken.append(Vector3(c.x * CHUNK, -1.0, 0))
	if road_z:
		_taken.append(Vector3(0, -2.0, c.y * CHUNK))
	# The landforms come first, this chunk's and its neighbours' (which may reach over into it),
	# so that nothing is put down on top of them
	for x in range(-1, 2):
		for z in range(-1, 2):
			for f: Dictionary in landforms(c + Vector2i(x, z)):
				_take(f["at"], float(f["skirt"]) + 2.0)
	for f: Dictionary in landforms(c):
		var block := Vector4(f["at"].x, f["at"].z, f["radius"], f["height"])
		(obstacles[c] as Array).append(block)
		_prop(f["name"], f["at"], f["turn"], f["size"], {}, block)
		if f["name"] == "devils_tower":
			# (ponderosa pines round its foot)
			for i in 10:
				_plant("pine", 0.8, 1.3, _ring_spot(f["at"], float(f["skirt"]) + 2.0, float(f["skirt"]) + 9.0))
	# Now and then a trader's saucer parked out of the way (and always one near the start)
	if game != null and not road_x and not road_z and (hash3(c.x, c.y, 33) < 0.06 or c == Vector2i(-1, 0)):
		var pad := _spot(7.0)
		_take(pad, 7.0)
		game.spawn_shop(pad, c)
	if road_x and road_z:
		_town(b)
	match b:
		Biome.FARM:
			_farm()
		Biome.PLAINS:
			_plains()
		Biome.DESERT:
			_desert()
		Biome.MESA:
			_mesa_land()
		Biome.MOUNTAIN:
			_mountain()
	if road_x and not road_z and _rng.randf() < 0.6:
		_car(b, "z")
	if road_z and not road_x and _rng.randf() < 0.6:
		_car(b, "x")
	for name: String in _scatter:
		_multimesh(name, _scatter[name])


## The mesas, buttes, peaks and Devils Tower of a chunk, decided by where it is alone (so its
## neighbours can keep clear of them before it is made): each {name, at, turn, size, radius (what
## the saucer cannot pass), skirt (how far it spreads on the ground), height}. A landform sits far
## enough in from the edges of its chunk that two never run into each other, and never on a road.
static func landforms(c: Vector2i) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if has_road(c.x) or has_road(c.y):
		return found
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash3(c.x, c.y, 91) * 1000000.0) + 7
	var b := biome(c)
	var r := rng.randf()
	var pick := ""
	if c == chunk_of(TOWER) or (b == Biome.PLAINS and hash3(c.x, c.y, 5) < 0.012):
		pick = "devils_tower"
	elif b == Biome.PLAINS and r < 0.18:
		pick = "butte"
	elif b == Biome.DESERT:
		pick = "mesa" if r < 0.35 else ("butte" if r < 0.65 else "")
	elif b == Biome.MESA and r < 0.3:
		pick = "mesa"
	elif b == Biome.MOUNTAIN and r < 0.55:
		pick = "peak"
	if pick == "":
		return found
	# [radius it blocks, skirt on the ground, height] at size 1, and the sizes it comes in
	var spec: Array = {"devils_tower": [11.0, 19.0, 26.0, 1.0, 1.0], "butte": [7.0, 10.0, 16.0, 0.85, 1.25],
		"mesa": [14.5, 19.0, 12.0, 0.8, 1.1], "peak": [20.0, 24.0, 37.0, 0.75, 1.0]}[pick]
	var size := rng.randf_range(spec[3], spec[4])
	var skirt: float = spec[1] * size
	var room := maxf(CHUNK * 0.5 - skirt, 0.0)
	var at := centre_of(c) + Vector3(rng.randf_range(-room, room), 0, rng.randf_range(-room, room))
	if c == chunk_of(TOWER):
		at = TOWER
	found.append({"name": pick, "at": at, "turn": rng.randf() * TAU, "size": size, "radius": spec[0] * size,
		"skirt": skirt, "height": spec[2] * size})
	return found


## A free spot in this chunk, `radius` clear of the roads and of what is already there. Anything
## big is kept wholly inside the chunk, so it never runs into what a neighbour puts down.
func _spot(radius: float) -> Vector3:
	var base := centre_of(_chunk)
	var room := CHUNK * 0.5 - (radius if radius >= 2.0 else 0.0)
	var p := base
	for attempt in 24:
		p = base + Vector3(_rng.randf_range(-room, room), 0, _rng.randf_range(-room, room))
		if _clear(p, radius):
			return p
	return p


## A spot between `low` and `high` from `at`
func _ring_spot(at: Vector3, low: float, high: float) -> Vector3:
	var a := _rng.randf() * TAU
	return at + Vector3(sin(a), 0, cos(a)) * _rng.randf_range(low, high)


## A free spot near `at`, within `spread`
func _near(at: Vector3, spread: float, radius: float) -> Vector3:
	var p := at
	var base := centre_of(_chunk)
	var room := CHUNK * 0.5 - (radius if radius >= 2.0 else 0.0)
	for attempt in 16:
		p = at + Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread, spread))
		p.x = clampf(p.x, base.x - room, base.x + room)
		p.z = clampf(p.z, base.z - room, base.z + room)
		if _clear(p, radius):
			return p
	return p


func _clear(p: Vector3, radius: float) -> bool:
	for t in _taken:
		if t.y == -1.0:
			if absf(p.x - t.x) < 4.0 + radius:
				return false
		elif t.y == -2.0:
			if absf(p.z - t.z) < 4.0 + radius:
				return false
		elif Vector2(p.x - t.x, p.z - t.z).length() < radius + t.y:
			return false
	return true


func _take(p: Vector3, radius: float) -> void:
	_taken.append(Vector3(p.x, radius, p.z))


## A building (or a landform, with the `block` it makes): a thing the beam can take, if strong enough
func _prop(name: String, at: Vector3, turn := 0.0, size := 1.0, tints := {}, block := Vector4.ZERO) -> void:
	if game == null:
		_put(name, at, turn, size, tints)
		return
	game.spawn(name, at, {"turn": turn, "size": size, "tints": tints, "chunk": _chunk, "obstacle": block})


func _put(name: String, at: Vector3, turn := 0.0, size := 1.0, tints := {}) -> Node3D:
	var n := Ps1.model(name, tints)
	n.position = at
	n.rotation.y = turn
	n.scale = Vector3.ONE * size
	_node.add_child(n)
	var fan := n.find_child("fan", true, false) as Node3D
	if fan != null:
		spinners.append(fan)
	return n


## One more of a kind of scenery (drawn together, in a MultiMesh)
func _plant(name: String, small := 0.8, big := 1.2, at := Vector3.INF, radius := 1.0) -> void:
	var p := _spot(radius) if at == Vector3.INF else at
	if not _scatter.has(name):
		_scatter[name] = []
	(_scatter[name] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(small, big)), p))


## Scenery that is one of the models recoloured: [model, {material: colour}]
const RECOLOURED := {
	"rock_red": ["rock", {"rock": Color(0.62, 0.3, 0.16)}],
	"rock_tan": ["rock", {"rock": Color(0.6, 0.48, 0.32)}],
}


func _multimesh(name: String, where: Array) -> void:
	if not _meshes.has(name):
		_meshes[name] = Ps1.model_mesh(RECOLOURED[name][0], RECOLOURED[name][1]) if RECOLOURED.has(name) else Ps1.model_mesh(name)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _meshes[name]
	mm.instance_count = where.size()
	for i in where.size():
		mm.set_instance_transform(i, where[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.extra_cull_margin = 30.0
	_node.add_child(mmi)
	if not loose.has(_chunk):
		loose[_chunk] = []
	for i in where.size():
		(loose[_chunk] as Array).append([name, mm, i, where[i]])


func _spawn(kind: String, at: Vector3) -> void:
	if game != null:
		game.spawn(kind, at)


func _herd(kind: String, at: Vector3, count: int, spread: float) -> void:
	for i in count:
		_spawn(kind, _near(at, spread, 0.5))


func _farm() -> void:
	for i in _rng.randi_range(3, 7):
		_plant("tree", 0.75, 1.05, Vector3.INF, 2.5)
	if _rng.randf() < 0.65:
		var at := _spot(16.0)
		var turn := _rng.randi_range(0, 3) * PI / 2
		var basis := Basis(Vector3.UP, turn)
		_prop("barn", at + basis * Vector3(-6, 0, -6), turn, 0.6)
		_prop("farmhouse", at + basis * Vector3(9, 0, -8), turn, 0.85)
		if _rng.randf() < 0.6:
			_prop("silo", at + basis * Vector3(-12, 0, -12), 0.0, 0.48)
		_take(at, 16.0)
		var pen := at + basis * Vector3(-2, 0, 10)
		_pen(pen, turn, 6, 4)
		_herd("cow", pen, _rng.randi_range(2, 4), 6.0)
		_herd(["sheep", "pig"][_rng.randi() % 2], pen, _rng.randi_range(1, 3), 5.0)
		_herd("chicken", at + basis * Vector3(2, 0, -2), _rng.randi_range(2, 5), 5.0)
		_spawn("farmer", at + basis * Vector3(4, 0, 2))
		if _rng.randf() < 0.5:
			_spawn("tractor", at + basis * Vector3(12, 0, 6))
		_herd("hay_bale", at + basis * Vector3(-12, 0, 4), _rng.randi_range(1, 3), 3.0)
		if _rng.randf() < 0.4:
			_spawn("outhouse", at + basis * Vector3(14, 0, -2))
	for i in _rng.randi_range(0, 2):
		_spawn("scarecrow", _spot(2.0))
	if _rng.randf() < 0.3:
		_herd("cow", _spot(6.0), _rng.randi_range(2, 4), 5.0)


## A pen of fence, w by d lengths, with a gap for a gate
func _pen(at: Vector3, turn: float, w: int, d: int) -> void:
	var basis := Basis(Vector3.UP, turn)
	for i in w:
		for side: float in [-1.0, 1.0]:
			_plant_at("fence", at + basis * Vector3((i - (w - 1) * 0.5) * 3.0, 0, side * d * 1.5), turn)
	for i in d:
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and i == 1:
				continue
			_plant_at("fence", at + basis * Vector3(side * w * 1.5, 0, (i - (d - 1) * 0.5) * 3.0), turn + PI / 2)


func _plant_at(name: String, at: Vector3, turn: float) -> void:
	if not _scatter.has(name):
		_scatter[name] = []
	(_scatter[name] as Array).append(Transform3D(Basis(Vector3.UP, turn), at))


func _plains() -> void:
	for i in _rng.randi_range(16, 28):
		_plant("sagebrush", 0.6, 1.2, Vector3.INF, 0.5)
	for i in _rng.randi_range(1, 3):
		_plant("rock", 0.5, 1.0, Vector3.INF, 1.0)
	if _rng.randf() < 0.45:
		_herd("bison", _spot(6.0), _rng.randi_range(3, 6), 7.0)
	if _rng.randf() < 0.35:
		var at := _spot(14.0)
		var turn := _rng.randi_range(0, 3) * PI / 2
		_prop("farmhouse", at + Basis(Vector3.UP, turn) * Vector3(8, 0, -6), turn, 0.8)
		_prop("windmill", at + Basis(Vector3.UP, turn) * Vector3(-8, 0, -8), turn)
		_take(at, 14.0)
		_pen(at + Basis(Vector3.UP, turn) * Vector3(-1, 0, 6), turn, 5, 3)
		_herd("horse", at + Basis(Vector3.UP, turn) * Vector3(-1, 0, 6), _rng.randi_range(2, 4), 4.0)
		_herd("cowboy", at, _rng.randi_range(1, 2), 4.0)
	elif _rng.randf() < 0.25:
		_prop("windmill", _spot(3.0), _rng.randf() * TAU)
	if _rng.randf() < 0.35:
		var at := _spot(8.0)
		for i in _rng.randi_range(1, 3):
			_spawn("pumpjack", _near(at, 10.0, 3.0))


func _desert() -> void:
	for i in _rng.randi_range(6, 12):
		_plant("saguaro", 0.7, 1.15, Vector3.INF, 1.0)
	for i in _rng.randi_range(4, 8):
		_plant("prickly_pear", 0.7, 1.2, Vector3.INF, 0.6)
	for i in _rng.randi_range(3, 6):
		_plant("rock_red", 0.6, 1.3, Vector3.INF, 1.2)
	for i in _rng.randi_range(2, 6):
		_plant("sagebrush", 0.5, 0.9, Vector3.INF, 0.5)
	for i in _rng.randi_range(1, 2):
		_spawn("saguaro", _spot(1.0))
	if _rng.randf() < 0.5:
		_herd("coyote", _spot(3.0), _rng.randi_range(1, 2), 4.0)


func _mesa_land() -> void:
	for i in _rng.randi_range(8, 14):
		_plant("pinyon", 0.6, 1.1, Vector3.INF, 1.5)
	for i in _rng.randi_range(5, 10):
		_plant("sagebrush", 0.6, 1.0, Vector3.INF, 0.5)
	for i in _rng.randi_range(1, 4):
		_plant("rock_tan", 0.5, 1.1, Vector3.INF, 1.0)
	if _rng.randf() < 0.3:
		var at := _spot(14.0)
		_village(at, 3, 5)
	if _rng.randf() < 0.4:
		var at := _spot(6.0)
		_herd("longhorn", at, _rng.randi_range(2, 5), 6.0)
		_spawn("cowboy", _near(at, 6.0, 1.0))
	if _rng.randf() < 0.2:
		_spawn("coyote", _spot(2.0))


func _village(at: Vector3, low: int, high: int) -> void:
	_take(at, 4.0)
	for i in _rng.randi_range(low, high):
		var p := _near(at, 14.0, 5.0)
		_prop("adobe", p, _rng.randi_range(0, 3) * PI / 2, _rng.randf_range(0.8, 1.0))
		_take(p, 5.0)
	if _rng.randf() < 0.6:
		var p := _near(at, 10.0, 3.0)
		_prop("water_tower", p)
		_take(p, 3.0)
	_herd("person", at, _rng.randi_range(2, 3), 8.0)


func _mountain() -> void:
	for i in _rng.randi_range(14, 24):
		_plant("pine", 0.8, 1.4, Vector3.INF, 1.8)
	if _rng.randf() < 0.6:
		var at := _spot(6.0)
		for i in _rng.randi_range(6, 10):
			_plant("aspen", 0.8, 1.2, _near(at, 8.0, 1.0))
	for i in _rng.randi_range(2, 5):
		_plant("rock", 0.6, 1.4, Vector3.INF, 1.2)
	if _rng.randf() < 0.3:
		var at := _spot(10.0)
		_prop("cabin", at, _rng.randf() * TAU)
		_take(at, 5.0)
		var tent := _near(at, 9.0, 2.0)
		_prop("camp_tent", tent, _rng.randf() * TAU)
		_take(tent, 2.0)
		_herd("person", tent, 2, 4.0)
	if _rng.randf() < 0.3:
		_herd("sheep", _spot(4.0), _rng.randi_range(2, 4), 5.0)
	if _rng.randf() < 0.2:
		_herd("horse", _spot(4.0), _rng.randi_range(1, 3), 5.0)


## A town where two roads cross: houses (adobe in the desert and New Mexico), people, a diner
func _town(b: int) -> void:
	var dry := b == Biome.DESERT or b == Biome.MESA
	var paint: Array[Color] = [Color(0.92, 0.9, 0.82), Color(0.75, 0.82, 0.9), Color(0.95, 0.85, 0.6), Color(0.8, 0.9, 0.75), Color(0.9, 0.7, 0.65)]
	var base := centre_of(_chunk)
	for qx: float in [-1.0, 1.0]:
		for qz: float in [-1.0, 1.0]:
			for i in 2:
				var p := base + Vector3(qx * (9.0 + i * 9.5), 0, qz * _rng.randf_range(9.0, 16.0))
				var turn := PI / 2 * -qx
				if not _clear(p, 4.5):
					continue
				if dry:
					_prop("adobe", p, turn, 0.85)
				else:
					_prop("house", p, turn, 0.9, {"walls": paint[_rng.randi() % paint.size()]})
				_take(p, 5.0)
	if b != Biome.MOUNTAIN and _clear(base + Vector3(-12, 0, -9), 5.0):
		_prop("diner", base + Vector3(-12, 0, -9), PI / 2)
		_take(base + Vector3(-12, 0, -9), 7.0)
	if _rng.randf() < 0.6 and _clear(base + Vector3(12, 0, -9), 3.0):
		_prop("water_tower", base + Vector3(12, 0, -9))
	for i in _rng.randi_range(3, 5):
		_spawn("person", base + Vector3(_rng.randf_range(-16, 16), 0, _rng.randf_range(-16, 16)))


func _car(b: int, axis: String) -> void:
	var kinds := ["car", "car", "pickup"]
	if b == Biome.DESERT or b == Biome.MESA:
		kinds = ["car", "pickup", "rv"]
	elif b == Biome.FARM:
		kinds = ["car", "pickup", "pickup"]
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var base := centre_of(_chunk)
	var along := _rng.randf_range(-20, 20)
	var at := base + (Vector3(1.5 * dir, 0, along) if axis == "z" else Vector3(along, 0, -1.5 * dir))
	if game != null:
		game.spawn_car(kinds[_rng.randi() % kinds.size()], at, axis, dir)
