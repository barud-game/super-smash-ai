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
