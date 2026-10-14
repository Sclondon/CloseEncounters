extends SceneTree
## Screenshots to look over (needs a window, not --headless):
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/shots.gd -- <out dir>
## title, play (beaming), heat (with police and army), close (the alien in its dome)

var main: Node
var frame := 0
var out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.testing = true
	root.add_child(main)


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		200:
			_shot("title")
			main.autopilot = true
			main.start()
		500:
			_shot("play")
			main.heat = 3.6
		1300:
			main.ufo.hull = 100.0
			_shot("heat")
		1310:
			main.hold_camera = true
	if frame > 1310:
		var c: Camera3D = main.camera
		c.position = main.ufo.position + Vector3(0, 1.6, 4.0)
		c.look_at(main.ufo.position + Vector3(0, 0.9, 0))
	if frame == 1320:
		_shot("close")
		return true
	if frame > 500:
		main.ufo.hull = 100.0
	return false
