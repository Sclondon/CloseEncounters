class_name Coop
extends Node
## Multiplayer over Net: up to four saucers over the same country (everyone's world made from the
## seed the leader started with), each flown on its own device. What is shared:
## - each saucer: where it is, which way its hull faces, its beam (on, and where it leans), its
##   ship, its score, and whether it is down; sent STATE_EVERY, drawn for the others as a
##   RemoteSaucer gliding after it
## - their police and army near them (FOES_EVERY), drawn for the others as models gliding after them
## - the host's moving things near it (PROPS_EVERY): everyone's copies of them go where the host's are
## - what happens: something taken up a beam goes for everyone ("take"), crop circles are pressed
##   for everyone ("circle"), and blasts are seen by everyone ("boom")
## Each player has their own heat, police and score. Guests send to the host, and the host passes
## everything on to everyone (the server only lets a guest's packets reach the host), with whose it
## was in the packet.

const K_STATE := 83  # S
const K_EVENT := 69  # E
const STATE_EVERY := 1.0 / 20.0
## Each player's police and army near them, for the others to see, this often
const K_FOES := 70  # F
const FOES_EVERY := 0.2
const FOES_REACH := 90.0
## The host's moving things (people, animals, cars) near it, for everyone's copies to follow
const K_PROPS := 80  # P
const PROPS_EVERY := 0.2
const PROPS_REACH := 70.0

var game: Node
var net: Net
## The other saucers, by seat
var others := {}
var _send_wait := 0.0
var _foes_wait := 0.0
var _props_wait := 0.0
## The things here by their names on every device (see Thing.net_key), made as needed
var _by_key := {}
## Others' police and army as seen here, by seat: {their id: Node3D}
var foes := {}


func _ready() -> void:
	net.packet.connect(_on_packet)
	net.left.connect(_on_left)


func active() -> bool:
	return net != null and net.in_game


func _process(delta: float) -> void:
	if not active() or game.mode != "play":
		return
	_send_wait -= delta
	if _send_wait <= 0.0:
		_send_wait = STATE_EVERY
		_send_state()
	_foes_wait -= delta
	if _foes_wait <= 0.0:
		_foes_wait = FOES_EVERY
		_send_foes()
	for slot in others:
		(others[slot] as RemoteSaucer).glide(delta)
	if net.is_host:
		_props_wait -= delta
		if _props_wait <= 0.0:
			_props_wait = PROPS_EVERY
			_send_props()
	_glide_foes(delta)


## This saucer, for the others
func _send_state() -> void:
	var ufo: Ufo = game.ufo
	var state := [net.slot, ufo.position.x, ufo.position.y, ufo.position.z, ufo.rotation.y + ufo.hull_model.rotation.y,
		ufo.beaming, ufo._aim.x, ufo._aim.z, game.ship, game.score, ufo.dead, ufo.velocity.x, ufo.velocity.z]
	_pass_on(K_STATE, var_to_bytes(state))



## This player's police and army near the ship, for the others: [kind, x, z, turn] each, by id
func _send_foes() -> void:
	var list := [net.slot]
	var here: Vector3 = game.ufo.ground()
	for t: Thing in game.things:
		if t.is_enemy() and t.state == "walk" and t.ground().distance_to(here) < FOES_REACH:
			list.append([t.get_instance_id(), t.kind, t.position.x, t.position.y, t.position.z, t.heading])
			if list.size() > 24:
				break
	_pass_on(K_FOES, var_to_bytes(list))


## Another player's police and army as heard: each a model of it gliding to where it was, gone when
## it is no longer about
func _hear_foes(whose: int, list: Array) -> void:
	if not foes.has(whose):
		foes[whose] = {}
	var mine: Dictionary = foes[whose]
	var seen := {}
	for i in range(1, list.size()):
		var f: Array = list[i]
		var id := int(f[0])
		seen[id] = true
		var at := Vector3(float(f[2]), float(f[3]), float(f[4]))
		if not mine.has(id):
			var kind := str(f[1])
			if not Thing.KINDS.has(kind):
				continue
			var info: Dictionary = Thing.KINDS[kind]
			var n := Ps1.model(info.get("model", kind), info.get("tints", {}))
			n.position = at
			game.view.add_child(n)
			mine[id] = n
		var node: Node3D = mine[id]
		node.set_meta("to", at)
		node.set_meta("turn", float(f[5]))
	for id in mine.keys():
		if not seen.has(id):
			(mine[id] as Node).queue_free()
			mine.erase(id)


func _glide_foes(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	for whose in foes:
		for id in foes[whose]:
			var n: Node3D = foes[whose][id]
			n.position = n.position.lerp(n.get_meta("to", n.position), k)
			n.rotation.y = lerp_angle(n.rotation.y, float(n.get_meta("turn", 0.0)), k)


## Something that happened here, for the others: "take" (a kind, where), "circle" (where, how
## big), "boom" (where, how big)
func tell(what: String, at: Vector3, kind := "", size := 1.0) -> void:
	if not active():
		return
	_pass_on(K_EVENT, var_to_bytes([net.slot, what, at, kind, size]))


func _pass_on(kind: int, data: PackedByteArray) -> void:
	net.send(Net.BROADCAST, kind, data)


func _on_packet(_from: int, kind: int, data: PackedByteArray) -> void:
	var got: Variant = bytes_to_var(data)
	if not (got is Array) or (got as Array).is_empty():
		return
	var said: Array = got
	var whose := int(said[0])
	# (the host hands on what a guest sent to everyone else)
	if net.is_host and whose != net.slot:
		_pass_on(kind, data)
	if whose == net.slot or game.mode != "play":
		return
	match kind:
		K_STATE:
			if said.size() < 11:
				return
			if not others.has(whose):
				var saucer := RemoteSaucer.new()
				saucer.slot = whose
				saucer.ship = str(said[8])
				game.view.add_child(saucer)
				others[whose] = saucer
			(others[whose] as RemoteSaucer).hear(said)
		K_EVENT:
			if said.size() < 5:
				return
			game.coop_event(str(said[1]), said[2], str(said[3]), float(said[4]))
		K_PROPS:
			_hear_props(said)
		K_FOES:
			_hear_foes(whose, said)


func _on_left(slot: int) -> void:
	if others.has(slot):
		(others[slot] as Node).queue_free()
		others.erase(slot)
	_drop_foes(slot)


## The run over (or never begun): the other saucers, and their police and army, gone
func clear() -> void:
	for slot in others:
		(others[slot] as Node).queue_free()
	others.clear()
	for whose in foes.keys():
		_drop_foes(whose)


func _drop_foes(whose: int) -> void:
	if not foes.has(whose):
		return
	for id in foes[whose]:
		(foes[whose][id] as Node).queue_free()
	foes.erase(whose)


## Host: the moving things near the ship, where each is and which way it faces
func _send_props() -> void:
	var list := [net.slot]
	var here: Vector3 = game.ufo.ground()
	for t: Thing in game.things:
		if t.state != "walk" or t.is_enemy() or t.info["move"] == "still" or t.net_to != Vector3.INF:
			continue
		if t.ground().distance_to(here) < PROPS_REACH:
			list.append([t.net_key(), snappedf(t.position.x, 0.05), snappedf(t.position.z, 0.05), snappedf(t.heading, 0.05)])
			if list.size() > 90:
				break
	_pass_on(K_PROPS, var_to_bytes(list))


## Guest: the host's word on its moving things; those of them here go where it says
func _hear_props(list: Array) -> void:
	if net.is_host:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var fresh := false
	for i in range(1, list.size()):
		var p: Array = list[i]
		var key := str(p[0])
		var t: Thing = _by_key.get(key)
		if (t == null or not is_instance_valid(t) or t.state == "gone") and not fresh:
			# (names made afresh for everything here, once a packet at most)
			fresh = true
			_by_key.clear()
			for th: Thing in game.things:
				if th.state == "walk":
					_by_key[th.net_key()] = th
			t = _by_key.get(key)
		if t == null or not is_instance_valid(t):
			continue
		if t.state != "walk":
			continue
		t.net_to = Vector3(float(p[1]), t.position.y, float(p[2]))
		t.net_turn = float(p[3])
		t.net_at = now
