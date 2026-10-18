extends SceneTree
## Two copies of the game in the ARENA, through a local relay (tools/dev_relay.mjs): both join (and must
## land in the same arena and see each other, and the same bots, flown by A, the lower seat), A beams up a
## moon gem that B must then see gone (claimed by A), B's weapons shoot A down (A drops its loot and comes
## back, untouchable a while, with nothing; B is told it shot A down and sees the loot), B shoots a bot
## down, B beams up A's wreck (A must see it go up B's beam, B's to keep), and both must get the
## standings, bots and all. Run by tools/arena_test.sh, or by hand:
##   godot --headless --path . -s res://tests/arena_test.gd -- --role=a --server=http://127.0.0.1:3112
##   godot --headless --path . -s res://tests/arena_test.gd -- --role=b --server=http://127.0.0.1:3112
## (--shots=<dir> in a window saves pictures along the way)
## With --rounds (and --round=20 --break=6, short rounds) it checks the ROUNDS instead: both copies see
## the round end at the same moment of the arena's clock, agree who won (A, given the most), and come
## back into the next round with nothing (A's item gone too), the bots' scores back to nothing as well.

var main: Node
var frame := 0
var role := "a"
var shots := ""
var on_at := -1
var fails := 0
var target := -1
var target_id := -1
var was_down := false
var saw_down := false
var came_back := false
var score_before := 0
var left := false
var saw_bot_down := false
var bot_target := -1
var rounds := false
var wreck_rose := false
var my_wreck := -1
var round_end_seen := -1.0
var round_two_at := -1


## The other player's seat, and the bots' ids, as this copy sees them
func _humans(arena: Arena) -> Array:
	return arena.remotes.keys().filter(func(s) -> bool: return int(s) < Arena.BOT_BASE)


func _bots(arena: Arena) -> Array:
	var ids: Array = arena.remotes.keys().filter(func(s) -> bool: return int(s) >= Arena.BOT_BASE)
	ids.sort()
	return ids


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
		elif a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
		elif a == "--rounds":
			rounds = true
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "title"
	main.testing = true
	root.add_child(main)
	# (in step with the clock, as the other copy and the server are)
	Engine.max_fps = 60


func _check(ok: bool, what: String) -> void:
	print(("[%s] PASS " if ok else "[%s] FAIL ") % role + what)
	if not ok:
		fails += 1


func _shot(name: String) -> void:
	if shots != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(shots)
		root.get_texture().get_image().save_png(shots.path_join("%s_%s.png" % [role, name]))


## The point both copies aim at: the first pink gem laid out (the same on both, from the arena's seed)
func _gem() -> int:
	for p in main.arena._points.size():
		if main.arena._points[p][0] == "arena_gem_pink":
			return p
	return 0


func _process(_delta: float) -> bool:
	frame += 1
	var arena: Arena = main.arena
	if frame == 20:
		main.ship = "saucer" if role == "a" else "orb"
		if not main.ship in main.unlocked:
			main.unlocked.append(main.ship)
		arena.join()
	if left:
		_check(main.mode == "title" and not main.arena_on, "left the arena for the title")
		return true
	if not arena.on:
		if frame > 1800:
			_check(false, "joined the arena")
			return true
		return false
	if on_at < 0:
		# (the clock starts once each sees the other)
		if _humans(arena).size() < 1 and frame < 1500:
			return false
		on_at = frame
		_check(main.mode == "play" and main.arena_on, "in the arena (seed %d, seat %d)" % [arena.net.seed, arena.net.slot])
		target = _gem()
	var t := frame - on_at
	if rounds:
		return _rounds_test(arena, t)
	# (the bots leave the gem alone, for A to take)
	if arena._here.size() > target and arena._here[target] != null and not arena._here[target] in arena.bots.spare:
		arena.bots.spare.append(arena._here[target])
	if role == "a" and t < 400:
		main.ufo.hull = main.ufo.hull_max
	# (the bots leave the wrecks alone too, for B to take)
	for w in arena.wreck_things:
		if not w in arena.bots.spare:
			arena.bots.spare.append(w)
	main.ufo.hull = maxf(main.ufo.hull, 1.0) if role == "b" else main.ufo.hull
	if t == 90:
		_check(_humans(arena).size() == 1, "sees the other saucer (%d)" % _humans(arena).size())
		_check(_bots(arena).size() == 4, "sees four bots, flown by the lower seat (%s; flying them here: %s)" % [str(_bots(arena)), str(arena.bots.simulating())])
		_check(arena.bots.simulating() == (role == "a"), "the bots are flown by A alone")
		print("[%s] bots %s" % [role, ", ".join(_bots(arena).map(func(i) -> String: return arena.name_of(int(i))))])
		_shot("both")
	if role == "a":
		if t >= 120 and t < 330:
			var p: Vector3 = arena._points[target][1]
			main.ufo.position = Vector3(p.x, main.ufo.altitude, p.z)
			main.ufo.velocity = Vector3.ZERO
			if t == 120:
				target_id = arena._id_at(target, arena.net.arena_time())
				score_before = main.score
				Input.action_press("beam")
		if t == 330:
			Input.action_release("beam")
			_check(main.score > score_before and int(arena.claimed.get(target_id, -1)) == arena.net.slot,
				"beamed up the gem and it is ours (score %d to %d, claimed by %s)" % [score_before, main.score, str(arena.claimed.get(target_id, "nobody"))])
			_shot("taken")
		if arena.down_for >= 0.0:
			was_down = true
		elif was_down and not main.ufo.dead and main.mode == "play" and arena.safe > 0.0:
			if not came_back:
				_check(main.score == 0 and main.level == 0 and str(main.weapons_had()) == str(Ufo.SHIPS[main.ship]["weapons"]), "came back with nothing: score %d, level %d, weapons %s" % [main.score, main.level, str(main.weapons_had())])
			came_back = true
		if arena._wrecks > 0 and my_wreck < 0:
			my_wreck = Arena.WRECK_BASE + (arena.net.slot << 20) + arena._wrecks
		for th: Thing in main.things:
			if th.kind == "arena_wreck" and th.state == "carried" and not wreck_rose:
				wreck_rose = true
				_shot("wreck_rising")
		if t == 900:
			_check(was_down, "shot down by the other saucer")
			_check(wreck_rose and my_wreck >= 0 and int(arena.claimed.get(my_wreck, -1)) != arena.net.slot and arena.claimed.has(my_wreck), "our wreck went up the other's beam, theirs (claimed by %s)" % str(arena.claimed.get(my_wreck, "nobody")))
		if t == 1100:
			_check(came_back, "back in the arena after it, untouchable a while")
	else:
		if t == 360:
			var id: int = arena._id_at(target, arena.net.arena_time())
			var here = arena._here[target]
			var gone: bool = here == null or not is_instance_valid(here) or (here as Thing).state == "gone"
			_check(arena.claimed.has(id) and int(arena.claimed[id]) != arena.net.slot and gone, "the gem the other took is gone here (claimed by %s)" % str(arena.claimed.get(id, "nobody")))
		if t >= 420 and t < 600 and t % 12 == 0 and _humans(arena).size() == 1:
			var s: int = _humans(arena)[0]
			var proxy: Thing = arena.remotes[s]["proxy"]
			if is_instance_valid(proxy) and not proxy.hiding:
				score_before = main.score if score_before == 0 else score_before
				main.weapon_hit(proxy, proxy.position, 2.0)
				if t == 432:
					_shot("hit")
		if _humans(arena).size() == 1 and arena.remotes[_humans(arena)[0]]["down"]:
			saw_down = true
		if t == 630:
			var n := 0
			for th: Thing in main.things:
				if th.kind == "arena_drop":
					n += 1
			set_meta("loot", n)
		# (A's wreck in its crater: beamed up from here)
		if t >= 640 and t < 840:
			var w: Thing = null
			for th: Thing in arena.wreck_things:
				if is_instance_valid(th) and th.state != "gone" and th.get_meta("arena_id", 0) < Arena.WRECK_BASE + (20 << 20):
					w = th
			if w != null:
				main.ufo.position = Vector3(w.position.x, main.ufo.altitude, w.position.z)
				main.ufo.velocity = Vector3.ZERO
				if not Input.is_action_pressed("beam"):
					score_before = main.score
					set_meta("wreck_id", int(w.get_meta("arena_id")))
					Input.action_press("beam")
		if t == 840:
			Input.action_release("beam")
			var wid := int(get_meta("wreck_id", -1))
			_check(wid >= 0 and int(arena.claimed.get(wid, -1)) == arena.net.slot, "beamed up the other's wreck (%d, claimed by %s)" % [wid, str(arena.claimed.get(wid, "nobody"))])
		# (and then one of the bots, shot down from here)
		if t >= 620 and t < 880 and t % 10 == 0 and not saw_bot_down:
			if bot_target == -1 or not arena.remotes.has(bot_target):
				bot_target = int(_bots(arena)[0]) if not _bots(arena).is_empty() else -1
			if bot_target != -1:
				var proxy: Thing = arena.remotes[bot_target]["proxy"]
				if is_instance_valid(proxy) and not proxy.hiding:
					main.weapon_hit(proxy, proxy.position, 2.0)
		if bot_target != -1 and arena.remotes.has(bot_target) and arena.remotes[bot_target]["down"]:
			saw_bot_down = true
		if t == 900:
			var loot := 0
			for th: Thing in main.things:
				if th.kind == "arena_drop":
					loot += 1
			_check(saw_down, "saw the other saucer go down")
			_check(saw_bot_down, "shot a bot down (%s)" % arena.name_of(bot_target))
			_check(int(get_meta("loot", 0)) > 0, "its loot lay about (%d)" % int(get_meta("loot", 0)))
			_shot("loot")
	if t == 940:
		_check(arena.top.size() >= 2, "the standings came (%d on them)" % arena.top.size())
		var rows: Array = arena.standings()
		_check(rows.filter(func(r) -> bool: return r["bot"]).size() == 4, "the board has the bots on it too (%d rows)" % rows.size())
	if t == (1140 if role == "a" else 960):
		print("[%s] %s" % [role, "PASSED" if fails == 0 else "FAILED"])
		arena.leave()
		left = true
	return false


func _rounds_test(arena: Arena, t: int) -> bool:
	if t == 30:
		# (A well ahead, and an item to lose; B a little)
		if role == "a":
			main.arena_scored("arena_rover", 50000)
			main.buy("missiles")
		else:
			main.arena_scored("arena_rover", 300)
	main.ufo.hull = main.ufo.hull_max
	if arena.round_over and round_end_seen < 0.0:
		var at := arena.net.arena_time()
		round_end_seen = at
		var into := fmod(at, arena.round_time + arena.break_time)
		print("[%s] round %d over at arena time %.3f (%.3f into its period)" % [role, arena.round, at, into])
		_check(into >= arena.round_time and into < arena.round_time + 0.3, "the round ended on the arena's clock (%.3f s in, round %.0f s)" % [into, arena.round_time])
		_check(paused, "the game is held still for the standings")
		_shot("round_over")
	if round_end_seen > 0.0 and arena.round_over and frame % 90 == 0 and round_two_at < 0:
		var rows := arena.final_standings()
		print("[%s] standings: %s" % [role, str(rows.map(func(r) -> String: return "%s %d" % [r["name"], r["score"]]))])
	if round_end_seen > 0.0 and not arena.round_over and round_two_at < 0:
		round_two_at = t
		_check(not paused, "play goes on in the next round")
		_check(main.score == 0 and main.level == 0 and str(main.weapons_had()) == str(Ufo.SHIPS[main.ship]["weapons"]), "back with nothing in the next round: score %d, level %d, weapons %s" % [main.score, main.level, str(main.weapons_had())])
		var a_name: String = arena.pilot_name if role == "a" else arena.name_of(_humans(arena)[0])
		_check(int(arena._wins.get(a_name, 0)) == 1, "A won the round, here too (%s)" % str(arena._wins))
		if role == "a":
			var scores: Array = arena.bots.bots.values().map(func(b) -> int: return int(b["score"]))
			_check(scores.all(func(x) -> bool: return x == 0), "the bots back with nothing too (%s)" % str(scores))
	if round_two_at >= 0 and t == round_two_at + 40:
		var here := arena._here.filter(func(x) -> bool: return x != null and is_instance_valid(x)).size()
		_check(here >= int(arena._points.size() * 0.85), "everything lying about fresh (%d of %d)" % [here, arena._points.size()])
		_shot("round_two")
		print("[%s] %s" % [role, "PASSED" if fails == 0 else "FAILED"])
		arena.leave()
		left = true
	if t > 60 * 120:
		_check(false, "a round came to an end")
		print("[%s] FAILED" % role)
		arena.leave()
		left = true
	return false
