extends SceneTree
## A screenshot of each region of the West, and of Devils Tower (needs a window):
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/regions.gd -- <out dir>

var main: Node
var frame := 0
var out := ""
var stops: Array = []
var at := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://regions"
	DirAccess.make_dir_recursive_absolute(out)
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	stops.append(["tower", World.TOWER + Vector3(-6, 0, 30)])
	var names := ["farm", "plains", "desert", "mesa", "mountain"]
	for b in 5:
		# (the nearest chunk of that region with the same region all round it)
		var found := Vector2i.ZERO
		var best := INF
		for x in range(-40, 41):
			for z in range(-40, 41):
				var c := Vector2i(x, z)
				if World.biome(c) != b or c.length() > best:
					continue
				var whole := true
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if World.biome(c + d) != b:
						whole = false
				if whole:
					best = c.length()
					found = c
		stops.append([names[b], World.centre_of(found) + Vector3(10, 0, 10)])


func _process(_delta: float) -> bool:
	frame += 1
	main.heat = 0.0
	main.ufo.hull = 100.0
	var stop: Array = stops[at]
	var p: Vector3 = stop[1]
	if frame == 1:
		main.ufo.position = Vector3(p.x, main.ufo.position.y, p.z)
		main.world.update(main.ufo.position, 0.0, true)
	if frame == 90:
		var img := root.get_texture().get_image()
		img.save_png(out.path_join(stop[0] + ".png"))
		print("saved ", stop[0], " at ", p)
		at += 1
		frame = 0
		if at >= stops.size():
			return true
	return false
