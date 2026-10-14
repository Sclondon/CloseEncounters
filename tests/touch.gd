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
	if frame == 5:
		size = root.get_visible_rect().size
		_touch(0, Vector2(size.x * 0.2, size.y * 0.6), true)
	elif frame > 5 and frame < 20:
		_drag(0, Vector2(size.x * 0.2 + (frame - 5) * 8.0, size.y * 0.6), Vector2(8, 0))
	elif frame == 60:
		_check(main.ufo.velocity.x > 3.0, "a thumb dragged right on the left half steers the ship right (speed %.1f)" % main.ufo.velocity.x)
		_touch(1, Vector2(size.x * 0.8, size.y * 0.6), true)
	elif frame == 70:
		_check(main.ufo.beaming, "a finger held on the right half turns the beam on")
		_touch(1, Vector2(size.x * 0.8, size.y * 0.6), false)
		_touch(0, Vector2(size.x * 0.32, size.y * 0.6), false)
	elif frame == 80:
		_check(not main.ufo.beaming and main.stick_finger == -1 and main.stick == Vector2.ZERO, "letting go stops the beam and lets go of the stick")
		_touch(2, Vector2(size.x * 0.3, size.y * 0.5), true)
	elif frame == 82:
		_drag(2, Vector2(size.x * 0.3 + 120.0, size.y * 0.5), Vector2(120, 0))
		_touch(2, Vector2(size.x * 0.3 + 120.0, size.y * 0.5), false)
	elif frame == 84:
		_check(main.ufo.dodging(), "a quick flick dodges")
	elif frame == 90:
		var button: Button = main._pause_button
		var at := button.get_global_rect().get_center()
		_touch(3, at, true)
	elif frame == 91:
		_touch(3, main._pause_button.get_global_rect().get_center(), false)
	elif frame == 95:
		_check(paused, "the pause button pauses")
		main.quit_to_menu()
	elif frame == 100:
		_check(main.mode == "title" and not paused and main.title_box.visible, "quitting from the pause menu goes back to the title")
		print("PASSED" if fails == 0 else "FAILED")
		return true
	return false
