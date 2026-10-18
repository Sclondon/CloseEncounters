extends SceneTree
## Cars and a police car near and far toward the horizon, from the game's camera (needs a window): their
## windows should sit on them however far off they are (pane.gdshader bends with the world):
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/glass_look.gd -- <out dir>

var main: Node
var frame := 0
var out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://glass_look"
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
	if frame == 60:
		var at: Vector3 = main.ufo.ground()
		for i in 6:
			main.spawn("car" if i % 2 == 0 else "police_car", at + Vector3(-4.0 + (i % 2) * 8.0, 0, -8.0 - i * 9.0))
	if frame == 75:
		root.get_texture().get_image().save_png(out.path_join("glass.png"))
	return frame >= 76
