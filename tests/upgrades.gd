extends SceneTree
## Trading and the strength of the beam: the ship beams up one of the pods the trader near the start
## has set out (bought, and the trader packs up and goes), pulls a tree out of the ground with a
## strong beam and then a whole mesa, and finally the heat goes up and another trader takes off.
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
				_check(not main.shops.is_empty(), "a trader is parked near the start (%d about)" % main.shops.size())
				main.ufo.tier = 2
				if main.shops.is_empty():
					return _end()
				shop = main.shops[0]
				_over(shop.position)
				wait = 0
			elif frame > 5 and wait == 2:
				_check(shop.pods.size() == 3, "the trader has three pods of goods set out")
				main.score = 0
				pod = shop.pods[0]
				_over(pod.position)
				Input.action_press("beam")
			elif frame > 5 and wait == 60:
				_check(pod.state == "walk", "with no score, a pod cannot be had: it stays where it is")
				main.score = 20000
			elif frame > 5 and wait > 60 and wait < 600 and (not is_instance_valid(pod) or pod.state == "gone"):
				Input.action_release("beam")
				_check(main.score < 20000, "beaming a pod up buys it (score left %d)" % main.score)
				_check(shop.state == "leaving" and shop.pods.is_empty(), "the trader packs up the rest and leaves")
				var tier: int = main.ufo.tier
				main.score = 20000
				main.buy("beam")
				_check(main.ufo.tier == mini(tier + 1, 4), "a BEAM upgrade makes the beam stronger (tier %d to %d)" % [tier, main.ufo.tier])
				step = "tree"
				wait = 0
			elif frame > 5 and wait >= 600:
				_check(false, "beaming a pod up buys it")
				Input.action_release("beam")
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
				step = "flee"
				wait = 0
		"crop":
			if wait == 1:
				# Over the farm country near the start, the beam held still
				main.ufo.tier = 1
				_over(Vector3(-30, 0, 30))
				main.world.update(main.ufo.position, 0.0, true)
				taken_before = main.score
				Input.action_press("beam")
			elif wait == 300:
				Input.action_release("beam")
				_check(main.score > taken_before and main._circle_done, "the beam held still over a field presses a crop circle (score %d to %d)" % [taken_before, main.score])
				step = "flee"
				wait = 0
		"flee":
			if wait == 1:
				main.ufo.tier = 2
				for s: Shop in main.shops:
					if s.state == "parked":
						shop = s
				_over(shop.position + Vector3(20, 0, 0))
				main.heat = 2.5
				main.calm = 0.0
			elif wait == 60:
				_check(shop.state == "leaving" or not is_instance_valid(shop), "with two stars of heat, the trader takes off")
				return _end()
	return false


func _end() -> bool:
	print("PASSED" if fails == 0 else "FAILED")
	return true
