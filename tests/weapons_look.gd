extends SceneTree
## The weapons (needs a window; phone first: --resolution 390x844, and 844x390 or 1280x720):
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/weapons_look.gd -- <out dir> [market]
## lightning (the FIZZWIGGLER's lightning gun aimed out among cows, cars and the police), lightning_big
## (with three SIZE RAYs), sling (the KRAKKATOOM's sling flung by hand at a mark, and where it lands),
## starbits (the KRYSTALLIX-9's star bits sprayed by hand), rainbow (the CARNIVORB's beam), beam_green / beam_blue / beam_purple (the beam's colour by BEAMs), turret (the BLORPMOTHER's auto turret
## firing its amber tracers), laser (the ENTERBLORPRISE's laser ray), emp (the TIKTAKKORAX's EMP among the police), market (both slots full, a new weapon picked: drop one?). With
## "market" only the last. Prints what each did.

var main: Node
var frame := 0
var out := ""
var plan: Array[Callable] = []
var at := 0
var wait := 0
var shots: Array = []
var name_now := ""
var score_from := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://weapons_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)
	if not (args.size() > 1 and args[1] == "market"):
		plan.append(func() -> void: _ship("foo", ["cow", "cow", "car", "police_car", "sheep", "house"], Vector2(0.0, -0.7), "lightning", [43, 46]))
		plan.append(func() -> void:
			main.upgrades["wide"] = 3
			main._apply_upgrades()
			_ship("foo", ["cow", "pickup", "police_car", "tree", "fence", "cow"], Vector2(0.0, -0.7), "lightning_big", [25], false))
		plan.append(func() -> void: _ship("meteor", ["police_car", "cow", "car", "tree", "house", "sheep"], Vector2(0.0, -0.8), "sling", [20, 45, 85, 130]))
		plan.append(func() -> void: _ship("diamond", ["police_car", "cow", "sheep", "car", "fence"], Vector2(0.0, -0.8), "starbits", [70, 120]))
		plan.append(func() -> void:
			_ship("cigar", ["police_car", "cow", "car", "sheep"], Vector2(0.0, -0.5), "turret", [4, 8], true, false)
			main._laser_wait = 0.0
			main._prop_wait = 0.0)
		plan.append(func() -> void:
			_ship("trek", ["police_car", "cow", "sheep", "fence"], Vector2(0.0, -0.6), "laser", [30])
			main.aimed = "laser")
		plan.append(func() -> void: _ship("carnival", ["cow", "sheep", "chicken"], Vector2.ZERO, "rainbow", [40]))
		for tier: Array in [[1, "beam_green"], [3, "beam_blue"], [5, "beam_purple"]]:
			plan.append(func() -> void:
				_ship("saucer", ["cow", "sheep"], Vector2.ZERO, tier[1], [40])
				main.upgrades["beam"] = tier[0]
				main._apply_upgrades())
		plan.append(func() -> void:
			_ship("tictac", ["police_car", "police_car", "car", "phone_pole", "street_light"], Vector2.ZERO, "emp", [8], true, false)
			main.ufo.charge = 3.0)
	plan.append(func() -> void:
		main.ship = "trek"
		main.start()
		main.testing = false
		main._picker.visible = true
		main._picker_dim.visible = true
		main._picker.custom_minimum_size = Vector2(1200 if main._upright() else 660, 0)
		main._picker_title.add_theme_font_size_override("font_size", 110 if main._upright() else 56)
		main._pick_one.add_theme_font_size_override("font_size", 50 if main._upright() else 26)
		main._ask_drop("lightning")
		name_now = "market"
		shots = [20])


## A ship, things set out in front of it, the aim pushed out (`aim`) and the button held (`hold`)
func _ship(s: String, kinds: Array, aim: Vector2, name: String, when: Array, fresh := true, hold := true) -> void:
	main.testing = true
	if fresh:
		main.ship = s
		main.start()
		main.levels_on = false
	name_now = name
	shots = when
	for t in main.things.duplicate():
		if t.ground().distance_to(main.ufo.ground()) < 22.0 and not t.fixed():
			main._remove(t)
	var front: Vector3 = main.target_point() if aim == Vector2.ZERO else main.ufo.ground() + Vector3(aim.x, 0, aim.y) * main.aim_reach()
	for i in kinds.size():
		var a := i * TAU / kinds.size()
		main.spawn(kinds[i], front + Vector3(cos(a), 0, sin(a)) * (0.8 + 0.7 * (i % 3)))
	for action in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		Input.action_release(action)
	if aim.x > 0.0:
		Input.action_press("aim_right", aim.x)
	elif aim.x < 0.0:
		Input.action_press("aim_left", -aim.x)
	if aim.y > 0.0:
		Input.action_press("aim_down", aim.y)
	elif aim.y < 0.0:
		Input.action_press("aim_up", -aim.y)
	if hold:
		Input.action_press("beam")
	else:
		Input.action_release("beam")
	score_from = main.score


func _process(_delta: float) -> bool:
	frame += 1
	if main.ufo != null:
		main.ufo.hull = main.ufo.hull_max
		main.heat = minf(main.heat, 1.5)
		main.ufo.velocity = Vector3.ZERO
	if frame < 30:
		return false
	wait += 1
	if wait == 1:
		plan[at].call()
	if name_now == "emp" and wait == 6:
		main._dodge(Vector2(1, 0))
	if name_now == "lightning_big" and wait == 2:
		Input.action_press("beam")
	if wait in shots:
		var tag := name_now if shots.size() == 1 else "%s_%d" % [name_now, wait]
		root.get_texture().get_image().save_png(out.path_join(tag + ".png"))
		print("%s: weapons %s aimed %s, score +%d, wrecked %s, killed %s" % [tag, main.weapons_had(), main.aimed, main.score - score_from, main._run_wrecked, main._run_killed])
	if wait >= shots.max() + 1:
		Input.action_release("beam")
		at += 1
		wait = 0
		if at >= plan.size():
			return true
	return false
