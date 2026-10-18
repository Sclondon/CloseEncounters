extends SceneTree
## Two copies of the game in the ARENA, through a local relay (tools/dev_relay.mjs): both join (and must
## land in the same arena and see each other), A beams up a moon gem that B must then see gone (claimed by
## A), B's weapons shoot A down (A drops its loot and comes back, untouchable a while; B is told it shot A
## down and sees the loot), and both must get the standings. Run by tools/arena_test.sh, or by hand:
##   godot --headless --path . -s res://tests/arena_test.gd -- --role=a --server=http://127.0.0.1:3112
##   godot --headless --path . -s res://tests/arena_test.gd -- --role=b --server=http://127.0.0.1:3112
## (--shots=<dir> in a window saves pictures along the way)

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


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
		elif a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
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
		if arena.remotes.size() < 1 and frame < 1500:
			return false
		on_at = frame
		_check(main.mode == "play" and main.arena_on, "in the arena (seed %d, seat %d)" % [arena.net.seed, arena.net.slot])
		target = _gem()
	var t := frame - on_at
	main.ufo.hull = maxf(main.ufo.hull, 1.0) if role == "b" else main.ufo.hull
	if t == 90:
		_check(arena.remotes.size() == 1, "sees the other saucer (%d)" % arena.remotes.size())
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
			came_back = true
		if t == 900:
			_check(was_down, "shot down by the other saucer")
		if t == 1100:
			_check(came_back, "back in the arena after it, untouchable a while")
	else:
		if t == 360:
			var id: int = arena._id_at(target, arena.net.arena_time())
			var here = arena._here[target]
			var gone: bool = here == null or not is_instance_valid(here) or (here as Thing).state == "gone"
			_check(arena.claimed.has(id) and int(arena.claimed[id]) != arena.net.slot and gone, "the gem the other took is gone here (claimed by %s)" % str(arena.claimed.get(id, "nobody")))
		if t >= 420 and t < 600 and t % 12 == 0 and arena.remotes.size() == 1:
			var s: int = arena.remotes.keys()[0]
			var proxy: Thing = arena.remotes[s]["proxy"]
			if is_instance_valid(proxy) and not proxy.hiding:
				score_before = main.score if score_before == 0 else score_before
				main.weapon_hit(proxy, proxy.position, 2.0)
				if t == 432:
					_shot("hit")
		if arena.remotes.size() == 1 and arena.remotes.values()[0]["down"]:
			saw_down = true
		if t == 900:
			var loot := 0
			for th: Thing in main.things:
				if th.kind == "arena_drop":
					loot += 1
			_check(saw_down, "saw the other saucer go down")
			_check(loot > 0, "its loot lies about (%d)" % loot)
			_shot("loot")
	if t == 940:
		_check(arena.top.size() >= 2, "the standings came (%d on them)" % arena.top.size())
	if t == (1140 if role == "a" else 960):
		print("[%s] %s" % [role, "PASSED" if fails == 0 else "FAILED"])
		arena.leave()
		left = true
	return false
