extends SceneTree
## A secret government facility: it holds a captured ship, and taking it unlocks that ship
var main: Node
var frame := 0
var fails := 0
var ship: Thing
var holding := false
func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1
func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
func _process(_d: float) -> bool:
	frame += 1
	main.heat = 0.0
	main.ufo.hull = main.ufo.hull_max
	if frame == 2:
		main.unlocked.assign(["saucer"])
		var at := Vector2i.ZERO
		for r in range(6, 60):
			for x in range(-r, r + 1):
				for z: int in [-r, r]:
					if at == Vector2i.ZERO and World.facility(Vector2i(x, z)) != "":
						at = Vector2i(x, z)
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
		print("PASSED" if fails == 0 else "FAILED")
		return true
	elif frame >= 900:
		_check(false, "taking it unlocks that ship")
		print("FAILED")
		return true
	return false