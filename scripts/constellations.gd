class_name Constellations
## Real constellations for the night sky (see sky.gdshader `named`): each star from its true right
## ascension and declination (degrees) and brightness (magnitude), drawn in its true shape round
## where the constellation is hung in the game's sky (its `at`: degrees round from north, and up from
## the horizon). They are hung where the camera sees the sky: low, and toward the way it looks (the
## world curves away, so the sky it sees is a little under the true horizon).

const SKY := {
	# Orion: Betelgeuse, Bellatrix, the belt, Saiph, Rigel, Meissa
	"orion": {"at": Vector2(50, -13), "stars": [[88.8, 7.4, 0.5], [81.3, 6.35, 1.6], [85.2, -1.94, 1.8], [84.05, -1.2, 1.7], [83.0, -0.3, 2.2], [86.9, -9.67, 2.1], [78.6, -8.2, 0.1], [83.8, 9.9, 3.4]]},
	# The Big Dipper
	"big_dipper": {"at": Vector2(76, -11), "stars": [[165.9, 61.75, 1.8], [165.5, 56.4, 2.3], [178.5, 53.7, 2.4], [183.9, 57.0, 3.3], [193.5, 55.96, 1.8], [200.98, 54.9, 2.2], [206.9, 49.3, 1.9]]},
	# Cassiopeia's W
	"cassiopeia": {"at": Vector2(28, -16), "stars": [[2.3, 59.1, 2.3], [10.1, 56.5, 2.2], [14.2, 60.7, 2.4], [21.45, 60.2, 2.7], [28.6, 63.7, 3.4]]},
	# Cygnus, the Northern Cross
	"cygnus": {"at": Vector2(98, -18), "stars": [[310.4, 45.3, 1.3], [305.6, 40.3, 2.2], [311.6, 33.97, 2.5], [296.2, 45.1, 2.9], [292.7, 27.96, 3.1]]},
	# Lyra: Vega and its parallelogram
	"lyra": {"at": Vector2(115, -12), "stars": [[279.2, 38.8, 0.0], [282.5, 33.4, 3.5], [284.7, 32.7, 3.2], [281.1, 37.6, 4.3], [283.6, 36.9, 4.2]]},
	# Scorpius: Antares and the tail
	"scorpius": {"at": Vector2(10, -20), "stars": [[247.35, -26.4, 1.0], [241.4, -19.8, 2.6], [240.1, -22.6, 2.3], [239.7, -26.1, 2.9], [248.97, -28.2, 2.8], [252.5, -34.3, 2.3], [253.1, -38.0, 3.0], [258.0, -43.2, 3.6], [264.3, -43.0, 1.9], [263.4, -37.1, 1.6], [262.7, -37.3, 2.7]]},
	# Leo: the sickle and Denebola
	"leo": {"at": Vector2(140, -14), "stars": [[152.1, 11.97, 1.4], [151.8, 16.8, 3.5], [155.0, 19.8, 2.0], [154.2, 23.4, 3.4], [148.2, 26.0, 3.9], [168.5, 20.5, 2.6], [168.6, 15.4, 3.3], [177.3, 14.6, 2.1]]},
}


## Every star as a direction in the sky (xyz) and how bright it is (w, 0 to 1)
## (`hung` moves any of them: its name to where to hang it, degrees round and up; `shrink` draws
## them smaller than life, for more to fit the picture)
static func directions(hung := {}, shrink := 0.6) -> PackedVector4Array:
	var out := PackedVector4Array()
	for name: String in SKY:
		var c: Dictionary = SKY[name]
		var stars: Array = c["stars"]
		# (the middle of the constellation, to hang it by)
		var mid := Vector2.ZERO
		for s: Array in stars:
			mid += Vector2(s[0], s[1])
		mid /= stars.size()
		var at: Vector2 = hung.get(name, c["at"])
		for s: Array in stars:
			# (east to the left, as the sky is seen; right ascension closes up toward the pole)
			var x := -(float(s[0]) - mid.x) * cos(deg_to_rad(float(s[1]))) * shrink
			var y := (float(s[1]) - mid.y) * shrink
			var az := deg_to_rad(at.x + x)
			var el := deg_to_rad(at.y + y)
			var d := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
			out.append(Vector4(d.x, d.y, d.z, clampf(1.0 - float(s[2]) / 4.5, 0.15, 1.0)))
	return out


## Where in the picture the ones always in view are hung (fractions across and down it)
const IN_VIEW := {"scorpius": Vector2(0.1, 0.2), "orion": Vector2(0.3, 0.09), "big_dipper": Vector2(0.66, 0.08), "cassiopeia": Vector2(0.9, 0.17)}


## The constellations as `camera` sees them: those in IN_VIEW hung where it shows them, the rest
## where they are in SKY
static func for_camera(camera: Camera3D) -> PackedVector4Array:
	var size := camera.get_viewport().get_visible_rect().size
	var hung := {}
	for name: String in IN_VIEW:
		var d := camera.project_ray_normal(size * (IN_VIEW[name] as Vector2))
		hung[name] = Vector2(rad_to_deg(atan2(d.x, -d.z)), rad_to_deg(asin(clampf(d.y, -1.0, 1.0))))
	var out := directions(hung)
	out.resize(64)
	return out
