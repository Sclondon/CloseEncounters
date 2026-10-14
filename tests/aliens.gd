extends SceneTree
## Eight pilots side by side, each from a seed of its own, to see that no two look alike (needs a window):
##   godot --path . --resolution 1280x720 -s res://tests/aliens.gd -- <out.png>

var frame := 0
var out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://aliens.png"
	var stage := Node3D.new()
	root.add_child(stage)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.8, 3.6), Vector3(0, 0.65, 0))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	cam.environment = env
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.4, 0)
	stage.add_child(sun)
	RenderingServer.global_shader_parameter_set("bend_focus", Vector3(0, 0, 0))
	RenderingServer.global_shader_parameter_set("saucer_pos", Vector3(0, -50, 0))
	for i in 8:
		var a := Alien.new()
		a.look_seed = 4000 + i * 977
		a.position = Vector3((i % 4 - 1.5) * 0.85, 0.75 - (i / 4) * 0.95, 0)
		a.scale = Vector3.ONE * 0.75
		stage.add_child(a)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
		return true
	return false
