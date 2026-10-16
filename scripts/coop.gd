class_name Coop
extends Node
## Multiplayer over Net: up to four saucers over the same country (everyone's world made from the
## seed the leader started with), each flown on its own device. What is shared:
## - each saucer: where it is, which way its hull faces, its beam (on, and where it leans), its
##   ship, its score, and whether it is down; sent STATE_EVERY, drawn for the others as a
##   RemoteSaucer gliding after it
## - what happens: something taken up a beam goes for everyone ("take"), crop circles are pressed
##   for everyone ("circle"), and blasts are seen by everyone ("boom")
## Each player has their own heat, police and score. Guests send to the host, and the host passes
## everything on to everyone (the server only lets a guest's packets reach the host), with whose it
## was in the packet.

const K_STATE := 83  # S
const K_EVENT := 69  # E
const STATE_EVERY := 1.0 / 15.0

var game: Node
var net: Net
## The other saucers, by seat
var others := {}
var _send_wait := 0.0


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
	for slot in others:
		(others[slot] as RemoteSaucer).glide(delta)


## This saucer, for the others
func _send_state() -> void:
	var ufo: Ufo = game.ufo
	var state := [net.slot, ufo.position.x, ufo.position.y, ufo.position.z, ufo.rotation.y + ufo.hull_model.rotation.y,
		ufo.beaming, ufo._aim.x, ufo._aim.z, game.ship, game.score, ufo.dead]
	_pass_on(K_STATE, var_to_bytes(state))


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


func _on_left(slot: int) -> void:
	if others.has(slot):
		(others[slot] as Node).queue_free()
		others.erase(slot)


## The run over (or never begun): the other saucers gone
func clear() -> void:
	for slot in others:
		(others[slot] as Node).queue_free()
	others.clear()
