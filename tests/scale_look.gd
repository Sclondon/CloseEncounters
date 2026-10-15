extends SceneTree
## The same spot drawn a few ways, to choose how big the world should feel (needs a window):
##   godot --path . --fixed-fps 30 --resolution <390x844|1280x720> -s res://tests/scale_look.gd -- <out dir>
## a_now; b_less_bend; c_bigger_buildings (and the people and animals smaller); d_lower_camera (and
## the camera lower, looking out more than down)

var main: Node
var frame := 0
var out := ""
const BUILDINGS := ["house", "farmhouse", "barn", "silo", "water_tower", "diner", "police_station", "outhouse", "cabin", "adobe", "hangar", "watchtower", "observatory", "substation", "windmill", "phone_booth", "tent", "camp_tent", "pine", "tree", "aspen"]
const FOLK := ["person", "farmer", "cowboy", "cow", "pig", "sheep", "chicken", "horse", "bison", "longhorn", "coyote", "scarecrow"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://scale_look"
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	root.add_child(main)
	main._touch_screen = false


func _grow(kinds: Array, by: float) -> void:
	for t in main.things:
		if t.kind in kinds and t.state == "walk":
			t.model.scale *= by


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _process(_delta: float) -> bool:
	frame += 1
	main.heat = 0.0
	main._banner("", 0.0)
	if frame > 110:
		main.ufo.velocity = Vector3.ZERO
	match frame:
		20:
			main.autopilot = true
		110:
			main.autopilot = false
		140:
			_shot("a_now")
			RenderingServer.global_shader_parameter_set("bend_k", 0.0025)
		145:
			_shot("b_less_bend")
			_grow(BUILDINGS, 1.45)
			_grow(FOLK, 0.8)
		150:
			_shot("c_bigger_buildings")
			main.camera_offset = Vector3(0, 16.0, 19.5)
		200:
			_shot("d_lower_camera")
	return frame >= 202
