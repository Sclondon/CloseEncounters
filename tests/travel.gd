extends SceneTree
## Flies the saucer a long way across the endless world and checks that chunks are made ahead and
## dropped behind, that what lives in them does not pile up, and that every region turns up.
##   godot --headless --path . --fixed-fps 60 -s res://tests/travel.gd
## Ends with PASSED or FAILED.

var main: Node
var frame := 0
var fails := 0
var seen := {}
var most_chunks := 0
var most_things := 0
var slowest := 0.0


func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.start_mode = "play"
	main.autopilot = true
	main.testing = true
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _process(_delta: float) -> bool:
	frame += 1
	var start := Time.get_ticks_usec()
	main.heat = 0.0
	main.ufo.hull = 100.0
	# A long way north-east and then west: 0.6 m a frame, three times as fast as it flies
	var way := Vector3(1, 0, -1).normalized() if frame < 2400 else Vector3(-1, 0, 0)
	main.ufo.position += way * 0.6
	seen[World.biome(World.chunk_of(main.ufo.position))] = true
	most_chunks = maxi(most_chunks, main.world.chunks.size())
	most_things = maxi(most_things, main.things.size())
	if frame > 10:
		slowest = maxf(slowest, (Time.get_ticks_usec() - start) / 1000.0)
	if frame == 9000:
		print("flew to %s; chunks at most %d, things at most %d" % [main.ufo.position.round(), most_chunks, most_things])
		_check(most_chunks <= 81, "chunks are dropped behind (at most %d)" % most_chunks)
		_check(most_things < 700, "things do not pile up (at most %d)" % most_things)
		_check(seen.size() == 5, "every region turned up (%s)" % [seen.keys()])
		print("PASSED" if fails == 0 else "FAILED")
		return true
	return false
