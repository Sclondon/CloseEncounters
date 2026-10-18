class_name ArenaNet
extends Node
## The connection to the Scareathon server's Close Encounters arenas (/close-encounters/arena/ws; see
## server/closeEncounters/arena.js in scareathon-v3): drop-in rooms of up to twelve saucers on a
## carnival on the moon, nobody hosting. Joining puts us in the fullest arena with a seat.
##
## Control messages are JSON text. Game packets are binary: byte 0 is who it is for (BROADCAST, or a
## seat), which the server rewrites to who sent it; byte 1 the packet's kind; then its data.
##
## The arena's things are laid out alike in every game from its `seed` and the server's clock (see
## `arena_time`); the server only says who got each first (`claimed`). A dropped socket keeps its
## seat a while: this reconnects with backoff and takes it back with its token.

signal joined_arena            # in (or back in) an arena: seed, slot, players set
signal player_joined(slot: int, name: String, hero: String)
signal player_left(slot: int)
signal claimed(id: int, slot: int)
signal standings(top: Array)
signal failed(message: String)
signal closed(reason: String)
signal packet(from: int, kind: int, data: PackedByteArray)

const BROADCAST := 255
const PATH := "/close-encounters/arena/ws"
## The server keeps a dropped seat 30 s
const GIVE_UP_AFTER := 32.0

var ws: WebSocketPeer
var arena := ""
var slot := -1
var token := ""
var seed := 0
## The arena's birth and the server's clock at the welcome, in ms, and when (here) that was
var born := 0
var _server_now := 0
var _here_at := 0.0
## [{slot, name, hero, score, away}]
var players: Array = []
var reconnecting := false
var _pending := {}
var _was_open := false
var _retry_in := 0.0
var _backoff := 0.5
var _down_for := 0.0
var _ping_wait := 0.0
var _name := "PLAYER"
var _hero := "saucer"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## In an arena
func active() -> bool:
	return slot >= 0


func join(name: String, hero: String) -> void:
	_name = name
	_hero = hero
	_open({"type": "join_arena", "name": name, "hero": hero})


func leave() -> void:
	if ws:
		_send_text({"type": "leave"})
		ws.close()
	_reset()


func claim(id: int) -> void:
	_send_text({"type": "claim", "id": id})


func report_score(score: int) -> void:
	_send_text({"type": "score", "score": score})


func pick_hero(hero: String) -> void:
	_hero = hero
	_send_text({"type": "pick", "hero": hero})


## Seconds the arena has been going, by the server's clock
func arena_time() -> float:
	var since := Time.get_ticks_msec() / 1000.0 - _here_at
	return (_server_now - born) / 1000.0 + since


func send(to: int, kind: int, data: PackedByteArray) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN or reconnecting:
		return
	var out := PackedByteArray([to, kind])
	out.append_array(data)
	ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)


func name_of(s: int) -> String:
	for p: Dictionary in players:
		if int(p["slot"]) == s:
			return str(p["name"])
	return "P%d" % (s + 1)


func hero_of(s: int) -> String:
	for p: Dictionary in players:
		if int(p["slot"]) == s:
			return str(p.get("hero", "saucer"))
	return "saucer"


func _url() -> String:
	var base := Net.server_flag().trim_suffix("/")
	return base.replace("https://", "wss://").replace("http://", "ws://") + PATH


func _reset() -> void:
	ws = null
	arena = ""
	slot = -1
	token = ""
	players = []
	reconnecting = false
	_was_open = false
	_retry_in = 0.0


func _open(first: Dictionary) -> void:
	if ws and not reconnecting:
		leave()
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	_was_open = false
	if ws.connect_to_url(_url()) != OK:
		ws = null
		if reconnecting:
			_schedule_retry()
		else:
			failed.emit("Couldn't reach the server.")
		return
	_pending = first


func _send_text(message: Dictionary) -> void:
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(message))


func _schedule_retry() -> void:
	ws = null
	_retry_in = _backoff
	_backoff = minf(_backoff * 2.0, 5.0)


func _give_up(reason: String) -> void:
	_reset()
	closed.emit(reason)


func _process(delta: float) -> void:
	if reconnecting:
		_down_for += delta
		if _down_for > GIVE_UP_AFTER:
			_give_up("lost")
			return
		if ws == null:
			_retry_in -= delta
			if _retry_in <= 0.0:
				_open({"type": "rejoin_arena", "arena": arena, "token": token})
			return
	if ws == null:
		return
	ws.poll()
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			if not _pending.is_empty():
				_send_text(_pending)
				_pending = {}
		# (the server's clock now and then, to keep the arena's time in step)
		_ping_wait -= delta
		if _ping_wait <= 0.0 and slot >= 0:
			_ping_wait = 10.0
			_send_text({"type": "ping", "t": Time.get_ticks_msec()})
		while ws and ws.get_available_packet_count() > 0:
			var data := ws.get_packet()
			if ws.was_string_packet():
				_on_text(data.get_string_from_utf8())
			elif data.size() >= 2:
				packet.emit(data[0], data[1], data.slice(2))
	elif state == WebSocketPeer.STATE_CLOSED:
		if slot >= 0 or reconnecting:
			if not reconnecting:
				reconnecting = true
				_down_for = 0.0
				_backoff = 0.5
			_schedule_retry()
		else:
			var opened := _was_open
			_reset()
			if not opened:
				failed.emit("Couldn't reach the server.")


func _on_text(text: String) -> void:
	var message: Variant = JSON.parse_string(text)
	if not (message is Dictionary):
		return
	match str(message.get("type")):
		"arena":
			arena = str(message["arena"])
			slot = int(message["slot"])
			token = str(message.get("token", token))
			seed = int(message["seed"])
			born = int(message["born"])
			_server_now = int(message["now"])
			_here_at = Time.get_ticks_msec() / 1000.0
			players = message["players"]
			reconnecting = false
			joined_arena.emit()
			for c: Array in message.get("claimed", []):
				claimed.emit(int(c[0]), int(c[1]))
		"joined":
			var s := int(message["slot"])
			players = players.filter(func(p: Dictionary) -> bool: return int(p["slot"]) != s)
			players.append({"slot": s, "name": str(message.get("name", "")), "hero": str(message.get("hero", "saucer")), "score": 0, "away": false})
			player_joined.emit(s, str(message.get("name", "")), str(message.get("hero", "saucer")))
		"left":
			var s := int(message["slot"])
			players = players.filter(func(p: Dictionary) -> bool: return int(p["slot"]) != s)
			player_left.emit(s)
		"picked":
			for p: Dictionary in players:
				if int(p["slot"]) == int(message["slot"]):
					p["hero"] = str(message.get("hero", "saucer"))
		"claimed":
			claimed.emit(int(message["id"]), int(message["slot"]))
		"top":
			standings.emit(message.get("top", []))
		"pong":
			# (the server's clock, half the round trip ago)
			var trip := (Time.get_ticks_msec() - int(message.get("t", Time.get_ticks_msec()))) / 1000.0
			_server_now = int(message["now"])
			_here_at = Time.get_ticks_msec() / 1000.0 - trip * 0.5
		"closed":
			_give_up(str(message.get("reason", "")))
		"error":
			if str(message.get("code")) == "gone":
				_give_up("gone")
			else:
				failed.emit(str(message.get("message", "Something went wrong.")))
