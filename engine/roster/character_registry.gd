extends Node
## Autoload `CharacterRegistry`: ontdekt alle characters in res://characters/.
## Mappen die met `_` beginnen zijn geen spelbare characters (`_dummy` doet alleen mee in debug-builds,
## zie `include_dummy`). Per map leest hij character.json (formaat: docs/ui.md).
## `rescan()` leest alles opnieuw van schijf (hot reload).

signal rescanned

const ROOT_DIR: String = "res://characters"
const DUMMY_ID: String = "_dummy"
const ARCHETYPES: Array[String] = ["Zwaargewicht", "Allrounder", "Fast-faller", "Floaty", "Lichtgewicht"]

## Doet `_dummy` mee? Standaard alleen in debug-builds.
var include_dummy: bool = OS.is_debug_build()
var characters: Array[CharacterInfo] = []

var _by_id: Dictionary = {}


func _ready() -> void:
	rescan()


## Scant opnieuw. `root` is alleen te overschrijven voor tests.
func rescan(root: String = ROOT_DIR) -> void:
	characters.clear()
	_by_id.clear()
	var da: DirAccess = DirAccess.open(root)
	if da != null:
		var names: PackedStringArray = da.get_directories()
		names.sort()
		for n in names:
			if n.begins_with("_") and not (include_dummy and n == DUMMY_ID):
				continue
			if n.begins_with("."):
				continue
			var info: CharacterInfo = load_dir(root.path_join(n), n)
			if info != null:
				characters.append(info)
				_by_id[info.id] = info
	# Vaste volgorde: alfabetisch op naam (hoofdletterongevoelig), dummy achteraan.
	characters.sort_custom(func(a: CharacterInfo, b: CharacterInfo) -> bool:
		if (a.id == DUMMY_ID) != (b.id == DUMMY_ID):
			return b.id == DUMMY_ID
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	rescanned.emit()


## Leest één character-map. Geeft null als de map geen character is (geen manifest en geen art).
func load_dir(dir: String, folder: String) -> CharacterInfo:
	var manifest_path: String = dir.path_join("character.json")
	var has_art: bool = DirAccess.dir_exists_absolute(dir.path_join("art"))
	var info: CharacterInfo
	if FileAccess.file_exists(manifest_path):
		var text: String = FileAccess.get_file_as_string(manifest_path)
		info = parse_manifest(text, folder)
		info.has_manifest = not info.warnings.has("manifest ongeldig")
	elif has_art:
		info = parse_manifest("{}", folder)
		info.warnings.append("character.json ontbreekt (afgeleid uit mapnaam)")
	else:
		return null
	info.dir = dir
	info.has_art = has_art
	if not has_art:
		info.warnings.append("art/ ontbreekt")
	for w in info.warnings:
		push_warning("[CharacterRegistry:%s] %s" % [folder, w])
	return info


## Parsed manifest-tekst. Fouten worden waarschuwingen; er komt altijd een bruikbare CharacterInfo uit.
func parse_manifest(text: String, folder: String) -> CharacterInfo:
	var info := CharacterInfo.new()
	info.id = folder
	info.display_name = folder.capitalize()
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null
	if not (parsed is Dictionary):
		info.warnings.append("manifest ongeldig")
		return info
	var d: Dictionary = parsed
	var mid: String = String(d.get("id", folder))
	if mid != folder:
		info.warnings.append("id '%s' wijkt af van mapnaam '%s'; mapnaam wordt gebruikt" % [mid, folder])
	info.display_name = String(d.get("name", info.display_name))
	info.archetype = String(d.get("archetype", ""))
	if info.archetype != "" and not ARCHETYPES.has(info.archetype):
		info.warnings.append("onbekend archetype '%s'" % info.archetype)
	info.op = bool(d.get("op", false))
	info.tagline = String(d.get("tagline", ""))
	var colors: Variant = d.get("colors", {})
	if colors is Dictionary:
		info.color_primary = _color(colors.get("primary", null), info.color_primary, info)
		info.color_secondary = _color(colors.get("secondary", null), info.color_secondary, info)
	return info


func _color(v: Variant, fallback: Color, info: CharacterInfo) -> Color:
	if v == null:
		return fallback
	var s: String = String(v)
	if not Color.html_is_valid(s):
		info.warnings.append("ongeldige kleur '%s'" % s)
		return fallback
	return Color.html(s)


func get_info(id: String) -> CharacterInfo:
	return _by_id.get(id) as CharacterInfo


func has_character(id: String) -> bool:
	return _by_id.has(id)


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for c in characters:
		out.append(c.id)
	return out


## Archetypes die echt voorkomen (in vaste volgorde, daarna onbekende).
func archetypes_in_use() -> Array[String]:
	var out: Array[String] = []
	for a in ARCHETYPES:
		for c in characters:
			if c.archetype == a:
				out.append(a)
				break
	for c in characters:
		if c.archetype != "" and not out.has(c.archetype):
			out.append(c.archetype)
	return out


## Willekeurig character-id (UI-gebruik, geen gameplay-RNG). `exclude` wordt overgeslagen als er alternatieven zijn.
func random_id(rng: RandomNumberGenerator, exclude: String = "") -> String:
	var pool: Array[String] = []
	for c in characters:
		if c.id != exclude:
			pool.append(c.id)
	if pool.is_empty():
		return exclude
	return pool[rng.randi_range(0, pool.size() - 1)]
