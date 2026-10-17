extends SceneTree
## The STAR BIT BLASTER at work (needs a window): three of it, four police cars about the ship, the
## camera close. Saves star_bits_<frame>.png, and prints how far off the cars are and how many have
## been blown up as it goes (they should be knocked back, and take a good while to go):
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/star_bits.gd -- <out dir>

var main: Node
var frame := 0
var out := ""
var cars: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://star_bits"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	main.ufo.hull = main.ufo.hull_max
	if frame == 90:
		main.score = 90000
		for i in 3:
			main.buy("starbits")
		main.heat = 2.5
		for i in 4:
			var a := i * TAU / 4.0
			cars.append(main.spawn("police_car", main.ufo.ground() + Vector3(cos(a), 0, sin(a)) * 8.0))
	if frame > 90:
		main.ufo.velocity = Vector3.ZERO
		main.heat = maxf(main.heat, 2.5)
	if frame > 90 and frame % 60 == 0:
		var far := []
		var gone := 0
		for c in cars:
			if c == null or not is_instance_valid(c):
				gone += 1
			else:
				far.append(snappedf((c as Node3D).global_position.distance_to(main.ufo.ground()), 0.1))
		print("t=%.1fs cars off at %s, %d blown up, star-bit hits on them %s" % [(frame - 90) / 60.0, str(far), gone,
			str(cars.filter(func(c) -> bool: return c != null and is_instance_valid(c)).map(func(c) -> String: return "%d+%.2f" % [int(c.get_meta("zapped", 0)), float(c.get_meta("star_bits", 0.0))]))])
	if frame in [150, 200, 260]:
		root.get_texture().get_image().save_png(out.path_join("star_bits_%d.png" % frame))
	return frame >= 90 + 60 * 12
