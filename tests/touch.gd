extends SceneTree
## Touch controls, with finger events sent through the same road a phone's take: a thumb dragged on
## the left half steers, a finger held on the right half beams, a quick flick dodges, and the
## pause button pauses.
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://tests/touch.gd
## (in a real window: a headless one is tiny, and scales every touch out of place)
## Ends with PASSED or FAILED.

var main: Node
var frame := 0
var fails := 0
var size := Vector2.ZERO


func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _touch(index: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)


func _drag(index: int, at: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	e.relative = rel
	Input.parse_input_event(e)


func _process(_delta: float) -> bool:
	frame += 1
	main.heat = 0.0
	main.ufo.hull = main.ufo.hull_max
	match frame:
		5:
			size = root.get_visible_rect().size
			_touch(0, Vector2(size.x * 0.2, size.y * 0.6), true)
		60:
			_check(main.ufo.velocity.x > 3.0, "a thumb dragged right on the left half steers the ship right (speed %.1f)" % main.ufo.velocity.x)
			_touch(0, Vector2(size.x * 0.32, size.y * 0.6), false)
			# A thumb that comes down and stays still: the stick appears under it, and nothing moves
			main.ufo.velocity = Vector3.ZERO
			_touch(4, Vector2(size.x * 0.1, size.y * 0.45), true)
		100:
			_check(main.stick_finger == 4 and main.stick_from.distance_to(Vector2(size.x * 0.1, size.y * 0.45)) < 1.0 and main.stick == Vector2.ZERO and main.ufo.velocity.length() < 1.0,
				"a thumb held still: the stick comes up under it, and the ship does not move (speed %.1f)" % main.ufo.velocity.length())
			_touch(4, Vector2(size.x * 0.1, size.y * 0.45), false)
			_touch(1, Vector2(size.x * 0.8, size.y * 0.6), true)
		110:
			_check(main.ufo.beaming, "a finger held on the right half turns the beam on")
			_touch(1, Vector2(size.x * 0.8, size.y * 0.6), false)
		120:
			_check(not main.ufo.beaming and main.stick_finger == -1 and main.stick == Vector2.ZERO, "letting go stops the beam and lets go of the stick")
			_touch(2, Vector2(size.x * 0.3, size.y * 0.5), true)
		122:
			_drag(2, Vector2(size.x * 0.3 + 120.0, size.y * 0.5), Vector2(120, 0))
			_touch(2, Vector2(size.x * 0.3 + 120.0, size.y * 0.5), false)
		124:
			_check(main.ufo.dodging(), "a quick flick dodges")
		130:
			_touch(3, main._pause_button.get_global_rect().get_center(), true)
		131:
			_touch(3, main._pause_button.get_global_rect().get_center(), false)
		135:
			_check(paused, "the pause button pauses")
			main.quit_to_menu()
		140:
			_check(main.mode == "title" and not paused and main.title_box.visible, "quitting from the pause menu goes back to the title")
			main._touch_screen = true
			main.start()
		150:
			# As an iPhone sent it: no finger down at all, only drags with a huge identifier, then up
			_drag(1273130520, Vector2(size.x * 0.25, size.y * 0.5), Vector2(-8, 0))
		151:
			_drag(1273130520, Vector2(size.x * 0.24, size.y * 0.5), Vector2(-8, 0))
		190:
			_check(main.stick_finger == 1273130520 and main.ufo.velocity.length() > 3.0, "a drag whose finger-down was lost still takes the stick (speed %.1f)" % main.ufo.velocity.length())
			_touch(1273130520, Vector2(size.x * 0.24, size.y * 0.5), false)
		200:
			_check(main.stick_finger == main.NO_FINGER, "and lifting it lets go")
			_touch(7, Vector2(size.x * 0.3, size.y * 0.3), true)
		202:
			_touch(7, Vector2(size.x * 0.3, size.y * 0.3), false)
		203:
			_check(main._move_target != Vector3.INF, "a tap on the ground sets where to fly")
		240:
			_check(main.ufo.velocity.length() > 2.0 or main._move_target == Vector3.INF, "and the ship flies there (speed %.1f)" % main.ufo.velocity.length())
			_touch(8, main.beam_button.get_global_rect().get_center(), true)
		242:
			_touch(8, main.beam_button.get_global_rect().get_center(), false)
		244:
			_check(main.ufo.beaming and main.beam_latched, "a tap on the beam's mark turns the beam on")
		270:
			_touch(9, main.beam_button.get_global_rect().get_center(), true)
		272:
			_touch(9, main.beam_button.get_global_rect().get_center(), false)
		274:
			_check(not main.beam_latched, "and another tap turns it off")
			print("PASSED" if fails == 0 else "FAILED")
			return true
	if frame > 5 and frame < 20:
		_drag(0, Vector2(size.x * 0.2 + (frame - 5) * 8.0, size.y * 0.6), Vector2(8, 0))
	return false