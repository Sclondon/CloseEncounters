extends SceneTree
## A balance check for the ships: one ship (`--ship=<name>`) over the same country (seed 4242),
## flown by the autopilot taking whatever its beam can, with no upgrades, for RUN seconds or until it
## is shot down. Prints one line: BALANCE ship score taken seconds-alive. Run all of them with
## tools/balance.sh.

const RUN := 150.0
var main: Node
var frame := 0
var ship := "saucer"
var began := -1
var seed_n := 4242
## Kept from dying (the shield held full), to measure what it earns rather than how long it lasts
var immortal := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_n = int(a.trim_prefix("--seed="))
		if a == "--immortal":
			immortal = true
		if a.begins_with("--ship="):
			ship = a.trim_prefix("--ship=")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "play"
	main.testing = true
	main.coop_seed = seed_n
	main.ship = ship
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if main.mode == "play" and main.intro <= 0.0 and began < 0:
		began = frame
		main.autopilot = true
		main.pilot_tier = 9
		main.levels_on = false
	if began < 0:
		return frame > 600
	if immortal:
		main.ufo.hull = main.ufo.hull_max
	var t := (frame - began) / 60.0
	if main.mode != "play" or main.ufo.dead or t >= RUN:
		print("BALANCE %s %d %d %.0f %d" % [ship, main.score, main.taken, t, seed_n])
		return true
	return false
