extends SceneTree
## Writes the game's three songs as One Man Band songs (music/*.omb.json, the shape One Man Band's
## Looper saves: bpm, bars, and four sections of a track for each instrument, a note being
## [beat, beats long, button, note]). One Man Band then plays them into music/*.wav:
##   godot --headless --path . -s tools/songs.gd
##   (in C:/Projects/FrontRangeInstituteGames/OneManBand)
##   godot --headless --path . -s tools/render_song.gd -- <this game>/music/lounge.omb.json <this game>/music/lounge.wav
##
## - Moon Lounge (the title and the pause): D minor, slow and swung, space-age lounge. The theremin
##   over organ chords, a soft tuba, bells, brushes.
## - Night Visitors (flying about): A minor, a B-movie surf tune. Theremin lead, a bouncing tuba,
##   organ stabs on the off beat, drums.
## - Tanks! (the heat is up): E minor and fast. A galloping bassoon and tuba, trumpet hits, a
##   trembling viola, and the theremin wailing over it all.

# One Man Band's instruments, by their place in its Kit.INSTRUMENTS
const PICCOLO := 0
const TRUMPET := 1
const TUBA := 4
const BELLS := 5
const DRUMS := 6
const ORGAN := 7
const THEREMIN := 8
const VIOLA := 9
const BASSOON := 11
const INSTRUMENTS := 12
# Its drums: which button, and which kit (a drum's note is the kit times 40)
const DRUM := {"kick": [0, 0], "snare": [1, 0], "hat": [2, 0], "tom": [3, 0], "crash": [4, 0],
	"boom": [0, -1], "rim": [1, -1], "open": [2, -1], "floor": [3, -1], "ride": [4, -1],
	"clap": [0, 1], "block": [1, 1], "shake": [2, 1]}


func _initialize() -> void:
	for pair: Array in [["lounge", _lounge()], ["visitors", _visitors()], ["chase", _chase()]]:
		var f := FileAccess.open("res://music/%s.omb.json" % pair[0], FileAccess.WRITE)
		f.store_string(JSON.stringify(pair[1], "\t"))
		print("wrote music/%s.omb.json" % pair[0])
	quit()


func _song(bpm: float, bars: int) -> Dictionary:
	var tracks := []
	for i in INSTRUMENTS:
		tracks.append([])
	return {"bpm": bpm, "bars": bars, "snap": 0.25, "metronome": false, "chain": false,
		"muted": [], "sections": [tracks, [], [], []]}


## A note `beats` long at beat `at` (a step is a quarter of a beat)
func _add(s: Dictionary, inst: int, at: float, n: int, beats: float) -> void:
	s["sections"][0][inst].append([snappedf(fposmod(at, s["bars"] * 4.0), 0.001), beats, -1, n])


func _tune(s: Dictionary, inst: int, at: float, tune: Array) -> void:
	for pair: Array in tune:
		if int(pair[0]) >= 0:
			_add(s, inst, at, pair[0], float(pair[1]) / 4.0 * 0.95)
		at += float(pair[1]) / 4.0


func _chord(s: Dictionary, inst: int, at: float, notes: Array, beats: float) -> void:
	for n: int in notes:
		_add(s, inst, at, n, beats)


## Sixteen steps of a bar: "x" a hit
func _beat(s: Dictionary, bar: int, drum: String, hits: String) -> void:
	for i in hits.length():
		if hits[i] == "x":
			s["sections"][0][DRUMS].append([bar * 4.0 + i / 4.0, 0.1, DRUM[drum][0], DRUM[drum][1] * 40])


## Moon Lounge: D minor, 84 to the minute, eight bars. Dm9, G13, Cmaj7, A7, two bars each.
func _lounge() -> Dictionary:
	var s := _song(84.0, 8)
	var chords := [[50, 53, 57, 60, 64], [43, 53, 59, 64, 65], [48, 52, 55, 59, 64], [45, 49, 52, 55, 58]]
	for c in 4:
		var bar := c * 2
		var ch: Array = chords[c]
		_chord(s, ORGAN, bar * 4.0, ch.slice(1), 7.6)
		_add(s, TUBA, bar * 4.0, ch[0], 1.6)
		_add(s, TUBA, bar * 4.0 + 2.0, ch[0] + 7, 1.4)
		_add(s, TUBA, bar * 4.0 + 4.0, ch[0], 1.6)
		_add(s, TUBA, bar * 4.0 + 6.5, ch[0] + 5, 1.2)
		for k in 4:
			_add(s, BELLS, bar * 4.0 + 0.5 + k * 0.75 + (4.0 if c % 2 == 1 else 0.0), ch[4 - k] + 12, 0.5)
	for bar in 8:
		_beat(s, bar, "hat", "....x.......x...")
		_beat(s, bar, "rim", "........x.......")
		_beat(s, bar, "kick", "x.........x.....")
	_tune(s, THEREMIN, 0.0, [[74, 8], [77, 4], [76, 4], [69, 16], [67, 8], [71, 4], [74, 4], [72, 16],
		[71, 6], [72, 2], [74, 8], [76, 12], [79, 4], [76, 8], [73, 8], [69, 16]])
	return s


## Night Visitors: A minor, 116 to the minute, eight bars. Am, F, Dm, E7, a bar each, twice.
func _visitors() -> Dictionary:
	var s := _song(116.0, 8)
	var roots := [45, 41, 38, 40]
	var stabs := [[57, 60, 64], [57, 60, 65], [57, 62, 65], [56, 59, 62, 64]]
	for bar in 8:
		var c := bar % 4
		var r: int = roots[c]
		_tune(s, TUBA, bar * 4.0, [[r, 3], [-1, 1], [r, 2], [r + 7, 2], [r + 12, 3], [-1, 1], [r + 7, 2], [r, 2]])
		for off: float in [0.5, 1.5, 2.5, 3.5]:
			_chord(s, ORGAN, bar * 4.0 + off, stabs[c], 0.2)
		_beat(s, bar, "kick", "x.......x.......")
		_beat(s, bar, "snare", "....x.......x...")
		_beat(s, bar, "hat", "x.x.x.x.x.x.x.x.")
		if bar % 4 == 0:
			_add(s, BELLS, bar * 4.0, 81, 0.5)
	_beat(s, 7, "tom", "........x.x.x.x.")
	_tune(s, THEREMIN, 0.0, [[69, 6], [72, 2], [76, 8], [75, 4], [76, 4], [77, 8], [76, 4], [72, 4], [74, 16],
		[-1, 4], [72, 4], [71, 4], [69, 4], [68, 12], [71, 4], [76, 16]])
	return s


## Tanks!: E minor, 152 to the minute, eight bars. Em, C, D, B7, a bar each, twice.
func _chase() -> Dictionary:
	var s := _song(152.0, 8)
	var roots := [40, 36, 38, 35]
	var hits := [[64, 67, 71], [64, 67, 72], [62, 66, 69], [63, 66, 69, 71]]
	for bar in 8:
		var c := bar % 4
		var r: int = roots[c]
		for beat in 4:
			_add(s, BASSOON, bar * 4.0 + beat, r, 0.2)
			_add(s, BASSOON, bar * 4.0 + beat + 0.25, r, 0.2)
			_add(s, BASSOON, bar * 4.0 + beat + 0.5, r + 12, 0.2)
			_add(s, TUBA, bar * 4.0 + beat, r, 0.45)
		_chord(s, TRUMPET, bar * 4.0 + 0.5, hits[c], 0.45)
		_chord(s, TRUMPET, bar * 4.0 + 3.0, hits[c], 0.7)
		for k in 16:
			_add(s, VIOLA, bar * 4.0 + k * 0.25, hits[c][1] - 12, 0.2)
		_beat(s, bar, "kick", "x...x...x...x...")
		_beat(s, bar, "snare", "....x.......x..x")
		_beat(s, bar, "hat", "x.x.x.x.x.x.x.x.")
		if bar % 4 == 0:
			_beat(s, bar, "crash", "x...............")
	_beat(s, 3, "snare", "............xxxx")
	_beat(s, 7, "snare", "........xxxxxxxx")
	_tune(s, THEREMIN, 0.0, [[76, 4], [79, 4], [83, 8], [84, 8], [83, 4], [79, 4], [81, 12], [78, 4], [79, 16],
		[76, 4], [79, 4], [83, 8], [88, 8], [87, 4], [84, 4], [86, 8], [87, 8], [83, 16]])
	return s
