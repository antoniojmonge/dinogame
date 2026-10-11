extends Node

## Gestor de audio (autoload "Sfx"). Sintetiza los sonidos en el momento
## (chip-tune retro) para no depender de archivos externos. Reemplazables luego.

const RATE := 44100

var _sfx: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _drift: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sfx()
	_music = AudioStreamPlayer.new()
	_music.stream = _make_music()
	_music.volume_db = -12.0
	add_child(_music)
	_music.play()

	_drift = AudioStreamPlayer.new()
	_drift.stream = _make_drift()
	_drift.volume_db = -16.0
	add_child(_drift)

	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play(sound: String) -> void:
	if not _sfx.has(sound):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[sound]
			p.play()
			return


func set_drift(on: bool) -> void:
	if on and not _drift.playing:
		_drift.play()
	elif not on and _drift.playing:
		_drift.stop()


# --- Sintesis ---

func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _buffer(dur: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(dur * RATE))
	return a


func _add_tone(a: PackedFloat32Array, start: float, f0: float, f1: float, dur: float, vol: float, kind: int) -> void:
	# kind: 0 square, 1 sine, 2 triangle, 3 noise
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx < 0 or idx >= a.size():
			continue
		var t := float(i) / float(maxi(n - 1, 1))
		var freq := lerpf(f0, f1, t)
		var env := (1.0 - t) * (1.0 - t)
		var s := 0.0
		match kind:
			0:
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			1:
				s = sin(phase * TAU)
			2:
				s = abs(fmod(phase, 1.0) * 2.0 - 1.0) * 2.0 - 1.0
			3:
				s = randf() * 2.0 - 1.0
		a[idx] += s * env * vol
		phase += freq / float(RATE)


func _build_sfx() -> void:
	var b := _buffer(0.45)
	_add_tone(b, 0.0, 300.0, 1400.0, 0.45, 0.5, 0)
	_sfx["boost"] = _to_wav(b)

	var p := _buffer(0.3)
	_add_tone(p, 0.0, 880.0, 880.0, 0.1, 0.45, 0)
	_add_tone(p, 0.1, 1320.0, 1320.0, 0.2, 0.45, 0)
	_sfx["pickup"] = _to_wav(p)

	var h := _buffer(0.3)
	_add_tone(h, 0.0, 0.0, 0.0, 0.3, 0.5, 3)
	_add_tone(h, 0.0, 180.0, 60.0, 0.3, 0.6, 1)
	_sfx["hit"] = _to_wav(h)

	var j := _buffer(0.18)
	_add_tone(j, 0.0, 400.0, 900.0, 0.18, 0.4, 0)
	_sfx["jump"] = _to_wav(j)

	var sh := _buffer(0.2)
	_add_tone(sh, 0.0, 1200.0, 300.0, 0.2, 0.4, 0)
	_sfx["shoot"] = _to_wav(sh)

	var ab := _buffer(0.5)
	_add_tone(ab, 0.0, 200.0, 520.0, 0.5, 0.45, 2)
	_sfx["ability"] = _to_wav(ab)

	var l := _buffer(0.6)
	_add_tone(l, 0.0, 660.0, 660.0, 0.15, 0.4, 0)
	_add_tone(l, 0.15, 880.0, 880.0, 0.15, 0.4, 0)
	_add_tone(l, 0.3, 1320.0, 1320.0, 0.3, 0.45, 0)
	_sfx["lap"] = _to_wav(l)

	var f := _buffer(1.0)
	_add_tone(f, 0.0, 523.0, 523.0, 0.2, 0.4, 0)
	_add_tone(f, 0.2, 659.0, 659.0, 0.2, 0.4, 0)
	_add_tone(f, 0.4, 784.0, 784.0, 0.2, 0.4, 0)
	_add_tone(f, 0.6, 1046.0, 1046.0, 0.4, 0.45, 0)
	_sfx["finish"] = _to_wav(f)


func _make_drift() -> AudioStreamWAV:
	var a := _buffer(0.35)
	_add_tone(a, 0.0, 0.0, 0.0, 0.35, 0.6, 3)
	var w := _to_wav(a)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = a.size()
	return w


func _make_music() -> AudioStreamWAV:
	var bpm := 140.0
	var beat := 60.0 / bpm
	var bars := 4
	var total := beat * 4.0 * float(bars)
	var a := _buffer(total)
	var chords := [
		[220.0, 261.6, 329.6],
		[174.6, 220.0, 261.6],
		[261.6, 329.6, 392.0],
		[196.0, 246.9, 293.7],
	]
	for bar in bars:
		var chord: Array = chords[bar % chords.size()]
		var bass_f: float = chord[0] / 2.0
		for step in 4:
			_add_tone(a, bar * beat * 4.0 + step * beat, bass_f, bass_f, beat * 0.9, 0.28, 0)
		for step in 4:
			var note: float = chord[step % chord.size()] * 2.0
			_add_tone(a, bar * beat * 4.0 + step * beat, note, note, beat * 0.45, 0.15, 0)
	var w := _to_wav(a)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = a.size()
	return w
