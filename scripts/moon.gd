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
## The cooler and the radio, and where each stands (they are blown away at lift-off, see `blast`)
var _props: Array[Node3D] = []
var _homes: Array[Transform3D] = []
## What the lift-off blew away, still flying: {node, velocity, spin, left, chair}; and the dust it
## raised: {mesh, velocity, grow, lasts, life}
var _flying: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []


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
		_props.append(thing)
		_homes.append(thing.transform)
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
	_fly(delta)


func earth_position() -> Vector3:
	return SITE + EARTH_AT


## Lift-off: the cooler, the radio and the lounge chair (`chair`, left behind by the ship) blown
## away tumbling, end over end, in a cloud of moon dust billowing out from under the ship
func blast(chair: Node3D) -> void:
	var under := SHIP_AT * Vector3(1, 0, 1)
	var things: Array[Node3D] = _props.duplicate()
	if chair != null:
		chair.reparent(self)
		things.append(chair)
	for t in things:
		var out := t.position * Vector3(1, 0, 1) - under
		out = out.normalized() if out.length() > 0.1 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_flying.append({"node": t, "velocity": out * randf_range(7.0, 10.0) + Vector3.UP * randf_range(5.0, 8.0),
			"spin": Vector3(randf_range(-9, 9), randf_range(-6, 6), randf_range(-9, 9)), "left": 3.0, "chair": t == chair})
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 10
	puff.rings = 5
	for i in 22:
		var a := TAU * i / 22.0 + randf_range(-0.15, 0.15)
		var way := Vector3(cos(a), 0, sin(a))
		var m := MeshInstance3D.new()
		m.mesh = puff
		var grey := StandardMaterial3D.new()
		grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		grey.disable_fog = true
		grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		grey.albedo_color = Color(0.62, 0.62, 0.66, 0.85)
		m.material_override = grey
		m.position = under + way * randf_range(0.8, 1.6) + Vector3.UP * 0.3
		m.scale = Vector3.ONE * randf_range(0.8, 1.4)
		add_child(m)
		_clouds.append({"mesh": m, "velocity": way * randf_range(4.0, 8.0) + Vector3.UP * randf_range(0.3, 1.5),
			"grow": randf_range(1.5, 2.6), "lasts": randf_range(1.6, 2.4), "life": 0.0})


## Back as it was for the title: the cooler and the radio where they stood, the dust settled
func tidy() -> void:
	for f in _flying:
		if f["chair"]:
			(f["node"] as Node3D).queue_free()
	_flying.clear()
	for i in _props.size():
		_props[i].transform = _homes[i]
		_props[i].visible = true
	for c in _clouds:
		(c["mesh"] as Node3D).queue_free()
	_clouds.clear()


func _fly(delta: float) -> void:
	for f in _flying:
		var t: Node3D = f["node"]
		if f["left"] <= 0.0:
			continue
		f["left"] -= delta
		f["velocity"] += Vector3.DOWN * 3.0 * delta
		t.position += f["velocity"] * delta
		t.rotation += f["spin"] * delta
		if f["left"] <= 0.0:
			t.visible = false
	for c in _clouds.duplicate():
		var m: MeshInstance3D = c["mesh"]
		c["life"] += delta
		var k: float = c["life"] / c["lasts"]
		if k >= 1.0:
			m.queue_free()
			_clouds.erase(c)
			continue
		c["velocity"] *= 1.0 - minf(delta * 1.6, 1.0)
		m.position += c["velocity"] * delta
		m.scale += Vector3.ONE * c["grow"] * delta
		(m.material_override as StandardMaterial3D).albedo_color.a = 0.85 * (1.0 - k)
