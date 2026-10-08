class_name SfxBank
extends RefCounted
## Recepten laden (JSON) en gegenereerde streams cachen.
## Lookup-volgorde: characters/<id>/sfx/<naam>.json  ->  engine/audio/recipes/<naam>.json

const RECIPE_DIR: String = "res://engine/audio/recipes/"
const CHARACTER_DIR: String = "res://characters/%s/sfx/%s.json"

const NAMES: PackedStringArray = [
	"hit_weak", "hit_medium", "hit_strong", "hit_kill",
	"shield_hit", "shield_break", "grab", "throw",
	"jump", "double_jump", "land", "land_heavy",
	"airdodge", "wavedash_slide", "dash", "ledge_grab",
	"ko_blast", "respawn",
	"menu_move", "menu_confirm", "menu_back", "countdown_tick", "go",
]

static var _streams: Dictionary = {}   # "<char>/<naam>" -> AudioStreamWAV
static var _recipes: Dictionary = {}   # "<char>/<naam>" -> Dictionary ({} = niet gevonden)


static func recipe_path(sfx_name: String, character_id: String = "") -> String:
	if character_id != "":
		var p: String = CHARACTER_DIR % [character_id, sfx_name]
		if FileAccess.file_exists(p):
			return p
	var d: String = RECIPE_DIR + sfx_name + ".json"
	return d if FileAccess.file_exists(d) else ""


static func get_recipe(sfx_name: String, character_id: String = "") -> Dictionary:
	var key: String = character_id + "/" + sfx_name
	if _recipes.has(key):
		return _recipes[key]
	var r: Dictionary = {}
	var path: String = recipe_path(sfx_name, character_id)
	if path != "":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			r = parsed
		else:
			push_error("SfxBank: ongeldige JSON in %s" % path)
	_recipes[key] = r
	return r


## Geeft de (gecachete) stream, of null als het geluid niet bestaat.
static func get_stream(sfx_name: String, character_id: String = "") -> AudioStreamWAV:
	var key: String = character_id + "/" + sfx_name
	if _streams.has(key):
		return _streams[key]
	var r: Dictionary = get_recipe(sfx_name, character_id)
	if r.is_empty():
		push_warning("SfxBank: onbekend geluid '%s'" % sfx_name)
		return null
	var s: AudioStreamWAV = SfxSynth.make_stream(r)
	_streams[key] = s
	return s


static func get_volume_db(sfx_name: String, character_id: String = "") -> float:
	return float(get_recipe(sfx_name, character_id).get("volume_db", 0.0))


static func clear_cache() -> void:
	_streams.clear()
	_recipes.clear()
