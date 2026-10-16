extends SceneTree
## The arcade shelf's preview film: the pilot lounging on the moon, hopping in and flying off to
## Earth, then the saucer flying itself, beaming things up while the heat climbs and the police and
## army come. Record it with Godot's movie maker:
##   godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie <out.avi> -s res://tests/preview.gd

## Frames on the moon before PLAY, and of the run after the descent
const ON_MOON := 8
const FLYING := 560

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
	# (a country of farms and plains all round where the run starts: no mesa filling the picture)
	for s in range(1, 400):
		World.world_seed = s
		var open := true
		for x in range(-4, 5):
			for z in range(-4, 5):
				if World.biome(World.chunk_of(World.START) + Vector2i(x, z)) in [World.Biome.MESA, World.Biome.DESERT, World.Biome.MOUNTAIN]:
					open = false
		if open:
			main.coop_seed = s
			break
	World.world_seed = 0


func _process(_delta: float) -> bool:
	frame += 1
	if frame == ON_MOON:
		main.begin_launch()
	# (the stretch out in space, between the moon and the farm, hurried through)
	var in_space: bool = main.mode == "launch" and main._launch_t > 3.6 or main.mode == "play" and main.intro > 2.0
	Engine.time_scale = 3.0 if in_space else 1.0
	# (no level-ups in the film: the ship as a new run has it)
	main.levels_on = false
	if began < 0:
		if main.mode == "play":
			began = frame
			main.autopilot = true
		return false
	main.ufo.hull = maxf(main.ufo.hull, 60.0)
	# (nothing staged: the ship as a new run has it, flying itself as a player would, the heat and
	# the police coming as they come)
	return frame - began >= 135 + FLYING
