class_name MoonSet
extends Node3D
## The title: the moon, high above the farm country, where the pilot lounges in a deck chair beside
## its parked ship with a cocktail, Earth hanging in the black behind. It sits at SITE (far above
## the world, out of reach of the camera from down there).

const SITE := Vector3(0, 900, 0)
## Where the ship parks, the chair stands, and Earth hangs (from SITE)
const SHIP_AT := Vector3(4.2, 1.7, -3.2)
const CHAIR_AT := Vector3(0.9, 0.0, 0.4)
const EARTH_AT := Vector3(150.0, 70.0, -150.0)
const EARTH_SIZE := 24.0
## The chair turned to face the camera
const CHAIR_TURN := -0.62

var lounger: Alien
var chair: Node3D
var drink: Node3D
var earth: MeshInstance3D


func _ready() -> void:
	position = SITE
	add_child(Ps1.model("moon_surface"))
	chair = Ps1.model("lounge_chair")
	chair.position = CHAIR_AT
	chair.rotation.y = CHAIR_TURN
	add_child(chair)
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


## The pilot in the chair, drink in hand (a new one each time: `look_seed`)
func seat(look_seed: int) -> void:
	if lounger != null:
		lounger.queue_free()
	lounger = Alien.new()
	lounger.look_seed = look_seed
	lounger.scale = Vector3.ONE * 0.95
	add_child(lounger)
	lounger.position = CHAIR_AT + Vector3(0, 0.36, 0.02)
	lounger.rotation.y = chair.rotation.y
	lounger.feel("lounge")
	drink = Ps1.model("cocktail")
	drink.scale = Vector3.ONE * 1.4
	lounger.arms[1].add_child(drink)
	drink.position = Vector3(0.02, -0.42, 0.03)
	drink.rotation = Vector3(PI, 0, 0)


## Off the chair and up into the ship, over `seconds` (the drink stays on the chair arm)
func hop_aboard(seconds: float) -> void:
	if lounger == null:
		return
	lounger.feel("tossed", seconds)
	drink.reparent(chair)
	drink.position = Vector3(0.35, 0.55, 0.0)
	drink.rotation = Vector3.ZERO
	var from := lounger.position
	var to := SHIP_AT + Vector3(0, 0.6, 0)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		lounger.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 2.2, 0)
		lounger.rotation.y = lerp_angle(chair.rotation.y, 0.0, k), 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void: lounger.visible = false)


func earth_position() -> Vector3:
	return SITE + EARTH_AT
