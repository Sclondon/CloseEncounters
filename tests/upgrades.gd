extends SceneTree
## The strength of the beam and level-ups (and no traders parked about any more): the ship pulls a
## tree out of the ground with a strong beam and then a whole mesa, and presses a crop circle.
## Then the defence laser shoots a shell down and blows up a police car, and the mini fleet beams up
## chickens by itself, stops a shot, is shot down and comes back.
##   godot --headless --path . --fixed-fps 60 -s res://tests/upgrades.gd
## Ends with PASSED or FAILED.

var main: Node
var frame := 0
var fails := 0
var step := "shop"
var shop: Shop
var wait := 0
var mesa_at := Vector3.ZERO
var taken_before := 0
var mesa: Thing
var pod: Thing
var shell: Shot
var police: Thing
var score_before := 0
var goods := ""
var level_before := 0
var hits_before := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	main = scene.instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _over(p: Vector3) -> void:
	main.ufo.position = Vector3(p.x, main.ufo.position.y, p.z)
	main.ufo.velocity = Vector3.ZERO


func _process(_delta: float) -> bool:
	frame += 1
	wait += 1
	main.ufo.hull = main.ufo.hull_max
	match step:
		"shop":
			if frame == 5:
				_check(main.shops.is_empty(), "no traders are parked out in the country (%d)" % main.shops.size())
				main.ufo.tier = 2
				var tier: int = main.ufo.tier
				var score: int = main.score
				main.buy("beam")
				main.buy("beam")
				_check(main.ufo.tier == mini(tier + 1, 4) and main.score == score, "two BEAM upgrades make the beam stronger (tier %d to %d), and cost nothing" % [tier, main.ufo.tier])
				var levels: int = main.level
				main.score = main.level_at(main.level + 2)
				main._levels()
				main._levels()
				_check(main.level == levels + 2, "score enough brings level-ups (level %d to %d)" % [levels, main.level])
				step = "tree"
				wait = 0
		"tree":
			if wait == 1:
				for c: Vector2i in main.world.loose:
					for entry: Array in main.world.loose[c]:
						if entry[0] in ["tree", "pine", "aspen", "pinyon"]:
							_over((entry[3] as Transform3D).origin)
							break
				taken_before = main.taken
				Input.action_press("beam")
			elif wait == 300:
				_check(main.taken > taken_before, "a strong beam pulls a tree out of the ground (%d taken)" % (main.taken - taken_before))
				Input.action_release("beam")
				step = "mesa"
				wait = 0
		"mesa":
			if wait == 1:
				for x in range(-30, 31):
					for z in range(-30, 31):
						for f: Dictionary in World.landforms(Vector2i(x, z)):
							if f["name"] == "mesa" and (mesa_at == Vector3.ZERO or Vector3(x, 0, z).length() < mesa_at.length() / World.CHUNK):
								mesa_at = f["at"]
				main.ufo.tier = 4
				_over(mesa_at)
				main.world.update(main.ufo.position, 0.0, true)
				_over(mesa_at)
				taken_before = main.taken
				for t in main.things:
					if t.kind == "mesa" and t.position.distance_to(mesa_at) < 1.0:
						mesa = t
				_check(mesa != null, "the mesa is a thing the beam can take")
				Input.action_press("beam")
			elif wait < 1200:
				main.heat = 0.0
				# (a freed thing compares equal to null, so it is only asked whether it is still there)
				if not is_instance_valid(mesa) or mesa.state == "gone":
					_check(main.taken > taken_before, "a beam strong enough takes a whole mesa (in %.1f s)" % (wait / 60.0))
					Input.action_release("beam")
					step = "crop"
					wait = 0
			else:
				_check(false, "a beam strong enough takes a whole mesa")
				Input.action_release("beam")
				step = "laser"
				wait = 0
		"crop":
			if wait == 1:
				# Over the crop field nearest the start's farm country, the beam held still
				main.ufo.tier = 1
				_over(_crop_near(Vector3(-30, 0, 30)))
				main.world.update(main.ufo.position, 0.0, true)
				taken_before = main.score
				Input.action_press("beam")
			elif wait == 480:
				Input.action_release("beam")
				_check(main.score > taken_before and main._circle_done, "the beam held still over a field presses a crop circle (score %d to %d)" % [taken_before, main.score])
				step = "laser"
				wait = 0
		"laser":
			if wait == 1:
				# Three stars, the laser bought, and a tank shell fired at the ship from 13 m off
				main.heat = 3.2
				main.score = 50000
				_check(main.buy("turret") and main.ufo.laser != null, "an AUTO TURRET can be bought, and a turret is slung under the ship")
				# (ready to fire: it may have been shooting at whatever stood about, now that it shoots at anything)
				main._laser_wait = 0.0
				shell = main._shot("shell", main.ufo.position + Vector3(0, -6, 11), main.ufo.position)
			elif wait == 12:
				_check((not is_instance_valid(shell) or shell.done) and main.ufo.since_hit > 0.15, "the laser shoots a shell down before it hits")
				for i in 3:
					main.buy("turret")
				_check(main.upgrades["turret"] >= 4 and is_equal_approx(main.laser_reload(), maxf(4.6 - 0.6 * main.upgrades["turret"], 0.9) * main.cooldown()),
					"the turret stacks, firing quicker each (every %.1f s)" % main.laser_reload())
				for t in main.things.duplicate():
					if t.is_enemy():
						main._remove(t)
				police = main.spawn("police_car", main.ufo.ground() + Vector3(6, 0, 6))
				score_before = main.score
			elif wait > 12 and wait < 500 and not is_instance_valid(police):
				_check(main.score > score_before, "the turret blows up a police car near the ship, for points (%d)" % (main.score - score_before))
				step = "cut"
				wait = 0
			elif wait == 500:
				_check(false, "the turret blows up a police car near the ship")
				step = "cut"
				wait = 0
		"cut":
			# The hand-fired LASER: switched over, held down, at a police car right under the ship
			if wait == 1:
				for t in main.things.duplicate():
					if t.is_enemy():
						main._remove(t)
				main.upgrades["turret"] = 0
				main.score = 50000
				main.buy("laser")
				main.toggle_laser()
				_check(main.laser_mode, "a LASER can be bought, and the beam switched over to it")
				police = main.spawn("police_car", main.ufo.ground() + Vector3(0.3, 0, 0.3))
				Input.action_press("beam")
			elif wait == 90:
				Input.action_release("beam")
				_check(not is_instance_valid(police) or int(police.get_meta("zapped", 0)) > 0, "held down, the laser cuts a police car where the beam would fall")
				_check(not main.ufo.beaming, "and no beam comes on while it fires")
				main.toggle_laser()
				_check(not main.laser_mode, "switched back, the beam is the beam again")
				step = "missile"
				wait = 0
		"missile":
			# MISSILES: a police car not far off, and a missile off the ship after it
			if wait == 1:
				for t in main.things.duplicate():
					if t.is_enemy():
						main._remove(t)
				# (weapons are never dropped, so the laser is taken off by hand to make room)
				main.upgrades["laser"] = 0
				main._got.erase("laser")
				main.buy("missiles")
				main._missile_wait = 0.0
				police = main.spawn("police_car", main.ufo.ground() + Vector3(18, 0, 10))
			elif wait == 30:
				_check(not main._missiles.is_empty() or not is_instance_valid(police), "MISSILES: a missile goes off by itself after the police")
			elif wait == 300:
				_check(not is_instance_valid(police) or police.state == "gone", "and blows the police car up")
				step = "cloak"
				wait = 0
		"cloak":
			# CLOAK: gone from sight; shots go through it; the beam breaks it
			if wait == 1:
				main.upgrades["missiles"] = 0
				main.buy("cloak")
				main.use_cloak()
				_check(main.ufo.cloak > 0.0 and not main.ufo.struck(main.ufo.position), "CLOAK: the ship cloaks, and a shot goes through it")
			elif wait == 20:
				Input.action_press("beam")
			elif wait == 24:
				Input.action_release("beam")
				_check(main.ufo.cloak <= 0.0, "and the beam breaks the cloak")
				step = "fleet"
				wait = 0
		"fleet":
			main.heat = 0.0
			if wait == 1:
				for t in main.things.duplicate():
					if t.is_enemy():
						main._remove(t)
				main.score = 50000
				main.buy("fleet")
				main.buy("fleet")
				_check(main.fleet.size() == main.upgrades["fleet"] and main.fleet.size() >= 2, "FLEET upgrades: a little saucer about the ship for each (%d)" % main.fleet.size())
				_over(Vector3(-40, 0, -40))
				for i in 5:
					var a := i * TAU / 5.0
					main.spawn("chicken", main.ufo.ground() + Vector3(cos(a), 0, sin(a)) * 8.0)
				taken_before = main.taken
				# (each ready to go off after something at once, not when it next takes the notion)
				for d: Drone in main.fleet:
					d._proc = 0.0
			elif wait == 600:
				_check(main.taken > taken_before, "the fleet beams up small things by itself (%d taken)" % (main.taken - taken_before))
				var d: Drone = main.fleet[0]
				hits_before = d.hits
				main._shot("bullet", d.position + Vector3(0, 0.3, 0), d.position + Vector3(0, -5, 0))
			elif wait == 610:
				var d: Drone = main.fleet[0]
				_check(d.hits > hits_before, "a shot that meets one of the fleet stops there")
				var decoys := 0
				for i in 400:
					if main._decoy() != null:
						decoys += 1
				_check(decoys > 20 and decoys < 200, "the police and army sometimes aim at the fleet instead (%d in 400)" % decoys)
				for i in Drone.HITS:
					d.hit()
				_check(not d.is_up(), "shot enough, one of the fleet goes down")
			elif wait == 610 + int(Drone.REBUILT * 60.0) + 30:
				_check(main.fleet[0].is_up(), "and a new one comes out of the ship a while later")
				return _end()
	return false


func _end() -> bool:
	print("PASSED" if fails == 0 else "FAILED")
	return true


## The nearest point to `p` in a field of a crop, off the roads (crop circles press only there)
func _crop_near(p: Vector3) -> Vector3:
	for r in range(0, 120, 4):
		for k in 16:
			var a := k * TAU / 16.0
			var q := p + Vector3(cos(a), 0, sin(a)) * float(r)
			if main.world.crops_at(q) and main.world.crops_at(q + Vector3(4, 0, 4)) and main.world.crops_at(q - Vector3(4, 0, 4)):
				return q
	return p
