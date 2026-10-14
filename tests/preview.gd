extends SceneTree
## The arcade shelf's preview film: the pilot lounging on the moon, hopping in and flying off to
## Earth, then the saucer flying itself, beaming things up while the heat climbs and the police and
## army come. Record it with Godot's movie maker:
##   godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie <out.avi> -s res://tests/preview.gd

## Frames on the moon before PLAY, and of the run after the descent
const ON_MOON := 80
const FLYING := 480

var main: Node
var frame := 0
## The frame the run began (after the flight from the moon), -1 until then
var began := -1


func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.testing = true
	main.intro_in_tests = true
	root.add_child(main)
	# (no touch controls in the film, whatever this machine has)
	main._touch_screen = false


func _process(_delta: float) -> bool:
	frame += 1
	if frame == ON_MOON:
		main.begin_launch()
	if began < 0:
		if main.mode == "play":
			began = frame
			main.autopilot = true
		return false
	main.ufo.hull = maxf(main.ufo.hull, 60.0)
	# (the heat climbing once the descent is over: 4.5 s, 135 frames)
	match frame - began:
		300:
			main.heat = 1.6
		420:
			main.heat = 3.2
		530:
			main.heat = 4.3
	return frame - began >= 135 + FLYING
