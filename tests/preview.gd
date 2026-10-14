extends SceneTree
## The arcade shelf's preview film: the saucer flying itself, beaming things up while the heat
## climbs and the police and army come. Record it with Godot's movie maker:
##   godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie <out.avi> -s res://tests/preview.gd

var main: Node
var frame := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.start_mode = "play"
	main.autopilot = true
	main.testing = true
	main.intro_in_tests = true
	root.add_child(main)
	# (no touch controls in the film, whatever this machine has)
	main._touch_screen = false


func _process(_delta: float) -> bool:
	frame += 1
	main.ufo.hull = maxf(main.ufo.hull, 60.0)
	match frame:
		240:
			main.heat = 1.6
		420:
			main.heat = 3.2
		600:
			main.heat = 4.3
	return frame >= 720
