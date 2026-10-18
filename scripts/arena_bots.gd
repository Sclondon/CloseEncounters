class_name ArenaBots
extends Node
## The ARENA's bots: rival saucers (purple, a pink beam, as the rivals on Earth) flying with the players
## when there are few of them, enough to make SAUCERS in all, fewer as players come in. They roam the
## floor beaming up what lies about, go for the saucers near them with their weapons and dash into them,
## run when their shields are low, are shot down like anyone (dropping their loot) and come back.
##
## Exactly one device flies them: the one in the lowest seat still there (`simulating`); it streams them
## to the rest (Arena.K_BOTS) like extra saucers, by ids from Arena.BOT_BASE up, and every device draws
## them as RemoteSaucers (Arena.remotes). A hit on a bot goes to that device (Arena.K_HIT_BOT); a bot's
## shot goes to the one it hit (Arena.K_BOT_SHOT). What a bot beams up is claimed from the server in that
## device's seat and counted to the bot here (`_claims`).

const SAUCERS := 6
const MOST := 5
const SPEED := 11.0
const HULL := 50.0
## A shot: this many laser hits' worth, every so often, from up to this far
const SHOT := 0.55
const REACH := 14.0
## Bots, by id: {id, ship, pos, vel, turn, hull, score, down (s, -1 flying), safe, wait, beam, beam_t,
## goal (a Thing), foe (an id: a seat or a bot), mood (how keen on a fight), dash, last_hit_by}
var bots := {}
## What a bot asked the server for: id -> [bot id, points]
var _claims := {}
var arena: Arena
var _send_wait := 0.0
var _think_wait := 0.0
var _was_simulating := false
var _drops := 0
## Things the bots leave alone (the tests keep one for a player to take)
var spare: Array = []


## Whether this device flies the bots: the lowest seat of those still in the arena
func simulating() -> bool:
	var net: ArenaNet = arena.net
	if net.slot < 0:
		return false
	var lowest := net.slot
	for p: Dictionary in net.players:
		if not bool(p.get("away", false)):
			lowest = mini(lowest, int(p["slot"]))
	return lowest == net.slot


## How many bots there should be, with this many players in
func wanted() -> int:
	var people := 0
	for p: Dictionary in arena.net.players:
		if not bool(p.get("away", false)):
			people += 1
	return clampi(SAUCERS - maxi(people, 1), 0, MOST)


## A bot's name on the board, alike on every device (from the arena's seed and its id)
func name_of(id: int) -> String:
	var bits: Array = Arena.NAME_BITS
	var h := hash([arena.net.seed, id])
	return "%s%s-%d" % [bits[absi(h) % bits.size()], (bits[absi(h / 13) % bits.size()] as String).substr(0, 2), absi(h / 169) % 99 + 1]


func clear() -> void:
	bots.clear()
	_claims.clear()
	_was_simulating = false


## Each frame (paused or not): the bots flown here if this device flies them, streamed to everyone
func tick(delta: float) -> void:
	if not simulating():
		if _was_simulating:
			# (someone in a lower seat flies them now)
			bots.clear()
			_was_simulating = false
		return
	if not _was_simulating:
		_was_simulating = true
		_take_over()
	_head_count()
	_think_wait -= delta
	var think := _think_wait <= 0.0
	if think:
		_think_wait = 0.25
	for id in bots:
		_fly(bots[id], delta, think)
	_bump_each_other()
	_send_wait -= delta
	if _send_wait <= 0.0:
		_send_wait = Arena.SEND_EVERY
		_send()
	# (and drawn here, as everyone else draws them)
	for id in bots:
		var b: Dictionary = bots[id]
		arena.heard_bot(int(id), b["pos"], float(b["turn"]), b["vel"], _flags(b), int(b["score"]), float(b["hull"]) / HULL, str(b["ship"]))


## Taking over the bots from whoever flew them: as they were last seen here
func _take_over() -> void:
	bots.clear()
	for s in arena.remotes:
		if int(s) < Arena.BOT_BASE:
			continue
		var r: Dictionary = arena.remotes[s]
		var u: Ufo = (r["saucer"] as RemoteSaucer).ufo
		var b := _new_bot(int(s))
		b["pos"] = Vector3(u.position.x, 0, u.position.z)
		b["score"] = int(r["score"])
		b["hull"] = float(r["hull"]) * HULL
		bots[int(s)] = b


func _head_count() -> void:
	var want := wanted()
	for i in MOST:
		var id := Arena.BOT_BASE + i
		if i < want and not bots.has(id):
			var b := _new_bot(id)
			b["pos"] = arena.rim_spot()
			bots[id] = b
		elif i >= want and bots.has(id):
			bots.erase(id)
			arena.drop_remote(id)


func _new_bot(id: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([arena.net.seed, id, "bot"])
	return {"id": id, "ship": "saucer", "pos": Vector3.ZERO, "vel": Vector3.ZERO, "turn": 0.0, "hull": HULL, "score": 0,
		"down": -1.0, "safe": Arena.SAFE, "wait": r.randf_range(1.0, 3.0), "beam": false, "beam_t": 0.0, "goal": null,
		"foe": -1, "mood": r.randf_range(0.25, 0.85), "dash": 0.0, "last_hit_by": -1, "wander": Vector3.ZERO}


func _flags(b: Dictionary) -> int:
	return (1 if b["beam"] else 0) | (2 if float(b["down"]) >= 0.0 else 0) | (4 if float(b["dash"]) > 0.0 else 0) | (8 if float(b["safe"]) > 0.0 else 0)


## Where a saucer is (a seat, a bot, or us), and whether it can be fought
func _saucer_at(who: int) -> Vector3:
	if who == arena.net.slot:
		return Vector3(arena.main.ufo.position.x, 0, arena.main.ufo.position.z)
	if bots.has(who):
		return bots[who]["pos"]
	if arena.remotes.has(who):
		var u: Ufo = (arena.remotes[who]["saucer"] as RemoteSaucer).ufo
		return Vector3(u.position.x, 0, u.position.z)
	return Vector3.INF


func _fightable(who: int) -> bool:
	if who == arena.net.slot:
		return not arena.main.ufo.dead and arena.safe <= 0.0 and arena.main.mode == "play"
	if bots.has(who):
		return float(bots[who]["down"]) < 0.0 and float(bots[who]["safe"]) <= 0.0
	if arena.remotes.has(who):
		return not arena.remotes[who]["down"] and not arena.remotes[who]["safe"]
	return false


func _everyone() -> Array:
	var all: Array = [arena.net.slot]
	for s in arena.remotes:
		if int(s) < Arena.BOT_BASE:
			all.append(int(s))
	for id in bots:
		all.append(int(id))
	return all


func _fly(b: Dictionary, delta: float, think: bool) -> void:
	b["safe"] = maxf(float(b["safe"]) - delta, 0.0)
	b["dash"] = maxf(float(b["dash"]) - delta, 0.0)
	if float(b["down"]) >= 0.0:
		b["down"] = float(b["down"]) + delta
		b["beam"] = false
		if float(b["down"]) >= Arena.RESPAWN:
			b["down"] = -1.0
			b["hull"] = HULL
			b["safe"] = Arena.SAFE
			b["pos"] = arena.rim_spot()
			b["vel"] = Vector3.ZERO
		return
	var pos: Vector3 = b["pos"]
	if think:
		_choose(b)
	var want := Vector3.ZERO
	var foe := int(b["foe"])
	var foe_at := _saucer_at(foe) if foe != -1 else Vector3.INF
	var low := float(b["hull"]) < HULL * 0.3
	if foe_at != Vector3.INF and _fightable(foe):
		var off := foe_at - pos
		var d := off.length()
		if low:
			want = -off.normalized()
		elif d > 6.0:
			want = off.normalized()
		else:
			# (round it, close in, and now and then dash into it)
			want = (Vector3(-off.z, 0, off.x).normalized() * 0.7 + off.normalized() * 0.5).normalized()
			if d < 4.5 and float(b["dash"]) <= 0.0 and randf() < delta * 0.6:
				b["dash"] = 0.25
				b["vel"] = off.normalized() * 30.0
		b["wait"] = float(b["wait"]) - delta
		if float(b["wait"]) <= 0.0 and d < REACH and not low:
			b["wait"] = randf_range(1.0, 1.8)
			_shoot(b, foe, foe_at)
		b["beam"] = false
	else:
		var goal = b["goal"]
		if goal != null and is_instance_valid(goal) and (goal as Thing).state == "walk":
			var at := (goal as Thing).ground()
			var off := at - pos
			if off.length() > 1.4:
				want = off.normalized() * clampf(off.length() / 4.0, 0.3, 1.0)
				b["beam"] = off.length() < 3.0
			else:
				b["beam"] = true
				b["beam_t"] = float(b["beam_t"]) + delta
				var thing: Thing = goal
				if float(b["beam_t"]) > 0.6 + float(thing.info["weight"]) * 0.45:
					_take(b, thing)
		else:
			b["beam"] = false
			want = b["wander"]
	var speed := SPEED * (1.3 if low else 1.0)
	if float(b["dash"]) <= 0.0:
		b["vel"] = (b["vel"] as Vector3).lerp(want * speed, minf(delta * 2.5, 1.0))
	pos += (b["vel"] as Vector3) * delta
	# (the rail and the islands bounce it back, as they do everyone)
	var flat := Vector3(pos.x, 0, pos.z)
	var most := Arena.R - 2.4
	if flat.length() > most:
		pos = flat.normalized() * most
		b["vel"] = (b["vel"] as Vector3) - flat.normalized() * maxf((b["vel"] as Vector3).dot(flat.normalized()), 0.0) * 1.9
	for isl: Array in arena._islands:
		var o: Vector3 = pos - (isl[0] as Vector3)
		var reach := float(isl[1]) + 1.6
		if o.length() < reach:
			pos = (isl[0] as Vector3) + o.normalized() * reach
	b["pos"] = pos
	var v: Vector3 = b["vel"]
	if v.length() > 0.5:
		b["turn"] = lerp_angle(float(b["turn"]), atan2(v.x, v.z), minf(delta * 4.0, 1.0))


## What a bot is after: the saucer nearest it if it is in the mood for a fight and one is near, else the
## nearest thing lying about that it can lift, else somewhere to drift to
func _choose(b: Dictionary) -> void:
	var pos: Vector3 = b["pos"]
	var best := -1
	var near := 18.0 * float(b["mood"]) + 6.0
	for who: int in _everyone():
		if who == int(b["id"]) or not _fightable(who):
			continue
		var at := _saucer_at(who)
		var d := at.distance_to(pos)
		if d < near:
			near = d
			best = who
	b["foe"] = best
	if best != -1:
		return
	var goal = b["goal"]
	if goal == null or not is_instance_valid(goal) or (goal as Thing).state != "walk" or (goal as Thing).has_meta("claiming"):
		b["goal"] = null
		b["beam_t"] = 0.0
		var far := 40.0
		for t in arena._here:
			if t == null or not is_instance_valid(t):
				continue
			var thing: Thing = t
			if thing.state != "walk" or thing.has_meta("claiming") or int(thing.info.get("tier", 1)) > 2 or thing in spare:
				continue
			var d := thing.ground().distance_to(pos)
			if d < far:
				far = d
				b["goal"] = thing
	if b["goal"] == null and (b["wander"] as Vector3).length() < 0.1 or randf() < 0.05:
		var a := randf() * TAU
		b["wander"] = Vector3(cos(a), 0, sin(a)) * 0.6


## Its beam on a thing long enough: up it goes, and the server is asked whose it is
func _take(b: Dictionary, thing: Thing) -> void:
	b["goal"] = null
	b["beam_t"] = 0.0
	var id := int(thing.get_meta("arena_id", -1))
	if id < 0:
		return
	thing.set_meta("claiming", true)
	_claims[id] = [int(b["id"]), thing.points()]
	arena.net.claim(id)
	arena.bot_took(thing, b["pos"])


## The server said whose a thing was: the bot's points if ours was the claim
func claimed(id: int, ours: bool) -> bool:
	if not _claims.has(id):
		return false
	var got: Array = _claims[id]
	_claims.erase(id)
	if ours and bots.has(int(got[0])):
		bots[int(got[0])]["score"] = int(bots[int(got[0])]["score"]) + int(got[1])
	return true


func _shoot(b: Dictionary, foe: int, at: Vector3) -> void:
	var from := Vector3(b["pos"].x, 8.0, b["pos"].z)
	var to := at + Vector3(0, 7.5, 0)
	arena.main._zap(from, to)
	if foe == arena.net.slot:
		arena.struck(int(b["id"]), SHOT, to)
	elif bots.has(foe):
		hurt(foe, SHOT, int(b["id"]))
	else:
		arena.bot_shot(foe, int(b["id"]), SHOT, to)


## A bot hit (`power` laser hits' worth) by `by` (a seat or a bot)
func hurt(id: int, power: float, by: int) -> void:
	if not bots.has(id):
		return
	var b: Dictionary = bots[id]
	if float(b["down"]) >= 0.0 or float(b["safe"]) > 0.0:
		return
	b["hull"] = float(b["hull"]) - power * Arena.PVP_HIT
	b["last_hit_by"] = by
	# (and it turns on whoever hit it)
	b["foe"] = by
	if float(b["hull"]) <= 0.0:
		_down(b)


func _down(b: Dictionary) -> void:
	b["down"] = 0.0
	b["beam"] = false
	var lost := int(float(b["score"]) * Arena.LOOT_SHARE)
	b["score"] = int(b["score"]) - lost
	var killer := int(b["last_hit_by"])
	b["last_hit_by"] = -1
	arena.bot_down(int(b["id"]), killer, b["pos"], lost)
	if bots.has(killer):
		bots[killer]["score"] = int(bots[killer]["score"]) + int(150 * Thing.WORTH)


## A bot shot down by a player whose device told us (the bonus is theirs; ours if it was a bot of ours)
func credit_kill(killer: int) -> void:
	if bots.has(killer):
		bots[killer]["score"] = int(bots[killer]["score"]) + int(150 * Thing.WORTH)


func next_drop() -> int:
	_drops += 1
	return _drops


## Bots knock into each other, and into the players' saucers, like bumper cars
func _bump_each_other() -> void:
	var ids := bots.keys()
	var others: Array = []
	for who: int in _everyone():
		if not bots.has(who):
			others.append(_saucer_at(who))
	for i in ids.size():
		var a: Dictionary = bots[ids[i]]
		if float(a["down"]) >= 0.0:
			continue
		var pts: Array = others.duplicate()
		for j in ids.size():
			if j != i and float(bots[ids[j]]["down"]) < 0.0:
				pts.append(bots[ids[j]]["pos"])
		for at: Vector3 in pts:
			if at == Vector3.INF:
				continue
			var off: Vector3 = (a["pos"] as Vector3) - at
			var d := off.length()
			if d < 4.4 and d > 0.01:
				a["pos"] = (a["pos"] as Vector3) + off / d * (4.4 - d) * 0.5
				a["vel"] = (a["vel"] as Vector3) + off / d * 6.0


func _send() -> void:
	var sb := StreamPeerBuffer.new()
	sb.put_u8(bots.size())
	for id in bots:
		var b: Dictionary = bots[id]
		sb.put_u8(int(id))
		sb.put_float((b["pos"] as Vector3).x)
		sb.put_float((b["pos"] as Vector3).z)
		sb.put_float(float(b["turn"]))
		sb.put_float((b["vel"] as Vector3).x)
		sb.put_float((b["vel"] as Vector3).z)
		sb.put_u8(_flags(b))
		sb.put_u32(maxi(int(b["score"]), 0))
		sb.put_u8(clampi(int(float(b["hull"]) / HULL * 255.0), 0, 255))
	arena.net.send(ArenaNet.BROADCAST, Arena.K_BOTS, sb.data_array)
