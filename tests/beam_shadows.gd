extends SceneTree
## The beam as a strong light (needs a window): the ship over a farmstead and over trees with the beam
## on, everything in its pool of light casting shadows (main.gd _beam_shadows). Saves shadows_farm.png
## and shadows_trees.png, and shadows_off.png with the beam off, to compare:
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/beam_shadows.gd -- <out dir>

var main: Node
var frame := 0
var out := ""
var farm := Vector3.INF
var trees := Vector3.INF


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://beam_shadows"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)


func _over(p: Vector3) -> void:
	main.ufo.position = Vector3(p.x, main.ufo.position.y, p.z)
	main.ufo.velocity = Vector3.ZERO
	main.world.update(main.ufo.position, 0.0, true)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name, " shadowed things ", main._shadowed.size(), " scenery ", main._shaded_scenery.size())


func _process(_delta: float) -> bool:
	frame += 1
	main.ufo.hull = main.ufo.hull_max
	main.heat = 0.0
	main.ufo.velocity = Vector3.ZERO
	if frame == 20:
		# (a farmhouse with things round it, and a clump of scenery trees)
		for t in main.things:
			if farm == Vector3.INF and t.kind in ["farmhouse", "barn"]:
				farm = t.ground() + Vector3(0, 0, 5)
		for c: Vector2i in main.world.loose:
			for entry: Array in main.world.loose[c]:
				if trees == Vector3.INF and entry[0] in ["tree", "pine", "cottonwood", "willow"]:
					trees = (entry[3] as Transform3D).origin + Vector3(2, 0, 2)
		if farm == Vector3.INF:
			farm = main.ufo.ground()
		_over(farm)
		main.upgrades["beam"] = 1
		main.ufo.tier = 0
	if frame == 60:
		_shot("shadows_off")
		Input.action_press("beam")
	if frame == 100:
		_shot("shadows_farm")
		Input.action_release("beam")
		if trees != Vector3.INF:
			_over(trees)
	if frame == 130:
		Input.action_press("beam")
	if frame == 170:
		_shot("shadows_trees")
		Input.action_release("beam")
		return true
	return false
