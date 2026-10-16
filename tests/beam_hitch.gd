extends SceneTree
## The frames round the first press of the beam in a run, to catch a stutter there (needs a window):
##   godot --path . --resolution 640x360 --max-fps 60 -s res://tests/beam_hitch.gd

var main: Node
var frame := 0
var _last := 0
var _times: Array = []


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	main._touch_screen = false


func _process(_delta: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	if _last > 0 and frame > 100:
		_times.append([(now - _last) / 1000.0, frame])
	_last = now
	main.ufo.hull = main.ufo.hull_max
	if frame == 150:
		Input.action_press("beam")
	if frame == 260:
		Input.action_release("beam")
	if frame == 300:
		_times.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		print("[beam] worst frames (ms, frame; beam on at 150): ", _times.slice(0, 6))
		quit()
	return false
