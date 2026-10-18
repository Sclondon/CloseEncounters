extends SceneTree
## The ARENA to look at (needs a window, and a relay: node tools/dev_relay.mjs <scareathon-v3/server> 3112):
##   godot --path . --resolution 390x844 -s res://tests/arena_look.gd -- <out dir> --server=http://127.0.0.1:3112
## menu (the title with ARENA on its button), in (just in, at the rim), fight (in among the bots, their
## pink beams and the board with them on it), crowd (the stands full of aliens, cheering), camp (aliens
## tailgating by a parked saucer), log (the side log after taking a few things: their own names),
## horizon (looking out over the rim), levelup (the Moon Market's pick, in the arena), moonbase (a moon
## base coming apart up the beam), pause

var main: Node
var frame := 0
var out := ""
var on_at := -1
var log_due := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	if out == "":
		out = "user://arena_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "title"
	main.testing = true
	root.add_child(main)
	Engine.max_fps = 60


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


## Our ship held at `at` (on the floor), still
func _hold(arena: Arena, at: Vector3) -> void:
	main.ufo.position = Vector3(at.x, main.ufo.altitude, at.z)
	main.ufo.velocity = Vector3.ZERO
	# (the camera straight there, not sweeping across the floor after it)
	main.camera.position = Vector3.ZERO


func _process(_delta: float) -> bool:
	frame += 1
	var arena: Arena = main.arena
	if frame == 60:
		main.play_mode = "arena"
		main._show_ship()
	if frame == 100:
		_shot("menu")
		main._play_pressed()
	if not arena.on:
		return frame > 1500
	if on_at < 0:
		on_at = frame
	var t := frame - on_at
	main.ufo.hull = main.ufo.hull_max
	if t == 90:
		_shot("in")
	# In among the bots: the nearest held under us a while
	if t > 100 and t < 300:
		var near := Vector3.ZERO
		var far := 999.0
		for s in arena.remotes:
			if int(s) >= Arena.BOT_BASE:
				var p: Vector3 = (arena.remotes[s]["saucer"] as RemoteSaucer).ufo.position
				if p.distance_to(main.ufo.position) < far:
					far = p.distance_to(main.ufo.position)
					near = p
		if t == 101:
			_hold(arena, near + Vector3(0, 0, 9))
		main.ufo.velocity = Vector3.ZERO
		if t == 290:
			_shot("fight")
	# The stands, up close from the floor's edge, the crowd cheering
	if t == 310:
		arena.excite(1.0)
		# (the camera looks north: from south of the first stand round from the gate)
		var a := Arena.GATE + TAU / (Arena.STANDS + 1)
		_hold(arena, Vector3(cos(a), 0, sin(a)) * (Arena.R + 5.5) + Vector3(0, 0, 13))
	if t > 310 and t < 360:
		main.ufo.velocity = Vector3.ZERO
	if t == 355:
		_shot("crowd")
	# A camp: by its parked saucer
	if t == 370 and not arena._parked.is_empty():
		# (the camp furthest north, from just south of it, inside the rail)
		var u: Ufo = arena._parked[0]
		for p: Ufo in arena._parked:
			if p.position.z < u.position.z:
				u = p
		var at := u.position * Vector3(1, 0, 1) + Vector3(0, 0, 12)
		if at.length() > Arena.R - 3.0:
			at = at.normalized() * (Arena.R - 3.0)
		_hold(arena, at)
	if t > 370 and t < 420:
		main.ufo.velocity = Vector3.ZERO
	if t == 415:
		_shot("camp")
	# A few things taken, for the log's lines
	if t >= 430 and t < 700:
		var best: Thing = null
		for th in arena._here:
			if th != null and is_instance_valid(th) and (th as Thing).state == "walk" and float((th as Thing).info["weight"]) <= 1.0:
				if best == null or (th as Thing).ground().distance_to(main.ufo.ground()) < best.ground().distance_to(main.ufo.ground()):
					best = th
		# (over the next once nothing is going up the beam)
		var lifting: bool = main.things.filter(func(x) -> bool: return x.state == "lifted").size() > 0
		if best != null and not lifting and t % 10 == 0:
			_hold(arena, best.ground())
		main.ufo.velocity = Vector3.ZERO
		if t == 431:
			Input.action_press("beam")
	# (the log shot a moment after the third thing taken, while its lines are up)
	if log_due < 0 and t > 430 and main.taken >= 3:
		log_due = t + 45
	if t == log_due:
		_shot("log")
	if t == 700:
		Input.action_release("beam")
		if log_due < 0:
			_shot("log")
	# Out over the rim, at the horizon
	if t == 710:
		_hold(arena, Vector3(0, 0, -Arena.R + 6.0))
	if t > 710 and t < 760:
		main.ufo.velocity = Vector3.ZERO
	if t == 755:
		_shot("horizon")
	# A level-up's pick, in the arena
	if t == 770:
		main.score = main.level_at(main.level + 1) + 10
	if t == 800:
		_shot("levelup")
		if main._picker.visible:
			main._pick(str(main._picks.get_child(0).get_meta("what", ""))) if main._picks.get_child_count() > 0 and main._picks.get_child(0).has_meta("what") else main._picked("")
	if t == 830:
		var best := Vector3.ZERO
		for p: Array in arena._points:
			if p[0] == "arena_habitat":
				best = p[1]
				break
		_hold(arena, best + Vector3(0, 0, 0.5))
		main.ufo.tier = 3
		Input.action_press("beam")
	if t > 830 and t < 990:
		main.ufo.velocity = Vector3.ZERO
	if t == 980:
		_shot("moonbase")
		Input.action_release("beam")
	if t == 1000:
		main.set_paused(true)
	if t == 1020:
		_shot("pause")
		main.set_paused(false)
		arena.leave()
	return t >= 1040
