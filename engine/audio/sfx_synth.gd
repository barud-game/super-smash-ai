class_name SfxSynth
extends RefCounted
## Procedurele geluidssynth: recept (Dictionary uit JSON) -> AudioStreamWAV.
## 16-bit, 44.1 kHz, mono. Volledig deterministisch: ruis komt uit een eigen LCG met vaste seed,
## nooit uit randf(). Zie docs/audio.md voor het receptformaat.

const RATE: int = 44100
const DEFAULT_PEAK: float = 0.89
const FADE_IN: int = 8      # samples
const FADE_OUT: int = 96    # samples (~2 ms), voorkomt kliks aan het eind
const MAX_CUTOFF_FRAC: float = 0.16   # SVF-filter blijft stabiel tot ~rate/6


## Rendert een recept naar floats in [-1, 1] (peak-genormaliseerd).
static func render(recipe: Dictionary) -> PackedFloat32Array:
	var duration: float = clampf(float(recipe.get("duration", 0.2)), 0.01, 3.0)
	var total: int = int(ceil(duration * RATE))
	var mix := PackedFloat32Array()
	mix.resize(total)
	var base_seed: int = int(recipe.get("seed", 1))
	var layers: Array = recipe.get("layers", [])
	for li in layers.size():
		_render_layer(mix, layers[li], base_seed + li * 7919, duration)
	_master(mix, recipe.get("master", {}))
	_finish(mix, float(recipe.get("peak", DEFAULT_PEAK)))
	return mix


static func make_stream(recipe: Dictionary) -> AudioStreamWAV:
	return to_stream(render(recipe))


static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, clampi(int(round(samples[i] * 32767.0)), -32768, 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


## Piek, RMS (beide 0..1) en duur in seconden.
static func stats(samples: PackedFloat32Array) -> Dictionary:
	var peak: float = 0.0
	var sum: float = 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
		sum += v * v
	var rms: float = sqrt(sum / maxf(1.0, float(samples.size())))
	return {"peak": peak, "rms": rms, "duration": float(samples.size()) / RATE}


static func _pair(v: Variant, fallback: float) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return Vector2(fallback, fallback)


static func _render_layer(mix: PackedFloat32Array, L: Dictionary, seed_value: int, duration: float) -> void:
	var total: int = mix.size()
	var delay: float = float(L.get("delay", 0.0))
	var start: int = int(round(delay * RATE))
	var len_s: float = float(L.get("len", duration - delay))
	len_s = minf(len_s, duration - delay)
	var n: int = mini(int(round(len_s * RATE)), total - start)
	if n <= 0:
		return
	var osc: String = str(L.get("osc", "sine"))
	var f: Vector2 = _pair(L.get("freq", 440.0), 440.0)
	f.x = maxf(f.x, 1.0)
	f.y = maxf(f.y, 1.0)
	var curve: float = float(L.get("curve", 1.0))
	var duty: float = clampf(float(L.get("duty", 0.5)), 0.05, 0.95)
	var env: Array = L.get("env", [0.002, 0.0, 1.0, 0.01])
	var ea: float = float(env[0])
	var ed: float = float(env[1])
	var es: float = float(env[2])
	var er: float = float(env[3])
	var epow: float = float(L.get("pow", 2.0))
	var gain: float = float(L.get("gain", 1.0))
	var vib: Vector2 = _pair(L.get("vib", [0.0, 0.0]), 0.0)
	var bits: int = int(L.get("bits", 0))
	var hold: int = maxi(1, int(L.get("hold", 1)))
	var drive: float = float(L.get("drive", 0.0))
	var drive_norm: float = tanh(1.0 + drive)
	var flt: Dictionary = L.get("filter", {})
	var ftype: String = str(flt.get("type", ""))
	var cut: Vector2 = _pair(flt.get("cutoff", 2000.0), 2000.0)
	var damp: float = 1.0 / maxf(0.5, float(flt.get("q", 0.7)))
	var low: float = 0.0
	var band: float = 0.0
	var rng: int = seed_value & 0xFFFFFFFF
	var phase: float = 0.0
	var held: float = 0.0
	var qlevels: float = pow(2.0, float(bits) - 1.0) if bits > 0 else 0.0
	for i in n:
		var x: float = float(i) / float(n)
		var t: float = float(i) / RATE
		# envelope
		var e: float = es
		if ea > 0.0 and t < ea:
			e = t / ea
		elif ed > 0.0 and t < ea + ed:
			e = es + (1.0 - es) * pow(1.0 - (t - ea) / ed, epow)
		var rem: float = len_s - t
		if er > 0.0 and rem < er:
			e *= maxf(0.0, rem / er)
		# frequency / phase
		var fr: float = f.x * pow(f.y / f.x, pow(x, curve))
		if vib.y != 0.0:
			fr *= pow(2.0, vib.y * sin(TAU * vib.x * t) / 12.0)
		phase += fr / RATE
		phase -= floor(phase)
		var v: float
		match osc:
			"square":
				v = 1.0 if phase < duty else -1.0
			"saw":
				v = 2.0 * phase - 1.0
			"tri":
				v = 4.0 * absf(phase - 0.5) - 1.0
			"noise":
				rng = (rng * 1664525 + 1013904223) & 0xFFFFFFFF
				v = float(rng >> 8) / 8388608.0 - 1.0
			_:
				v = sin(TAU * phase)
		# filter (Chamberlin state-variable)
		if ftype != "":
			var fc: float = clampf(cut.x * pow(cut.y / cut.x, x), 20.0, RATE * MAX_CUTOFF_FRAC)
			var ff: float = 2.0 * sin(PI * fc / RATE)
			low += ff * band
			var high: float = v - low - damp * band
			band += ff * high
			match ftype:
				"hp":
					v = high
				"bp":
					v = band
				_:
					v = low
		# bitcrush / sample-rate reductie / distortion
		if hold > 1:
			if i % hold == 0:
				held = v
			v = held
		if qlevels > 0.0:
			v = round(v * qlevels) / qlevels
		if drive > 0.0:
			v = tanh(v * (1.0 + drive)) / drive_norm
		mix[start + i] += v * e * gain


static func _master(mix: PackedFloat32Array, M: Dictionary) -> void:
	var drive: float = float(M.get("drive", 0.0))
	var lp: float = float(M.get("lp", 0.0))
	if lp > 0.0:
		var ff: float = 2.0 * sin(PI * clampf(lp, 20.0, RATE * MAX_CUTOFF_FRAC) / RATE)
		var low: float = 0.0
		var band: float = 0.0
		for i in mix.size():
			low += ff * band
			var high: float = mix[i] - low - 0.7 * band
			band += ff * high
			mix[i] = low
	if drive > 0.0:
		# eerst grof naar ~1 normaliseren zodat drive voorspelbaar werkt
		var pk: float = 0.0
		for v in mix:
			pk = maxf(pk, absf(v))
		var inv: float = 1.0 / maxf(pk, 0.0001)
		var norm: float = tanh(1.0 + drive)
		for i in mix.size():
			mix[i] = tanh(mix[i] * inv * (1.0 + drive)) / norm


static func _finish(mix: PackedFloat32Array, peak_target: float) -> void:
	var n: int = mix.size()
	var mean: float = 0.0
	for v in mix:
		mean += v
	mean /= maxf(1.0, float(n))
	for i in n:
		mix[i] -= mean
	for i in mini(FADE_IN, n):
		mix[i] *= float(i) / FADE_IN
	for i in mini(FADE_OUT, n):
		mix[n - 1 - i] *= float(i) / FADE_OUT
	var pk: float = 0.0
	for v in mix:
		pk = maxf(pk, absf(v))
	if pk > 0.0:
		var g: float = clampf(peak_target, 0.05, 0.99) / pk
		for i in n:
			mix[i] *= g
