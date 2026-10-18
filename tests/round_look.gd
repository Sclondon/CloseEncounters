extends SceneTree
## The arena's ROUNDS to look at (needs a window, and a relay: node tools/dev_relay.mjs <scareathon-v3/server> 3112),
## with short rounds: clock (the round's clock by the board), last (the last ten seconds, red), over (the
## ROUND OVER board, fireworks and all):
##   godot --path . --resolution 390x844 -s res://tests/round_look.gd -- <out dir> --server=http://127.0.0.1:3112 --round=25 --break=8

var main: Node
var frame := 0
var out := ""
var shot := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	if out == "":
		out = "user://round_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "title"
	main.testing = true
	root.add_child(main)
	Engine.max_fps = 60


func _shot(name: String) -> void:
	if shot.has(name):
		return
	shot[name] = true
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _process(_delta: float) -> bool:
	frame += 1
	var arena: Arena = main.arena
	if frame == 60:
		main.play_mode = "arena"
		main._show_ship()
	if frame == 100:
		main._play_pressed()
	if not arena.on:
		return frame > 2000
	main.ufo.hull = main.ufo.hull_max
	var left := arena.round_left(arena.net.arena_time())
	if frame == 300:
		main.arena_scored("arena_rover", 4200)
	if not arena.round_over and left < 20.0 and left > 12.0:
		_shot("clock")
	if not arena.round_over and left < 6.0 and left > 4.0:
		_shot("last")
	if arena.round_over and left + arena.break_time < arena.break_time - 2.0:
		_shot("over")
		return true
	return frame > 60 * 120
