class_name Sfx
extends Node
## Procedural audio. Every sound is synthesised into a sample buffer at startup.

## Audio is switched off for now. Set this to true to bring every sound back.
const ENABLED := false
const RATE := 16000

var streams := {}
var muted := false
var _pool: Array = []
var _pool3: Array = []
var _birds: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _lp := 0.0


func _ready() -> void:
	if not ENABLED:
		muted = true
		return
	_rng.seed = 20240
	_generate()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 8:
		var p := AudioStreamPlayer3D.new()
		setup3(p)
		add_child(p)
		_pool3.append(p)
	_birds = AudioStreamPlayer.new()
	_birds.stream = streams["birds"]
	add_child(_birds)
	_birds.play()
	_crickets = AudioStreamPlayer.new()
	_crickets.stream = streams["crickets"]
	add_child(_crickets)
	_crickets.play()
	set_day(1.0)


static func setup3(p: AudioStreamPlayer3D) -> void:
	p.unit_size = 16.0
	p.max_distance = 90.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE


func get_stream(n: String) -> AudioStream:
	return streams.get(n)


func play(n: String, db := -8.0) -> void:
	if not ENABLED:
		return
	for p in _pool:
		if not p.playing:
			p.stream = streams[n]
			p.volume_db = db
			p.play()
			return


func play_at(n: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	if not ENABLED:
		return
	for p in _pool3:
		if not p.playing:
			p.stream = streams[n]
			p.position = pos
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


## 1 = full day (birdsong), 0 = night (crickets).
func set_day(f: float) -> void:
	if not ENABLED:
		return
	_birds.volume_db = linear_to_db(maxf(0.001, f * 0.5))
	_crickets.volume_db = linear_to_db(maxf(0.001, (1.0 - f) * 0.6))


func set_muted(m: bool) -> void:
	if not ENABLED:
		return
	muted = m
	AudioServer.set_bus_mute(0, m)


# ---------------------------------------------------------------- synthesis

func _make(n: String, dur: float, f: Callable, loop := false) -> void:
	var count := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	_lp = 0.0
	for i in count:
		data.encode_s16(i * 2, int(clampf(f.call(float(i) / RATE), -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = count
	streams[n] = w


func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0


## Low-passed noise; k near 0 = dull rumble, near 1 = hiss.
func _soft(k: float) -> float:
	_lp += (_noise() - _lp) * k
	return _lp


func _generate() -> void:
	_make("click", 0.04, func(t): return sin(TAU * 1100.0 * t) * exp(-t * 90.0) * 0.5)
	_make("place", 0.18, func(t): return sin(TAU * (170.0 - 300.0 * t) * t) * exp(-t * 22.0) * 0.8 + _noise() * exp(-t * 60.0) * 0.25)
	var f1 := func(t):
		var lt: float = t if t < 0.07 else t - 0.07
		return sin(TAU * (1320.0 if t < 0.07 else 1760.0) * t) * exp(-lt * 14.0) * 0.35
	_make("coin", 0.3, f1)
	_make("error", 0.16, func(t): return signf(sin(TAU * 150.0 * t)) * 0.2 * exp(-t * 12.0))
	_make("chime", 0.5, func(t): return (sin(TAU * 660.0 * t) + 0.6 * sin(TAU * 990.0 * t)) * exp(-t * 7.0) * 0.28)
	var notes := [523.0, 659.0, 784.0, 1047.0]
	var f2 := func(t):
		var i := mini(3, int(t / 0.12))
		return sin(TAU * notes[i] * t) * exp(-(t - i * 0.12) * 6.0) * 0.32
	_make("jingle", 0.75, f2)
	_make("toll", 2.5, func(t): return (sin(TAU * 196.0 * t) + 0.5 * sin(TAU * 470.0 * t) + 0.3 * sin(TAU * 705.0 * t)) * exp(-t * 1.6) * 0.32)
	var f3 := func(t):
		if t > 0.54:
			return 0.0
		var lt := fmod(t, 0.18)
		return sin(TAU * 120.0 * lt) * exp(-lt * 45.0) * 0.9 + _noise() * exp(-lt * 80.0) * 0.3
	_make("knock", 0.6, f3)
	_make("flush", 1.4, func(t): return _soft(0.35) * sqrt(sin(PI * t / 1.4)) * 0.9)
	_make("water", 1.2, func(_t): return _soft(0.5) * 0.5, true)
	var f4 := func(_t):
		var n := _noise()
		return (n - _soft(0.4)) * (0.12 + (0.25 if _rng.randf() < 0.02 else 0.0))
	_make("sizzle", 1.0, f4, true)
	_make("tv", 2.0, func(t): return sin(TAU * (180.0 + 40.0 * sin(TAU * 3.0 * t)) * t) * (0.5 + 0.5 * sin(TAU * 5.5 * t)) * 0.16 + _soft(0.2) * 0.08, true)
	var scale := [262.0, 294.0, 330.0, 392.0, 440.0, 523.0]
	var tune := []
	for i in 8:
		tune.append(scale[_rng.randi() % scale.size()])
	var f5 := func(t):
		var i := int(t / 0.5) % 8
		var lt := fmod(t, 0.5)
		var f: float = tune[i]
		var bass := 131.0 if i % 4 < 2 else 98.0
		return (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * exp(-lt * 4.0) * 0.22 + sin(TAU * bass * t) * 0.14 * exp(-fmod(t, 1.0) * 2.0)
	_make("music", 4.0, f5, true)
	var taps := []
	for i in 8:
		taps.append(_rng.randf() * 1.1)
	var f6 := func(t):
		var v := 0.0
		for c in taps:
			if t >= c and t < c + 0.03:
				v += _noise() * exp(-(t - c) * 200.0) * 0.35
		return v
	_make("keys", 1.2, f6, true)
	_make("munch", 0.8, func(t): return _soft(0.25) * exp(-fmod(t, 0.4) * 18.0) * 1.2, true)
	var chirps := []
	for i in 8:
		chirps.append([_rng.randf() * 4.6, _rng.randf_range(2200.0, 3800.0), _rng.randf_range(0.1, 0.2), _rng.randf_range(-3000.0, 3000.0)])
	var f7 := func(t):
		var v := 0.0
		for c in chirps:
			var lt: float = t - c[0]
			if lt >= 0.0 and lt < c[2]:
				v += sin(TAU * (c[1] + c[3] * lt + 300.0 * sin(TAU * 25.0 * lt)) * lt) * sin(PI * lt / c[2]) * 0.14
		return v
	_make("birds", 5.0, f7, true)
	_make("crickets", 1.0, func(t): return sin(TAU * 4200.0 * t) * maxf(0.0, sin(TAU * 28.0 * t)) * (1.0 if fmod(t, 0.5) < 0.3 else 0.0) * 0.07, true)
	for k in 3:
		var syl := []
		for i in 4:
			syl.append(_rng.randf_range(210.0, 400.0))
		var f8 := func(t):
			var i := mini(3, int(t / 0.17))
			var lt: float = t - i * 0.17
			if lt > 0.13:
				return 0.0
			var f: float = syl[i] * (1.0 + 0.04 * sin(TAU * 9.0 * t))
			return (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) + 0.25 * sin(TAU * f * 3.0 * t)) * sin(PI * lt / 0.13) * 0.22
		_make("talk%d" % k, 0.68, f8)
