extends SceneTree
## Weapons on the scenery (needs a window): crops, bushes, rocks, benches and the scattered trees are
## drawn many to a MultiMesh, and a weapon stands them up as Things to wreck them (main.gd
## wake_scenery). The TIKTAKKORAX's laser is swept over the crop field the game starts on, then the
## NEBULONK-B's missiles fly by themselves; prints what was wrecked and saves scenery_<ship>.png:
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/scenery_wreck.gd -- <out dir>

var main: Node
var frame := 0
var out := ""
var plan := ["tictac", "frigate"]
var at := 0
var wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://scenery_wreck"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)


func _wrecked() -> int:
	var n := 0
	for g in main._run_wrecked:
		n += int(main._run_wrecked[g][0])
	return n


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	wait += 1
	main.ufo.hull = main.ufo.hull_max
	main.heat = 0.0
	if wait == 1:
		main.ship = plan[at]
		main.start()
		main.autopilot = false
		# (no Things about: only the scenery to shoot at)
		for t in main.things.duplicate():
			if not t.fixed():
				main._remove(t)
		set_meta("before", _wrecked())
	if wait > 1:
		main.ufo.velocity = Vector3.ZERO
		# (the laser swept slowly round under the ship)
		main.ufo.beam_aim = Vector2(cos(wait * 0.02), sin(wait * 0.02)) * 0.8
	if wait == 30:
		Input.action_press("beam")
	if wait == 330:
		root.get_texture().get_image().save_png(out.path_join("scenery_%s.png" % plan[at]))
	if wait == 360:
		Input.action_release("beam")
		print("%s wrecked %d pieces of scenery and things" % [plan[at], _wrecked() - int(get_meta("before"))])
		at += 1
		wait = 0
		if at >= plan.size():
			return true
	return false
