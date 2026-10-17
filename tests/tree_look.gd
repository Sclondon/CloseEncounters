extends SceneTree
## The grown trees (ps1.gd GROWN: GameCommon's LeafyTree, and the pine) in a row by the ship, close and
## from the game's own camera (needs a window):
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/tree_look.gd -- <out dir>

var main: Node
var frame := 0
var out := ""
const KINDS := ["tree", "aspen", "cottonwood", "willow", "pinyon", "pine"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://tree_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	main.ufo.hull = main.ufo.hull_max
	main.heat = 0.0
	if frame > 60:
		main.ufo.velocity = Vector3.ZERO
	var at: Vector3 = main.ufo.ground() + Vector3(0, 0, -18)
	if frame == 60:
		for t in main.things.duplicate():
			if t.ground().distance_to(at) < 16.0:
				main._remove(t)
		for i in KINDS.size():
			main.spawn(KINDS[i], at + Vector3(-7.5 + i * 3.0, 0, (i % 2) * 2.0))
	if frame == 120:
		root.get_texture().get_image().save_png(out.path_join("trees_game.png"))
		main.hold_camera = true
	if frame > 120:
		var c: Camera3D = main.camera
		c.position = at + Vector3(0, 4.0, 14.0)
		c.look_at(at + Vector3(0, 3.0, 0))
		RenderingServer.global_shader_parameter_set("saucer_pos", main.ufo.position)
		RenderingServer.global_shader_parameter_set("bend_focus", Vector3(at.x, 0.0, at.z + 4.0))
	if frame == 140:
		root.get_texture().get_image().save_png(out.path_join("trees_close.png"))
	return frame >= 141
