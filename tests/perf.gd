extends SceneTree
## How heavy the game is to run: the ship flies itself for a while through town and country, and every
## couple of seconds this prints the frame time, the script time, draw calls, objects drawn and
## things alive (needs a window):
##   godot --path . --resolution 1280x720 -s res://tests/perf.gd
var main: Node
var frame := 0
var worst := 0.0
var sum := 0.0
var n := 0
func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.autopilot = true
	main.testing = true
	root.add_child(main)
func _process(delta: float) -> bool:
	frame += 1
	main.ufo.hull = main.ufo.hull_max
	if frame > 60:
		worst = maxf(worst, delta)
		sum += delta
		n += 1
	if frame % 120 == 0:
		print("f%4d  fps %5.1f  process %5.2f ms  draws %4d  objects %4d  prims %6d  things %3d" % [frame,
			Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), main.things.size()])
	if frame == 1200:
		print("average frame %.2f ms, worst %.2f ms" % [sum / n * 1000.0, worst * 1000.0])
		return true
	return false