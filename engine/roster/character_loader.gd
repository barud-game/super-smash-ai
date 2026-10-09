class_name CharacterLoader
extends RefCounted
## Centrale plek waar een character-map `characters/<id>/` tot spelbare data wordt. Match, training en sandbox
## gebruiken allemaal `CharacterLoader.stats_for(id)`. Formaat: docs/character-creatie.md ("Opslag per character").
##
## stats_for(id):
##   1. `stats.tres` (FighterStats) bestaat -> volledige override (alleen visual_height wordt geklemd).
##   2. anders: archetype-preset (character.json "archetype") als kopie, daarna
##        a. `visual_height` uit character.json (8-30, geklemd + waarschuwing),
##        b. `movement_extras` uit scores.json via de vaste tabel EXTRAS (docs/balans.md sectie 2).
## Een onbekend of ontbrekend character geeft de Allrounder-preset.

## Map met characters. Alleen te overschrijven door tests (de rest van de engine leest res://characters).
static var root: String = "res://characters"
static var _cache: Dictionary = {}

## Movement-extra -> [effect-omschrijving]. De sleutel in scores.json mag ook een alias zijn (EXTRA_ALIASES);
## de waarde in scores.json zijn de punten (balans.md) en wordt hier genegeerd.
const EXTRAS: Dictionary = {
	"zwaarder": "weight x1.10",
	"lichter": "weight x0.90",
	"extra_jump": "air_jumps +1",
	"geen_double_jump": "air_jumps = 0",
	"snellere_jumpsquat": "jumpsquat_frames -1 (min 2)",
	"tragere_dash": "dash_initial_velocity x0.8, dash_accel_additional x0.85",
	"langere_wavedash": "traction x0.8",
	"glide": "stats.glide = true (vlag)",
	"wall_jump": "stats.wall_jump = true (vlag)",
}
const EXTRA_ALIASES: Dictionary = {
	"heavier": "zwaarder", "heavy": "zwaarder", "lighter": "lichter", "light": "lichter",
	"extra_jumps": "extra_jump", "no_double_jump": "geen_double_jump", "geen_dubbele_sprong": "geen_double_jump",
	"faster_jumpsquat": "snellere_jumpsquat", "slower_dash": "tragere_dash",
	"longer_wavedash": "langere_wavedash", "walljump": "wall_jump",
}
const WEIGHT_HEAVIER: float = 1.10
const WEIGHT_LIGHTER: float = 0.90
const DASH_SLOW_INITIAL: float = 0.8
const DASH_SLOW_ACCEL: float = 0.85
const WAVEDASH_TRACTION: float = 0.8
const JUMPSQUAT_MIN: int = 2


static func clear_cache() -> void:
	_cache.clear()


static func dir(id: String) -> String:
	return root.path_join(id)


static func exists(id: String) -> bool:
	return id != "" and FileAccess.file_exists(dir(id).path_join("character.json"))


# --- manifest --------------------------------------------------------------------------------

static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## character.json als Dictionary (gecachet; leeg als het ontbreekt of ongeldig is).
static func manifest(id: String) -> Dictionary:
	var key: String = "m|%s|%s" % [root, id]
	if not _cache.has(key):
		_cache[key] = _json(dir(id).path_join("character.json"))
	return _cache[key]


static func scores(id: String) -> Dictionary:
	var key: String = "s|%s|%s" % [root, id]
	if not _cache.has(key):
		_cache[key] = _json(dir(id).path_join("scores.json"))
	return _cache[key]


## Archetype-id (allrounder/fast_faller/...) uit character.json; "allrounder" als onbekend.
static func archetype_id(id: String) -> String:
	var a: String = Archetypes.normalize(String(manifest(id).get("archetype", "")))
	return a if a != "" else "allrounder"


## Geklemde lengte uit character.json; < 0 als het veld ontbreekt.
static func visual_height_of(id: String, warnings: PackedStringArray = PackedStringArray()) -> float:
	var m: Dictionary = manifest(id)
	if not m.has("visual_height"):
		return -1.0
	var raw: float = float(m["visual_height"])
	var vh: float = clampf(raw, FighterStats.VISUAL_HEIGHT_MIN, FighterStats.VISUAL_HEIGHT_MAX)
	if not is_equal_approx(raw, vh):
		var msg: String = "visual_height %.1f buiten %.0f-%.0f, geklemd op %.1f" % [raw, FighterStats.VISUAL_HEIGHT_MIN,
			FighterStats.VISUAL_HEIGHT_MAX, vh]
		warnings.append(msg)
		push_warning("[CharacterLoader:%s] %s" % [id, msg])
	return vh


static func taunt_text(id: String) -> String:
	return String(manifest(id).get("taunt_text", ""))


static func taunt_frames(id: String) -> int:
	var n: int = int(manifest(id).get("taunt_frames", FighterConst.TAUNT_FRAMES))
	return clampi(n, FighterConst.TAUNT_FRAMES_MIN, FighterConst.TAUNT_FRAMES_MAX)


## `taunt_props` uit character.json: ruwe prop-events (PropEvent).
static func taunt_props(id: String) -> Array:
	var raw: Variant = manifest(id).get("taunt_props", [])
	return raw if raw is Array else []


# --- stats -----------------------------------------------------------------------------------

## Movement-stats van een character (zie klasse-commentaar). Altijd een eigen kopie: vrij te muteren.
static func stats_for(id: String) -> FighterStats:
	return report(id)["stats"]


## Als stats_for, plus {archetype, source ("preset"/"stats.tres"/"fallback"), warnings, applied (extras)}.
static func report(id: String) -> Dictionary:
	var warnings := PackedStringArray()
	var applied: Array[String] = []
	var arch: String = archetype_id(id)
	var stats: FighterStats = null
	var source: String = "preset"
	var override_path: String = dir(id).path_join("stats.tres")
	if id != "" and ResourceLoader.exists(override_path):
		var res: Resource = ResourceLoader.load(override_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is FighterStats:
			stats = (res as FighterStats).duplicate() as FighterStats
			source = "stats.tres"
		else:
			warnings.append("stats.tres is geen FighterStats; archetype-preset gebruikt")
	if stats == null:
		var base: FighterStats = Archetypes.load_stats(arch)
		if base == null:
			base = Archetypes.load_stats("allrounder")
			source = "fallback"
		stats = base.duplicate() as FighterStats
		if not exists(id):
			source = "fallback"
		var vh: float = visual_height_of(id, warnings)
		if vh > 0.0:
			stats.visual_height = vh
		var extras: Variant = scores(id).get("movement_extras", {})
		if extras is Dictionary:
			for k: Variant in (extras as Dictionary).keys():
				var name_: String = canonical_extra(String(k))
				if name_ == "":
					warnings.append("onbekende movement_extra '%s' (genegeerd)" % k)
					push_warning("[CharacterLoader:%s] onbekende movement_extra '%s'" % [id, k])
					continue
				apply_extra(stats, name_)
				applied.append(name_)
	else:
		stats.visual_height = clampf(stats.visual_height, FighterStats.VISUAL_HEIGHT_MIN, FighterStats.VISUAL_HEIGHT_MAX)
	return {"stats": stats, "archetype": arch, "source": source, "warnings": warnings, "applied": applied}


## Alias of canonieke naam -> canonieke naam; "" als onbekend.
static func canonical_extra(key: String) -> String:
	var k: String = key.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	k = String(EXTRA_ALIASES.get(k, k))
	return k if EXTRAS.has(k) else ""


## Past één movement-extra toe op `s` (de tabel staat in docs/balans.md sectie 2).
static func apply_extra(s: FighterStats, extra: String) -> void:
	match extra:
		"zwaarder":
			s.weight *= WEIGHT_HEAVIER
		"lichter":
			s.weight *= WEIGHT_LIGHTER
		"extra_jump":
			s.air_jumps += 1
			if not s.air_jump_forces.is_empty():
				s.air_jump_forces.append(s.air_jump_forces[s.air_jump_forces.size() - 1])
		"geen_double_jump":
			s.air_jumps = 0
		"snellere_jumpsquat":
			s.jumpsquat_frames = maxi(s.jumpsquat_frames - 1, JUMPSQUAT_MIN)
		"tragere_dash":
			s.dash_initial_velocity *= DASH_SLOW_INITIAL
			s.dash_accel_additional *= DASH_SLOW_ACCEL
		"langere_wavedash":
			s.traction *= WAVEDASH_TRACTION
		"glide":
			s.glide = true
		"wall_jump":
			s.wall_jump = true
