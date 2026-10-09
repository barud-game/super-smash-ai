class_name Archetypes
extends RefCounted
## Movement-presets per archetype (engine/fighter/archetypes/<id>.tres). Vaste volgorde (deterministisch).
## Referentiecharacters: zie docs/movement.md, "Archetype-presets".

const DIR: String = "res://engine/fighter/archetypes"
const IDS: Array[String] = ["allrounder", "fast_faller", "heavyweight", "floaty", "lightweight"]


static func path(id: String) -> String:
	return "%s/%s.tres" % [DIR, id]


static func load_stats(id: String) -> FighterStats:
	var s: FighterStats = load(path(id)) as FighterStats
	if s == null:
		push_error("Archetypes: kan %s niet laden" % path(id))
	return s


## Archetype-namen zoals in character.json/presets (NL/EN, hoofdletters vrij) -> id.
const ALIASES: Dictionary = {
	"allrounder": "allrounder", "fast_faller": "fast_faller", "fastfaller": "fast_faller",
	"heavyweight": "heavyweight", "zwaargewicht": "heavyweight", "floaty": "floaty",
	"lightweight": "lightweight", "lichtgewicht": "lightweight",
}


## "Zwaargewicht" / "Fast-faller" / "heavyweight" -> id; onbekend = "".
static func normalize(raw: String) -> String:
	var k: String = raw.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	return String(ALIASES.get(k, ""))


## Archetype-id van een preset-resource (via resource_path of display_name); "" als onbekend.
static func id_for_stats(s: FighterStats) -> String:
	if s == null:
		return ""
	if s.resource_path.begins_with(DIR + "/") and s.resource_path.ends_with(".tres"):
		var id: String = s.resource_path.get_file().get_basename()
		if IDS.has(id):
			return id
	return normalize(s.display_name)


## Archetype-id uit characters/<id>/character.json ("" als onbekend).
static func id_for_character(character_id: String) -> String:
	var path: String = "res://characters/%s/character.json" % character_id
	if character_id == "" or not FileAccess.file_exists(path):
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		return normalize(String((data as Dictionary).get("archetype", "")))
	return ""
