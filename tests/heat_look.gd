extends SceneTree
## The heat's eye and cooling, and the men in black after a crash (needs a window):
##   godot --path . --fixed-fps 30 --resolution <390x844|844x390|1280x720> -s res://tests/heat_look.gd -- <out dir>
## eye_seen (a police car's light on the ship), eye_shut (nobody looking, the heat not cooling yet),
## eye_cool (cooling); then flies straight off with two stars and police about, printing the heat and
## how much of the time the ship was seen every 5 s; then crashes and checks that both agents are
## gone once the men in black drive off (mib_<t>.png along the way; "mib" after the out dir for only that)

var main: Node
var frame := 0
var out := ""
var _phase := "eye"
var _t := 0.0
var _seen_time := 0.0
var _next_print := 5.0
var _cop: Thing
var _crash_at := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://heat_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	main._touch_screen = false
	# ("mib" after the out dir: straight to the crash)
	if args.size() > 1 and args[1] == "mib":
		_phase = "flee"
		_t = 82.0


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _clear_enemies() -> void:
	for t in main.things.duplicate():
		if t.is_enemy():
			main._remove(t)


func _process(delta: float) -> bool:
	frame += 1
	if main.ufo != null and _phase != "crash":
		main.ufo.hull = main.ufo.hull_max
	match _phase:
		"eye":
			main._banner("", 0.0)
			if frame == 60:
				main.heat = 2.3
				main.calm = 0.0
				_clear_enemies()
				main.spawn("police_car", main.ufo.ground() + Vector3(-9, 0, 6))
			if frame > 60 and frame < 150:
				main.calm = 0.0
			if frame == 150:
				print("seen ", main.seen, " heat ", main.heat)
				_shot("eye_seen")
				_clear_enemies()
				main.seen = 0.0
			if frame == 158:
				main.calm = 0.0
				_shot("eye_shut")
			if frame == 160:
				main.calm = 100.0
			if frame == 170:
				_shot("eye_cool")
				print("cooling ", main.cooling(), " heat ", main.heat)
				_phase = "flee"
				_t = 0.0
				main.heat = 2.5
				main.calm = 0.0
				_clear_enemies()
				Input.action_press("up")
				Input.action_press("right")
		"flee":
			_t += delta
			if main.seen > 0.0:
				_seen_time += delta
			if _t >= _next_print:
				print("t %3d  heat %.2f  seen %.0f%%  enemies %d" % [int(_t), main.heat, 100.0 * _seen_time / _t,
					main.things.filter(func(x: Thing) -> bool: return x.is_enemy()).size()])
				_next_print += 5.0
			if _t > 90.0:
				Input.action_release("up")
				Input.action_release("right")
				_phase = "crash"
				_clear_enemies()
				main.heat = 0.0
				main.ufo.hull = 0.0
				main.ufo.hurt(1.0)
				_crash_at = frame
				# (the army should leave once the ship is down, the police stay: see main.gd _army_away)
				var g: Vector3 = main.ufo.ground()
				for k: Array in [["tank", Vector3(14, 0, 4)], ["jeep", Vector3(-12, 0, 6)], ["helicopter", Vector3(6, 9, -10)], ["police_car", Vector3(-9, 0, -8)]]:
					var th: Thing = main.spawn(k[0], g + k[1])
					if th != null:
						th.set_meta("test_force", k[0])
						if k[0] == "police_car":
							_cop = th
		"crash":
			var wt: float = main._wreck_t
			if frame % 45 == 0 and main._mib_car != null:
				var mt: float = (wt - main.MIB_COME) * main.MIB_PACE
				_shot("mib_%02d" % int(mt))
				print("mib t %.1f  a %s  b %s  car %s" % [mt, main._mib_a.visible, main._mib_b.visible, main._mib_car.visible])
			# (on past the men in black to the news vans pulling up)
			if frame % 60 == 0 and _cop != null:
				print("cop t %.0f valid %s state %s leaving %s off %.1f" % [wt, is_instance_valid(_cop), _cop.state if is_instance_valid(_cop) else "-", _cop.leaving if is_instance_valid(_cop) else "-", (_cop.ground().distance_to(main.wreck) if is_instance_valid(_cop) else -1.0)])
				if not is_instance_valid(_cop) or _cop.state == "gone":
					_cop = null
			if frame % 300 == 0:
				var forces := []
				for th: Thing in main.things:
					if th.has_meta("test_force"):
						forces.append("%s%s" % [th.get_meta("test_force"), " leaving" if th.leaving else ""])
				print("wreck t %.0f: forces left %s, tape posts %d, markers %d" % [wt, str(forces), main._scene_done, main._scene_marks])
			# (on past the men in black to the news vans pulling up and the police taping the scene off)
			if wt > main.MIB_COME + 50.0 / main.MIB_PACE:
				var ok: bool = main._mib_a != null and not main._mib_a.visible and not main._mib_b.visible and not main._mib_car.visible
				print("MIB ALL GONE: ", ok)
				return true
			if frame - _crash_at > 9000:
				print("no wreck sequence?")
				return true
	return false
