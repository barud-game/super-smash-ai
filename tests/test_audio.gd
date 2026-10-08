extends SceneTree
## Headless test voor de geluidssynth. Draaien:
##   Godot_console.exe --headless --path . --script res://tests/test_audio.gd

const Synth := preload("res://engine/audio/sfx_synth.gd")
const Bank := preload("res://engine/audio/sfx_bank.gd")

const MAX_LEN: float = 1.5
const MIN_RMS: float = 0.01   # geen stilte

var _fails: int = 0
var _total: int = 0


func _initialize() -> void:
	print("%-16s %6s %6s %6s" % ["naam", "dur", "peak", "rms"])
	for n in Bank.NAMES:
		_test_one(n)
	_test_override_lookup()
	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _test_one(n: String) -> void:
	var r: Dictionary = Bank.get_recipe(n)
	check("%s: recept bestaat" % n, not r.is_empty())
	if r.is_empty():
		return
	var a: PackedFloat32Array = Synth.render(r)
	var st: Dictionary = Synth.stats(a)
	print("%-16s %5.3fs %6.3f %6.3f" % [n, st["duration"], st["peak"], st["rms"]])
	check("%s: duur <= %.1fs" % [n, MAX_LEN], st["duration"] <= MAX_LEN and st["duration"] > 0.0)
	check("%s: geen clipping (peak <= 1)" % n, st["peak"] <= 1.0)
	check("%s: niet stil (rms > %.2f)" % [n, MIN_RMS], st["rms"] > MIN_RMS)
	var finite: bool = true
	for v in a:
		if is_nan(v) or is_inf(v):
			finite = false
			break
	check("%s: alle samples eindig" % n, finite)
	var b1: PackedByteArray = Synth.to_stream(a).data
	var b2: PackedByteArray = Synth.to_stream(Synth.render(r)).data
	check("%s: deterministisch" % n, b1 == b2 and b1.size() == a.size() * 2)
	var s: AudioStreamWAV = Synth.to_stream(a)
	check("%s: 16-bit 44.1k mono" % n, s.format == AudioStreamWAV.FORMAT_16_BITS and s.mix_rate == 44100 and not s.stereo)


func _test_override_lookup() -> void:
	check("override: onbekend karakter valt terug op standaard", Bank.recipe_path("jump", "bestaat_niet").ends_with("recipes/jump.json"))
	check("onbekend geluid geeft leeg pad", Bank.recipe_path("nope") == "")
