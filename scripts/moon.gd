class_name MoonSet
extends Node3D
## The title: the moon, high above the farm country, where the ship stands parked with its canopy
## open and the pilot up on top of it with a cocktail (see `Ufo.lounge`), Earth hanging in the black
## behind. It sits at SITE (far above the world, out of reach of the camera from down there).

const SITE := Vector3(0, 900, 0)
## Where the ship parks (its feet, 1.58 below it, on the flat patch of ground made for it: see
## moon_surface in tools/build_models.py), the cooler and the radio in front of it, and where Earth
## hangs (from SITE)
const SHIP_AT := Vector3(4.2, 1.58, -3.2)
const COOLER_AT := Vector3(1.99, 0.0, -2.11)
const RADIO_AT := Vector3(3.6, 0.0, -0.76)
const EARTH_AT := Vector3(150.0, 70.0, -150.0)
const EARTH_SIZE := 24.0
## The parked ship turned to face the camera
const SHIP_TURN := -0.65

var earth: MeshInstance3D


func _ready() -> void:
	position = SITE
	var ground := Ps1.model("moon_surface")
	add_child(ground)
	var regolith := ShaderMaterial.new()
	regolith.shader = load("res://shaders/moon.gdshader")
	var meshes := ground.find_children("*", "MeshInstance3D", true, false)
	if ground is MeshInstance3D:
		meshes.append(ground)
	for m in meshes:
		(m as MeshInstance3D).material_override = regolith
	# The cooler of beers and the radio, on the ground in front of the ship
	for prop: Array in [["cooler", COOLER_AT, 0.5], ["boombox", RADIO_AT, -0.3]]:
		var thing := Ps1.model(prop[0])
		thing.position = prop[1]
		thing.rotation.y = SHIP_TURN + float(prop[2])
		add_child(thing)
	earth = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = EARTH_SIZE
	ball.height = EARTH_SIZE * 2.0
	ball.radial_segments = 48
	ball.rings = 24
	earth.mesh = ball
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/earth.gdshader")
	earth.material_override = m
	earth.position = EARTH_AT
	earth.rotation = Vector3(0.4, 0, 0.2)
	add_child(earth)


func _process(delta: float) -> void:
	earth.rotate_object_local(Vector3.UP, delta * 0.03)


func earth_position() -> Vector3:
	return SITE + EARTH_AT


## Earth brought along into the descent (see Main._process): hung at `at`, `grow` times its size,
## `fade` of it showing
func carry_earth(at: Vector3, grow: float, fade: float) -> void:
	earth.visible = fade > 0.0
	earth.global_position = at
	earth.scale = Vector3.ONE * grow
	(earth.material_override as ShaderMaterial).set_shader_parameter("fade", fade)


## Earth back where it hangs over the moon
func rest_earth() -> void:
	earth.visible = true
	earth.position = EARTH_AT
	earth.scale = Vector3.ONE
	(earth.material_override as ShaderMaterial).set_shader_parameter("fade", 1.0)
