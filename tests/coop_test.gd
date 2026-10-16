extends SceneTree
## Two copies of the game in one room, through a local relay (tools/dev_relay.mjs): one hosts, one
## joins with the host's code, the host starts, and each must see the other's saucer, and a cow
## taken on the guest's side must be gone on the host's. Run by tools/coop_test.sh, or by hand:
##   godot --headless --path . --fixed-fps 60 -s res://tests/coop_test.gd -- --role=host --server=http://127.0.0.1:3112
##   godot --headless --path . --fixed-fps 60 -s res://tests/coop_test.gd -- --role=join --room=CODE --server=...

var main: Node
var frame := 0
var role := "host"
var room := ""
var playing_from := -1
var fails := 0
var cow: Thing
const COW_AT := Vector3(70, 0, 30)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
		elif a.begins_with("--room="):
			room = a.trim_prefix("--room=")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.start_mode = "title"
	main.testing = true
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	print(("[%s] PASS " if ok else "[%s] FAIL ") % role + what)
	if not ok:
		fails += 1


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 20:
		if role == "host":
			main.net.create("saucer")
		else:
			main.net.join(room, "orb")
	if role == "host" and main.net.active() and frame % 30 == 0 and main.mode == "title":
		print("[room] %s %d" % [main.net.code, main.net.players.size()])
		if main.net.players.size() >= 2:
			main.net.pick_stage("s4242")
			main.net.start_game()
	if main.mode == "play" and main.intro <= 0.0 and playing_from < 0:
		playing_from = frame
		_check(main.coop_seed == 4242 and World.world_seed == 4242, "the run is over the room's country (seed %d)" % World.world_seed)
		cow = main.spawn("cow", COW_AT)
	if playing_from > 0:
		main.ufo.hull = main.ufo.hull_max
		var t := frame - playing_from
		if t == 120:
			_check(main.coop.others.size() == 1, "the other player's saucer is here (%d)" % main.coop.others.size())
			if role == "join":
				main.coop.tell("take", COW_AT, "cow")
		if t == 240:
			if role == "host":
				_check(not is_instance_valid(cow) or cow.state == "gone", "the cow the guest took is gone here too")
			print("[%s] %s" % [role, "PASSED" if fails == 0 else "FAILED"])
			quit(fails)
	if frame > 60 * 60:
		_check(false, "the game started in a minute")
		quit(1)
	return false
