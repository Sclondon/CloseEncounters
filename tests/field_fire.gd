extends SceneTree
##   godot --path . --fixed-fps 60 --resolution 390x844 -s res://tests/field_fire.gd
## A field of 100 crops, one set alight, with three GASOLINE and two WILDFIRE: how far the fire goes and
## what it costs (the chain used to run on without end and take a phone down)
var main
var f := 0
var worst := 0.0
var last := 0
var crops: Array = []
func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.testing = true
	main.start_mode = "play"
	root.add_child(main)
func _left() -> int:
	var n := 0
	for c in crops:
		if is_instance_valid(c) and c.state == "walk":
			n += 1
	return n
func _process(_d: float) -> bool:
	f += 1
	var now := Time.get_ticks_usec()
	if f > 100:
		worst = maxf(worst, (now - last) / 1000.0)
	last = now
	main.ufo.hull = main.ufo.hull_max
	main.heat = 0.0
	if f == 60:
		main.ship = "tictac"
		main.start()
		main.autopilot = false
		for i in 3:
			main.buy("gasoline")
		for i in 2:
			main.buy("wildfire")
		var g: Vector3 = main.ufo.ground() + Vector3(0, 0, -30)
		for x in 10:
			for z in 10:
				crops.append(main.spawn("pumpkin", g + Vector3(x * 1.6 - 8.0, 0, z * 1.6 - 8.0)))
	if f > 60:
		main.ufo.velocity = Vector3.ZERO
	if f == 90:
		var first: Thing = crops[44]
		first.set_meta("weapon_hit", true)
		main.ignite(first)
	if f % 300 == 0:
		print("t %ds: crops left %d/100, burning %d, worst frame %.1f ms" % [f / 60, _left(), main._burning.size(), worst])
	return f >= 2400
