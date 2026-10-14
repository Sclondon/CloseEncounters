class_name Sfx
extends Node
## Every sound is made at start-up, as in Cryptlins (no audio files): the beam's warbling hum,
## the bloop of a catch, the animals' voices, guns, booms, and a siren for the police.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var hum: AudioStreamPlayer
var siren: AudioStreamPlayer
var engine: AudioStreamPlayer
var next := 0
var muted := false:
	set(value):
		muted = value
		AudioServer.set_bus_mute(0, muted)


func _ready() -> void:
	sounds["bloop"] = _voice(0.32, PackedFloat32Array([300.0, 520.0, 1400.0]), 0.5)
	sounds["moo"] = _voice(0.8, PackedFloat32Array([150.0, 190.0, 175.0, 120.0]), 0.6, 0.01, 0.1)
	sounds["baa"] = _voice(0.5, PackedFloat32Array([420.0, 440.0, 400.0]), 0.5, 0.12, 0.1)
	sounds["oink"] = _voice(0.2, PackedFloat32Array([260.0, 330.0, 200.0]), 0.6, 0.0, 0.45)
	sounds["cluck"] = _voice(0.12, PackedFloat32Array([900.0, 1300.0, 700.0]), 0.5, 0.0, 0.2)
	sounds["neigh"] = _voice(0.7, PackedFloat32Array([700.0, 1100.0, 900.0, 1000.0, 600.0]), 0.45, 0.09, 0.2)
	sounds["howl"] = _voice(1.0, PackedFloat32Array([500.0, 900.0, 950.0, 700.0]), 0.4, 0.02, 0.05)
	sounds["scream"] = _voice(0.6, PackedFloat32Array([700.0, 1200.0, 1100.0, 800.0]), 0.45, 0.04, 0.1)
	sounds["bang"] = _voice(0.25, PackedFloat32Array([180.0, 60.0]), 0.8, 0.0, 0.9)
	sounds["pop"] = _voice(0.1, PackedFloat32Array([500.0, 120.0]), 0.6, 0.0, 0.85)
	sounds["rat"] = _voice(0.05, PackedFloat32Array([400.0, 100.0]), 0.6, 0.0, 0.9)
	sounds["boom"] = _voice(0.9, PackedFloat32Array([90.0, 40.0, 30.0]), 1.0, 0.0, 0.85)
	sounds["clang"] = _voice(0.2, PackedFloat32Array([1300.0, 900.0]), 0.6, 0.02, 0.4)
	sounds["thud"] = _voice(0.15, PackedFloat32Array([120.0, 50.0]), 0.8, 0.0, 0.5)
	sounds["whoosh"] = _voice(0.9, PackedFloat32Array([200.0, 600.0, 300.0]), 0.5, 0.0, 0.95)
	sounds["star"] = _voice(0.5, PackedFloat32Array([880.0, 660.0, 880.0, 660.0]), 0.45, 0.0, 0.0)
	sounds["cool"] = _voice(0.5, PackedFloat32Array([660.0, 520.0, 440.0]), 0.35, 0.0, 0.0)
	sounds["click"] = _voice(0.04, PackedFloat32Array([1700.0, 700.0]), 0.45, 0.0, 0.5)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	hum = _looper(_theremin(), -10.0)
	siren = _looper(_siren(), -20.0)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = sounds[sound]
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.volume_db = volume_db
	p.play()


func loop(p: AudioStreamPlayer, on: bool) -> void:
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()


func _looper(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p


# A short voiced sweep through `freqs`, with optional vibrato (a fraction of the pitch) and noise
func _voice(dur: float, freqs: PackedFloat32Array, vol: float, vibrato := 0.0, noise := 0.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var last := freqs.size() - 1
	for i in n:
		var u := float(i) / n
		var at := u * last
		var k := mini(int(at), last)
		var f := lerpf(freqs[k], freqs[mini(k + 1, last)], at - k)
		f *= 1.0 + sin(u * dur * TAU * 11.0) * vibrato
		phase += TAU * f / RATE
		var s := sin(phase) + 0.35 * sin(phase * 2.0) + 0.15 * sin(phase * 3.0)
		if noise > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)
		var env := minf(u / 0.05, 1.0) * minf((1.0 - u) / 0.4, 1.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol * 0.6, -1.0, 1.0) * 32767.0))
	return _wav(data)


# Two seconds that loop cleanly: a theremin wavering up and down, as a saucer's beam should sound
func _theremin() -> AudioStreamWAV:
	var n := RATE * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 520.0 + 120.0 * sin(TAU * 0.5 * t) + 18.0 * sin(TAU * 6.0 * t)
		phase += TAU * f / RATE
		var s := sin(phase) * 0.8 + sin(phase * 0.5) * 0.2
		data.encode_s16(i * 2, int(s * 0.35 * 32767.0))
	var wav := _wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav


# A police siren's wail, a second up and a second down
func _siren() -> AudioStreamWAV:
	var n := RATE * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 650.0 + 350.0 * (0.5 - 0.5 * cos(PI * t))
		phase += TAU * f / RATE
		var s := sin(phase) + 0.3 * sin(phase * 3.0)
		data.encode_s16(i * 2, int(s * 0.3 * 32767.0))
	var wav := _wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
