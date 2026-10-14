extends SceneTree
## The moon title and the flight to Earth, as stills (needs a window):
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/moon_look.gd -- <out dir>
var main: Node
var frame := 0
var out := ""
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://moon"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.intro_in_tests = true
	root.add_child(main)
	main._touch_screen = false
func _process(_d: float) -> bool:
	frame += 1
	if frame == 240:
		main.begin_launch()
	if frame in [120, 236, 272, 330, 400, 470, 560]:
		root.get_texture().get_image().save_png(out.path_join("moon_%03d.png" % frame))
	return frame >= 560