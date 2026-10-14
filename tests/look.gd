extends SceneTree
## Pictures of the newer things to look over (needs a window):
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/look.gd -- <out dir>
## ship_<each of Ufo.ORDER> (the title with each), aliens (four pilots close up), trader,
## patrol (a searchlight sweeping)

var main: Node
var frame := 0
var out := ""
var plan: Array[Callable] = []
var at := 0
var wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://look"
	DirAccess.make_dir_recursive_absolute(out)
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.testing = true
	root.add_child(main)
	for i in 4:
		plan.append(func() -> String:
			main.alien_seed = 1000 + i * 77
			main._pick_ship(0)
			main.hold_camera = true
			main.title_box.visible = false
			return "alien_%d" % i)
	for i in Ufo.ORDER.size():
		plan.append(func() -> String:
			main.hold_camera = false
			main.title_box.visible = true
			if i > 0:
				main._pick_ship(1)
			return "ship_" + main.ship)
	plan.append(func() -> String:
		main._pick_ship(1)
		main.start()
		var s: Shop = main.shops[0]
		main.score = 450
		main.ufo.position = Vector3(s.position.x - 4.0, main.ufo.position.y, s.position.z + 10.0)
		return "trader")
	plan.append(func() -> String:
		var patrol: Thing
		for t in main.things:
			if t.info.get("searchlight", false):
				patrol = t
		if patrol == null:
			patrol = main.spawn("patrol_car", main.ufo.ground() + Vector3(8, 0, -14))
		main.ufo.position = Vector3(patrol.position.x - 6.0, main.ufo.position.y, patrol.position.z + 10.0)
		return "patrol")


func _process(_delta: float) -> bool:
	frame += 1
	wait += 1
	main.heat = 0.0
	if main.hold_camera:
		var c: Camera3D = main.camera
		c.position = main.ufo.position + Vector3(0, 1.4, 3.2)
		c.look_at(main.ufo.position + Vector3(0, 1.0, 0))
	if wait == 1:
		var name: String = plan[at].call()
		set_meta("name", name)
	if wait == 70:
		var img := root.get_texture().get_image()
		img.save_png(out.path_join(str(get_meta("name")) + ".png"))
		print("saved ", get_meta("name"))
		at += 1
		wait = 0
		if at >= plan.size():
			return true
	return false
