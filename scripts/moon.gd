class_name MoonSet
extends Node3D
## The title: the moon, high above the farm country, where the ship stands parked with its canopy
## open and the pilot up on top of it with a cocktail (see `Ufo.lounge`), Earth hanging in the black
## behind. It sits at SITE (far above the world, out of reach of the camera from down there).

const SITE := Vector3(0, 900, 0)
## Where the ship parks, and where Earth hangs (from SITE)
const SHIP_AT := Vector3(4.2, 1.7, -3.2)
const EARTH_AT := Vector3(150.0, 70.0, -150.0)
const EARTH_SIZE := 24.0
## The parked ship turned to face the camera
const SHIP_TURN := -0.65

var earth: MeshInstance3D


func _ready() -> void:
	position = SITE
	add_child(Ps1.model("moon_surface"))
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
