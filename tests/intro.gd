extends SceneTree
## Frames of the descent from space at the start of a run (needs a window):
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/intro.gd -- <out dir>
var main: Node
var frame := 0
var out := ""
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://intro"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	main.intro_in_tests = true
	root.add_child(main)
	main._touch_screen = false
func _process(_d: float) -> bool:
	frame += 1
	if frame in [20, 80, 140, 200, 280]:
		root.get_texture().get_image().save_png(out.path_join("intro_%03d.png" % frame))
	return frame >= 280