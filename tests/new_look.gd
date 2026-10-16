extends SceneTree
## Pictures of the newer things, to look over (needs a window):
##   godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/new_look.gd -- <out dir>
## start (the HUD and the cornfield under the ship), stars (sparkles off a swallow), wonder (a police
## car's question mark filling), rival (a rival saucer at its beam), hide (people gone indoors),
## wreck (the crash site, people come to look)

var main: Node
var frame := 0
var out := ""
var _cop: Thing
var _rival: Thing


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://new_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	main._touch_screen = false


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 520:
		main.ufo.hull = main.ufo.hull_max
	match frame:
		30:
			_shot("start")
		40:
			main.spawn("cow", main.ufo.ground() + Vector3(0.2, 0, 0.2))
			Input.action_press("beam")
		75:
			Input.action_release("beam")
			main.ufo.sparkle()
		80:
			_shot("stars")
		90:
			main.heat = 1.0
			_cop = main.spawn("police_car", main.ufo.ground() + Vector3(8, 0, 10))
			_cop.alert = 0.45
		95:
			_shot("wonder")
		140:
			_shot("wonder_full")
		150:
			_remove_cop()
			_rival = main.spawn_rival(main.ufo.ground() + Vector3(14, 0, -6))
			_rival.position.y = 8.5
			main.spawn("cow", main.ufo.ground() + Vector3(15, 0, -6))
		210:
			_shot("rival")
		240:
			for i in 3:
				main.spawn("person", main.ufo.ground() + Vector3(-4 + i * 2, 0, 3))
			main.spawn("house", main.ufo.ground() + Vector3(-8, 0, 8))
		246:
			_shot("hide_before")
		300:
			_shot("hide_after")
		305:
			main.heat = 5.5
			main._five_for = 31.0
			main._nuke_wait = 0.0
			main.ufo.position.x += 20.0
		330:
			_shot("nuke_ring")
		459:
			_shot("nuke_flash")
		475:
			_shot("nuke_cloud")
		500:
			main.heat = 0.0
			_shot("nuke_after")
		520:
			for k in ["COW", "CORN", "PERSON", "CHICKEN", "PIG", "SHEEP", "HAY BALE", "PICKUP", "FARMER", "BARN"]:
				main._run_taken[k] = [2, 120]
			for i in 5:
				main.spawn("person", main.ufo.ground() + Vector3(-30 + i * 3, 0, 25))
			main.ufo.hull = 0.0
			main.ufo.hurt(10.0)
		610:
			_shot("wreck")
		760:
			_shot("wreck_later")
		775:
			main.intro_in_tests = true
			main._over_wait = 0.0
			main.quit_to_menu()
		805:
			_shot("zoom_out_1")
		850, 880, 910, 940:
			_shot("zoom_out_%d" % frame)
		1000:
			_shot("back_home")
		1010:
			main.testing = false
			main._flyby_wait = 0.0
		1011:
			main.testing = true
		1050, 1070, 1090, 1110:
			_shot("flyby_%d" % frame)
			if frame == 1110:
				quit()
	return false


func _remove_cop() -> void:
	if is_instance_valid(_cop):
		main.remove_thing(_cop)
