extends SceneTree
## A secret government facility: it holds a captured ship, and taking it unlocks that ship. Every
## ship but the saucer is held in one somewhere, a facility whose ship has been found holds another
## instead, and every ship flies.
var main: Node
var frame := 0
var fails := 0
var ship: Thing
var holding := false
var step := "unlock"
var flying: Array[String] = []
var wait := 0
func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1
func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
## The nearest facility holding `held` ("" for any), out to `most` chunks
func _facility(held: String, most: int) -> Vector2i:
	for r in range(6, most):
		for x in range(-r, r + 1):
			for z: int in [-r, r]:
				var f := World.facility(Vector2i(x, z))
				if f != "" and (held == "" or f == held):
					return Vector2i(x, z)
	return Vector2i.ZERO
func _process(_d: float) -> bool:
	frame += 1
	wait += 1
	main.heat = 0.0
	main.ufo.hull = main.ufo.hull_max
	if step == "unlock":
		return _unlock()
	return _fly()
func _unlock() -> bool:
	if frame == 2:
		for s: String in Ufo.ORDER.slice(1):
			var kind := "captured_" + s
			_check(Thing.KINDS.has(kind) and Thing.KINDS[kind]["unlock"] == s and ResourceLoader.exists("res://models/%s.glb" % Ufo.SHIPS[s]["model"]),
				"the %s can be captured, and has a model" % s)
			_check(_facility(s, 70) != Vector2i.ZERO, "a facility somewhere holds the %s (chunk %s)" % [s, _facility(s, 70)])
			_check((Ufo.SHIPS[s]["title"] as String).find(" ") < 0, "the %s has a one-word name (%s)" % [s, Ufo.SHIPS[s]["title"]])
		main.unlocked.assign(["saucer", "orb"])
		var swapped: String = main.captive("orb", Vector2i(3, 9))
		_check(swapped != "orb" and not swapped in main.unlocked, "a facility whose ship is found holds one not yet found (%s)" % swapped)
		main.unlocked.assign(Ufo.ORDER)
		_check(main.captive("orb", Vector2i(3, 9)) == "orb", "with every ship found, it holds its own")
		main.unlocked.assign(["saucer"])
		var at := _facility("", 60)
		_check(at != Vector2i.ZERO, "there is a secret facility out in the country (chunk %s, holding the %s)" % [at, World.facility(at)])
		var p := World.centre_of(at)
		main.ufo.position = Vector3(p.x, main.ufo.position.y, p.z)
		main.world.update(main.ufo.position, 0.0, true)
		for t in main.things:
			if t.info.has("unlock") and t.ground().distance_to(p) < 1.0:
				ship = t
		holding = ship != null
		_check(holding, "it holds a captured ship")
		Input.action_press("beam")
	# (a freed thing compares equal to null, so only whether it is still there is asked)
	elif frame > 2 and frame < 900 and holding and (not is_instance_valid(ship) or ship.state == "gone"):
		Input.action_release("beam")
		_check(main.unlocked.size() == 2, "taking it unlocks that ship (%s)" % [main.unlocked])
		main.quit_to_menu()
		main.ship = "orb" if not "orb" in main.unlocked else "saucer"
		main._show_ship()
		_check(main.ship in main.unlocked or main._play_button.disabled, "a ship not yet found cannot be flown")
		main.unlocked.assign(Ufo.ORDER)
		flying.assign(Ufo.ORDER.slice(3))
		step = "fly"
		wait = 0
	elif frame >= 900:
		_check(false, "taking it unlocks that ship")
		print("FAILED")
		return true
	return false
## Each new ship flown for a while by the autopilot: built as its spec says, its pilot under its dome
func _fly() -> bool:
	if wait == 1:
		main.ship = flying[0]
		main.start()
		main.autopilot = true
	elif wait == 240:
		var spec: Dictionary = Ufo.SHIPS[flying[0]]
		var u: Ufo = main.ufo
		_check(u.ship == flying[0] and is_equal_approx(u.speed, spec["speed"]) and u.tier == spec["tier"] and is_equal_approx(u.hull_max, spec["hull"]),
			"the %s flies as its spec says (speed %.1f, tier %d, shield %d)" % [flying[0], u.speed, u.tier, u.hull_max])
		_check(u.hull_model.find_child("dome*", true, false) != null, "the %s has a dome over its pilot" % flying[0])
		_check(not u.dead and absf(u.position.y - u.altitude) < 0.5, "the %s is up at its height (%.1f m)" % [flying[0], u.position.y])
		main.autopilot = false
		flying.pop_front()
		wait = 0
		if flying.is_empty():
			print("PASSED" if fails == 0 else "FAILED")
			return true
	return false
