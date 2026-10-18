class_name Arena
extends Node3D
## THE ARENA (ARENA on the title, by PLAY, HOST and JOIN): drop in to a room of up to twelve saucers on a
## carnival the aliens have set up on the moon, a round crater ringed with a padded bumper rail, and
## beam up what lies about (astronauts, tourists in bubble helmets, buggies, landers, moon bases, dishes,
## solar panels, flags, moon rocks and glowing gems) for the top spot, as in agar.io. The more taken, the
## bigger the saucer and its beam, and the stronger (a bigger saucer lifts heavier things), but the slower.
## The saucers knock each other about like bumper cars, a dash into one hurts it, the weapons hurt them,
## and a saucer half as big again as another can beam it up whole. Shot down, a saucer drops a share of
## its score as LOST LOOT for anyone to take, and comes back small at the rim a few seconds later.
##
## Everything lying about is laid out alike on every device from the arena's seed (ArenaNet), and comes
## back on a clock (`_refresh`); what matters is who took it first, and the server says that (`claimed`).
## Each device flies its own saucer and streams it to the rest (K_STATE); the others are drawn as
## RemoteSaucers, with an unseen stand-in under each (an "arena_foe" Thing) for the weapons to aim at
## (main.gd `weapon_hit` sends the hit to its owner, K_HIT, who takes the damage).

## The padded rail round the floor (the floor rises to it), and where the saucers come in
const R := 40.0
const SPAWN_R := 31.0
## Packets: a saucer's state, a hit on another, shot down, its lost loot, beamed up by a bigger one
const K_STATE := 1
const K_HIT := 2
const K_DOWN := 3
const K_LOOT := 4
const K_EAT := 5
const SEND_EVERY := 1.0 / 15.0
## Shield taken from a saucer by a laser hit's worth of anything
const PVP_HIT := 9.0
## A dash into another saucer: this many laser hits' worth
const RAM_HIT := 1.6
const RESPAWN := 3.0
## Untouchable this long after coming back
const SAFE := 3.0
## The share of its score a saucer drops as loot when shot down (and how much of that is a gem's worth)
const LOOT_SHARE := 0.4
const LOOT_MOST := 8
## Ids from here up are lost loot (DROP_BASE + seat * 2^20 + count), below are the arena's own things
const DROP_BASE := 1 << 30
## The growth: up to GROW_MOST bigger again, most of it by GROW_SCORE
const GROW_SCORE := 40000.0
const GROW_MOST := 1.6
## A saucer this many times bigger than another beams it up whole, held under the beam this long
const EAT_RATIO := 1.45
const EAT_HOLD := 1.4
## What lies about: [kind, how many, seconds before one taken comes back]
const LAYOUT := [["arena_rock_small", 12, 22.0], ["arena_flag", 4, 30.0], ["arena_gem_pink", 3, 30.0], ["arena_gem_blue", 3, 30.0],
	["arena_gem_green", 3, 30.0], ["arena_gem_gold", 2, 45.0], ["arena_astronaut", 7, 25.0], ["arena_tourist", 8, 25.0],
	["arena_solar", 4, 40.0], ["arena_rock_big", 4, 40.0], ["arena_snack_cart", 3, 40.0], ["arena_rover", 4, 40.0],
	["arena_dish", 3, 45.0], ["arena_booth", 2, 60.0], ["arena_lander", 2, 70.0], ["arena_habitat", 2, 80.0]]
## Names the pilots go by on the board
const NAME_BITS := ["ZORP", "BLIX", "GLOR", "VEX", "QUIB", "SNORK", "FLUM", "KRIX", "MOOP", "ZAZ", "PLUX", "NIBB"]

var main: Node
var net: ArenaNet
## In the arena, flying (or down, waiting to come back)
var on := false
var _joining := false
var pilot_name := ""
## The places things lie: [kind, where, every, phase] and what is at each now (a Thing or null)
var _points: Array = []
var _here: Array = []
## Who took each thing (by its number) first, as the server says; and things of ours up the beam
## before it said, with what they are worth: id -> [kind, points]
var claimed := {}
var _pending := {}
var _by_id := {}
var _refresh_wait := 0.0
## The others: slot -> {saucer, proxy, score, grow, down, safe, heard, hero}
var remotes := {}
## How much bigger our saucer is for its score, and when that was last put on the ship
var grow := 1.0
var _grow_set := 1.0
var _send_wait := 0.0
var _score_wait := 0.0
var _reported := -1
## Seconds since our saucer went down (-1 while flying), the seconds left untouchable, and who hit us last
var down_for := -1.0
var safe := 0.0
var _last_hit_by := -1
var _drops := 0
var _eat_hold := {}
var _bump_wait := 0.0
var _rail_wait := 0.0
## The standings: [{slot, name, score}], the leader's seat (-1 none)
var top: Array = []
var leader := -1
var _map: Node3D
var _earth: MeshInstance3D
var _crown: Node3D
var _board: Label
var _panel: Control
var _panel_text: Label


func _ready() -> void:
	net = ArenaNet.new()
	add_child(net)
	net.joined_arena.connect(_on_joined)
	net.claimed.connect(_on_claimed)
	net.standings.connect(_on_top)
	net.packet.connect(_on_packet)
	net.player_left.connect(_on_left)
	net.failed.connect(_on_failed)
	net.closed.connect(_on_closed)


# ------------------------------------------------------------------ joining and leaving

## ARENA pressed on the title: a word while the server is asked, then in we go
func join() -> void:
	if _joining or on:
		return
	_joining = true
	var r := RandomNumberGenerator.new()
	r.randomize()
	pilot_name = "%s%s-%d" % [NAME_BITS[r.randi() % NAME_BITS.size()], NAME_BITS[r.randi() % NAME_BITS.size()].substr(0, 2), r.randi_range(1, 99)]
	_say("JOINING THE ARENA...", false)
	net.join(pilot_name, main.ship)


func _on_joined() -> void:
	if on:
		# (back after the connection dropped: what was taken while away is in what came with it)
		return
	_joining = false
	_hide_panel()
	begin()


func _on_failed(message: String) -> void:
	if _joining:
		_joining = false
		_say(message.to_upper(), true)


func _on_closed(reason: String) -> void:
	_joining = false
	if on:
		leave()
		main._heat_note("LOST THE ARENA" if reason != "replaced" else "PLAYING IN ANOTHER WINDOW", 3.0)


## Into the arena: the moon's carnival made, the ship put down at the rim, everything laid out
func begin() -> void:
	main.start_arena()
	on = true
	grow = 1.0
	_grow_set = 0.0
	down_for = -1.0
	safe = SAFE
	_reported = -1
	_drops = 0
	_build_map()
	_lay_out(net.seed)
	_put_at_rim()
	_refresh(net.arena_time())


## Out of the arena and back to the title (LEAVE ARENA in the pause, or the connection lost)
func leave() -> void:
	if not on and not _joining:
		return
	on = false
	_joining = false
	net.leave()
	for s in remotes.keys():
		_drop_remote(s)
	for t in _here:
		if t != null and is_instance_valid(t):
			t.set_meta("arena_gone", true)
	for t: Thing in main.things.duplicate():
		if t.kind.begins_with("arena_"):
			t.set_meta("arena_gone", true)
			t.set_meta("arena_free", true)
			main._remove(t)
	_here.clear()
	_points.clear()
	claimed.clear()
	_pending.clear()
	_by_id.clear()
	top.clear()
	leader = -1
	if _map != null:
		_map.queue_free()
		_map = null
	_earth = null
	_crown = null
	if _board != null:
		_board.visible = false
	_hide_panel()
	main.end_arena()


# ------------------------------------------------------------------ the moon's carnival

func _build_map() -> void:
	if _map != null:
		_map.queue_free()
	_map = Node3D.new()
	add_child(_map)
	var regolith := ShaderMaterial.new()
	regolith.shader = load("res://shaders/moon.gdshader")
	for name: String in ["arena_floor", "arena_rim"]:
		var m := Ps1.model(name)
		_map.add_child(m)
		if name == "arena_floor":
			for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
				mi.material_override = regolith
	# (the moon out beyond the rim, rolling away over the bend)
	var plain := PlaneMesh.new()
	plain.size = Vector2(520, 520)
	plain.subdivide_width = 64
	plain.subdivide_depth = 64
	var outside := Ps1.part(_map, plain, regolith, Vector3(0, -0.05, 0))
	outside.extra_cull_margin = 200.0
	# The carnival round the rim: the arch facing the way the camera looks in, the Ferris wheel and the
	# rocket tower behind, tents, string lights all round, bumper posts on the rail
	var dress := [["arena_arch", -PI * 0.5, 49.0], ["arena_ferris", -PI * 0.5 - 0.75, 50.0], ["arena_rocket_tower", -PI * 0.5 + 0.8, 48.0],
		["arena_tent", -PI * 0.5 + 1.6, 47.0], ["arena_tent", -PI * 0.5 - 1.6, 47.0], ["arena_tent", PI * 0.5 + 0.9, 47.0],
		["arena_tent", PI * 0.5 - 0.9, 47.0], ["arena_booth", PI * 0.5, 46.0]]
	for d: Array in dress:
		var a: float = d[1]
		var at := Vector3(cos(a), 0, sin(a)) * float(d[2])
		var n := Ps1.model(d[0])
		n.position = at
		n.rotation.y = atan2(-at.x, -at.z)
		_map.add_child(n)
	var poles: Array = []
	for i in 12:
		var a := i * TAU / 12.0 + 0.13
		var at := Vector3(cos(a), 0, sin(a)) * (R + 3.2)
		poles.append(Transform3D(Basis(Vector3.UP, atan2(-at.x, -at.z)), at))
	_multi("arena_lights", poles)
	var posts: Array = []
	for i in 16:
		var a := i * TAU / 16.0
		var at := Vector3(cos(a), 0, sin(a)) * (R - 0.6)
		posts.append(Transform3D(Basis(Vector3.UP, atan2(-at.x, -at.z)), at + Vector3(0, 1.3, 0)))
	_multi("arena_bumper_post", posts)
	# Earth hanging in the black (kept far off along one way as the camera moves: see `_place_earth`)
	_earth = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 14.0
	ball.height = 28.0
	ball.radial_segments = 40
	ball.rings = 20
	_earth.mesh = ball
	var em := ShaderMaterial.new()
	em.shader = load("res://shaders/earth.gdshader")
	_earth.material_override = em
	_earth.rotation = Vector3(0.4, 0, 0.2)
	_earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_map.add_child(_earth)
	# The leader's crown
	_crown = Node3D.new()
	var gold := Ps1.own(Color(1.0, 0.82, 0.25), 1.6)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.9
	ring.bottom_radius = 0.75
	ring.height = 0.5
	ring.radial_segments = 10
	Ps1.part(_crown, ring, gold, Vector3.ZERO)
	for i in 5:
		var a := i * TAU / 5.0
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.22
		spike.height = 0.6
		spike.radial_segments = 4
		Ps1.part(_crown, spike, gold, Vector3(cos(a) * 0.8, 0.5, sin(a) * 0.8))
	_crown.visible = false
	_map.add_child(_crown)


func _multi(name: String, where: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Ps1.model_mesh(name)
	mm.instance_count = where.size()
	for i in where.size():
		mm.set_instance_transform(i, where[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = Ps1.CULL_MARGIN
	_map.add_child(mmi)


func _place_earth() -> void:
	if _earth == null:
		return
	var cam: Camera3D = main.camera
	# (high in the picture, to one side, whatever the screen's shape)
	var view: Vector2 = cam.get_viewport().get_visible_rect().size
	_earth.global_position = cam.project_position(Vector2(view.x * (0.72 if view.y > view.x else 0.56), view.y * (0.2 if view.y > view.x else 0.15)), 180.0)
	_earth.rotate_y(0.0004)


## Where things lie, alike on every device: the arena's seed scatters them over the floor, each kind
## its own number, the big ones kept apart from each other and from the middle a little
func _lay_out(seed_: int) -> void:
	_points.clear()
	_here.clear()
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var taken: Array[Vector3] = []
	var room: Array[float] = []
	for entry: Array in LAYOUT:
		var kind: String = entry[0]
		var size: float = Thing.KINDS[kind]["size"]
		for i in int(entry[1]):
			var at := Vector3.ZERO
			for attempt in 40:
				var a := r.randf() * TAU
				var d := sqrt(r.randf_range(0.02, 1.0)) * (R - 5.0 - size)
				at = Vector3(cos(a) * d, 0, sin(a) * d)
				var clear := true
				for k in taken.size():
					if taken[k].distance_to(at) < (room[k] + size) * 0.75 + 1.2:
						clear = false
						break
				if clear:
					break
			taken.append(at)
			room.append(size)
			_points.append([kind, at, float(entry[2]) * r.randf_range(0.85, 1.15), r.randf() * 100.0, r.randf() * TAU])
			_here.append(null)


## The number of what lies at point `p` now: the point, and how many times it has come back
func _id_at(p: int, t: float) -> int:
	var every: float = _points[p][2]
	var gen := floori((t + float(_points[p][3])) / every)
	return p * 1024 + posmod(gen, 1024)


## What lies about kept as it should be: what someone else took gone, a thing back where its time has
## come round and nobody has taken this one
func _refresh(t: float) -> void:
	for p in _points.size():
		var id := _id_at(p, t)
		var have = _here[p]
		if have != null and (not is_instance_valid(have) or (have as Thing).state == "gone"):
			have = null
			_here[p] = null
		if have != null:
			var thing: Thing = have
			var was := int(thing.get_meta("arena_id", -1))
			if was != id and thing.state == "walk" and not thing.has_meta("claiming"):
				# (still lying there when its time came round again: the same thing, by its new number)
				_by_id.erase(was)
				thing.set_meta("arena_id", id)
				_by_id[id] = thing
			continue
		if claimed.has(id):
			continue
		var made: Thing = main.spawn(_points[p][0], _points[p][1], {"turn": float(_points[p][4])})
		made.set_meta("arena_id", id)
		_by_id[id] = made
		_here[p] = made
		if made.info["move"] == "still":
			# (out of the ground with a puff, as if it had always been there)
			made.model.scale = Vector3.ONE * 0.05
			var tw := made.create_tween()
			tw.tween_property(made.model, "scale", Vector3.ONE * made.base_size, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_claimed(id: int, slot: int) -> void:
	claimed[id] = slot
	if claimed.size() > 30000:
		claimed.clear()
	if slot == net.slot:
		if _pending.has(id):
			var got: Array = _pending[id]
			_pending.erase(id)
			_scored(got[0], int(got[1]))
		return
	# (someone else had it first: gone from here, even out of our beam)
	_pending.erase(id)
	var t = _by_id.get(id)
	_by_id.erase(id)
	if t == null or not is_instance_valid(t) or (t as Thing).state == "gone":
		return
	var thing: Thing = t
	if thing.state == "lifted":
		main._popup("SNATCHED", thing.position + Vector3(0, 1.5, 0), Color(1.0, 0.5, 0.4))
	main.puff(thing.position + Vector3(0, 0.5, 0), Color(0.75, 0.74, 0.72, 0.7), 0.8)
	thing.set_meta("arena_gone", true)
	main._remove(thing)


## Something of the arena's in our beam: ask for it
func grabbed(t: Thing) -> void:
	if not t.has_meta("arena_id") or t.has_meta("claiming"):
		return
	t.set_meta("claiming", true)
	net.claim(int(t.get_meta("arena_id")))


## Something of the arena's swallowed: ours if the server says so (now, or when it does)
func taken(t: Thing) -> void:
	var id := int(t.get_meta("arena_id", -1))
	var worth := int(t.get_meta("loot", 0)) if t.kind == "arena_drop" else t.points()
	if not t.has_meta("claiming"):
		t.set_meta("claiming", true)
		net.claim(id)
	main.ufo.gulp(t.size() * t.base_size * 0.7)
	main.sfx.play("bloop", 1.0 + randf() * 0.2)
	if claimed.get(id, -1) == net.slot:
		_scored(t.kind, worth)
	elif not claimed.has(id):
		_pending[id] = [t.kind, worth]
	_by_id.erase(id)
	t.state = "gone"
	t.queue_free()


## Wrecked by one of our weapons: ours (the first claim wins)
func wrecked(t: Thing) -> void:
	var id := int(t.get_meta("arena_id", -1))
	if id >= 0 and not t.has_meta("claiming"):
		t.set_meta("claiming", true)
		net.claim(id)
	_by_id.erase(id)


func _scored(kind: String, worth: int) -> void:
	main.arena_scored(kind, worth)
	if kind == "arena_gem_gold":
		_power_gem()


## A POWER GEM: a weapon not had (while there is a free slot for it), or else another of one had
func _power_gem() -> void:
	var had: Array[String] = main.weapons_had()
	var w := ""
	if had.size() < 2:
		var free: Array[String] = []
		for k: String in main.WEAPONS:
			if not k in had:
				free.append(k)
		w = free[randi() % free.size()]
		main._got.append(w)
	else:
		w = had[randi() % had.size()]
	main.upgrades[w] = int(main.upgrades[w]) + 1
	main._apply_upgrades()
	_apply_grow(true)
	main._heat_note("POWER GEM: %s x%d" % [main.UPGRADES[w]["title"], main.upgrades[w]], 2.5)
	main.sfx.play("fanfare", 1.4, -4.0)


# ------------------------------------------------------------------ each frame

func step(delta: float) -> void:
	if not on:
		return
	var ufo: Ufo = main.ufo
	_refresh_wait -= delta
	if _refresh_wait <= 0.0:
		_refresh_wait = 0.25
		_refresh(net.arena_time())
	safe = maxf(safe - delta, 0.0)
	_grow_to(delta)
	_keep_in(ufo, delta)
	_keep_things_in()
	for s in remotes.keys():
		_glide_remote(s, delta)
	_bumper_cars(ufo, delta)
	_eat(ufo, delta)
	_place_earth()
	_crown_on_leader()
	# Ours, to everyone
	_send_wait -= delta
	if _send_wait <= 0.0:
		_send_wait = SEND_EVERY
		_send_state(ufo)
	_score_wait -= delta
	if _score_wait <= 0.0:
		_score_wait = 1.0
		if main.score != _reported:
			_reported = main.score
			net.report_score(main.score)
	_show_board()
	# (the shield flickering while untouchable)
	if safe > 0.0 and not ufo.dead:
		ufo.bubble.visible = fmod(safe, 0.25) < 0.17


func _grow_to(delta: float) -> void:
	var want := 1.0 + GROW_MOST * pow(clampf(float(main.score) / GROW_SCORE, 0.0, 1.0), 0.6)
	grow = lerpf(grow, want, minf(delta * 2.0, 1.0))
	if absf(grow - _grow_set) > 0.03:
		_apply_grow(false)


## The ship as big as its score (`grow`): the hull and the shield, the beam and its reach on the ground,
## heavier things it can lift, slower to steer
func _apply_grow(force: bool) -> void:
	if not force and absf(grow - _grow_set) < 0.03:
		return
	_grow_set = grow
	main.arena_grow = grow
	main._apply_upgrades()
	size_ship(main.ufo, grow)


## A ship (ours or another's) drawn `g` times its size
static func size_ship(u: Ufo, g: float) -> void:
	if u == null or u.body == null:
		return
	var spec: Dictionary = Ufo.SHIPS[u.ship]
	u.body.scale = Vector3.ONE * g
	u.radius = float(spec["radius"]) * g
	u.bubble.scale = Vector3(u.radius + 0.7, u.radius * 0.55 + 0.6, u.radius + 0.7)


## The padded rail: a saucer flying into it bounces back off it, as off a bumper car's
func _keep_in(ufo: Ufo, delta: float) -> void:
	_rail_wait -= delta
	var flat := Vector3(ufo.position.x, 0, ufo.position.z)
	var most := R - 1.0 - ufo.radius * 0.5
	if flat.length() <= most:
		return
	var out := flat.normalized()
	ufo.position.x = out.x * most
	ufo.position.z = out.z * most
	var into := ufo.velocity.dot(out)
	if into > 0.0:
		ufo.velocity -= out * into * 1.9
		ufo.knock = -out * minf(into, 14.0) * 0.6
		if into > 3.0 and _rail_wait <= 0.0:
			_rail_wait = 0.3
			main.sfx.play("bloop", 0.55, -2.0)
			main._shake = maxf(main._shake, 0.12)


## Nothing walks off over the rail
func _keep_things_in() -> void:
	for t in _here:
		if t == null or not is_instance_valid(t) or (t as Thing).state != "walk" or (t as Thing).info["move"] == "still":
			continue
		var thing: Thing = t
		var flat := thing.ground()
		if flat.length() > R - 3.0:
			var p := flat.normalized() * (R - 3.0)
			thing.position.x = p.x
			thing.position.z = p.z


## Saucers that meet bounce apart, the smaller the harder; a dash into one hurts it
func _bumper_cars(ufo: Ufo, delta: float) -> void:
	_bump_wait -= delta
	if ufo.dead:
		return
	for s in remotes:
		var r: Dictionary = remotes[s]
		if r["down"]:
			continue
		var other: Ufo = (r["saucer"] as RemoteSaucer).ufo
		var off := Vector3(ufo.position.x - other.position.x, 0, ufo.position.z - other.position.z)
		var d := off.length()
		var reach := ufo.radius * 0.85 + other.radius * 0.85
		if d >= reach:
			continue
		var out := off / d if d > 0.01 else Vector3.RIGHT
		var theirs := float(r["grow"]) / (grow + float(r["grow"]))
		ufo.position += out * (reach - d) * (0.4 + theirs)
		ufo.velocity += out * (5.0 + 12.0 * theirs)
		ufo.knock = out * (6.0 + 10.0 * theirs)
		if _bump_wait <= 0.0:
			_bump_wait = 0.35
			main.sfx.play("thud", 0.8 + randf() * 0.2, 0.0)
			main.sfx.play("bloop", 0.7, -6.0)
			main._shake = maxf(main._shake, 0.2)
			main.puff((ufo.position + other.position) * 0.5, Color(1.0, 0.9, 0.6, 0.7), 0.7)
			if ufo.dodging() and not r["safe"]:
				_hit(int(s), RAM_HIT, (ufo.position + other.position) * 0.5)
				main._heat_note("RAMMED %s" % net.name_of(int(s)), 1.2)


## A saucer much smaller than ours, held under our beam a moment: beamed up whole
func _eat(ufo: Ufo, delta: float) -> void:
	for s in remotes:
		var r: Dictionary = remotes[s]
		var other: Ufo = (r["saucer"] as RemoteSaucer).ufo
		var under: bool = ufo.beaming and not ufo.dead and not r["down"] and not r["safe"] and grow >= float(r["grow"]) * EAT_RATIO \
			and ufo.in_beam(Vector3(other.position.x, 0.3, other.position.z))
		if not under:
			_eat_hold.erase(s)
			continue
		var held := float(_eat_hold.get(s, 0.0)) + delta
		_eat_hold[s] = held
		if randf() < delta * 8.0:
			main.puff(other.position, Color(0.6, 1.0, 0.7, 0.6), 0.6)
		if held >= EAT_HOLD:
			_eat_hold.erase(s)
			net.send(int(s), K_EAT, PackedByteArray())
			var worth := int(clampf(float(r["score"]) * 0.5, 200.0 * Thing.WORTH, 20000.0))
			_scored("arena_foe", worth)
			main._heat_note("YOU BEAMED UP %s!" % net.name_of(int(s)), 2.5)
			main.sfx.play("fanfare", 1.2, -2.0)


# ------------------------------------------------------------------ the others

func _send_state(ufo: Ufo) -> void:
	var b := StreamPeerBuffer.new()
	b.put_float(ufo.position.x)
	b.put_float(ufo.position.y)
	b.put_float(ufo.position.z)
	b.put_float(ufo.rotation.y + ufo.hull_model.rotation.y)
	b.put_float(ufo.velocity.x)
	b.put_float(ufo.velocity.z)
	var lean := ufo.beam_aim * Ufo.BEAM_REACH
	b.put_float(lean.x)
	b.put_float(lean.y)
	var flags := (1 if ufo.beaming else 0) | (2 if ufo.dead else 0) | (4 if ufo.dodging() else 0) | (8 if safe > 0.0 else 0)
	b.put_u8(flags)
	b.put_u32(maxi(main.score, 0))
	b.put_float(grow)
	b.put_u8(clampi(int(ufo.hull / maxf(ufo.hull_max, 1.0) * 255.0), 0, 255))
	b.put_u8(maxi(Ufo.ORDER.find(main.ship), 0))
	net.send(ArenaNet.BROADCAST, K_STATE, b.data_array)


func _on_packet(from: int, kind: int, data: PackedByteArray) -> void:
	if not on or from == net.slot:
		return
	var b := StreamPeerBuffer.new()
	b.data_array = data
	match kind:
		K_STATE:
			if data.size() < 43:
				return
			var at := Vector3(b.get_float(), b.get_float(), b.get_float())
			var turn := b.get_float()
			var vx := b.get_float()
			var vz := b.get_float()
			var ax := b.get_float()
			var az := b.get_float()
			var flags := b.get_u8()
			var score := b.get_u32()
			var g := b.get_float()
			var hull := b.get_u8() / 255.0
			var hero: String = Ufo.ORDER[clampi(b.get_u8(), 0, Ufo.ORDER.size() - 1)]
			_heard(from, at, turn, Vector3(vx, 0, vz), Vector2(ax, az), flags, score, g, hull, hero)
		K_HIT:
			var power := b.get_float()
			var where := Vector3(b.get_float(), b.get_float(), b.get_float())
			_struck(from, power, where)
		K_DOWN:
			var killer := b.get_8()
			if killer == net.slot:
				var bonus := int(150 * Thing.WORTH)
				_scored("arena_foe", bonus)
				main._heat_note("YOU SHOT DOWN %s!" % net.name_of(from), 2.5)
				main.sfx.play("fanfare", 1.0, -2.0)
			if remotes.has(from):
				remotes[from]["down"] = true
		K_LOOT:
			var count := b.get_u8()
			for i in count:
				var id := b.get_u32()
				var x := b.get_float()
				var z := b.get_float()
				var worth := b.get_u32()
				_drop_loot(id, Vector3(x, 0, z), worth)
		K_EAT:
			if not main.ufo.dead and safe <= 0.0:
				_last_hit_by = from
				main._heat_note("BEAMED UP BY %s!" % net.name_of(from), 2.5)
				main.ufo.hull = 0.0
				main.ufo.second_winds = 0
				main.ufo.hurt(9999.0)


func _heard(s: int, at: Vector3, turn: float, vel: Vector3, aim: Vector2, flags: int, score: int, g: float, hull: float, hero: String) -> void:
	if remotes.has(s) and str(remotes[s]["hero"]) != hero:
		_drop_remote(s)
	if not remotes.has(s):
		var saucer := RemoteSaucer.new()
		saucer.slot = s
		saucer.ship = hero
		add_child(saucer)
		var proxy: Thing = main.spawn("arena_foe", at)
		proxy.model.visible = false
		proxy.set_meta("slot", s)
		remotes[s] = {"saucer": saucer, "proxy": proxy, "score": 0, "grow": 1.0, "down": false, "safe": false, "heard": 0.0, "hero": hero, "hull": 1.0}
	var r: Dictionary = remotes[s]
	var down := flags & 2 != 0
	var saucer: RemoteSaucer = r["saucer"]
	saucer.hear([s, at.x, at.y, at.z, turn, flags & 1 != 0, aim.x, aim.y, hero, score, down, vel.x, vel.z])
	r["score"] = score
	r["grow"] = g
	r["down"] = down
	r["safe"] = flags & 8 != 0
	r["hull"] = hull
	r["heard"] = Time.get_ticks_msec() / 1000.0
	size_ship(saucer.ufo, g)
	saucer._tag.text = "%s  $%d" % [net.name_of(s), score]


func _glide_remote(s: int, delta: float) -> void:
	var r: Dictionary = remotes[s]
	if Time.get_ticks_msec() / 1000.0 - float(r["heard"]) > 6.0:
		_drop_remote(s)
		return
	var saucer: RemoteSaucer = r["saucer"]
	saucer.glide(delta)
	# (the shield showing what is left of it, flickering while they cannot be touched)
	saucer.ufo.bubble.visible = not r["down"] and (not r["safe"] or fmod(Time.get_ticks_msec() / 1000.0, 0.25) < 0.17)
	var proxy: Thing = r["proxy"]
	if is_instance_valid(proxy):
		proxy.position = saucer.ufo.position
		proxy.hiding = r["down"] or r["safe"]
	saucer._tag.position = saucer.ufo.position + Vector3(0, 2.0 + saucer.ufo.radius * 0.4, 0)


func _drop_remote(s: int) -> void:
	if not remotes.has(s):
		return
	var r: Dictionary = remotes[s]
	(r["saucer"] as Node).queue_free()
	var proxy: Thing = r["proxy"]
	if is_instance_valid(proxy):
		proxy.set_meta("arena_free", true)
		main._remove(proxy)
	remotes.erase(s)


func _on_left(s: int) -> void:
	_drop_remote(s)


## One of our weapons on another saucer's stand-in (main.gd `weapon_hit`): the hit sent to its owner,
## who takes it; a flash on it here
func hit_foe(t: Thing, power: float, at: Vector3) -> void:
	if not t.has_meta("slot"):
		return
	var s := int(t.get_meta("slot"))
	if not remotes.has(s) or remotes[s]["down"] or remotes[s]["safe"]:
		return
	_hit(s, power, at)


func _hit(s: int, power: float, at: Vector3) -> void:
	var b := StreamPeerBuffer.new()
	b.put_float(power)
	b.put_float(at.x)
	b.put_float(at.y)
	b.put_float(at.z)
	net.send(s, K_HIT, b.data_array)
	var other: Ufo = (remotes[s]["saucer"] as RemoteSaucer).ufo
	Ps1.flash(other.hull_model, Color(1.2, 0.2, 0.15))
	var held: WeakRef = weakref(other)
	create_tween().tween_callback(func() -> void:
		var still: Ufo = held.get_ref()
		if still != null:
			Ps1.flash(still.hull_model, Color.BLACK)).set_delay(0.12)
	for i in 4:
		other.puffs.spark(at, Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3)), Color(1.0, 0.7, 0.3))


## Hit by another saucer's weapon (or its dash): the shield takes it, a streak from them to us
func _struck(from: int, power: float, at: Vector3) -> void:
	var ufo: Ufo = main.ufo
	if ufo.dead or safe > 0.0 or ufo.dodging():
		return
	_last_hit_by = from
	ufo.hurt(power * PVP_HIT, at)
	main._hurt = maxf(main._hurt, 0.5)
	main.sfx.play("boom", 1.7, -6.0)
	if remotes.has(from):
		main._zap((remotes[from]["saucer"] as RemoteSaucer).ufo.position, at)


# ------------------------------------------------------------------ down, and back

## Our saucer down (main.gd `_crash`, each frame it lies there): its loot dropped and its fall told, then
## back at the rim, small, a few seconds later
func ship_down(delta: float) -> void:
	if down_for < 0.0:
		down_for = 0.0
		var lost := int(float(main.score) * LOOT_SHARE)
		var b := StreamPeerBuffer.new()
		b.put_8(_last_hit_by)
		net.send(ArenaNet.BROADCAST, K_DOWN, b.data_array)
		_drop_ours(lost)
		main.score -= lost
		main._heat_note("SHOT DOWN! BACK IN %d" % int(RESPAWN), RESPAWN)
		main.sfx.play("boom", 0.7, 2.0)
		main._shake = 0.5
		_last_hit_by = -1
	down_for += delta
	if down_for >= RESPAWN:
		down_for = -1.0
		main.arena_respawn()
		safe = SAFE
		_grow_set = 0.0
		_apply_grow(true)
		_put_at_rim()


## What we lost, scattered as gems round where we fell, for anyone (us too) to take
func _drop_ours(lost: int) -> void:
	if lost <= 0:
		return
	var count := clampi(1 + lost / int(400 * Thing.WORTH), 1, LOOT_MOST)
	var each := lost / count
	var at: Vector3 = main.ufo.ground()
	var b := StreamPeerBuffer.new()
	b.put_u8(count)
	for i in count:
		_drops += 1
		var id := DROP_BASE + (net.slot << 20) + (_drops % (1 << 20))
		var a := randf() * TAU
		var p := at + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 5.0)
		var flat := Vector3(p.x, 0, p.z)
		if flat.length() > R - 3.0:
			p = flat.normalized() * (R - 3.0)
		b.put_u32(id)
		b.put_float(p.x)
		b.put_float(p.z)
		b.put_u32(each)
		_drop_loot(id, p, each)
	net.send(ArenaNet.BROADCAST, K_LOOT, b.data_array)


func _drop_loot(id: int, at: Vector3, worth: int) -> void:
	if claimed.has(id) or _by_id.has(id):
		return
	var t: Thing = main.spawn("arena_drop", at)
	t.set_meta("arena_id", id)
	t.set_meta("loot", worth)
	_by_id[id] = t
	t.model.scale = Vector3.ONE * 0.05
	var tw := t.create_tween()
	tw.tween_property(t.model, "scale", Vector3.ONE * 1.2, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	main.puff(at + Vector3(0, 0.6, 0), Color(1.0, 0.85, 0.4, 0.7), 0.7)


## Our saucer put in at the rim, on a side away from the others if it can be
func _put_at_rim() -> void:
	var best := Vector3.ZERO
	var far := -1.0
	for i in 12:
		var a := randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * SPAWN_R
		var near := 999.0
		for s in remotes:
			near = minf(near, p.distance_to((remotes[s]["saucer"] as RemoteSaucer).ufo.position * Vector3(1, 0, 1)))
		if near > far:
			far = near
			best = p
	main.ufo.position = Vector3(best.x, main.ufo.altitude, best.z)
	main.ufo.velocity = Vector3.ZERO


# ------------------------------------------------------------------ the board

func _on_top(list: Array) -> void:
	top = list
	leader = int(list[0]["slot"]) if not list.is_empty() else -1


func _crown_on_leader() -> void:
	if _crown == null:
		return
	var who: Ufo = null
	if leader == net.slot:
		who = main.ufo
	elif remotes.has(leader):
		who = (remotes[leader]["saucer"] as RemoteSaucer).ufo
	_crown.visible = who != null and not who.dead and top.size() > 1
	if _crown.visible:
		_crown.global_position = who.global_position + Vector3(0, 1.8 + who.radius * 0.35, 0)
		_crown.rotation.y += get_process_delta_time() * 1.5
		_crown.scale = Vector3.ONE * clampf(who.radius / 2.8, 0.8, 2.0)


func _show_board() -> void:
	if _board == null:
		_board = main._label(30, Color(0.85, 1.0, 0.86))
		_board.add_theme_constant_override("line_spacing", -4)
		_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		main._hud_root.add_child(_board)
	var playing: bool = main.mode == "play"
	_board.visible = playing
	if not playing:
		return
	var big: bool = main._upright()
	var shown := 5 if big else 8
	var lines: Array[String] = ["ARENA  %d/%d" % [net.players.size(), 12]]
	var me_in := false
	for i in mini(top.size(), shown):
		var row: Dictionary = top[i]
		var mine := int(row["slot"]) == net.slot
		me_in = me_in or mine
		lines.append("%s%d %s  %s" % ["> " if mine else "", i + 1, str(row["name"]), _money(int(row["score"]))])
	if not me_in:
		var rank := top.size() + 1
		for i in top.size():
			if int(top[i]["slot"]) == net.slot:
				rank = i + 1
		lines.append("> %d YOU  %s" % [rank, _money(main.score)])
	_board.text = "\n".join(lines)
	_board.add_theme_font_size_override("font_size", 46 if big else 26)
	var view: Vector2 = main.get_viewport().get_visible_rect().size / main.hud.scale.x
	_board.size = Vector2(view.x * (0.62 if big else 0.32), 0)
	_board.position = Vector2(view.x - _board.size.x - 24.0, (main.heat_note.position.y + 50.0) if big else 150.0)


static func _money(n: int) -> String:
	if n >= 100000:
		return "$%dk" % (n / 1000)
	return "$%d" % n


# ------------------------------------------------------------------ the word while joining

func _say(text: String, with_back: bool) -> void:
	if _panel == null:
		_panel = main._panel(main._hud_root)
		_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		_panel.custom_minimum_size = Vector2(560, 0)
		_panel.offset_left = -280.0
		_panel.offset_right = 280.0
		_panel.offset_top = 0.0
		_panel.offset_bottom = 0.0
		_panel_text = main._label(40, Color(0.85, 1.0, 0.86))
		_panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel.add_child(_panel_text)
		var back: Button = main._button("BACK", func() -> void:
			net.leave()
			_joining = false
			_hide_panel())
		back.name = "back"
		_panel.add_child(back)
	_panel_text.text = text
	(_panel.get_node("back") as Control).visible = with_back
	_panel.visible = true
	main.title_box.visible = false


func _hide_panel() -> void:
	if _panel != null:
		_panel.visible = false
	if main.mode == "title":
		main.title_box.visible = true
