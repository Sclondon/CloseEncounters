extends SceneTree
## Frames of the flight from the moon into the descent, every fourth and every one round the
## handoff (the ship should stay put in the picture throughout; needs a window):
##   godot --path . --fixed-fps 30 --resolution 1280x720 -s res://tests/launch.gd -- <out dir>
var main: Node
var frame := 0
var out := ""
var began := -1
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://launch"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.intro_in_tests = true
	root.add_child(main)
	main._touch_screen = false
func _process(_d: float) -> bool:
	frame += 1
	if frame == 40:
		main.begin_launch()
	if frame >= 60 and (frame % 4 == 0 or (frame >= 156 and frame <= 176) or (frame >= 66 and frame <= 100 and frame % 2 == 0)):
		root.get_texture().get_image().save_png(out.path_join("f_%03d_%s.png" % [frame, main.mode]))
	return frame >= 40 + 130 + 140
