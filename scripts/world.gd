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
## Where a run starts: over a cornfield, the chunk off the corner of the first town
const START := Vector3(48, 0, 48)
## Props tall enough for the saucer to fly into
const TALL := ["watchtower", "water_tower", "silo", "clock_tower", "control_tower", "radio_tower", "church"]
## Chunks are made out to this many from the saucer's, and dropped beyond FAR
const NEAR := 3
const FAR := 4
## Roads run along every fifth line of chunks (every 240 m)
const ROAD_EVERY := 5
## Devils Tower: one of it, about a kilometre out from where the game starts, well away from the
## roads, in a forest of pines
## Where Devils Tower stands (moved by `reseed`)
static var TOWER := Vector3(-624, 0, -864)
## The world's seed: a new one each run makes a new country (see `reseed`); 0 is the first one
static var world_seed := 0
## The roads' wandering and which of them are dirt, from the seed (see `reseed`)
static var _road_phase := 0.0
static var _dirt_step_x := 7
static var _dirt_step_z := 11
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
## The lakes of the chunks made: (x, z, radius) (no crops in them, see `crops_at`)
var lakes := {}
const WATER := preload("res://shaders/water.gdshader")
var _rattled: Array = []
## Crop circles pressed into the fields: (x, z, radius, unused), the oldest written over first
var _circles: PackedVector4Array = PackedVector4Array()
var _circle_next := 0
## The lines pressed between crop circles near each other: (x, z) to (x, z) each
var _links: PackedVector4Array = PackedVector4Array()
var _link_next := 0
const LINK_REACH := 14.0


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(324, 324)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	ground = MeshInstance3D.new()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.mesh = plane
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://shaders/ground.gdshader")
	_ground_mat.set_shader_parameter("chunk", CHUNK)
	_ground_mat.set_shader_parameter("road_every_chunks", float(ROAD_EVERY))
	_biome_img = Image.create(BIOME_SPAN, BIOME_SPAN, false, Image.FORMAT_RGB8)
	_biome_tex = ImageTexture.create_from_image(_biome_img)
	_ground_mat.set_shader_parameter("biomes", _biome_tex)
	_circles.resize(24)
	_links.resize(16)
	_ground_mat.set_shader_parameter("links", _links)
	_ground_mat.set_shader_parameter("circles", _circles)
	ground.material_override = _ground_mat
	ground.extra_cull_margin = 200.0
	add_child(ground)



## A new country from `s`: its regions, roads and props all change, and Devils Tower moves. Forgets
## every chunk made so far (and all that was in them); they are made again round the ship as it goes.
func reseed(s: int) -> void:
	world_seed = s
	var r := RandomNumberGenerator.new()
	r.seed = s
	_road_phase = r.randf() * TAU if s != 0 else 0.0
	_dirt_step_x = [7, 6, 9, 8][r.randi() % 4] if s != 0 else 7
	_dirt_step_z = [11, 12, 13, 14][r.randi() % 4] if s != 0 else 11
	if s != 0:
		# (out somewhere 15 to 22 chunks off, never on a road line)
		var a := r.randf() * TAU
		var d := r.randf_range(15.0, 22.0)
		var c := Vector2i(roundi(cos(a) * d), roundi(sin(a) * d))
		c.x += posmod(2 - c.x, ROAD_EVERY)
		c.y += posmod(2 - c.y, ROAD_EVERY)
		TOWER = centre_of(c)
	else:
		TOWER = Vector3(-624, 0, -864)
	_ground_mat.set_shader_parameter("road_phase", _road_phase)
	_ground_mat.set_shader_parameter("dirt_step", Vector2(_dirt_step_x, _dirt_step_z))
	for c: Vector2i in chunks.keys():
		chunks[c].queue_free()
		if game != null:
			game.forget_chunk(c)
	chunks.clear()
	obstacles.clear()
	loose.clear()
	lakes.clear()
	_queue.clear()
	_centre = Vector2i(99999, 99999)
	_circles.fill(Vector4.ZERO)
	_links.fill(Vector4.ZERO)
	_circle_next = 0
	_link_next = 0
	_ground_mat.set_shader_parameter("circles", _circles)
	_ground_mat.set_shader_parameter("links", _links)

# ------------------------------------------------------------------ where things are

static func chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x + CHUNK * 0.5) / CHUNK), floori((p.z + CHUNK * 0.5) / CHUNK))


static func centre_of(c: Vector2i) -> Vector3:
	return Vector3(c.x * CHUNK, 0, c.y * CHUNK)


## A number from 0 to 1 that only depends on the three it is given
static func hash3(x: int, z: int, s: int) -> float:
	var h := (x * 374761393 + z * 668265263 + s * 1442695041 + world_seed * 2654435761) & 0x7fffffff
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
	# Farm country where the game starts, and plains (and pines) round the tower
	if near_tower(c):
		return Biome.PLAINS
	if absi(c.x) <= 1 and absi(c.y) <= 1:
		return Biome.FARM
	var high := noise(c.x / 10.0, c.y / 10.0, 2) + noise(c.x / 3.5, c.y / 3.5, 3) * 0.15
	var dry := noise(c.x / 8.5 + 40.0, c.y / 8.5, 1) + noise(c.x / 3.0, c.y / 3.0, 4) * 0.1
	if high > 0.72:
		return Biome.MOUNTAIN
	if dry > 0.66:
		return Biome.DESERT
	if dry > 0.52:
		return Biome.MESA
	if dry < 0.4:
		return Biome.FARM
	return Biome.PLAINS


## Whether a chunk is Devils Tower's or one of those round it (its forest)
static func near_tower(c: Vector2i) -> bool:
	var d := c - chunk_of(TOWER)
	return maxi(absi(d.x), absi(d.y)) <= 1


static func has_road(n: int) -> bool:
	return posmod(n, ROAD_EVERY) == 0


## Railways run straight along x down the middle of every row of chunks `m` with this: a few rows
## apart, and never on a road's row or the rows of houses either side of one (z = m * CHUNK)
static func has_rail(m: int) -> bool:
	return posmod(m, 7) == 3 and posmod(m, ROAD_EVERY) in [2, 3]


## The railway along row `m`: down the middle of it
static func rail_z(m: int) -> float:
	return m * CHUNK


# ------------------------------------------------------------------ the roads
# Roads run along every fifth line of chunks, both ways. In open country they meander a little to
# either side of their line (but never out of their chunks); near a crossing they run straight, so a
# town is a grid. Some lines are dirt roads (narrower, no line down the middle, no towns on them).
# shaders/ground.gdshader paints them with the same sums: keep the two the same.

## How far a road wanders from its line, at most
const MEANDER := 11.0


## Where the road along line `n` (a column of chunks; it runs along z) is, at `z`
static func road_x(n: int, z: float) -> float:
	return n * CHUNK + _wander(float(n), z)


## Where the road along line `m` (a row of chunks; it runs along x) is, at `x`
static func road_z(m: int, x: float) -> float:
	return m * CHUNK + _wander(float(m) + 0.5, x)


static func _wander(line: float, t: float) -> float:
	var spacing := CHUNK * ROAD_EVERY
	var from_crossing := absf(t - roundf(t / spacing) * spacing)
	var amount := MEANDER * smoothstep(30.0, 90.0, from_crossing)
	return amount * (sin(t * 0.013 + line * 1.7 + _road_phase) + 0.45 * sin(t * 0.031 + line * 2.9 + _road_phase * 1.3)) / 1.45


## Whether the road along column `n` / row `m` is a dirt road
static func dirt_x(n: int) -> bool:
	return posmod(floori(n / float(ROAD_EVERY)) * _dirt_step_x + 3, 5) < 2


static func dirt_z(m: int) -> bool:
	return posmod(floori(m / float(ROAD_EVERY)) * _dirt_step_z + 3, 5) < 2


## How wide either side of its middle a road is
static func road_half(dirt: bool) -> float:
	return 2.0 if dirt else 3.0


## How far `p` is from the middle of the nearest road each way, less that road's half width (so
## below 0 is on it): [along-z road, along-x road]
static func road_gaps(p: Vector3) -> Vector2:
	var n := roundi(p.x / (CHUNK * ROAD_EVERY)) * ROAD_EVERY
	var m := roundi(p.z / (CHUNK * ROAD_EVERY)) * ROAD_EVERY
	return Vector2(absf(p.x - road_x(n, p.z)) - road_half(dirt_x(n)), absf(p.z - road_z(m, p.x)) - road_half(dirt_z(m)))


## Whether a town stands where two roads cross here (some crossings are only crossings; never on a
## dirt road)
static func is_town(c: Vector2i) -> bool:
	return has_road(c.x) and has_road(c.y) and not dirt_x(c.x) and not dirt_z(c.y) and (c == Vector2i.ZERO or hash3(c.x, c.y, 61) < 0.4)


## Whether this chunk is on a road leading straight out of a town, and is lined with houses
static func is_edge_of_town(c: Vector2i) -> bool:
	if has_road(c.x) and not has_road(c.y):
		return is_town(c + Vector2i(0, 1)) or is_town(c + Vector2i(0, -1))
	if has_road(c.y) and not has_road(c.x):
		return is_town(c + Vector2i(1, 0)) or is_town(c + Vector2i(-1, 0))
	return false


## Whether a secret government facility takes up this chunk, and which ship it holds ("" if none)
static func facility(c: Vector2i) -> String:
	if has_road(c.x) or has_road(c.y) or has_rail(c.y) or absi(c.x) + absi(c.y) < 6 or biome(c) == Biome.MOUNTAIN or not landforms(c).is_empty():
		return ""
	if hash3(c.x, c.y, 101) >= 0.022:
		return ""
	# (any ship but the saucer, which is flown from the start)
	var held := Ufo.ORDER.slice(1)
	return held[mini(int(hash3(c.x, c.y, 102) * held.size()), held.size() - 1)]


## Whether an army base takes up this chunk
static func is_base(c: Vector2i) -> bool:
	return not has_road(c.x) and not has_road(c.y) and not has_rail(c.y) and absi(c.x) + absi(c.y) > 3 and biome(c) != Biome.MOUNTAIN \
		and hash3(c.x, c.y, 71) < 0.035 and landforms(c).is_empty() and hash3(c.x, c.y, 101) >= 0.022


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
	# (made all at once: what is in them is put down at once too)
	if now and game != null:
		game._spawn_some(true)


func _ring(d: Vector2i) -> int:
	return maxi(absi(d.x), absi(d.y))


func _recentre() -> void:
	for c: Vector2i in chunks.keys():
		if _ring(c - _centre) > FAR:
			chunks[c].queue_free()
			chunks.erase(c)
			obstacles.erase(c)
			loose.erase(c)
			lakes.erase(c)
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
			var cz := _centre + Vector2i(x - half, z - half)
			_biome_img.set_pixel(x, z, Color(biome(cz) * 40.0 / 255.0, field(cz) * 20.0 / 255.0, 1.0 if rows_across(cz) else 0.0))
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


## Shakes the scenery under the beam that is too much for it (`reach` 0 settles it all again)
func rattle(p: Vector3, reach: float, tier: int) -> void:
	for entry: Array in _rattled:
		(entry[1] as MultiMesh).set_instance_transform(entry[2], entry[3])
	_rattled.clear()
	if reach <= 0.0:
		return
	for entry: Array in loose.get(chunk_of(p), []):
		var xf: Transform3D = entry[3]
		var name: String = entry[0]
		var kind: String = RECOLOURED[name][0] if RECOLOURED.has(name) else name
		if Vector2(xf.origin.x - p.x, xf.origin.z - p.z).length() < reach and int(Thing.KINDS[kind].get("tier", 1)) > tier:
			var shaken := xf.translated(Vector3(randf_range(-0.1, 0.1), randf() * 0.08, randf_range(-0.1, 0.1)))
			(entry[1] as MultiMesh).set_instance_transform(entry[2], shaken)
			_rattled.append(entry)


## Presses a crop circle into the ground at `p` (drawn only where crops grow), `radius` across, joined
## by a line pressed through the crop to the nearest other circles within LINK_REACH: never more than
## two lines to a circle, and never a line through another circle. How many it was joined to
func crop_circle(p: Vector3, radius: float) -> int:
	var here := Vector2(p.x, p.z)
	var near: Array[Vector4] = []
	for c: Vector4 in _circles:
		if c.z > 0.0 and Vector2(c.x, c.y).distance_to(here) < LINK_REACH:
			near.append(c)
	near.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x, a.y).distance_to(here) < Vector2(b.x, b.y).distance_to(here))
	var joined := 0
	for c: Vector4 in near:
		if joined >= MAX_LINKS:
			break
		var there := Vector2(c.x, c.y)
		if _links_at(there) >= MAX_LINKS or _crosses_circle(here, there):
			continue
		_links[_link_next] = Vector4(c.x, c.y, p.x, p.z)
		_link_next = (_link_next + 1) % _links.size()
		joined += 1
	_circles[_circle_next] = Vector4(p.x, p.z, radius, 0.0)
	_circle_next = (_circle_next + 1) % _circles.size()
	_ground_mat.set_shader_parameter("circles", _circles)
	_ground_mat.set_shader_parameter("links", _links)
	return joined


const MAX_LINKS := 2
## How big a crop circle may grow, for keeping lines clear of one still growing
const CIRCLE_ROOM := 7.0


## How many lines already run to the circle at `at`
func _links_at(at: Vector2) -> int:
	var count := 0
	for l: Vector4 in _links:
		if Vector2(l.x, l.y).distance_to(at) < 0.1 or Vector2(l.z, l.w).distance_to(at) < 0.1:
			count += 1
	return count


## Whether a line from `a` to `b` would pass through a crop circle other than those at its ends
func _crosses_circle(a: Vector2, b: Vector2) -> bool:
	for c: Vector4 in _circles:
		if c.z <= 0.0:
			continue
		var o := Vector2(c.x, c.y)
		if o.distance_to(a) < 0.1 or o.distance_to(b) < 0.1:
			continue
		var ab := b - a
		var k := clampf((o - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if o.distance_to(a + ab * k) < maxf(c.z, CIRCLE_ROOM) + 1.0:
			return true
	return false


## The nearest crop circle to `p` within `reach`, for the curious to come and look at: (x, its radius,
## z), or INF
func nearest_circle(p: Vector3, reach: float) -> Vector3:
	var best := Vector3.INF
	var gap := reach
	for c in _circles:
		if c.z <= 0.0:
			continue
		var d := Vector2(c.x - p.x, c.y - p.z).length()
		if d < gap:
			gap = d
			best = Vector3(c.x, c.z, c.y)
	return best


## Grows the newest crop circle (the beam is still held over it)
func grow_circle(radius: float) -> void:
	var i := posmod(_circle_next - 1, _circles.size())
	var c: Vector4 = _circles[i]
	_circles[i] = Vector4(c.x, c.y, radius, 0.0)
	_ground_mat.set_shader_parameter("circles", _circles)



## What the ground is at `p`, for what the beam kicks up there: "water", "road", "crop", "grass",
## "sand", "dirt" or "rock"
func surface_at(p: Vector3) -> String:
	var lake: Vector3 = lakes.get(chunk_of(p), Vector3(0, 0, -1))
	if Vector2(p.x - lake.x, p.z - lake.y).length() < lake.z:
		return "water"
	if on_road(p, 0.0):
		return "road"
	match biome_at(p):
		Biome.FARM:
			return "crop" if field(chunk_of(p)) in [Field.WHEAT, Field.CORN] else "grass"
		Biome.PLAINS:
			return "grass"
		Biome.DESERT:
			return "sand"
		Biome.MESA:
			return "dirt"
	return "rock"

## Whether a crop circle can be pressed at `p`: anywhere in the farm country off the roads
func crops_at(p: Vector3) -> bool:
	if biome_at(p) != Biome.FARM or on_road(p, 2.0):
		return false
	var lake: Vector3 = lakes.get(chunk_of(p), Vector3(0, 0, -1))
	return Vector2(p.x - lake.x, p.z - lake.y).length() > lake.z


## Only people and cars are ever put down in a road
const STREET_KINDS: Array[String] = ["person", "farmer", "cowboy", "car", "pickup", "rv"]


## A point moved to the side of any road it is on (with `margin` to spare)
func off_road(p: Vector3, margin: float) -> Vector3:
	var n := roundi(p.x / (CHUNK * ROAD_EVERY)) * ROAD_EVERY
	var m := roundi(p.z / (CHUNK * ROAD_EVERY)) * ROAD_EVERY
	var clear_x := road_half(dirt_x(n)) + margin + 0.5
	var clear_z := road_half(dirt_z(m)) + margin + 0.5
	var dx := p.x - road_x(n, p.z)
	var dz := p.z - road_z(m, p.x)
	if absf(dx) < clear_x:
		p.x += (clear_x - absf(dx)) * (1.0 if dx >= 0.0 else -1.0)
	if absf(dz) < clear_z:
		p.z += (clear_z - absf(dz)) * (1.0 if dz >= 0.0 else -1.0)
	return p

## Whether a point is on (or within `margin` of) a road
func on_road(p: Vector3, margin := 0.0) -> bool:
	var gaps := road_gaps(p)
	# (the railway's bed counts too, for nothing to be put down on it)
	var row := roundi(p.z / CHUNK)
	if has_rail(row) and absf(p.z - rail_z(row)) < 1.8 + margin:
		return true
	return gaps.x < margin or gaps.y < margin


## Whether any scenery under `p` is too much for a beam of `tier`
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
	# (and the railway, if one runs through)
	if has_rail(c.y):
		_taken.append(Vector3(0, -4.0, rail_z(c.y)))
		_rail_line(c)
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
			# (a thick ring of ponderosa pines round its foot)
			for i in 40:
				var foot := _ring_spot(f["at"], float(f["skirt"]) + 1.0, float(f["skirt"]) + 14.0)
				if _clear(foot, 1.3):
					_plant("pine", 0.8, 1.4, foot)
	if near_tower(c) and c != chunk_of(TOWER):
		# (and the forest round it, out to the next chunks)
		for i in 26:
			_plant("pine", 0.8, 1.4, Vector3.INF, 1.3)
	# Now and then a trader's saucer parked out of the way (and always one near the start)
	if game != null and not road_x and not road_z and (hash3(c.x, c.y, 33) < 0.06 or c == Vector2i(-1, 0)):
		var pad := _spot(7.0)
		if pad != Vector3.INF:
			_take(pad, 7.0)
			game.spawn_shop(pad, c)
	var town := is_town(c)
	var open := not road_x and not road_z and not town and facility(c) == "" and not is_base(c) and not near_tower(c)
	if open and airfield(c):
		_airfield()
	elif town:
		_town(b)
	elif is_edge_of_town(c):
		_edge_of_town(b, "z" if road_x else "x")
	elif facility(c) != "":
		_facility(facility(c))
	elif is_base(c):
		_base()
	else:
		# (out in the open country, now and then a lake, or a low hill)
		var wild := open and (b in [Biome.PLAINS, Biome.MOUNTAIN] or field(c) == Field.PASTURE)
		if wild and hash3(c.x, c.y, 141) < 0.07:
			_lake()
		elif wild and hash3(c.x, c.y, 142) < 0.16:
			var at := _spot(13.0)
			if at != Vector3.INF:
				_take(at, 13.0)
				_prop("hill", at, _rng.randf() * TAU, _rng.randf_range(0.8, 1.2))
		elif open and b == Biome.FARM and hash3(c.x, c.y, 216) < 0.08:
			# (a farm pond)
			var r := _rng.randf_range(4.5, 7.0)
			var pond := _spot(r + 1.5)
			if pond != Vector3.INF:
				_water(pond, r)
				_take(pond, r + 1.5)
		# (now and then a place people come to, in the middle)
		if open:
			_venue(c, b)
		# (and a hot air balloon hanging over the fields)
		if open and b in [Biome.FARM, Biome.PLAINS] and hash3(c.x, c.y, 215) < 0.07:
			_spawn("balloon", _spot(3.0))
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
		_watchers(c, b)
		_country_folk(c, b)
	if road_x:
		_phone_line(c, "z")
	if road_z:
		_phone_line(c, "x")
	if not town and not is_base(c) and facility(c) == "":
		_wildlife(b)
		_rare(c, b)
	if road_x != road_z and not town and not is_edge_of_town(c):
		_roadside(c, "z" if road_x else "x")
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
	if has_road(c.x) or has_road(c.y) or has_rail(c.y):
		return found
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash3(c.x, c.y, 91) * 1000000.0) + 7
	var b := biome(c)
	var r := rng.randf()
	var pick := ""
	if c == chunk_of(TOWER):
		pick = "devils_tower"
	elif b == Biome.PLAINS and r < 0.08 and not near_tower(c):
		pick = "butte"
	elif b == Biome.DESERT:
		pick = "mesa" if r < 0.15 else ("butte" if r < 0.3 else "")
	elif b == Biome.MESA and r < 0.15:
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
	# (no room: the caller puts nothing down)
	return Vector3.INF


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
	return Vector3.INF


func _clear(p: Vector3, radius: float) -> bool:
	for t in _taken:
		if t.y == -1.0:
			if absf(p.x - road_x(roundi(t.x / CHUNK), p.z)) < 4.0 + radius:
				return false
		elif t.y == -2.0:
			if absf(p.z - road_z(roundi(t.z / CHUNK), p.x)) < 4.0 + radius:
				return false
		elif t.y == -4.0:
			if absf(p.z - t.z) < 3.5 + radius:
				return false
		elif Vector2(p.x - t.x, p.z - t.z).length() < radius + t.y:
			return false
	return true


func _take(p: Vector3, radius: float) -> void:
	_taken.append(Vector3(p.x, radius, p.z))


## A building (or a landform, with the `block` it makes): a thing the beam can take, if strong enough
func _prop(name: String, at: Vector3, turn := 0.0, size := 1.0, tints := {}, block := Vector4.ZERO) -> void:
	if at == Vector3.INF or (block == Vector4.ZERO and on_road(at, float(Thing.KINDS[name]["size"]) * size * 0.6)):
		return
	if game == null:
		_put(name, at, turn, size, tints)
		return
	if block == Vector4.ZERO and name in TALL:
		# (tall enough to fly into: the saucer bounces off it, see push_out)
		block = Vector4(at.x, at.z, float(Thing.KINDS[name]["size"]) * size * 0.6, 12.0)
		(obstacles[_chunk] as Array).append(block)
	game.spawn_later(name, at, {"turn": turn, "size": size, "tints": tints, "chunk": _chunk, "obstacle": block})


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
	if p == Vector3.INF:
		return
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
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.multimesh = mm
	mmi.extra_cull_margin = Ps1.CULL_MARGIN
	mmi.visibility_range_end = Ps1.DRAW_TO + 20.0
	_node.add_child(mmi)
	if not loose.has(_chunk):
		loose[_chunk] = []
	for i in where.size():
		(loose[_chunk] as Array).append([name, mm, i, where[i]])


func _spawn(kind: String, at: Vector3) -> void:
	if game != null and at != Vector3.INF:
		game.spawn_later(kind, at if kind in STREET_KINDS else off_road(at, float(Thing.KINDS[kind]["size"])), {})


func _herd(kind: String, at: Vector3, count: int, spread: float) -> void:
	if at == Vector3.INF:
		return
	for i in count:
		_spawn(kind, _near(at, spread, 0.5))


func _farm() -> void:
	var kind := field(_chunk)
	_fences()
	if kind != Field.PASTURE and kind != Field.NONE:
		_crops(kind)
		return
	# Pasture: trees, cows, and most often a farmstead (a farmhouse with its porch, a barn and a silo
	# or two, a haystack and bales, pens of animals)
	for i in _rng.randi_range(3, 7):
		_plant("tree", 0.75, 1.05, Vector3.INF, 2.5)
	for i in _rng.randi_range(2, 5):
		_plant("bush", 0.6, 1.1, Vector3.INF, 1.2)
	var farm_at := _spot(17.0) if _rng.randf() < 0.75 else Vector3.INF
	if farm_at != Vector3.INF:
		var at := farm_at
		var turn := _rng.randi_range(0, 3) * PI / 2
		var basis := Basis(Vector3.UP, turn)
		_prop("barn", at + basis * Vector3(-6, 0, -6), turn, 0.6)
		_prop("farmhouse", at + basis * Vector3(9, 0, -8), turn, 0.85)
		_prop("silo", at + basis * Vector3(-12, 0, -12), 0.0, 0.48)
		if _rng.randf() < 0.45:
			_prop("silo", at + basis * Vector3(-15.5, 0, -9), 0.0, 0.42)
		_take(at, 17.0)
		var pen := at + basis * Vector3(-2, 0, 10)
		_pen(pen, turn, 6, 4)
		_herd("cow", pen, _rng.randi_range(2, 4), 6.0)
		_herd(["sheep", "pig"][_rng.randi() % 2], pen, _rng.randi_range(1, 3), 5.0)
		_herd("chicken", at + basis * Vector3(2, 0, -2), _rng.randi_range(2, 5), 5.0)
		_spawn("farmer", at + basis * Vector3(4, 0, 2))
		if _rng.randf() < 0.5:
			_spawn("tractor", at + basis * Vector3(12, 0, 6))
		_prop("hay_pile", at + basis * Vector3(-13, 0, 3), _rng.randf() * TAU, _rng.randf_range(0.8, 1.1))
		_herd("hay_bale", at + basis * Vector3(-12, 0, 8), _rng.randi_range(2, 4), 3.0)
		if _rng.randf() < 0.6:
			_herd("barrel", at + basis * Vector3(-3, 0, -12), _rng.randi_range(2, 3), 1.5)
		if _rng.randf() < 0.4:
			_spawn("outhouse", at + basis * Vector3(14, 0, -2))
	elif _rng.randf() < 0.15:
		# (a country church on its own)
		var at := _spot(9.0)
		if at != Vector3.INF:
			_take(at, 9.0)
			_prop("church", at, _rng.randi_range(0, 3) * PI / 2, 0.8)
	elif _rng.randf() < 0.5:
		# (a field barn on its own, with hay)
		var at := _spot(8.0)
		if at != Vector3.INF:
			_take(at, 8.0)
			_prop("barn", at, _rng.randi_range(0, 3) * PI / 2, 0.55)
			_herd("hay_bale", at + Vector3(7, 0, 4), _rng.randi_range(1, 3), 3.0)
	if _rng.randf() < 0.5:
		_herd("cow", _spot(6.0), _rng.randi_range(2, 4), 5.0)


## A field of a crop, in rows right across the chunk (but for the road), and what goes with it
func _crops(kind: int) -> void:
	var base := centre_of(_chunk)
	var across := rows_across(_chunk)
	var crop: String = {Field.WHEAT: "wheat", Field.CORN: "corn", Field.PUMPKIN: "pumpkin"}.get(kind, "")
	if crop != "":
		# (corn packed close, row on row; wheat and pumpkins sparser)
		var gap: float = {"pumpkin": 2.6, "corn": 1.3}.get(crop, 2.2)
		var rows: float = 1.8 if crop == "corn" else 3.0
		var row := -CHUNK * 0.5 + 1.5
		while row < CHUNK * 0.5:
			var along := -CHUNK * 0.5 + 1.0
			while along < CHUNK * 0.5:
				var p := base + (Vector3(row, 0, along) if across else Vector3(along, 0, row))
				p += Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))
				if not on_road(p, 1.5):
					_plant_at(crop, p, _rng.randf() * TAU)
				along += gap
			row += rows
	match kind:
		Field.WHEAT:
			if _rng.randf() < 0.4:
				_spawn("scarecrow", _spot(2.0))
		Field.PLOUGHED:
			if _rng.randf() < 0.35:
				_spawn("tractor", _spot(4.0))
			if _rng.randf() < 0.5:
				_prop("hay_pile", _spot(4.0), _rng.randf() * TAU, _rng.randf_range(0.8, 1.1))
		Field.GREEN:
			if _rng.randf() < 0.5:
				_herd("hay_bale", _spot(3.0), _rng.randi_range(2, 5), 6.0)


## Fences along the field's west and north edges where the field next door is farmland too (each
## field fences its own two, so every edge is fenced once), with gaps where a road crosses
func _fences() -> void:
	var base := centre_of(_chunk)
	for side in 2:
		var next := _chunk + (Vector2i(-1, 0) if side == 0 else Vector2i(0, -1))
		if field(next) == Field.NONE:
			continue
		var k := -CHUNK * 0.5 + 1.5
		while k < CHUNK * 0.5:
			var p := base + (Vector3(-CHUNK * 0.5, 0, k) if side == 0 else Vector3(k, 0, -CHUNK * 0.5))
			if not on_road(p, 2.0):
				_plant_at("fence", p, PI / 2 if side == 0 else 0.0)
			k += 3.0


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
	# (nobody lives in the forest round Devils Tower: no ranches, windmills or oil wells there)
	var wild := near_tower(_chunk)
	var ranch_at := _spot(14.0) if _rng.randf() < 0.35 and not wild else Vector3.INF
	if ranch_at != Vector3.INF:
		var at := ranch_at
		var turn := _rng.randi_range(0, 3) * PI / 2
		_prop("farmhouse", at + Basis(Vector3.UP, turn) * Vector3(8, 0, -6), turn, 0.8)
		_prop("windmill", at + Basis(Vector3.UP, turn) * Vector3(-8, 0, -8), turn)
		_take(at, 14.0)
		_pen(at + Basis(Vector3.UP, turn) * Vector3(-1, 0, 6), turn, 5, 3)
		_herd("horse", at + Basis(Vector3.UP, turn) * Vector3(-1, 0, 6), _rng.randi_range(2, 4), 4.0)
		_herd("cowboy", at, _rng.randi_range(1, 2), 4.0)
	elif _rng.randf() < 0.25 and not wild:
		_prop("windmill", _spot(3.0), _rng.randf() * TAU)
	if _rng.randf() < 0.35 and not wild:
		var at := _spot(8.0)
		if at != Vector3.INF:
			for i in _rng.randi_range(1, 3):
				var jack := _near(at, 10.0, 3.0)
				if jack != Vector3.INF:
					_take(jack, 3.0)
					_spawn("pumpjack", jack)
			if _rng.randf() < 0.6:
				_herd("barrel", _near(at, 6.0, 1.0), 2, 1.5)


func _desert() -> void:
	for i in _rng.randi_range(6, 12):
		_plant("saguaro", 0.45, 0.7, Vector3.INF, 1.0)
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
		if at != Vector3.INF:
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
		if p == Vector3.INF:
			continue
		_prop("adobe", p, _rng.randi_range(0, 3) * PI / 2, _rng.randf_range(0.8, 1.0))
		_take(p, 5.0)
	if _rng.randf() < 0.6:
		var p := _near(at, 10.0, 3.0)
		if p != Vector3.INF:
			_prop("water_tower", p)
			_take(p, 3.0)
	_herd("person", at, _rng.randi_range(2, 3), 8.0)


func _mountain() -> void:
	for i in _rng.randi_range(14, 24):
		_plant("pine", 0.8, 1.4, Vector3.INF, 1.8)
	if _rng.randf() < 0.6:
		var at := _spot(6.0)
		if at != Vector3.INF:
			for i in _rng.randi_range(6, 10):
				_plant("aspen", 0.8, 1.2, _near(at, 8.0, 1.0))
	for i in _rng.randi_range(2, 5):
		_plant("rock", 0.6, 1.4, Vector3.INF, 1.2)
	var cabin_at := _spot(10.0) if _rng.randf() < 0.3 else Vector3.INF
	if cabin_at != Vector3.INF:
		_prop("cabin", cabin_at, _rng.randf() * TAU)
		_take(cabin_at, 5.0)
		var tent := _near(cabin_at, 9.0, 2.0)
		if tent != Vector3.INF:
			_prop("camp_tent", tent, _rng.randf() * TAU)
			_take(tent, 2.0)
			_herd("person", tent, 2, 4.0)
	if _rng.randf() < 0.3:
		_herd("sheep", _spot(4.0), _rng.randi_range(2, 4), 5.0)
	if _rng.randf() < 0.2:
		_herd("horse", _spot(4.0), _rng.randi_range(1, 3), 5.0)


## The roads out of a town, lined with houses on both sides
func _edge_of_town(b: int, axis: String) -> void:
	var dry := b == Biome.DESERT or b == Biome.MESA
	var paint: Array[Color] = [Color(0.92, 0.9, 0.82), Color(0.75, 0.82, 0.9), Color(0.95, 0.85, 0.6), Color(0.8, 0.9, 0.75), Color(0.9, 0.7, 0.65)]
	var base := centre_of(_chunk)
	_sidewalks(axis)
	for i in _rng.randi_range(3, 6):
		_plant("bush", 0.6, 1.0, Vector3.INF, 1.0)
	# (now and then one of the houses is a church instead)
	var church := _rng.randi_range(0, 5) if _rng.randf() < 0.3 else -1
	var slot := -1
	for k: float in [-15.0, 0.0, 15.0]:
		for side: float in [-1.0, 1.0]:
			slot += 1
			var out := 12.5 if slot == church else 10.0
			var p := base + (Vector3(side * out, 0, k) if axis == "z" else Vector3(k, 0, side * out))
			if not _clear(p, 4.5) or _rng.randf() < 0.2:
				continue
			var turn := (PI / 2 * side if axis == "z" else (0.0 if side < 0.0 else PI))
			if slot == church:
				_prop("church", p, turn, 0.8)
			elif dry:
				_prop("adobe", p, turn, 0.8)
			else:
				_prop("house", p, turn, 0.85, {"walls": paint[_rng.randi() % paint.size()]})
			_take(p, 5.0)
	_herd("person", base + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)), _rng.randi_range(2, 5), 10.0)
	for i in _rng.randi_range(2, 4):
		_plant("tree", 0.7, 1.0, Vector3.INF, 2.0)


## An army base: a hangar with fighter jets out in front, watchtowers sweeping searchlights,
## tents, parked jeeps and a tank, all inside a fence
func _base() -> void:
	var base := centre_of(_chunk)
	_take(base, 22.0)
	_prop("hangar", base + Vector3(0, 0, -6), 0.0)
	for x: float in [-6.0, 6.0]:
		_spawn_at("fighter_jet", base + Vector3(x, 0, 9), PI)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
		_prop("watchtower", base + Vector3(corner.x * 17.0, 0, corner.y * 17.0), 0.0)
	for x: float in [-15.0, 15.0]:
		_prop("tent", base + Vector3(x, 0, 2), PI / 2)
	_spawn_at("parked_jeep", base + Vector3(-12, 0, 14), 0.3)
	_spawn_at("parked_jeep", base + Vector3(12, 0, 14), -0.3)
	_spawn_at("parked_tank", base + Vector3(0, 0, 18), 0.0)
	for i in 12:
		var along := (i - 5.5) * 3.0
		for side: float in [-1.0, 1.0]:
			_plant_at("fence", base + Vector3(along, 0, side * 21.0), 0.0)
			if absf(along) > 4.0 or side < 0.0:
				_plant_at("fence", base + Vector3(side * 21.0, 0, along), PI / 2)
	_herd("person", base + Vector3(0, 0, 8), 2, 8.0)
	_herd("barrel", base + Vector3(-15, 0, 4), _rng.randi_range(4, 6), 2.0)


## A secret government facility: a captured ship on a pad in the middle, under searchlights from four
## towers, behind a double fence, with a hangar and jeeps. Take the ship and it is yours. (One already
## found is swapped for one not yet found: see main.gd `captive`.)
func _facility(ship: String) -> void:
	var base := centre_of(_chunk)
	if game != null:
		ship = game.captive(ship, _chunk)
	_take(base, 22.0)
	_spawn_at("captured_" + ship, base, _rng.randf() * TAU)
	_prop("hangar", base + Vector3(0, 0, -15), 0.0, 0.7)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_prop("watchtower", base + Vector3(corner.x * 16.0, 0, corner.y * 16.0), 0.0)
	for corner: Vector2 in [Vector2(-1, 0), Vector2(1, 0)]:
		_prop("floodlight", base + Vector3(corner.x * 8.0, 0, 6.0), 0.0)
	_spawn_at("parked_jeep", base + Vector3(-10, 0, 12), 0.4)
	_spawn_at("parked_jeep", base + Vector3(10, 0, 12), -0.4)
	for ring: float in [19.0, 21.5]:
		for i in int(ring * 2.0 / 3.0):
			var along := (i - ring / 3.0) * 3.0
			for side: float in [-1.0, 1.0]:
				_plant_at("fence", base + Vector3(along, 0, side * ring), 0.0)
				_plant_at("fence", base + Vector3(side * ring, 0, along), PI / 2)
	_herd("person", base + Vector3(0, 0, 8), 2, 6.0)


## A thing put down in this chunk (and gone with it), facing `turn`
func _spawn_at(kind: String, at: Vector3, turn: float) -> void:
	if game != null:
		game.spawn_later(kind, off_road(at, float(Thing.KINDS[kind]["size"])), {"turn": turn, "chunk": _chunk})


## Those who watch the sky: an observatory up high or in the desert, a row of radio dishes on the
## plains and mesas (New Mexico's Very Large Array), or a single dish out in the country
func _watchers(c: Vector2i, b: int) -> void:
	if hash3(c.x, c.y, 91) < 0.04 and b in [Biome.MOUNTAIN, Biome.DESERT]:
		var at := _spot(7.0)
		if at != Vector3.INF:
			_take(at, 7.0)
			_prop("observatory", at, _rng.randf() * TAU)
	elif hash3(c.x, c.y, 92) < 0.12 and b in [Biome.MESA, Biome.PLAINS, Biome.DESERT]:
		var along := _rng.randf() < 0.5
		var base := centre_of(c)
		# (one size to an array, from small ones to the great ones of the Very Large Array)
		var big := _rng.randf_range(0.4, 0.8)
		for k in range(-2, 3):
			var at := base + (Vector3(k * 9.0, 0, 0) if along else Vector3(0, 0, k * 9.0))
			if _clear(at, 4.0):
				_take(at, 4.5)
				_prop("seti_dish", at, 0.0, big)
	elif hash3(c.x, c.y, 93) < 0.08 and b != Biome.MOUNTAIN and field(c) in [Field.NONE, Field.PASTURE]:
		# (or a single dish on its own)
		var at := _spot(4.5)
		if at != Vector3.INF:
			_take(at, 4.5)
			_prop("seti_dish", at, 0.0, _rng.randf_range(0.3, 0.75))


## A town where two roads cross: main street (shops with sign boards and awnings, in a row facing
## the road, houses behind them), a town square with its city hall, the police station on a corner, a
## diner, a clock tower or a water
## tower, and plenty of people about (more, and more worth taking, than out in the country)
func _town(b: int) -> void:
	var dry := b == Biome.DESERT or b == Biome.MESA
	var paint: Array[Color] = [Color(0.92, 0.9, 0.82), Color(0.75, 0.82, 0.9), Color(0.95, 0.85, 0.6), Color(0.8, 0.9, 0.75), Color(0.9, 0.7, 0.65)]
	var brick: Array[Color] = [Color(0.6, 0.32, 0.24), Color(0.72, 0.62, 0.48), Color(0.5, 0.42, 0.4), Color(0.78, 0.7, 0.55)]
	var awning: Array[Color] = [Color(0.75, 0.15, 0.12), Color(0.15, 0.4, 0.3), Color(0.2, 0.3, 0.6), Color(0.85, 0.65, 0.2)]
	var base := centre_of(_chunk)
	# The police station on one corner of the crossing
	var station := base + Vector3(13.0, 0, 13.0)
	_prop("police_station", station, PI)
	_take(station, 8.0)
	for qx: float in [-1.0, 1.0]:
		for qz: float in [-1.0, 1.0]:
			# (the town square takes this corner)
			if qx < 0.0 and qz > 0.0:
				continue
			for i in 2:
				var p := base + Vector3(qx * (9.0 + i * 9.5), 0, qz * _rng.randf_range(9.0, 16.0))
				var turn := PI / 2 * -qx
				if not _clear(p, 4.5):
					continue
				if i == 0:
					_prop("storefront", p, turn, 0.9, {"walls": brick[_rng.randi() % brick.size()], "awning": awning[_rng.randi() % awning.size()]})
				elif dry:
					_prop("adobe", p, turn, 0.85)
				else:
					_prop("house", p, turn, 0.9, {"walls": paint[_rng.randi() % paint.size()]})
				_take(p, 5.0)
	if b != Biome.MOUNTAIN and _clear(base + Vector3(-12, 0, -9), 5.0):
		_prop("diner", base + Vector3(-12, 0, -9), PI / 2)
		_take(base + Vector3(-12, 0, -9), 7.0)
	if _clear(base + Vector3(12, 0, -9), 3.0):
		if not dry and _rng.randf() < 0.6:
			_prop("clock_tower", base + Vector3(12, 0, -9), PI)
		elif _rng.randf() < 0.6:
			_prop("water_tower", base + Vector3(12, 0, -9))
	# The town square on one corner: paved, a fountain in the middle, trees, and the city hall on its
	# far side looking over it
	var square := base + Vector3(-12.5, 0, 10.0)
	Ps1.part(_node, BoxMesh.new(), Ps1.flat(Color(0.5, 0.48, 0.45)), square + Vector3(0, 0.04, 0), Vector3(13.0, 0.08, 11.0))
	_prop("fountain", square, 0.0, 0.8)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_plant("tree", 0.6, 0.8, square + Vector3(corner.x * 5.2, 0, corner.y * 4.2))
	_take(square, 7.5)
	var hall := base + Vector3(-12.5, 0, 20.0)
	_prop("city_hall", hall, PI, 0.72)
	_take(hall, 6.0)
	for i in _rng.randi_range(7, 11):
		_spawn("person", base + Vector3(_rng.randf_range(-16, 16), 0, _rng.randf_range(-16, 16)))
	if _rng.randf() < 0.5:
		_spawn("believer", base + Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-14, 14)))
	_sidewalks("z")
	for i in _rng.randi_range(6, 10):
		_plant("bush", 0.6, 1.0, Vector3.INF, 1.0)
	_sidewalks("x")


## Sidewalks along both sides of the road through this chunk that runs along `axis` (in a town, and
## on the roads out of it): pale concrete kerbs a step up, broken where the other road crosses
func _sidewalks(axis: String) -> void:
	var base := centre_of(_chunk)
	var half := road_half(dirt_x(_chunk.x) if axis == "z" else dirt_z(_chunk.y))
	var crossing := has_road(_chunk.x) and has_road(_chunk.y)
	var paving := Ps1.flat(Color(0.62, 0.61, 0.58))
	for i in 8:
		var along := -CHUNK * 0.5 + 3.0 + i * 6.0
		if crossing and absf(along) < half + 2.5:
			continue
		for side: float in [-1.0, 1.0]:
			var at: Vector3
			var size: Vector3
			if axis == "z":
				at = Vector3(road_x(_chunk.x, base.z + along) + side * (half + 0.9), 0.06, base.z + along)
				size = Vector3(1.6, 0.12, 6.05)
			else:
				at = Vector3(base.x + along, 0.06, road_z(_chunk.y, base.x + along) + side * (half + 0.9))
				size = Vector3(6.05, 0.12, 1.6)
			Ps1.part(_node, BoxMesh.new(), paving, at, size)
			# (street lights along the outer edge every other slab, their arms out over the road; a
			# bench and a trash can here and there)
			var edge := at + (Vector3(side * 0.55, -0.06, 0) if axis == "z" else Vector3(0, -0.06, side * 0.55))
			var to_road := -PI / 2 * side if axis == "z" else (PI if side > 0.0 else 0.0)
			if i % 2 == 0:
				_plant_at("street_light", edge, to_road)
			elif i == 3 or i == 5 and side < 0.0:
				_plant_at("bench", edge, to_road)
				_plant_at("trash_can", edge + (Vector3(0, 0, 1.6) if axis == "z" else Vector3(1.6, 0, 0)), 0.0)


## Animals out where nobody lives, and birds over everything
func _wildlife(b: int) -> void:
	match b:
		Biome.MOUNTAIN:
			if _rng.randf() < 0.35:
				_spawn("bear", _spot(2.0))
			if _rng.randf() < 0.45:
				_herd("mountain_goat", _spot(2.0), _rng.randi_range(2, 4), 6.0)
			if _rng.randf() < 0.4:
				_herd("elk", _spot(3.0), _rng.randi_range(2, 4), 7.0)
		Biome.PLAINS:
			if _rng.randf() < 0.5:
				_herd("pronghorn", _spot(3.0), _rng.randi_range(3, 5), 8.0)
			if _rng.randf() < 0.5:
				_herd("rabbit", _spot(1.0), _rng.randi_range(1, 3), 6.0)
		Biome.DESERT, Biome.MESA:
			if _rng.randf() < 0.45:
				_herd("rabbit", _spot(1.0), _rng.randi_range(1, 2), 6.0)
			if _rng.randf() < 0.5:
				_herd("roadrunner", _spot(1.0), _rng.randi_range(1, 2), 6.0)
		Biome.FARM:
			if _rng.randf() < 0.3:
				_herd("rabbit", _spot(1.0), _rng.randi_range(1, 2), 6.0)
	if _rng.randf() < (0.45 if b == Biome.FARM else 0.25):
		_herd("crow", _spot(1.0), _rng.randi_range(3, 5), 5.0)
	if _rng.randf() < 0.3:
		_spawn("hawk", _spot(1.0))


## Now and then something worth a great deal: a golden cow, a jackalope, Bigfoot, a meteorite, a satellite
func _rare(c: Vector2i, b: int) -> void:
	# (and, rarer, another saucer that came down long ago, to be found and taken home)
	if hash3(c.x, c.y, 58) < 0.012:
		_spawn("crash_site", _spot(5.0))
	if hash3(c.x, c.y, 55) > 0.03:
		return
	var kind: String = {Biome.FARM: "golden_cow", Biome.PLAINS: "jackalope", Biome.MOUNTAIN: "sasquatch",
		Biome.DESERT: "meteorite", Biome.MESA: "meteorite"}[b]
	if hash3(c.x, c.y, 56) < 0.3:
		kind = "satellite"
	_spawn(kind, _spot(3.0))


## The telephone poles along a road through this chunk, every 16 m on one side, wired to the next
func _phone_line(c: Vector2i, axis: String) -> void:
	if game == null:
		return
	var base := centre_of(c)
	for k in [-1, 0, 1]:
		var at: Vector3
		var next: Vector3
		if axis == "z":
			var z: float = base.z + k * 16.0
			at = Vector3(road_x(c.x, z) + 4.5, 0, z)
			next = Vector3(road_x(c.x, z + 16.0) + 4.5, 0, z + 16.0)
		else:
			var x: float = base.x + k * 16.0
			at = Vector3(x, 0, road_z(c.y, x) - 4.5)
			next = Vector3(x + 16.0, 0, road_z(c.y, x + 16.0) - 4.5)
		# (none standing in the other road where two cross)
		if has_road(c.x) and has_road(c.y) and (absf(at.x - base.x) < 5.0 and absf(at.z - base.z) < 5.0):
			continue
		game.spawn_later("phone_pole", at, {"turn": 0.0, "chunk": c, "wire_to": next})
	# Now and then a substation beside the road, off the poles' side, a pole wired across to it
	if not (has_road(c.x) and has_road(c.y)) and hash3(c.x, c.y, 81 if axis == "z" else 82) < 0.14:
		var yard: Vector3
		var feed: Vector3
		if axis == "z":
			yard = Vector3(road_x(c.x, base.z + 8.0) + 12.0, 0, base.z + 8.0)
			feed = Vector3(road_x(c.x, base.z + 8.0) + 4.5, 0, base.z + 8.0)
		else:
			yard = Vector3(base.x + 8.0, 0, road_z(c.y, base.x + 8.0) - 12.0)
			feed = Vector3(base.x + 8.0, 0, road_z(c.y, base.x + 8.0) - 4.5)
		if _clear(yard, 5.0):
			_take(yard, 6.0)
			_prop("substation", yard, PI / 2 if axis == "z" else 0.0)
			game.spawn_later("phone_pole", feed, {"turn": 0.0, "chunk": c, "wire_to": yard})
	# Road signs: now and then a stop sign across from the poles; and on the way into a crossing of
	# paved roads, a big green highway sign
	var line_n := c.x if axis == "z" else c.y
	var cross_n := c.y if axis == "z" else c.x
	if hash3(c.x, c.y, 301 if axis == "z" else 302) < 0.35:
		if axis == "z":
			_plant_at("road_sign", Vector3(road_x(c.x, base.z - 10.0) - 4.2, 0, base.z - 10.0), PI / 2)
		else:
			_plant_at("road_sign", Vector3(base.x - 10.0, 0, road_z(c.y, base.x - 10.0) + 4.2), PI)
	var dirt := dirt_x(line_n) if axis == "z" else dirt_z(line_n)
	if not dirt and posmod(cross_n, ROAD_EVERY) in [1, ROAD_EVERY - 1] and hash3(c.x, c.y, 303) < 0.7:
		var facing := PI if posmod(cross_n, ROAD_EVERY) == ROAD_EVERY - 1 else 0.0
		if axis == "z":
			_plant_at("highway_sign", Vector3(road_x(c.x, base.z + 14.0) + 7.5, 0, base.z + 14.0), facing)
		else:
			_plant_at("highway_sign", Vector3(base.x + 14.0, 0, road_z(c.y, base.x + 14.0) - 7.5), facing + PI / 2)
	# A phone booth across the road from the poles, mostly, its door to the road
	if hash3(c.x, c.y, 133 if axis == "z" else 134) < 0.6:
		if axis == "z":
			game.spawn_later("phone_booth", Vector3(road_x(c.x, base.z + 8.0) - 4.0, 0, base.z + 8.0), {"turn": PI / 2, "chunk": c})
		else:
			game.spawn_later("phone_booth", Vector3(base.x + 8.0, 0, road_z(c.y, base.x + 8.0) + 4.0), {"turn": PI, "chunk": c})


func _car(b: int, axis: String) -> void:
	var kinds := ["car", "car", "pickup"]
	if b == Biome.DESERT or b == Biome.MESA:
		kinds = ["car", "pickup", "rv"]
	elif b == Biome.FARM:
		kinds = ["car", "pickup", "pickup"]
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var base := centre_of(_chunk)
	var along := _rng.randf_range(-20, 20)
	var at := Vector3(road_x(_chunk.x, base.z + along) + 1.5 * dir, 0, base.z + along) if axis == "z" else Vector3(base.x + along, 0, road_z(_chunk.y, base.x + along) - 1.5 * dir)
	if game != null:
		game.spawn_car(kinds[_rng.randi() % kinds.size()], at, axis, dir)


## The railway through a chunk: a bed of grey gravel right across it, the rails on their sleepers
## laid along it
func _rail_line(c: Vector2i) -> void:
	var z := rail_z(c.y)
	var x0 := c.x * CHUNK
	Ps1.part(_node, BoxMesh.new(), Ps1.flat(Color(0.36, 0.35, 0.34)), Vector3(x0, 0.03, z), Vector3(CHUNK, 0.06, 3.6))
	for i in 6:
		_put("track", Vector3(x0 - CHUNK * 0.5 + 4.0 + i * 8.0, 0.06, z))


## Whether an airfield is out here: now and then, in open country away from where the game starts
static func airfield(c: Vector2i) -> bool:
	return not has_rail(c.y) and maxi(absi(c.x), absi(c.y)) > 3 and biome(c) in [Biome.FARM, Biome.PLAINS, Biome.DESERT] and hash3(c.x, c.y, 143) < 0.025


## A little airfield: a runway across the chunk, a control tower and a hangar beside it, and a few
## prop planes parked
func _airfield() -> void:
	var base := centre_of(_chunk)
	var turn := PI / 2 if _rng.randf() < 0.5 else 0.0
	var basis := Basis(Vector3.UP, turn)
	_put("runway", base, turn)
	for k in range(-4, 5):
		_take(base + basis * Vector3(0, 0, k * 9.0), 6.0)
	var tower := base + basis * Vector3(14, 0, -12)
	_prop("control_tower", tower, turn)
	_take(tower, 4.0)
	var shed := base + basis * Vector3(15, 0, 8)
	if _clear(shed, 7.0):
		_prop("hangar", shed, turn - PI / 2, 0.7)
		_take(shed, 8.0)
	for i in _rng.randi_range(2, 3):
		var at := base + basis * Vector3(-10.0, 0, -12.0 + i * 11.0)
		if _clear(at, 4.0):
			_prop("plane", at, turn + PI / 2 + _rng.randf_range(-0.3, 0.3))
			_take(at, 4.5)
	_herd("person", base + basis * Vector3(10, 0, 0), _rng.randi_range(1, 3), 6.0)
	_herd("barrel", base + basis * Vector3(13, 0, -4), _rng.randi_range(3, 5), 2.0)


## A lake, dark under the moon, with reeds and trees round its shore
func _lake() -> void:
	var r := _rng.randf_range(10.0, 15.0)
	var at := _spot(r + 2.0)
	if at == Vector3.INF:
		return
	_take(at, r + 2.0)
	_water(at, r)
	for i in _rng.randi_range(5, 9):
		var shore := _ring_spot(at, r + 1.0, r + 4.0)
		if _clear(shore, 1.2):
			_plant("tree" if _rng.randf() < 0.6 else "pine", 0.7, 1.1, shore)


## Water, `r` across, at `at`: a lake, or a park's pond
func _water(at: Vector3, r: float) -> void:
	lakes[_chunk] = Vector3(at.x, at.z, r)
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.06
	disc.radial_segments = 28
	disc.rings = 1
	water.mesh = disc
	var m := ShaderMaterial.new()
	m.shader = WATER
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.extra_cull_margin = Ps1.CULL_MARGIN
	water.visibility_range_end = Ps1.DRAW_TO
	water.position = at + Vector3(0, 0.04, 0)
	_node.add_child(water)


# ------------------------------------------------------------------ places out in the country
# Now and then out in the open a place people come to: a schoolhouse, a park with its pond, a
# carnival, a drive-in, a junkyard, a building site, a rodeo (which, by the part of the West); and by
# the roads, gas stations and car dealerships

const VENUES := {
	Biome.FARM: ["school", "park", "carnival", "drive_in", "junkyard"],
	Biome.PLAINS: ["rodeo", "carnival", "drive_in", "junkyard", "school"],
	Biome.DESERT: ["drive_in", "junkyard", "construction", "rodeo"],
	Biome.MESA: ["rodeo", "school", "junkyard", "carnival"],
	Biome.MOUNTAIN: ["park", "construction", "school"],
}
const PAINTS: Array[Color] = [Color(0.75, 0.12, 0.1), Color(0.2, 0.45, 0.75), Color(0.95, 0.95, 0.92), Color(0.15, 0.15, 0.17), Color(0.95, 0.75, 0.15), Color(0.3, 0.55, 0.3)]


## Whether a place went down here (taking the middle of the chunk; the rest filled round it as usual)
func _venue(c: Vector2i, b: int) -> bool:
	if hash3(c.x, c.y, 211) > 0.14 or maxi(absi(c.x - 1), absi(c.y - 1)) < 1:
		return false
	var pick: Array = VENUES[b]
	var name: String = pick[mini(int(hash3(c.x, c.y, 212) * pick.size()), pick.size() - 1)]
	var at := _spot(16.0)
	if at == Vector3.INF:
		return false
	# (the ground it takes, kept from the rest once it is all down: see the end)
	var turn := _rng.randf() * TAU
	var basis := Basis(Vector3.UP, turn)
	match name:
		"school":
			_prop("schoolhouse", at + basis * Vector3(-4, 0, 0), turn)
			_prop("playground", at + basis * Vector3(7, 0, 3), turn)
			_herd("person", at + basis * Vector3(6, 0, -3), _rng.randi_range(3, 6), 5.0)
		"park":
			_water(at + basis * Vector3(4, 0, 2), _rng.randf_range(5.0, 7.0))
			_prop("gazebo", at + basis * Vector3(-9, 0, -6), turn)
			for i in 3:
				var a := turn + i * 1.4
				_prop("bench", at + basis * Vector3(4, 0, 2) + Vector3(sin(a), 0, cos(a)) * 9.0, a + PI)
			for i in 8:
				_plant("tree", 0.7, 1.1, _ring_spot(at, 12.0, 15.0))
			# (lamp posts round the pond, a trash can, and bushes)
			for i in 4:
				var a := turn + i * TAU / 4.0 + 0.4
				_plant_at("lamp_post", at + basis * Vector3(4, 0, 2) + Vector3(sin(a), 0, cos(a)) * 8.0, 0.0)
			_plant_at("trash_can", at + basis * Vector3(-6, 0, -3), 0.0)
			for i in 6:
				_plant("bush", 0.7, 1.1, _ring_spot(at, 9.0, 14.0))
			_herd("person", at + basis * Vector3(-6, 0, 6), _rng.randi_range(2, 5), 6.0)
		"carnival":
			_prop("ferris_wheel", at + basis * Vector3(-8, 0, -5), turn)
			_prop("carousel", at + basis * Vector3(7, 0, -7), turn)
			_prop("circus_tent", at + basis * Vector3(6, 0, 7), turn + PI)
			for i in 3:
				_prop("booth", at + basis * Vector3(-10 + i * 3.6, 0, 8), turn + PI)
			_herd("person", at, _rng.randi_range(6, 10), 9.0)
		"drive_in":
			_prop("screen", at + basis * Vector3(0, 0, -11), turn)
			for row in 3:
				for i in 4:
					var spot := at + basis * Vector3(-7.5 + i * 5.0, 0, -2.0 + row * 5.0)
					if _rng.randf() < 0.75:
						_prop("lot_car", spot, turn + PI + _rng.randf_range(-0.1, 0.1), 1.0, {"paint": PAINTS[_rng.randi() % PAINTS.size()]})
					_prop("speaker_post", spot + basis * Vector3(1.6, 0, 0), turn)
		"junkyard":
			_pen(at, turn, 8, 6)
			for i in _rng.randi_range(5, 8):
				_prop("junk_car", _near(at, 9.0, 1.5), _rng.randf() * TAU, 1.0)
			for i in _rng.randi_range(2, 3):
				_prop("scrap_pile", _near(at, 8.0, 2.5), _rng.randf() * TAU)
			for i in _rng.randi_range(3, 6):
				_prop("tire_stack", _near(at, 10.0, 0.8), _rng.randf() * TAU)
		"construction":
			_prop("crane", at + basis * Vector3(-7, 0, -6), turn)
			_prop("excavator", at + basis * Vector3(5, 0, -3), turn + 2.0)
			_prop("mixer", at + basis * Vector3(7, 0, 7), turn + PI / 2)
			_prop("girders", at + basis * Vector3(-5, 0, 6), turn)
			_herd("person", at, _rng.randi_range(2, 4), 6.0)
		"rodeo":
			# (a ring of fence, bleachers either side, riders and a bull in it)
			for i in 18:
				var a := i / 18.0 * TAU
				_plant_at("fence", at + Vector3(sin(a), 0, cos(a)) * 8.5, a + PI / 2)
			_prop("bleachers", at + basis * Vector3(0, 0, -12.5), turn + PI)
			_prop("bleachers", at + basis * Vector3(0, 0, 12.5), turn)
			_herd("rider", at, _rng.randi_range(2, 3), 4.0)
			_herd("longhorn", at, 1, 3.0)
			_herd("person", at + basis * Vector3(0, 0, 14.5), _rng.randi_range(3, 5), 4.0)
			_herd("person", at + basis * Vector3(0, 0, -14.5), _rng.randi_range(3, 5), 4.0)
	# (and, at any of them, now and then a true believer, hoping)
	if _rng.randf() < 0.3:
		_spawn("believer", _near(at, 10.0, 0.5))
	_take(at, 16.0)
	return true


## Beside a road through this chunk now and then: a gas station, or a car dealership with its lot of
## cars and its wacky waving inflatable tube men; facing the road
func _roadside(c: Vector2i, axis: String) -> void:
	if hash3(c.x, c.y, 213) > 0.22:
		return
	var base := centre_of(c)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var at: Vector3
	var turn: float
	if axis == "z":
		at = Vector3(road_x(c.x, base.z + 6.0) + side * 15.0, 0, base.z + 6.0)
		turn = -PI / 2 * side
	else:
		at = Vector3(base.x + 6.0, 0, road_z(c.y, base.x + 6.0) + side * 15.0)
		turn = PI if side > 0.0 else 0.0
	if not _clear(at, 9.0):
		return
	var basis := Basis(Vector3.UP, turn)
	if hash3(c.x, c.y, 214) < 0.5:
		_prop("gas_station", at, turn)
		_prop("tube_man", at + basis * Vector3(5.5, 0, 3.0), turn)
		if _rng.randf() < 0.6:
			_prop("lot_car", at + basis * Vector3(1.8, 0, -0.5), turn + PI / 2, 1.0, {"paint": PAINTS[_rng.randi() % PAINTS.size()]})
	else:
		_prop("dealership", at + basis * Vector3(0, 0, -4.0), turn)
		for row in 2:
			for i in 3:
				_prop("lot_car", at + basis * Vector3(-5.0 + i * 5.0, 0, 2.5 + row * 4.5), turn + 0.5, 1.0, {"paint": PAINTS[_rng.randi() % PAINTS.size()]})
		_prop("tube_man", at + basis * Vector3(-7.5, 0, 7.0), turn)
		_prop("tube_man", at + basis * Vector3(7.5, 0, 7.0), turn)
	_herd("person", at + basis * Vector3(0, 0, 4.0), _rng.randi_range(1, 2), 3.0)
	_take(at, 10.0)


## The nearest point in the middle of a road to `p`, and which way that road runs ("z" or "x")
func nearest_road(p: Vector3) -> Array:
	var n := roundi(p.x / (CHUNK * ROAD_EVERY)) * ROAD_EVERY
	var m := roundi(p.z / (CHUNK * ROAD_EVERY)) * ROAD_EVERY
	var on_z := Vector3(road_x(n, p.z), 0, p.z)
	var on_x := Vector3(p.x, 0, road_z(m, p.x))
	return [on_z, "z"] if on_z.distance_to(p) < on_x.distance_to(p) else [on_x, "x"]


# ------------------------------------------------------------------ the fields
# Out in farm country each chunk is one field, fenced along its edges: pasture (where the farms,
# lakes and hills are), wheat, corn, pumpkins, ploughed earth, or young green crops. The ground is
# painted for it (the green of `_biome_img`, see shaders/ground.gdshader), and a field of a crop
# has rows of it right across (see `_crops`).

enum Field { NONE, PASTURE, WHEAT, CORN, PUMPKIN, PLOUGHED, GREEN }


static func field(c: Vector2i) -> int:
	if biome(c) != Biome.FARM or is_town(c) or is_edge_of_town(c) or facility(c) != "" or is_base(c) or airfield(c):
		return Field.NONE
	# (corn under the ship where the game starts, and pasture round it, for a farm to be seen at once)
	if c == chunk_of(START):
		return Field.CORN
	if maxi(absi(c.x), absi(c.y)) <= 1:
		return Field.PASTURE
	var h := hash3(c.x, c.y, 151)
	if h < 0.3:
		return Field.PASTURE
	if h < 0.5:
		return Field.WHEAT
	if h < 0.65:
		return Field.CORN
	if h < 0.75:
		return Field.PUMPKIN
	if h < 0.9:
		return Field.PLOUGHED
	return Field.GREEN


## Which way a field's rows run: across x (true) or along z
static func rows_across(c: Vector2i) -> bool:
	return hash3(c.x, c.y, 152) < 0.5


## People out in the country at night: campers round their tents, hikers in the hills, and now
## and then a stargazer at a telescope (who gives the ship away if it lingers in their sky)
func _country_folk(c: Vector2i, b: int) -> void:
	var wild := b != Biome.FARM or field(c) == Field.PASTURE
	if not wild:
		return
	# (cowboys out on horseback; and now and then a true believer, waiting to be taken)
	if b in [Biome.MOUNTAIN, Biome.PLAINS] and _rng.randf() < 0.25:
		_herd("hunter", _spot(2.0), _rng.randi_range(1, 2), 5.0)
	if b in [Biome.PLAINS, Biome.MESA] and _rng.randf() < 0.3:
		_herd("rider", _spot(2.0), _rng.randi_range(1, 3), 7.0)
	if _rng.randf() < 0.08:
		_spawn("believer", _spot(1.0))
	if b != Biome.FARM and hash3(c.x, c.y, 161) < 0.09:
		var at := _spot(6.0)
		if at != Vector3.INF:
			_take(at, 6.0)
			_prop("camp_tent", at, _rng.randf() * TAU)
			if _rng.randf() < 0.5:
				_prop("camp_tent", at + Vector3(3.5, 0, 1.5), _rng.randf() * TAU)
			_herd("camper", at + Vector3(0, 0, 3.0), _rng.randi_range(2, 3), 3.0)
	if b == Biome.MOUNTAIN and _rng.randf() < 0.4 or b == Biome.PLAINS and _rng.randf() < 0.12:
		_herd("hiker", _spot(2.0), _rng.randi_range(1, 2), 4.0)
	if hash3(c.x, c.y, 162) < 0.07:
		var at := _spot(3.0)
		if at != Vector3.INF:
			_take(at, 3.0)
			var turn := _rng.randf() * TAU
			_prop("telescope", at, turn)
			_spawn("stargazer", at + Basis(Vector3.UP, turn) * Vector3(0.8, 0, -0.6))
