extends SceneTree
## Pictures of the newer ships and upgrades to look over (needs a window; try a phone's shape too,
## --resolution 390x844 or 844x390):
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/look_ships.gd -- <out dir> [ship,ship,...|all] [only]
## fly_<ship> and close_<ship> for each ship named (the jelly if none; "only" skips the rest); laser (a bolt at the police);
## fleet (the little saucers beaming up chickens); captured (a ship held in a secret facility)

var main: Node
var frame := 0
var out := ""
var plan: Array[Callable] = []
var at := 0
var wait := 0
var close := false
## Whether to wait for the laser to fire before taking the picture
var zap := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://look_ships"
	DirAccess.make_dir_recursive_absolute(out)
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)
	var ships: Array = ["jelly"]
	if args.size() > 1:
		ships = Array(Ufo.ORDER) if args[1] == "all" else Array(args[1].split(","))
	for s: String in ships:
		plan.append(func() -> String:
			close = false
			main.hold_camera = false
			main.ship = s
			main.start()
			main.autopilot = true
			return "fly_" + s)
		plan.append(func() -> String:
			close = true
			main.hold_camera = true
			return "close_" + s)
	if args.size() > 2 and args[2] == "only":
		return
	plan.append(func() -> String:
		close = false
		main.hold_camera = false
		main.ship = "saucer"
		main.start()
		main.autopilot = false
		main.score = 90000
		for i in 4:
			main.buy("turret")
		main.heat = 3.5
		for i in 2:
			main.spawn("police_car", main.ufo.ground() + Vector3(-7 + i * 13, 0, -6 + i * 3))
		zap = true
		return "laser")
	plan.append(func() -> String:
		zap = false
		for t in main.things.duplicate():
			if t.is_enemy():
				main._remove(t)
		main.heat = 0.0
		for i in 4:
			main.buy("fleet")
		for i in 10:
			var a := i * TAU / 10.0
			main.spawn(["chicken", "sheep", "pig"][i % 3], main.ufo.ground() + Vector3(cos(a), 0, sin(a)) * randf_range(5.0, 10.0))
		return "fleet")
	plan.append(func() -> String:
		var c := Vector2i.ZERO
		for r in range(6, 40):
			for x in range(-r, r + 1):
				for z: int in [-r, r]:
					if c == Vector2i.ZERO and World.facility(Vector2i(x, z)) == "bell":
						c = Vector2i(x, z)
		var p := World.centre_of(c)
		main.ufo.position = Vector3(p.x, main.ufo.position.y, p.z + 11.0)
		main.world.update(main.ufo.position, 0.0, true)
		main.hold_camera = true
		main.camera.position = p + Vector3(5.0, 4.5, 9.0)
		main.camera.look_at(p + Vector3(0, 1.0, 0))
		# (the world bends away from where the camera was: it is told where it is now)
		RenderingServer.global_shader_parameter_set("bend_focus", p + Vector3(0, 0, 4.0))
		return "captured")


func _process(_delta: float) -> bool:
	frame += 1
	wait += 1
	if main.mode == "play" and not zap:
		main.heat = 0.0
	main.ufo.hull = main.ufo.hull_max
	if close:
		var c: Camera3D = main.camera
		var r: float = main.ufo.radius
		c.position = main.ufo.position + Vector3(r * 0.9, 1.0 + r * 0.45, r * 2.0)
		c.look_at(main.ufo.position + Vector3(0, 0.3, 0))
		# (a held camera leaves these where they were: the ship would be drawn see-through)
		RenderingServer.global_shader_parameter_set("saucer_pos", main.ufo.position)
		RenderingServer.global_shader_parameter_set("bend_focus", Vector3(main.ufo.position.x, 0.0, main.ufo.position.z))
	if wait == 1:
		var name: String = plan[at].call()
		set_meta("name", name)
	# (the laser's picture is taken the frame after it fires)
	var ready: bool = wait >= 150 if not zap else (wait > 40 and main._laser_wait > main.laser_reload() - 0.04) or wait > 600
	if ready:
		var img := root.get_texture().get_image()
		img.save_png(out.path_join(str(get_meta("name")) + ".png"))
		print("saved ", get_meta("name"))
		at += 1
		wait = 0
		if at >= plan.size():
			return true
	return false
