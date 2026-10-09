class_name MoveSet
extends RefCounted
## De moves van één fighter (docs/combat.md, "M3-integratie"):
##   1. archetype-moveset  `engine/fighter/archetypes/<archetype>/moves/<move>.tres`
##   2. per move overschreven door `characters/<character_id>/moves/<move>.tres` als die bestaat
##   3. gemeenschappelijke moves die geen bestand hebben (ledge attack, getup attack) worden ingebouwd
##      gegenereerd (`builtin()`), geschaald met de lengte van het character.
## Resultaat: Dictionary move-naam -> MoveData. Bestanden worden gecachet per (archetype, character);
## `clear_cache()` voor hot reload. Alleen lezen: MoveData-resources worden gedeeld tussen fighters.

const ARCHETYPE_DIR: String = "res://engine/fighter/archetypes/%s/moves"
const CHARACTER_DIR: String = "res://characters/%s/moves"
## Moves die het systeem zelf aanvult als er geen bestand is.
const BUILTIN: Array[String] = ["ledge_attack", "ledge_attack_slow", "getup_attack"]

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## Alle moves uit de bestanden (archetype + character-overrides). Geen ingebouwde moves.
static func load_files(archetype_id: String, character_id: String) -> Dictionary:
	var key: String = "%s|%s" % [archetype_id, character_id]
	if _cache.has(key):
		return _cache[key]
	var out: Dictionary = {}
	if archetype_id != "":
		_load_dir(ARCHETYPE_DIR % archetype_id, out)
	if character_id != "":
		_load_dir(CHARACTER_DIR % character_id, out)
	_cache[key] = out
	return out


## Bestanden + ingebouwde aanvullingen (ledge/getup attack) voor een character van `height` units met `stats`.
static func load_for(archetype_id: String, character_id: String, stats: FighterStats) -> Dictionary:
	var out: Dictionary = load_files(archetype_id, character_id).duplicate()
	for n: String in BUILTIN:
		if not out.has(n):
			out[n] = builtin(n, stats)
	return out


static func _load_dir(dir: String, out: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for f: String in files:
		var name: String = f.trim_suffix(".remap")
		if name.get_extension() != "tres":
			continue
		var res: Resource = load(dir.path_join(name))
		if res is MoveData:
			out[name.get_basename()] = res


## Ingebouwde gemeenschappelijke moves. Alle waarden ⚠️ (Melee: ledge attack ~8% / ≥100% ~10%, getup attack ~6%).
## Frames zijn state-frames van de state die de move gebruikt (CliffAttack resp. DownGetup "attack").
static func builtin(move_name: String, stats: FighterStats) -> MoveData:
	var h: float = stats.visual_height if stats != null else 15.0
	var k: float = h / 15.0
	var m := MoveData.new()
	m.move_name = move_name
	match move_name:
		"ledge_attack", "ledge_attack_slow":
			var slow: bool = move_name == "ledge_attack_slow"
			var opt: Dictionary = stats.ledge_option("attack", slow) if stats != null \
				else FighterStats.LEDGE_OPTION_DEFAULTS["attack"]["high" if slow else "low"]
			var hit: int = int(opt.get("hit", 25))
			m.total_frames = int(opt.get("frames", 55))
			var dmg: float = 10.0 if slow else 8.0
			m.hitboxes = [
				make_hitbox(0, hit, hit + 3, Vector2(11.0 * k, 0.4 * h), 4.0, dmg, 361.0, 30.0, 70.0),
				make_hitbox(1, hit, hit + 3, Vector2(4.0 * k, 0.4 * h), 4.0, dmg, 361.0, 30.0, 70.0),
			]
		"getup_attack":
			m.total_frames = FighterConst.GETUP_ATTACK_FRAMES
			m.hitboxes = [
				make_hitbox(0, 17, 19, Vector2(9.0 * k, 0.25 * h), 4.5, 6.0, 361.0, 40.0, 50.0),
				make_hitbox(1, 24, 26, Vector2(-9.0 * k, 0.25 * h), 4.5, 6.0, 361.0, 40.0, 50.0),
			]
		_:
			push_error("MoveSet: onbekende ingebouwde move '%s'" % move_name)
	return m


static func make_hitbox(id_: int, start: int, end: int, offset: Vector2, radius: float, damage: float,
		angle: float, base_kb: float, kb_growth: float, group: int = 0) -> HitboxData:
	var hb := HitboxData.new()
	hb.id = id_
	hb.group = group
	hb.start_frame = start
	hb.end_frame = end
	hb.offset = offset
	hb.radius = radius
	hb.damage = damage
	hb.angle = angle
	hb.base_kb = base_kb
	hb.kb_growth = kb_growth
	return hb
