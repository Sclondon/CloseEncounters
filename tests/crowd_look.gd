extends SceneTree
## The arena's bank and its folk to look at (needs a window, and a relay: node tools/dev_relay.mjs
## <scareathon-v3/server> 3112): pilot (the title's pilot, one with antennae), crowd (a stand by the gate up
## close: the game's own aliens, baked), camp (a still camp: a parked saucer, aliens in deck chairs and
## standing about), live (one of the live camps), bank (looking along the bank from the floor), rising (a
## bot's catch going up its beam):
##   godot --path . --resolution 390x844 -s res://tests/crowd_look.gd -- <out dir> --server=http://127.0.0.1:3112

var main: Node
var frame := 0
var out := ""
var on_at := -1
var shot := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	if out == "":
		out = "user://crowd_look"
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


## The camera held looking at `at` from `from` (the world's bend round where it looks)
func _look(from: Vector3, at: Vector3) -> void:
	main.hold_camera = true
	main.camera.position = from
	main.camera.look_at(at)
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(at.x, 0.0, at.z))
	RenderingServer.global_shader_parameter_set("saucer_pos", main.camera.position)


func _process(_delta: float) -> bool:
	frame += 1
	var arena: Arena = main.arena
	if frame == 30:
		# (a pilot with antennae: the first seed that gives one)
		for s in range(1, 400):
			var al := Alien.new()
			al.look_seed = s
			root.add_child(al)
			var has: bool = "antenna" in al.extras
			al.free()
			if has:
				main.alien_seed = s
				break
		main.ufo.queue_free()
		main._make_ufo(Vector3.ZERO)
		main._park_ufo(false)
	if frame == 150:
		_shot("pilot")
		main.play_mode = "arena"
		main._show_ship()
	if frame == 180:
		main._play_pressed()
	if not arena.on:
		return frame > 2400
	if on_at < 0:
		on_at = frame
	var t := frame - on_at
	main.ufo.hull = main.ufo.hull_max
	var gate_side := Arena.GATE + 1.0 * TAU / (Arena.STANDS + 1)
	if t == 60:
		var at := Vector3(cos(gate_side), 2.0, sin(gate_side)) * Vector3(Arena.R + 5.5, 1, Arena.R + 5.5)
		var inward := -Vector3(cos(gate_side), 0, sin(gate_side))
		_look(at + inward * 9.0 + Vector3(-inward.z, 0, inward.x) * 3.0 + Vector3(0, 4.5, 0), at + Vector3(0, 2.0, 0))
	if t == 75:
		_shot("crowd")
	var still := Arena.GATE + 3.0 * TAU / (Arena.STANDS + 1)
	if t == 90:
		var at := Vector3(cos(still), 0, sin(still)) * (Arena.R + 9.0) + Vector3(0, Arena.bank_y(Arena.R + 9.0), 0)
		var inward := -Vector3(cos(still), 0, sin(still))
		_look(at + inward * 9.0 + Vector3(-inward.z, 0, inward.x) * 3.5 + Vector3(0, 5.0, 0), at + Vector3(0, 0.5, 0))
	if t == 105:
		_shot("camp")
	var live := Arena.GATE + 5.0 * TAU / (Arena.STANDS + 1)
	if t == 120:
		var at := Vector3(cos(live), 0, sin(live)) * (Arena.R + 9.0) + Vector3(0, Arena.bank_y(Arena.R + 9.0), 0)
		var inward := -Vector3(cos(live), 0, sin(live))
		_look(at + inward * 9.0 + Vector3(-inward.z, 0, inward.x) * 3.5 + Vector3(0, 5.0, 0), at + Vector3(0, 0.5, 0))
	if t == 135:
		_shot("live")
	if t == 150:
		_look(Vector3(0, 6.0, -10.0), Vector3(0, 3.0, -Arena.R - 6.0))
	if t == 165:
		_shot("bank")
		main.hold_camera = false
	# A bot's catch on its way up its beam
	if t > 170 and not shot.has("rising"):
		for th: Thing in main.things:
			if th.state == "carried" and th.position.y > 2.0:
				main.ufo.position = Vector3(th.position.x, main.ufo.altitude, th.position.z + 14.0)
				main.camera.position = Vector3.ZERO
				set_meta("rise_at", t)
				break
		if has_meta("rise_at") and t == int(get_meta("rise_at")) + 4:
			_shot("rising")
	if t > 60 * 60 or shot.has("rising"):
		return true
	return false
