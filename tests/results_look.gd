extends SceneTree
## The RESULTS after a long run (needs a window): something taken in every category, a dozen kinds of
## hunter destroyed, a stack of every item; saves results.png once it is all typed out, and prints
## whether the panel is wholly on the screen. Try every shape:
##   godot --path . --fixed-fps 30 --resolution <1280x720|1920x1080|1280x600|390x844|844x390> -s res://tests/results_look.gd -- <out dir>

var main: Node
var frame := 0
var out := ""
var _crashed_at := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://results_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	main._touch_screen = false


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 60:
		for group: String in Thing.CATEGORIES:
			main._run_taken[group] = [randi_range(3, 40), randi_range(500, 20000)]
		for kind: String in ["police_car", "patrol_car", "officer", "jeep", "tank", "helicopter", "chinook", "jet", "stealth", "warthog", "hunter", "motorcycle_cop", "laser_truck", "railgun"]:
			main._run_killed[kind] = randi_range(1, 30)
		for what: String in main.upgrades:
			main.upgrades[what] = randi_range(1, 6)
		main._threat = 4
		main.score = 987654
		main.ufo.hull = 0.0
		main.ufo.second_winds = 0
		main.ufo.hurt(99.0)
		_crashed_at = frame
	if _crashed_at > 0 and main.over_box.visible and not has_meta("skipped"):
		set_meta("skipped", true)
		# (typed out at once)
		main.over_label.visible_characters = maxi(main.over_label.text.length() - 1, 0)
		if main._over_kills.visible and main._over_kills.visible_characters >= 0:
			main._over_kills.visible_characters = maxi(main._over_kills.text.length() - 1, 0)
	if _crashed_at > 0 and frame - _crashed_at > 240:
		var rect: Rect2 = main.over_box.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, main.over_box.size)
		var screen: Vector2 = root.get_visible_rect().size
		var on := rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= screen.x + 1 and rect.end.y <= screen.y + 1
		print("results %s on a %s screen: %s" % [str(rect), str(screen), "ALL ON SCREEN" if on else "OFF THE SCREEN"])
		root.get_texture().get_image().save_png(out.path_join("results.png"))
		return true
	return false
