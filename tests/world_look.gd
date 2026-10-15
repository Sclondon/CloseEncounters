extends SceneTree
## Pictures of the places in the world, to look over (needs a window):
##   godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/world_look.gd -- <out dir>
## town (main street, a clock tower), farm (a farmhouse with its porch, rows of crops), hill, lake,
## airfield

var main: Node
var frame := 0
var out := ""
var stops: Array = []
var at := 0
var wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://world_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	main._touch_screen = false
	stops.append(["town", Vector3(-6, 0, 6)])
	stops.append(["farm", _find(func(c: Vector2i) -> bool: return World.biome(c) == World.Biome.FARM and not World.has_road(c.x) and not World.has_road(c.y) and maxi(absi(c.x), absi(c.y)) == 1)])
	stops.append(["hill", _find(func(c: Vector2i) -> bool: return _open(c) and World.hash3(c.x, c.y, 141) >= 0.07 and World.hash3(c.x, c.y, 142) < 0.16)])
	stops.append(["lake", _find(func(c: Vector2i) -> bool: return _open(c) and World.hash3(c.x, c.y, 141) < 0.07)])
	stops.append(["airfield", _find(func(c: Vector2i) -> bool: return _open_any(c) and World.airfield(c))])


func _open_any(c: Vector2i) -> bool:
	return not World.has_road(c.x) and not World.has_road(c.y) and World.facility(c) == "" and not World.is_base(c) and not World.near_tower(c)


func _open(c: Vector2i) -> bool:
	return _open_any(c) and World.biome(c) in [World.Biome.FARM, World.Biome.PLAINS, World.Biome.MOUNTAIN] and not World.airfield(c)


## The middle of the nearest chunk that passes `test`
func _find(test: Callable) -> Vector3:
	for r in range(1, 40):
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if maxi(absi(x), absi(z)) != r:
					continue
				if test.call(Vector2i(x, z)):
					return World.centre_of(Vector2i(x, z))
	return Vector3.INF


func _process(_delta: float) -> bool:
	frame += 1
	main.heat = 0.0
	main._banner("", 0.0)
	main.ufo.velocity = Vector3.ZERO
	wait += 1
	if wait == 1:
		var p: Vector3 = stops[at][1]
		if p == Vector3.INF:
			print("no ", stops[at][0], " found")
			wait = 1000
		else:
			main.ufo.position = Vector3(p.x, main.ufo.position.y, p.z + 6.0)
			main.world.update(main.ufo.position, 0.0, true)
	if wait == 60:
		root.get_texture().get_image().save_png(out.path_join(str(stops[at][0]) + ".png"))
		print("saved ", stops[at][0], " at ", stops[at][1])
	if wait >= 60:
		at += 1
		wait = 0
	return at >= stops.size()
