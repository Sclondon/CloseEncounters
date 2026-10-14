extends SceneTree
## The title's buttons and the log, as stills (needs a window):
##   godot --path . --resolution 390x844 -s res://tests/log_look.gd -- <out dir>
var main: Node
var frame := 0
var out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://log"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	root.add_child(main)
	main._touch_screen = true
	main._log_taken = {"cow": 12, "sheep": 3, "barn": 1, "jackalope": 1}
	main._log_met.assign(["police_car", "jeep"])


func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		root.get_texture().get_image().save_png(out.path_join("title.png"))
		main.open_log()
	if frame == 40:
		root.get_texture().get_image().save_png(out.path_join("log.png"))
		main.close_log()
	if frame == 50:
		assert(main.title_box.visible, "BACK brings the title back")
		print("LOG LOOK DONE")
	return frame >= 50
