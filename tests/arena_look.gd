extends SceneTree
## The ARENA to look at (needs a window, and a relay: node tools/dev_relay.mjs <scareathon-v3/server> 3112):
##   godot --path . --resolution 390x844 -s res://tests/arena_look.gd -- <out dir> --server=http://127.0.0.1:3112
## menu (the title with ARENA on its button), in (just in, at the rim), grown (a big score: the saucer
## and its beam grown) and moonbase (a moon base coming apart up its beam)

var main: Node
var frame := 0
var out := ""
var on_at := -1


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
	if t == 90:
		_shot("in")
	if t == 100:
		main.score = 36000
	if t == 260:
		_shot("grown")
		# (over the nearest moon base, beam on)
		var best := Vector3.ZERO
		for p: Array in arena._points:
			if p[0] == "arena_habitat":
				best = p[1]
				break
		main.ufo.position = Vector3(best.x, main.ufo.altitude, best.z + 0.5)
		main.ufo.velocity = Vector3.ZERO
		Input.action_press("beam")
	if t > 260 and t < 420:
		main.ufo.velocity = Vector3.ZERO
	if t == 400:
		_shot("moonbase")
		Input.action_release("beam")
	if t == 430:
		main.set_paused(true)
	if t == 450:
		_shot("pause")
		main.set_paused(false)
		arena.leave()
	return t >= 470
