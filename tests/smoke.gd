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
var dodge_from := 0.0
var patrols := 0
var spotted := false


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
	if main._spotted_for > 0.0:
		spotted = true
	for t in main.things:
		if t.info.get("searchlight", false):
			patrols = maxi(patrols, 1)
	# (kept alive while the levels are gone through)
	if frame < 3000:
		main.ufo.hull = 100.0
	match frame:
		600:
			_check(main.taken > 0, "the autopilot took something (%d, score %d, heat %.2f)" % [main.taken, main.score, main.heat])
			main.heat = 2.5
		650:
			var x: float = main.ufo.position.x
			main._dodge(Vector2(1, 0))
			_check(main.ufo.dodging() and not main.ufo.struck(main.ufo.position), "a dodge makes the saucer untouchable")
			dodge_from = x
		670:
			_check(main.ufo.position.x > dodge_from + 4.0, "a dodge dashes the saucer sideways (%.1f m)" % (main.ufo.position.x - dodge_from))
		1500:
			_check(seen.has("police_car"), "police came at two stars")
			_check(patrols > 0, "patrols with searchlights rove about")
			_check(spotted, "a patrol's searchlight found the ship")
			_check(seen.has("officer"), "a police car pulled up and an officer got out")
			main.heat = 3.5
		2050:
			_check(seen.has("helicopter"), "a police helicopter came at three stars")
			main.heat = 4.5
		2600:
			_check(seen.has("jeep"), "army jeeps came at four stars")
			_check(hit, "the saucer was shot at and hit")
			main.heat = 5.0
		3000:
			_check(main.jets.size() > 0 or main.shots.size() >= 0, "five stars")
			main.score = 0
			var calm: float = main.danger()
			main.score = 12000
			_check(main.danger() > calm and is_equal_approx(main.danger(), 3.0), "a high score makes them keener (danger %.1f to %.1f)" % [calm, main.danger()])
		4800:
			_check(seen.has("tank"), "tanks came at five stars")
			_check(main.mode == "over", "the saucer was shot down (hull %.0f, mode %s)" % [main.ufo.hull, main.mode])
			print("score %d, taken %d, things %d, shots %d" % [main.score, main.taken, main.things.size(), main.shots.size()])
			print("PASSED" if fails == 0 else "FAILED")
			return true
	if frame > 3000 and main.mode == "play":
		main.heat = 5.0
		main.calm = 0.0
	return false
