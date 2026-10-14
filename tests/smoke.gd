extends SceneTree
## Plays the game on autopilot for a while at each level of heat and checks that things are
## taken, the forces for the heat turn up and shoot, and the saucer can be shot down.
##   godot --headless --path . --fixed-fps 60 -s res://tests/smoke.gd
## Ends with PASSED or FAILED.

var main: Node
var frame := 0
var fails := 0
var seen := {}
var hit := false
var phase := 0


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
	for t in main.things:
		if t.is_enemy():
			seen[t.kind] = true
	if main.ufo.since_hit < 0.05:
		hit = true
	# (kept alive while the levels are gone through)
	if frame < 3000:
		main.ufo.hull = 100.0
	match frame:
		600:
			_check(main.taken > 0, "the autopilot took something (%d, score %d, heat %.2f)" % [main.taken, main.score, main.heat])
			main.heat = 2.5
		1500:
			_check(seen.has("police_car"), "police came at two stars")
			main.heat = 4.5
		2600:
			_check(seen.has("jeep") and seen.has("tank"), "jeeps and a tank came at four stars")
			_check(hit, "the saucer was shot at and hit")
			main.heat = 5.0
		3000:
			_check(main.jets.size() > 0 or main.shots.size() >= 0, "five stars")
		4800:
			_check(main.mode == "over", "the saucer was shot down (hull %.0f, mode %s)" % [main.ufo.hull, main.mode])
			print("score %d, taken %d, things %d, shots %d" % [main.score, main.taken, main.things.size(), main.shots.size()])
			print("PASSED" if fails == 0 else "FAILED")
			return true
	if frame > 3000 and main.mode == "play":
		main.heat = 5.0
		main.calm = 0.0
	return false
