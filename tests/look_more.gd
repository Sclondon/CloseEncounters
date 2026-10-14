extends SceneTree
## Pictures of the newest things (needs a window):
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/look_more.gd -- <out dir>
## town (a police station), base (an army base), watchers (a substation, a radio dish and an
## observatory), drain (the beam on the substation), crop (a crop circle), dash (afterimages),
## sky (the stars)

var main: Node
var out := ""
var plan: Array[Callable] = []
var at := 0
var wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://look_more"
	DirAccess.make_dir_recursive_absolute(out)
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	plan.append(func() -> String:
		_go(Vector3(14, 0, 22))
		return "town")
	plan.append(func() -> String:
		var best := Vector2i.ZERO
		for r in range(4, 40):
			for x in range(-r, r + 1):
				for z: int in [-r, r]:
					if best == Vector2i.ZERO and World.is_base(Vector2i(x, z)):
						best = Vector2i(x, z)
		_go(World.centre_of(best) + Vector3(0, 0, 26))
		return "base")
	plan.append(func() -> String:
		var spot := Vector3(400, 0, 400)
		_go(spot)
		main.spawn("substation", main.world.off_road(spot + Vector3(0, 0, -6), 4.0))
		main.spawn("seti_dish", main.world.off_road(spot + Vector3(16, 0, -14), 3.0))
		main.spawn("observatory", main.world.off_road(spot + Vector3(-16, 0, -16), 4.0))
		return "watchers")
	plan.append(func() -> String:
		main.ufo.hull = 5.0
		_go(main.ufo.position + Vector3(0, 0, -6))
		Input.action_press("beam")
		return "drain")
	plan.append(func() -> String:
		Input.action_release("beam")
		for x in range(-30, 31):
			for z in range(-30, 31):
				var p := Vector3(x * 7.0, 0, z * 7.0)
				if main.world.crops_at(p) and main.world.biome_at(p) == World.Biome.FARM:
					_go(p)
					Input.action_press("beam")
					return "crop"
		return "crop")
	plan.append(func() -> String:
		Input.action_release("beam")
		main.ufo.velocity = Vector3(8, 0, 0)
		main._dodge(Vector2(1, 0))
		return "dash")
	plan.append(func() -> String:
		main.hold_camera = true
		var c: Camera3D = main.camera
		c.position = main.ufo.position + Vector3(0, 3, 12)
		c.look_at(main.ufo.position + Vector3(0, 14, -30))
		return "sky")


func _go(p: Vector3) -> void:
	main.ufo.position = Vector3(p.x, main.ufo.position.y, p.z)
	main.ufo.velocity = Vector3.ZERO
	main.world.update(main.ufo.position, 0.0, true)


func _process(_delta: float) -> bool:
	wait += 1
	main.heat = 0.0
	main.calm = 0.0
	if wait == 1:
		set_meta("name", plan[at].call())
	var long := 200 if str(get_meta("name")) in ["crop", "drain"] else 70
	if str(get_meta("name")) == "dash" and wait == 8:
		long = 8
	if wait == long:
		root.get_texture().get_image().save_png(out.path_join(str(get_meta("name")) + ".png"))
		print("saved ", get_meta("name"))
		at += 1
		wait = 0
		if at >= plan.size():
			return true
	return false