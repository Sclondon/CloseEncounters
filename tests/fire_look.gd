extends SceneTree
## Pictures of the newer weapon effects (needs a window; a phone's shape first):
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/fire_look.gd -- <out dir>
## heat_1 / heat_3 (the TIKTAKKORAX's heat ray on a farmstead, plain and with three SIZE RAYs: the ray, the
## mark and the burn wider together), burning (what it set alight, a few seconds on), spread (the fire
## gone on through the crops), magnet (MAGNET x2 pulling chickens and sheep in), sling_a / sling_b (the
## KRAKKATOOM's moonlet on its tether, just flung and halfway), bolt (the lightning gun's bolt the frame it
## strikes), items (all eight new items on the item bar)

var main: Node
var frame := 0
var out := ""
var step := 0
var wait := 0
var shot := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://fire_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _fresh(s: String) -> void:
	Input.action_release("beam")
	_aim(Vector2.ZERO)
	main.ship = s
	main.start()
	main.autopilot = false
	# (no coming down from space: straight to it)
	main.intro = 0.0
	main.ufo.descent = 0.0
	for t in main.things.duplicate():
		if not t.fixed():
			main._remove(t)


## The aim pushed out, as the aiming keys would (a held thumb or the keys set it each frame)
func _aim(aim: Vector2) -> void:
	for action in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		Input.action_release(action)
	if aim.x > 0.0:
		Input.action_press("aim_right", minf(aim.x, 1.0))
	elif aim.x < 0.0:
		Input.action_press("aim_left", minf(-aim.x, 1.0))
	if aim.y > 0.0:
		Input.action_press("aim_down", minf(aim.y, 1.0))
	elif aim.y < 0.0:
		Input.action_press("aim_up", minf(-aim.y, 1.0))


func _around(kinds: Array, centre: Vector3, r: float) -> void:
	for i in kinds.size():
		var a := i * TAU / kinds.size()
		main.spawn(kinds[i], centre + Vector3(cos(a), 0, sin(a)) * r)


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	wait += 1
	main.ufo.hull = main.ufo.hull_max
	main.heat = 0.0
	main.ufo.velocity = Vector3.ZERO
	match step:
		0:
			if wait == 1:
				_fresh("tictac")
				var g: Vector3 = main.ufo.ground() + Vector3(0, 0, -7)
				main.spawn("house", g + Vector3(3.5, 0, -2))
				_around(["tree", "hay_bale", "cow", "fence", "person", "tree"], g, 3.0)
				_aim(Vector2(0.0, -0.55))
			if wait == 20:
				Input.action_press("beam")
			if wait > 20:
				# (swept round the ring of things, as far out as they stand: see Main.aim_reach)
				var ring := Vector3(sin(wait * 0.05), 0, cos(wait * 0.05)) * 3.0 + Vector3(0, 0, -7)
				_aim(Vector2(ring.x, ring.z) / main.aim_reach())
			if wait == 80:
				_save("heat_1")
			if wait == 90:
				for i in 3:
					main.buy("wide")
			if wait == 140:
				_save("heat_3")
			if wait == 170:
				Input.action_release("beam")
			if wait == 260:
				_save("burning")
				print("burning now: %d" % main._burning.size())
			if wait == 520:
				_save("spread")
				print("burning later: %d" % main._burning.size())
				step += 1
				wait = 0
		1:
			if wait == 1:
				_fresh("saucer")
				for i in 2:
					main.buy("magnet")
				_around(["chicken", "sheep", "chicken", "pig", "chicken", "sheep", "rabbit", "chicken"], main.ufo.ground(), 7.5)
				Input.action_press("beam")
			if wait == 50:
				_save("magnet")
				Input.action_release("beam")
				step += 1
				wait = 0
		2:
			if wait == 1:
				_fresh("meteor")
				_around(["cow", "sheep", "person", "cow"], main.ufo.ground() + Vector3(0, 0, -10), 3.0)
				_aim(Vector2(0.0, -0.75))
				main._sling_wait = 0.0
			if wait == 10:
				Input.action_press("beam")
			if wait == 12:
				Input.action_release("beam")
			if not main._slung.is_empty():
				var age: float = main._slung[0]["age"]
				if age > 0.12 and not shot.has("sling_a"):
					shot["sling_a"] = true
					_save("sling_a")
				if age > 0.55 and not shot.has("sling_b"):
					shot["sling_b"] = true
					_save("sling_b")
			if wait == 200:
				step += 1
				wait = 0
		3:
			if wait == 1:
				_fresh("foo")
				for i in 2:
					main.buy("lightning")
				_around(["cow", "sheep", "person", "cow", "sheep", "person", "cow", "sheep"], main.ufo.ground() + Vector3(0, 0, -7), 4.0)
				_aim(Vector2(0.0, -0.6))
			if wait == 20:
				Input.action_press("beam")
			if wait > 25 and not shot.has("bolt") and main._bolts.size() > 0 and float(main._bolts[-1][2]) < 0.02:
				shot["bolt"] = true
				_save("bolt")
			if wait == 300:
				Input.action_release("beam")
				step += 1
				wait = 0
		4:
			if wait == 1:
				_fresh("saucer")
				for k: String in ["damage", "cooldown", "elite", "crowbar", "splitter", "ignition", "gasoline", "wildfire"]:
					main.buy(k)
			if wait == 60:
				_save("items")
				return true
	return false
