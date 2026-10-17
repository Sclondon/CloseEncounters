extends SceneTree
## A car dropped among things (needs a window): other cars (they should go up after it, one by one),
## a police car, an outhouse, a tree and a fence (brought down), a house (damaged), a cow (thrown back
## and running). Prints what is left and saves car_drop_<frame>.png:
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/car_drop.gd -- <out dir>

var main: Node
var frame := 0
var out := ""
var put := {}
var at := Vector3.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://car_drop"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)


func _report(when: String) -> void:
	var left := []
	for k: String in put:
		var t = put[k]
		if t == null or not is_instance_valid(t) or t.state == "gone":
			left.append("%s: GONE" % k)
		else:
			left.append("%s: %.1f m, hurt %.1f" % [k, (t as Node3D).global_position.distance_to(at), float(t.get_meta("burnt", 0.0))])
	print(when, "  ", ", ".join(left))


func _process(_delta: float) -> bool:
	frame += 1
	main.ufo.hull = main.ufo.hull_max
	main.heat = 0.0
	if frame == 60:
		at = main.ufo.ground() + Vector3(0, 0, -4)
		for t in main.things.duplicate():
			if t.ground().distance_to(at) < 14.0:
				main._remove(t)
		var plan := {"dropped": ["car", Vector3.ZERO], "car_a": ["car", Vector3(3.0, 0, 0)], "car_b": ["pickup", Vector3(5.5, 0, 1.5)],
			"police": ["police_car", Vector3(-3.0, 0, 1.0)], "outhouse": ["outhouse", Vector3(-2.5, 0, -2.5)], "tree": ["tree", Vector3(1.5, 0, -3.5)],
			"fence": ["fence", Vector3(-4.5, 0, -1.0)], "house": ["house", Vector3(0, 0, 6.5)], "cow": ["cow", Vector3(-1.0, 0, 4.0)]}
		for k: String in plan:
			put[k] = main.spawn(plan[k][0], at + plan[k][1])
		_report("before")
	if frame == 70:
		main.landed(put["dropped"], 6.0)
	if frame in [72, 85, 100]:
		root.get_texture().get_image().save_png(out.path_join("car_drop_%d.png" % frame))
	if frame == 200:
		_report("after ")
		return true
	return false
