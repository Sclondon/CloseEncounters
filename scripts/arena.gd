class_name Arena
extends Node3D
## THE ARENA (ARENA on the title, by PLAY, HOST and JOIN): drop in to a room of up to twelve saucers on a
## carnival the aliens have set up on the moon, a round crater ringed with a padded bumper rail and stands
## full of aliens watching, and beam up what lies about (astronauts, tourists in bubble helmets, buggies,
## landers, moon bases, dishes, solar panels, flags, moon rocks and glowing gems) for the top spot. It
## plays as a run on Earth does (each ship its own, level-ups and the Moon Market's picks, shields and
## dodges), with no police or army: the other saucers are the danger. They knock each other about like
## bumper cars, a dash into one hurts it, the weapons hurt them. Shot down, a saucer loses everything (its
## score dropped as LOST LOOT for anyone to take, its level and items gone) and comes back at the rim a
## few seconds later, as it started. With few players in, rival saucers fly too (ArenaBots).
##
## Everything lying about is laid out alike on every device from the arena's seed (ArenaNet), and comes
## back on a clock (`_refresh`); what matters is who took it first, and the server says that (`claimed`).
## Each device flies its own saucer and streams it to the rest (K_STATE); the others are drawn as
## RemoteSaucers, with an unseen stand-in under each (an "arena_foe" Thing) for the weapons to aim at
## (main.gd `weapon_hit` sends the hit to its owner, K_HIT, who takes the damage).

## The padded rail round the floor (the floor rises to it), and where the saucers come in
const R := 62.0
const SPAWN_R := 50.0
## Packets: a saucer's state, a hit on another, shot down, its lost loot, beamed up by a bigger one
const K_STATE := 1
const K_HIT := 2
const K_DOWN := 3
const K_LOOT := 4
## (5 was a bigger saucer beaming up a smaller one, before the saucers stopped growing)
## The bots: their states (from the device flying them), a hit on one (to that device), one's shot at
## a player (to them), one shot down (to all)
const K_BOTS := 6
const K_HIT_BOT := 7
const K_BOT_SHOT := 8
const K_BOT_DOWN := 9
const SEND_EVERY := 1.0 / 15.0
## Bots go by ids from here up (the seats are below it)
const BOT_BASE := 100
## Shield taken from a saucer by a laser hit's worth of anything
const PVP_HIT := 9.0
## A dash into another saucer: this many laser hits' worth
const RAM_HIT := 1.6
const RESPAWN := 3.0
## Untouchable this long after coming back
const SAFE := 3.0
## The share of its score a saucer drops as loot when shot down: all of it (and how many gems at most)
const LOOT_SHARE := 1.0
const LOOT_MOST := 8
## Ids from here up are lost loot (DROP_BASE + seat * 2^20 + count), below are the arena's own things
const DROP_BASE := 1 << 30
## What lies about: [kind, how many, seconds before one taken comes back]
const LAYOUT := [["arena_rock_small", 24, 22.0], ["arena_flag", 8, 30.0], ["arena_gem_pink", 6, 30.0], ["arena_gem_blue", 6, 30.0],
	["arena_gem_green", 6, 30.0], ["arena_gem_gold", 4, 45.0], ["arena_astronaut", 14, 25.0], ["arena_tourist", 16, 25.0],
	["arena_solar", 8, 40.0], ["arena_rock_big", 8, 40.0], ["arena_snack_cart", 6, 40.0], ["arena_rover", 8, 40.0],
	["arena_dish", 6, 45.0], ["arena_booth", 4, 60.0], ["arena_lander", 4, 70.0], ["arena_habitat", 4, 80.0]]
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
## The others (seats, and bots from BOT_BASE): id -> {saucer, proxy, score, down, safe, heard, hero, hull}
var remotes := {}
var bots: ArenaBots
var _send_wait := 0.0
var _score_wait := 0.0
var _reported := -1
## Seconds since our saucer went down (-1 while flying), the seconds left untouchable, and who hit us last
var down_for := -1.0
var safe := 0.0
var _last_hit_by := -1
var _drops := 0
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
	# (on while a level-up's pick holds the game: the others, and the bots, go on meanwhile)
	process_mode = Node.PROCESS_MODE_ALWAYS
	net = ArenaNet.new()
	add_child(net)
	bots = ArenaBots.new()
	bots.arena = self
	add_child(bots)
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
	bots.clear()
	for s in remotes.keys():
		drop_remote(s)
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
	_islands.clear()
	_parked.clear()
	var regolith := ShaderMaterial.new()
	regolith.shader = load("res://shaders/moon.gdshader")
	for name: String in ["arena_floor", "arena_rim"]:
		var m := Ps1.model(name)
		_map.add_child(m)
		# (the bank too: its ground the moon's, its rail and bulbs their own, see moon.gdshader)
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = regolith
	# (the moon round about, from under the bank out to the horizon: a ring, cut finer near the rim,
	# for it to bend with the world as the floor does; none of it under the floor)
	var outside := MeshInstance3D.new()
	outside.mesh = _moon_ring()
	outside.material_override = regolith
	outside.extra_cull_margin = 200.0
	outside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_map.add_child(outside)
	# The carnival's gate, the way the camera looks in from, and a rocket tower beside it
	for d: Array in [["arena_arch", GATE, R + 9.0], ["arena_rocket_tower", GATE + 0.32, R + 12.0]]:
		_stand_up(Ps1.model(d[0]), float(d[1]), float(d[2]))
	# The crowd: stands all round the bank, full of aliens watching, and in the gaps, aliens
	# tailgating by their parked saucers
	var stands: Array = []
	var camps: Array = []
	for i in STANDS:
		var a := GATE + (i + 1) * TAU / (STANDS + 1)
		if i in CAMPS:
			camps.append(a)
		else:
			stands.append(a)
	var stand_at: Array = []
	for a: float in stands:
		stand_at.append(_flat_at(a, R + 5.5))
	_multi("arena_stands", stand_at)
	_crowd(stand_at)
	for a: float in camps:
		_camp(a)
	# Lamps strung with bulbs all round the rail, and its padded posts
	var poles: Array = []
	for i in 24:
		poles.append(_flat_at(i * TAU / 24.0 + 0.13, R + 3.2))
	var posts: Array = []
	for i in 32:
		var t := _flat_at(i * TAU / 32.0, R - 0.6)
		posts.append(t.translated(Vector3(0, 1.3, 0)))
	_multi("arena_lights", poles)
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


## The rim's bank round the floor, as tools/build_arena.py makes it: [metres out from the rail, height]
const BANK := [[0.4, 0.3], [2.0, 1.6], [5.0, 3.4], [9.0, 3.8], [15.0, 2.4], [21.0, 0.7], [24.0, -0.8]]
## Which way the gate stands (the camera looks in from beyond it), how many places round the bank (stands,
## but for the camps), and which of them are camps (the floor itself is open: nothing on it to fly into)
const GATE := -PI * 0.5
const STANDS := 15
const CAMPS := [1, 6, 11]
## Round obstacles on the floor that saucers bounce off: [where, radius]
var _islands: Array = []
## The parked saucers by the camps (ticked, for their lights and their pilots: see `step`)
var _parked: Array[Ufo] = []
## The crowd's material, and how excited they are (up when something big happens: see `excite`)
var _crowd_mat: ShaderMaterial
var _cheer := 1.0


## How high the bank stands `r` metres from the middle (0 on the floor)
static func bank_y(r: float) -> float:
	var d := r - R
	if d <= float(BANK[0][0]):
		return 0.0
	for i in BANK.size() - 1:
		var a: Array = BANK[i]
		var b: Array = BANK[i + 1]
		if d <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (d - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(BANK[-1][1])


## A place on the bank `r` out along `a`, on its ground, facing in
func _flat_at(a: float, r: float) -> Transform3D:
	var at := Vector3(cos(a) * r, bank_y(r), sin(a) * r)
	return Transform3D(Basis(Vector3.UP, atan2(-at.x, -at.z)), at)


func _stand_up(n: Node3D, a: float, r: float) -> void:
	n.transform = _flat_at(a, r)
	_map.add_child(n)


## The moon beyond the bank, a ring out to the horizon
func _moon_ring() -> ArrayMesh:
	var radii: Array[float] = []
	var r := R + 20.0
	while r < 330.0:
		radii.append(r)
		r += 4.0 if r < R + 70.0 else (10.0 if r < 170.0 else 25.0)
	var sides := 96
	var c := Color(0.58, 0.57, 0.55).srgb_to_linear()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in radii.size() - 1:
		for k in sides:
			var a0 := k * TAU / sides
			var a1 := (k + 1) * TAU / sides
			var p00 := Vector3(cos(a0) * radii[i], 0, sin(a0) * radii[i])
			var p01 := Vector3(cos(a1) * radii[i], 0, sin(a1) * radii[i])
			var p10 := Vector3(cos(a0) * radii[i + 1], 0, sin(a0) * radii[i + 1])
			var p11 := Vector3(cos(a1) * radii[i + 1], 0, sin(a1) * radii[i + 1])
			for v: Vector3 in [p00, p10, p01, p01, p10, p11]:
				st.set_normal(Vector3.UP)
				st.set_color(c)
				st.add_vertex(v)
	return st.commit()


## The audience: aliens sitting along each stand's three tiers, each its own colour, bobbing and
## swaying to their own beat (bend.gdshaderinc `cheer`), all in one MultiMesh
func _crowd(stands: Array) -> void:
	var places: Array = []
	for t: Transform3D in stands:
		for tier in 3:
			for k in 9:
				var x := -6.2 + k * 1.55 + randf_range(-0.25, 0.25)
				var local := Vector3(x, 0.5 + tier * 0.75, -(tier * 1.5 + 0.55))
				places.append(t * Transform3D(Basis(Vector3.UP, randf_range(-0.35, 0.35)).scaled(Vector3.ONE * randf_range(0.85, 1.15)), local))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = Ps1.model_mesh("arena_fan")
	mm.instance_count = places.size()
	for i in places.size():
		mm.set_instance_transform(i, places[i])
		var coat: Color = Alien.COATS[randi() % Alien.COATS.size()].lightened(randf_range(0.0, 0.3))
		mm.set_instance_color(i, coat)
		mm.set_instance_custom_data(i, Color(randf(), randf(), 0.0, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = Ps1.CULL_MARGIN
	_crowd_mat = Ps1.own(Color.WHITE, 0.0, 0.3)
	_crowd_mat.set_shader_parameter("cheer", 1.0)
	mmi.material_override = _crowd_mat
	_map.add_child(mmi)


## Something big happened (a saucer shot down, one beamed up whole, a new leader): the crowd goes wild
## for a moment
func excite(how := 1.0) -> void:
	_cheer = maxf(_cheer, 1.0 + 2.5 * how)


## A camp in a gap between the stands: a saucer parked on its legs with its canopy open and its pilot
## lounging on top with a drink, a cooler and a radio, two more aliens in deck chairs with theirs, and
## one up cheering
func _camp(a: float) -> void:
	var r := R + 9.0
	var home := _flat_at(a, r)
	var ufo := Ufo.new()
	var picks := ["saucer", "orb", "bell", "saturn", "carnival", "jelly", "diamond", "foo"]
	ufo.ship = picks[randi() % picks.size()]
	ufo.alien_seed = randi() % 9999
	ufo.parked = true
	_map.add_child(ufo)
	ufo.position = home.origin + home.basis * Vector3(0, 1.58, 2.5)
	ufo.rotation.y = randf() * TAU
	ufo.lounge(true)
	ufo.spot.visible = false
	ufo.glow.visible = false
	ufo.beam_light.visible = false
	_parked.append(ufo)
	for prop: Array in [["cooler", Vector3(-1.8, 0, -1.0), 0.6], ["boombox", Vector3(1.7, 0, -1.4), -0.4]]:
		var n := Ps1.model(prop[0])
		n.transform = home * Transform3D(Basis(Vector3.UP, float(prop[2])), prop[1])
		_map.add_child(n)
	for k in 3:
		var al := Alien.new()
		al.look_seed = randi() % 99999
		var spot: Vector3 = [Vector3(-3.0, 0, -2.6), Vector3(-0.6, 0, -3.4), Vector3(2.8, 0, -2.4)][k]
		if k < 2:
			var chair := Ps1.model("lounge_chair")
			chair.transform = home * Transform3D(Basis(Vector3.UP, randf_range(-0.4, 0.4)), spot)
			_map.add_child(chair)
			chair.add_child(al)
			al.position = Ufo.CHAIR_SEAT
			al.feel("lounge")
			var drink := Ps1.model("beer_can" if k == 0 else "beer")
			drink.scale = Vector3.ONE * 1.6
			al.arms[1].add_child(drink)
			drink.position = Vector3(0.02, -0.36, 0.03)
			drink.rotation = Vector3(PI, 0, 0)
		else:
			al.transform = home * Transform3D(Basis(Vector3.UP, PI), spot + Vector3(0, 0.05, 0))
			_map.add_child(al)
			al.feel("cheer")


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
	if bots.claimed(id, slot == net.slot):
		return
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
	var can: Array[String] = []
	for k: String in main.WEAPONS:
		if main.can_take(k) and int(main.upgrades[k]) < main.MAX_UPGRADE:
			can.append(k)
	if can.is_empty():
		return
	var w: String = can[randi() % can.size()]
	main.buy(w)
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
	_keep_in(ufo, delta)
	_keep_things_in()
	_bumper_cars(ufo, delta)
	_place_earth()
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


## What goes on whether or not a level-up's pick holds the game: our saucer told to the rest, the
## others and the bots flown and drawn, the crowd, the parked saucers by the camps
func _process(delta: float) -> void:
	if not on:
		return
	bots.tick(delta)
	for s in remotes.keys():
		if remotes.has(s):
			_glide_remote(s, delta)
	_crown_on_leader(delta)
	_send_wait -= delta
	if _send_wait <= 0.0:
		_send_wait = SEND_EVERY
		_send_state(main.ufo)
	for u in _parked:
		if is_instance_valid(u):
			u.tick(delta, Vector2.ZERO, false)
	if _crowd_mat != null:
		_cheer = lerpf(_cheer, 1.0, minf(delta * 0.6, 1.0))
		_crowd_mat.set_shader_parameter("cheer", _cheer)
	if main.mode == "play" and get_tree().paused:
		_show_board()


## Whether our saucer is picking at a level-up (the game held still for it): it cannot be hit meanwhile
func picking() -> bool:
	return main._picker != null and main._picker.visible


## The padded rail: a saucer flying into it bounces back off it, as off a bumper car's; and the islands
## of posts out on the floor, the same
func _keep_in(ufo: Ufo, delta: float) -> void:
	_rail_wait -= delta
	var flat := Vector3(ufo.position.x, 0, ufo.position.z)
	var most := R - 1.0 - ufo.radius * 0.5
	if flat.length() > most:
		_bounce(ufo, flat.normalized(), flat.normalized() * most)
	for isl: Array in _islands:
		var off: Vector3 = flat - (isl[0] as Vector3)
		var reach := float(isl[1]) + ufo.radius * 0.5
		if off.length() < reach and off.length() > 0.01:
			_bounce(ufo, -off.normalized(), (isl[0] as Vector3) + off.normalized() * reach)


func _bounce(ufo: Ufo, out: Vector3, to: Vector3) -> void:
	ufo.position.x = to.x
	ufo.position.z = to.z
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


## Saucers that meet bounce apart; a dash into one hurts it
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
		ufo.position += out * (reach - d) * 0.9
		ufo.velocity += out * 11.0
		ufo.knock = out * 14.0
		if _bump_wait <= 0.0:
			_bump_wait = 0.35
			main.sfx.play("thud", 0.8 + randf() * 0.2, 0.0)
			main.sfx.play("bloop", 0.7, -6.0)
			main._shake = maxf(main._shake, 0.2)
			main.puff((ufo.position + other.position) * 0.5, Color(1.0, 0.9, 0.6, 0.7), 0.7)
			if ufo.dodging() and not r["safe"]:
				_hit(int(s), RAM_HIT, (ufo.position + other.position) * 0.5)
				main._heat_note("RAMMED %s" % name_of(int(s)), 1.2)


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
	var flags := (1 if ufo.beaming else 0) | (2 if ufo.dead else 0) | (4 if ufo.dodging() else 0) | (8 if safe > 0.0 or picking() else 0)
	b.put_u8(flags)
	b.put_u32(maxi(main.score, 0))
	# (where the saucers' growth was, before they stopped growing: kept, for the packet's shape)
	b.put_float(1.0)
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
			b.get_float()
			var hull := b.get_u8() / 255.0
			var hero: String = Ufo.ORDER[clampi(b.get_u8(), 0, Ufo.ORDER.size() - 1)]
			_heard(from, at, turn, Vector3(vx, 0, vz), Vector2(ax, az), flags, score, hull, hero)
		K_HIT:
			var power := b.get_float()
			var where := Vector3(b.get_float(), b.get_float(), b.get_float())
			struck(from, power, where)
		K_DOWN:
			var killer := b.get_8()
			_killed_by(killer, from)
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
		K_BOTS:
			if bots.simulating():
				return
			var count := b.get_u8()
			if data.size() < 1 + count * 27:
				return
			var sent := {}
			for i in count:
				var id := b.get_u8()
				sent[id] = true
				var x := b.get_float()
				var z := b.get_float()
				var turn := b.get_float()
				var vx := b.get_float()
				var vz := b.get_float()
				var flags := b.get_u8()
				var score := b.get_u32()
				var hull := b.get_u8() / 255.0
				heard_bot(id, Vector3(x, 0, z), turn, Vector3(vx, 0, vz), flags, score, hull, "saucer")
			# (a bot no longer flown, as players came in: gone)
			for s in remotes.keys():
				if int(s) >= BOT_BASE and not sent.has(int(s)):
					drop_remote(int(s))
		K_HIT_BOT:
			var id := b.get_u8()
			var power := b.get_float()
			bots.hurt(id, power, from)
		K_BOT_SHOT:
			var id := b.get_u8()
			var power := b.get_float()
			var where := Vector3(b.get_float(), b.get_float(), b.get_float())
			struck(id, power, where)
		K_BOT_DOWN:
			var id := b.get_u8()
			var killer := b.get_8()
			_killed_by(killer, id)


## Someone (`who`: a seat or a bot) shot down by `killer`: a bonus to whoever it was, here (ours, or a
## bot's if this device flies the bots), and the crowd goes wild
func _killed_by(killer: int, who: int) -> void:
	excite(1.0)
	if killer == net.slot:
		var bonus := int(150 * Thing.WORTH)
		_scored("arena_foe", bonus)
		main._heat_note("YOU SHOT DOWN %s!" % name_of(who), 2.5)
		main.sfx.play("fanfare", 1.0, -2.0)
	elif killer >= BOT_BASE and bots.simulating():
		bots.credit_kill(killer)


func _heard(s: int, at: Vector3, turn: float, vel: Vector3, aim: Vector2, flags: int, score: int, hull: float, hero: String) -> void:
	if remotes.has(s) and str(remotes[s]["hero"]) != hero:
		drop_remote(s)
	if not remotes.has(s):
		var saucer := RemoteSaucer.new()
		saucer.slot = s
		saucer.ship = hero
		if s >= BOT_BASE:
			# (a bot: a rival saucer, purple with a pink beam)
			saucer.tints = Thing.KINDS["rival"]["tints"]
		add_child(saucer)
		if s >= BOT_BASE:
			saucer.ufo.colour_beam(Color(1.0, 0.4, 0.85))
		var proxy: Thing = main.spawn("arena_foe", at)
		proxy.model.visible = false
		proxy.set_meta("slot", s)
		remotes[s] = {"saucer": saucer, "proxy": proxy, "score": 0, "down": false, "safe": false, "heard": 0.0, "hero": hero, "hull": 1.0}
	var r: Dictionary = remotes[s]
	var down := flags & 2 != 0
	var saucer: RemoteSaucer = r["saucer"]
	saucer.hear([s, at.x, at.y, at.z, turn, flags & 1 != 0, aim.x, aim.y, hero, score, down, vel.x, vel.z])
	r["score"] = score
	r["down"] = down
	r["safe"] = flags & 8 != 0
	r["hull"] = hull
	r["heard"] = Time.get_ticks_msec() / 1000.0
	saucer._tag.text = "%s  $%d" % [name_of(s), score]


## A bot's state, from the device flying it (or this one): drawn like any other saucer
func heard_bot(id: int, at: Vector3, turn: float, vel: Vector3, flags: int, score: int, hull: float, hero: String) -> void:
	var y: float = Ufo.SHIPS[hero]["altitude"]
	_heard(id, Vector3(at.x, y, at.z), turn, vel, Vector2.ZERO, flags, score, hull, hero)


func _glide_remote(s: int, delta: float) -> void:
	var r: Dictionary = remotes[s]
	if Time.get_ticks_msec() / 1000.0 - float(r["heard"]) > 6.0:
		drop_remote(s)
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
	# (a tag is not bent with the world: far off it would hang in the sky over where the saucer has gone down
	# behind the curve)
	saucer._tag.visible = not r["down"] and saucer.ufo.position.distance_to(main.ufo.position) < 38.0


func drop_remote(s: int) -> void:
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
	drop_remote(s)


## What a saucer (a seat or a bot) goes by
func name_of(s: int) -> String:
	return bots.name_of(s) if s >= BOT_BASE else net.name_of(s)


## One of our weapons on another saucer's stand-in (main.gd `weapon_hit`): the hit sent to its owner
## (for a bot, the device flying it), who takes it; a flash on it here
func hit_foe(t: Thing, power: float, at: Vector3) -> void:
	if not t.has_meta("slot"):
		return
	var s := int(t.get_meta("slot"))
	if not remotes.has(s) or remotes[s]["down"] or remotes[s]["safe"]:
		return
	_hit(s, power, at)


func _hit(s: int, power: float, at: Vector3) -> void:
	if s >= BOT_BASE:
		if bots.simulating():
			bots.hurt(s, power, net.slot)
		else:
			var hb := StreamPeerBuffer.new()
			hb.put_u8(s)
			hb.put_float(power)
			net.send(_bots_seat(), K_HIT_BOT, hb.data_array)
	else:
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


## The seat flying the bots (the lowest still in)
func _bots_seat() -> int:
	var lowest := 9999
	for p: Dictionary in net.players:
		if not bool(p.get("away", false)):
			lowest = mini(lowest, int(p["slot"]))
	return lowest


## Hit by another saucer's weapon, its dash, or a bot's shot (`from`: a seat or a bot): the shield takes
## it, a streak from them to us
func struck(from: int, power: float, at: Vector3) -> void:
	var ufo: Ufo = main.ufo
	if ufo.dead or safe > 0.0 or ufo.dodging() or picking():
		return
	_last_hit_by = from
	ufo.hurt(power * PVP_HIT, at)
	main._hurt = maxf(main._hurt, 0.5)
	main.sfx.play("boom", 1.7, -6.0)
	if remotes.has(from) and from < BOT_BASE:
		main._zap((remotes[from]["saucer"] as RemoteSaucer).ufo.position, at)


## A bot of ours (this device flies them) shot a player on another device: the hit sent to them
func bot_shot(seat: int, id: int, power: float, at: Vector3) -> void:
	var b := StreamPeerBuffer.new()
	b.put_u8(id)
	b.put_float(power)
	b.put_float(at.x)
	b.put_float(at.y)
	b.put_float(at.z)
	net.send(seat, K_BOT_SHOT, b.data_array)


## A bot of ours beamed something up: up its beam it goes (gone here; gone elsewhere when the server
## says whose it was)
func bot_took(t: Thing, at: Vector3) -> void:
	var id := int(t.get_meta("arena_id", -1))
	_by_id.erase(id)
	t.set_meta("arena_gone", true)
	var rise := t.create_tween()
	rise.tween_property(t, "position", Vector3(at.x, 7.0, at.z), 0.5).set_ease(Tween.EASE_IN)
	rise.parallel().tween_property(t.model, "scale", Vector3.ONE * 0.05, 0.5)
	rise.tween_callback(func() -> void:
		if is_instance_valid(t) and t.state != "gone":
			main._remove(t))


## A bot of ours shot down: told to all, its loot scattered, the crowd cheering
func bot_down(id: int, killer: int, at: Vector3, lost: int) -> void:
	var b := StreamPeerBuffer.new()
	b.put_u8(id)
	b.put_8(killer)
	net.send(ArenaNet.BROADCAST, K_BOT_DOWN, b.data_array)
	_killed_by(killer, id)
	main.boom(Vector3(at.x, 7.0, at.z), 3.0)
	_scatter_loot(lost, at, 32 + id - BOT_BASE, bots.next_drop())


## A place at the rim to come in at, away from everyone if it can be
func rim_spot() -> Vector3:
	var best := Vector3.ZERO
	var far := -1.0
	for i in 12:
		var a := randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * SPAWN_R
		var near := 999.0
		near = minf(near, p.distance_to(main.ufo.position * Vector3(1, 0, 1)))
		for s in remotes:
			near = minf(near, p.distance_to((remotes[s]["saucer"] as RemoteSaucer).ufo.position * Vector3(1, 0, 1)))
		if near > far:
			far = near
			best = p
	return best


# ------------------------------------------------------------------ down, and back

## Our saucer down (main.gd `_crash`, each frame it lies there): everything it had lost (its score dropped
## as loot, its fall told), then back at the rim, as it started, a few seconds later
func ship_down(delta: float) -> void:
	if down_for < 0.0:
		down_for = 0.0
		var lost := int(float(main.score) * LOOT_SHARE)
		var b := StreamPeerBuffer.new()
		b.put_8(_last_hit_by)
		net.send(ArenaNet.BROADCAST, K_DOWN, b.data_array)
		if _last_hit_by >= BOT_BASE and bots.simulating():
			bots.credit_kill(_last_hit_by)
		excite(1.0)
		_drops += 1
		_scatter_loot(lost, main.ufo.ground(), net.slot, _drops)
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
		_put_at_rim()


## What a saucer lost, scattered as gems round where it fell, for anyone to take (`code` the seat, or
## 32 and up for a bot, and `n` a count, for the gems' ids)
func _scatter_loot(lost: int, at: Vector3, code: int, n: int) -> void:
	if lost <= 0:
		return
	var count := clampi(1 + lost / int(400 * Thing.WORTH), 1, LOOT_MOST)
	var each := lost / count
	var b := StreamPeerBuffer.new()
	b.put_u8(count)
	for i in count:
		var id := DROP_BASE + (code << 20) + ((n * LOOT_MOST + i) % (1 << 20))
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
	var p := rim_spot()
	main.ufo.position = Vector3(p.x, main.ufo.altitude, p.z)
	main.ufo.velocity = Vector3.ZERO


# ------------------------------------------------------------------ the board

func _on_top(list: Array) -> void:
	top = list


## Everyone on the board: the players as the server ranks them (ours as it is now), and the bots
func standings() -> Array:
	var rows: Array = []
	for row: Dictionary in top:
		var s := int(row["slot"])
		rows.append({"slot": s, "name": str(row["name"]), "score": main.score if s == net.slot else int(row["score"]), "bot": false})
	var me_in := false
	for row: Dictionary in rows:
		me_in = me_in or int(row["slot"]) == net.slot
	if not me_in:
		rows.append({"slot": net.slot, "name": "YOU", "score": main.score, "bot": false})
	for s in remotes:
		if int(s) >= BOT_BASE:
			rows.append({"slot": int(s), "name": name_of(int(s)), "score": int(remotes[s]["score"]), "bot": true})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return rows


func _crown_on_leader(delta: float) -> void:
	if _crown == null:
		return
	var rows := standings()
	var was := leader
	leader = int(rows[0]["slot"]) if not rows.is_empty() and int(rows[0]["score"]) > 0 else -1
	if leader != was and leader != -1 and was != -1:
		excite(0.6)
	var who: Ufo = null
	if leader == net.slot:
		who = main.ufo
	elif remotes.has(leader):
		who = (remotes[leader]["saucer"] as RemoteSaucer).ufo
	_crown.visible = who != null and not who.dead and rows.size() > 1
	if _crown.visible:
		_crown.global_position = who.global_position + Vector3(0, 1.8 + who.radius * 0.35, 0)
		_crown.rotation.y += delta * 1.5
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
	var rows := standings()
	var lines: Array[String] = ["ARENA  %d/%d" % [net.players.size(), 12]]
	var me_in := false
	for i in mini(rows.size(), shown):
		var row: Dictionary = rows[i]
		var mine := int(row["slot"]) == net.slot
		me_in = me_in or mine
		lines.append("%s%d %s%s  %s" % ["> " if mine else "", i + 1, str(row["name"]), " BOT" if row["bot"] else "", _money(int(row["score"]))])
	if not me_in:
		var rank := rows.size()
		for i in rows.size():
			if int(rows[i]["slot"]) == net.slot:
				rank = i + 1
		lines.append("> %d YOU  %s" % [rank, _money(main.score)])
	_board.text = "\n".join(lines)
	_board.add_theme_font_size_override("font_size", 46 if big else 26)
	var view: Vector2 = main.get_viewport().get_visible_rect().size / main.hud.scale.x
	# (clear of the side log, top right, where what is taken is typed out: on an upright phone down the
	# left under the round buttons; on a wide screen at the right, under the log's lines)
	if big:
		_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_board.size = Vector2(view.x * 0.62, 0)
		_board.position = Vector2(24.0, view.y * 0.2)
	else:
		_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_board.size = Vector2(view.x * 0.32, 0)
		var under: float = main.log_box.position.y + main.log_box.size.y + 12.0 if main.log_box.get_child_count() > 0 else 150.0
		_board.position = Vector2(view.x - _board.size.x - 24.0, maxf(under, 150.0))


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
