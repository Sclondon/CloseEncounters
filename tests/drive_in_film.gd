extends SceneTree
## The film shown on drive-in screens (see world.gd `_venue` "drive_in"): the BLOOPUS-7 over a
## town, hovering over one building after another and burning each down with the laser ray.
## Recorded with Godot's movie maker and packed into a flipbook by tools/drive_in_film.sh:
##   godot --path . --fixed-fps 15 --resolution 384x216 --write-movie <dir>/f.png -s res://tests/drive_in_film.gd

const FRAMES := 80
const LEAD := 25
const EACH := 22
const BUILDINGS := ["house", "storefront", "hospital", "fire_station", "bank", "liquor_store", "church", "diner", "city_hall", "police_station", "clock_tower", "water_tower", "adobe"]
var main: Node
var frame := 0
var town := Vector3.ZERO
var stops: Array[Vector3] = []


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	main.ship = "jelly"
	root.add_child(main)
	main._touch_screen = false


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		# (the nearest town to the start)
		var best := 1e9
		for x in range(-12, 13):
			for z in range(-12, 13):
				var c := Vector2i(x, z)
				if World.is_town(c) and Vector2(x, z).length() < best:
					best = Vector2(x, z).length()
					town = World.centre_of(c)
		main.upgrades["laser"] = 5
		main._apply_upgrades()
		main.laser_mode = true
		main.levels_on = false
		main.ufo.position = Vector3(town.x - 20, main.ufo.position.y, town.z)
		main.world.update(main.ufo.position, 0.0, true)
		main.hud.visible = false
		# (the camera in close and high, for the saucer to read on a little screen)
		main.camera_offset = Vector3(0, 21.0, 14.0)
	if frame == 6:
		# (its buildings, west to east)
		for t: Thing in main.things:
			if t.kind in BUILDINGS and t.ground().distance_to(town) < 30.0:
				stops.append(t.ground())
		stops.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
		print("film stops ", stops.size())
	if frame > 6 and not stops.is_empty():
		main.heat = 0.0
		main.ufo.hull = main.ufo.hull_max
		# (over each in turn, gliding from one to the next, the ray down on it)
		var i := clampi((frame - LEAD + EACH) / EACH, 0, stops.size() - 1)
		var goal: Vector3 = stops[i]
		var here := Vector3(main.ufo.position.x, 0, main.ufo.position.z)
		var step := (goal - here).limit_length(0.9)
		main.ufo.velocity = step * 15.0
		main.ufo.position.x += step.x
		main.ufo.position.z += step.z
		if frame > LEAD - 10:
			main.beam_finger = 7
			main._beam_from = Vector2.ZERO
			var size: Vector2 = main.get_viewport().get_visible_rect().size
			main._beam_at = Vector2(sin(frame * 0.5), cos(frame * 0.5)) * 0.12 * minf(size.x, size.y) * 0.2
	return frame >= FRAMES + LEAD
