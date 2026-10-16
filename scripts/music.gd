class_name Music
extends Node
## The music: three songs made in One Man Band and played into music/*.wav by its
## tools/render_song.gd (their One Man Band songs are music/*.omb.json, written by tools/songs.gd,
## so they can be opened and changed there):
##
## - "lounge": Moon Lounge, for the title and the pause
## - "visitors": Night Visitors, for flying about
## - "chase": Tanks!, for when the heat is up
##
## Each loops; `play` fades from one to another.

const SONGS := ["lounge", "visitors", "chase"]
const FADE := 1.2
const LOUD := -7.0
## The bus the songs play on (its loudness is the MUSIC option)
const BUS := &"Music"

var players := {}
var song := ""
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name: String in SONGS:
		Sfx.make_bus(BUS)
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.stream = load("res://music/%s.wav" % name)
		p.volume_db = -80.0
		add_child(p)
		players[name] = p


## Fades to this song ("" for none); a song already playing goes on where it is
func play(name: String) -> void:
	if name == song:
		return
	song = name
	for other: String in players:
		var p: AudioStreamPlayer = players[other]
		if other == name and not muted:
			if not p.playing:
				p.volume_db = -40.0
				p.play()
			create_tween().tween_property(p, "volume_db", LOUD, FADE * 0.5)
		elif p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, FADE)
			tw.tween_callback(p.stop)
