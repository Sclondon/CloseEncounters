extends SceneTree
## The dev room's TEST ROOM (needs a window; --resolution 390x844, and 844x390 or 1280x720):
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/test_room_look.gd -- <out dir>
## room (the FIZZWIGGLER's lightning gun on the DPS dummy, its numbers over it, the rows of things
## behind), panel (the TEST panel open: the ship, every item's stack, police / tank / helicopter, RESET,
## CLOSE, EXIT), fight (a police car spawned, the BLORPMOTHER with five AUTO TURRETs). Prints the dummy's
## numbers.

var main: Node
var frame := 0
var out := ""
## Frames since the test room was opened (it waits for the title)
var since := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://test_room_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "title"
	root.add_child(main)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("%s: test_room %s ship %s dummy total %.2f last %.2f, slots %d, paused %s" % [name, main.test_room, main.ship, main._dummy_total, main._dummy_last, main._test_slots.size(), paused])


func _process(_delta: float) -> bool:
	frame += 1
	if since < 0:
		if main.mode == "title" and frame > 30:
			if not main.dev:
				main.toggle_dev()
			main.ship = "foo"
			main.open_test_room()
			since = 60
		return frame > 3000
	since += 1
	match since:
		340:
			Input.action_press("aim_up", 0.75)
			Input.action_press("beam")
		470:
			_shot("room")
			Input.action_release("beam")
			Input.action_release("aim_up")
			main._toggle_test_panel()
		485:
			_shot("panel")
			main._test_ship(-1)
		500:
			# (the BLORPMOTHER: five turrets, against a police car)
			main.ship = "cigar"
			main._toggle_test_panel()
			main._test_ship(0)
			main._toggle_test_panel()
			for i in 4:
				main._test_stack("turret", 1)
			main._test_foe("police_car")
		620:
			_shot("fight")
			return true
	return false
