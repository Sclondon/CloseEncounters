extends SceneTree
var main: Node
var f := 0
func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		var w: World = main.world
		var worst := 0.0
		var by := {}
		for x in range(8, 20):
			for z in range(8, 20):
				var c := Vector2i(x, z)
				if w.chunks.has(c):
					continue
				var t0 := Time.get_ticks_usec()
				w._make(c)
				var ms := (Time.get_ticks_usec() - t0) / 1000.0
				var k := "%d/%d" % [World.biome(c), World.field(c)]
				by[k] = maxf(by.get(k, 0.0), ms)
				worst = maxf(worst, ms)
		print("[chunk] worst make %.1f ms; by biome/field: %s" % [worst, by])
		var t1 := Time.get_ticks_usec()
		main._spawn_some(true)
		print("[chunk] spawning all that waited: %.1f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
		quit()
	return false
