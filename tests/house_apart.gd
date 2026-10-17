extends SceneTree
## A house taken up the beam, and a barn blown up (needs a window): each should come apart in the
## very parts it was built of, the house's from the top down up into the ship, the barn's thrown out
## and falling back. Saves apart_<frame>.png:
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/house_apart.gd -- <out dir>

var main: Node
var frame := 0
var out := ""
var house: Thing
var barn: Thing


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://house_apart"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	main.ufo.hull = main.ufo.hull_max
	main.heat = 0.0
	if frame > 60:
		main.ufo.velocity = Vector3.ZERO
	if frame == 60:
		main.ufo.tier = 3
		var at: Vector3 = main.ufo.ground()
		for t in main.things.duplicate():
			if t.ground().distance_to(at) < 16.0:
				main._remove(t)
		house = main.spawn("house", at)
		barn = main.spawn("barn", at + Vector3(9, 0, -3))
	if frame == 70:
		Input.action_press("beam")
	if frame in [100, 140, 180, 200, 220]:
		root.get_texture().get_image().save_png(out.path_join("apart_%d.png" % frame))
		if is_instance_valid(house):
			print("frame %d: house lift %.2f, %d of %d parts gone" % [frame, house.lift, house._parts_gone, house._parts.size()])
	if frame == 240:
		Input.action_release("beam")
		if is_instance_valid(barn):
			main._blast(barn, 999.0)
	if frame in [250, 265, 290]:
		root.get_texture().get_image().save_png(out.path_join("apart_%d.png" % frame))
	return frame >= 300
