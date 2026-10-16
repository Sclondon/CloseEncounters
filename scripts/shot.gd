class_name Shot
extends Node3D
## Something fired at the saucer: a bullet (the shotgun's pellets, the police pistol, the jeep's
## machine gun), a tank shell, or a jet's missile, which turns after the saucer. All of them can be
## seen coming and flown out of the way of. The game moves them through `tick`.

const SPECS := {
	"pellet": {"speed": 26.0, "damage": 2.0, "life": 1.2, "colour": Color(1.0, 0.9, 0.5), "size": Vector3(0.09, 0.09, 0.6)},
	"bullet": {"speed": 30.0, "damage": 4.0, "life": 1.5, "colour": Color(1.0, 0.85, 0.3), "size": Vector3(0.1, 0.1, 0.9)},
	"ray": {"speed": 24.0, "damage": 5.0, "life": 1.7, "colour": Color(0.45, 1.0, 0.6), "size": Vector3(0.12, 0.12, 1.5)},
	"tracer": {"speed": 36.0, "damage": 2.5, "life": 1.4, "colour": Color(1.0, 0.5, 0.2), "size": Vector3(0.12, 0.12, 1.3)},
	"shell": {"speed": 20.0, "damage": 18.0, "life": 3.0, "colour": Color(1.0, 0.4, 0.1), "size": Vector3(0.35, 0.35, 0.6)},
	"missile": {"speed": 17.0, "damage": 14.0, "life": 6.0, "colour": Color(0.9, 0.9, 0.9), "size": Vector3(0.22, 0.22, 1.2)},
}

var kind := "bullet"
var velocity := Vector3.ZERO
var damage := 1.0
var life := 1.0
var done := false
var _smoke := 0.0


func setup(k: String, from: Vector3, toward: Vector3) -> void:
	kind = k
	var spec: Dictionary = SPECS[k]
	position = from
	velocity = (toward - from).normalized() * float(spec["speed"])
	damage = spec["damage"]
	life = spec["life"]
	var colour: Color = spec["colour"]
	Ps1.part(self, BoxMesh.new(), Ps1.flat(colour), Vector3.ZERO, spec["size"])
	if k == "missile":
		Ps1.part(self, Ps1.ball(), Ps1.flat(Color(1.0, 0.6, 0.15)), Vector3(0, 0, -0.75), Vector3(0.18, 0.18, 0.3))
	if k == "ray":
		# (a bright head on the bolt, and a glow)
		Ps1.part(self, Ps1.ball(), Ps1.flat(Color(0.85, 1.0, 0.9)), Vector3(0, 0, 0.75), Vector3.ONE * 0.16)
		Ps1.part(self, Ps1.ball(), Ps1.own(Color(0.3, 1.0, 0.5), 2.0), Vector3(0, 0, 0.6), Vector3.ONE * 0.26)
	if k == "shell":
		Ps1.part(self, Ps1.ball(), Ps1.flat(Color(1.0, 0.8, 0.3)), Vector3.ZERO, Vector3.ONE * 0.28)
	_face()


func _face() -> void:
	if velocity.length() > 0.01:
		look_at(position - velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)


func tick(delta: float, ufo: Ufo, game: Node) -> void:
	life -= delta
	if kind == "missile" and not ufo.dead:
		# (turns after the saucer, but not quickly enough to catch one that dodges)
		var want := (ufo.position - position).normalized() * velocity.length()
		velocity = velocity.lerp(want, minf(delta * 1.1, 1.0)).normalized() * float(SPECS[kind]["speed"])
		_smoke -= delta
		if _smoke <= 0.0:
			_smoke = 0.06
			game.puff(position - velocity.normalized() * 0.8, Color(0.6, 0.6, 0.62), 0.4)
	position += velocity * delta
	_face()
	if ufo.struck(position):
		ufo.hurt(damage)
		game.shot_hit(self)
		done = true
	elif life <= 0.0 or position.y < 0.0:
		if kind in ["shell", "missile"]:
			game.boom(position, 1.5)
		done = true
