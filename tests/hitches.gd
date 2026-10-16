extends SceneTree
## Times every frame through the flight off the moon and the descent, and prints the worst: a frame
## far over 17 ms (at 60 a second) is a hitch (needs a window; desktop shaders are made far faster
## than a phone browser's, so a hitch here is a big one there):
##   godot --path . --resolution 640x360 --max-fps 60 -s res://tests/hitches.gd
var main: Node
var frame := 0
var last := 0
var worst := []
func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.intro_in_tests = true
	root.add_child(main)
	main._touch_screen = false
	last = Time.get_ticks_usec()
func _process(_d: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	var ms := (now - last) / 1000.0
	last = now
	if frame == 60:
		main.begin_launch()
	if frame > 60:
		worst.append([ms, frame, main.mode])
	if frame >= 60 + 720:
		worst.sort_custom(func(a, b): return a[0] > b[0])
		print("[hitch] worst frames: ", worst.slice(0, 6))
		return true
	return false
