extends SceneTree
## Pictures of the effects in a run, to look over (needs a window):
##   godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/fx_look.gd -- <out dir>
## flying (dust in the air, clouds, the reticle on the ground), beam (the beam on, aimed off to the
## right), patrol (a searchlight),
## booth_run and booth_call (a witness running to a phone booth and calling, radio waves off its
## aerial), booth_cut (the same with the lines down: sparks), windmill, smoking (the shield gone)

var main: Node
var frame := 0
var out := ""
var shots: Array[String] = []
var _booth: Thing
var _caller: Thing


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://fx_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	main._touch_screen = false


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _booth_scene(cut: bool) -> void:
	_booth = null
	for t in main.things:
		if t.kind == "phone_booth" and t.state == "walk":
			_booth = t
			break
	if _booth == null:
		_booth = main.spawn("phone_booth", main.ufo.ground() + Vector3(10, 0, -6), {"turn": PI / 2})
	main.ufo.position = Vector3(_booth.position.x + 3.0, main.ufo.position.y, _booth.position.z + 6.0)
	_caller = main.spawn("person", _booth.position + Vector3(9, 0, 5))
	main._cuts.clear()
	if cut:
		main._cuts.append(_booth.position)
	_caller.witness()


func _process(_delta: float) -> bool:
	frame += 1
	main.heat = 0.0
	if frame > 425:
		main.ufo.hull = 0.0
		main.heat = 1.2
	if main.hold_camera and _booth != null:
		var far := 2.2 if _booth.kind == "windmill" else 1.0
		main.camera.position = _booth.position + Vector3(5.0, 4.0, 7.0) * far
		main.camera.look_at(_booth.position + Vector3(0, 2.2, 0) * far * far)
	match frame:
		40:
			main.autopilot = true
		100:
			_shot("flying")
		110:
			main.autopilot = false
			main.ufo.velocity = Vector3.ZERO
			Input.action_press("beam")
		122:
			main.beam_finger = 7
			main._beam_at = Vector2(400, 300)
		123:
			main._beam_at = Vector2(700, 300)
			main.spawn("cow", main.ufo.ground() + Vector3(0.3, 0, 0.2))
		150:
			_shot("beam")
			main.beam_finger = main.NO_FINGER
			Input.action_release("beam")
		140:
			var patrol: Thing = main.spawn("patrol_car", main.ufo.ground() + Vector3(8, 0, -14))
			main.ufo.position = Vector3(patrol.position.x - 6.0, main.ufo.position.y, patrol.position.z + 10.0)
		190:
			_shot("patrol")
		200:
			_booth_scene(false)
			main.hold_camera = true
		215:
			_shot("booth_run")
		285:
			_shot("booth_call")
		305:
			main._remove(_caller)
			_booth_scene(true)
		375:
			_shot("booth_cut")
			var mill: Thing = main.spawn("windmill", main.ufo.ground() + Vector3(-30, 0, -12), {"size": 1.6})
			_booth = mill
		420:
			_shot("windmill")
		425:
			main.hold_camera = false
			_booth = null
			main.ufo.hull = 0.0
			main.autopilot = true
		450:
			_shot("smoking")
			print("[smoke] bits ", main.ufo.puffs._bits.size(), " hull ", main.ufo.hull, " parked ", main.ufo.parked)
			if main.ufo.puffs._bits.size() > 0:
				print("[smoke] at ", main.ufo.puffs._bits[0]["node"].global_position, " ufo ", main.ufo.global_position, " pg ", main.ufo.puffs.global_position)
	return frame >= 455
