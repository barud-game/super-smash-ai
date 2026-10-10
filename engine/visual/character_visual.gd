class_name CharacterVisual
extends Node2D
## Het uiterlijk van één character: SVG-onderdelen uit characters/<id>/art/ op een Skeleton2D met Bone2D's.
##
## PUUR VISUEEL. Geen physics, geen input, geen eigen klok: de fighter roept per sim-frame
## play(state_pose) en tick(frame) aan. Positie van de node = voeten-midden op de grond (in px).
## Zie docs/rig.md.

signal reloaded

@export var character_id: String = "":
	set(v):
		character_id = v
		if is_inside_tree():
			reload()
## 0-based speler-index voor de teamkleur (0 = speler 1, 1 = speler 2, ...).
@export var player_index: int = 0:
	set(v):
		player_index = v
		if is_inside_tree():
			reload()
## +1 = kijkt rechts, -1 = kijkt links (spiegelt het hele skelet).
@export_enum("Rechts:1", "Links:-1") var facing: int = 1:
	set(v):
		facing = -1 if v < 0 else 1
		if _flip != null:
			_flip.scale.x = float(facing)
## Overschrijft de art-map (voor tests); leeg = res://characters/<id>/art
var art_dir_override: String = ""
## Overschrijft de props-map (voor tests); leeg = <art-map>/props.
var props_dir_override: String = ""

var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()
var is_valid: bool = false
var current_pose: String = ""
var pose_frame: float = 0.0

var skeleton: Skeleton2D
var bones: Dictionary = {}       # naam -> Bone2D
var sprites: Dictionary = {}     # "<part>" of "<part>_l"/"<part>_r" -> Sprite2D
var library: PoseLibrary

var _flip: Node2D
## Hergebruikte sample-buffers en per-bot arrays (zelfde volgorde als Rig.BONES) voor `_apply`.
var _scratch_r: Dictionary = {}
var _scratch_o: Dictionary = {}
var _scratch: Dictionary = {"r": _scratch_r, "o": _scratch_o}
var _bone_names: Array[String] = []
var _bone_nodes: Array[Bone2D] = []
var _bone_rest: PackedVector2Array = PackedVector2Array()
var _bone_rot: PackedFloat64Array = PackedFloat64Array()
var _bone_pos: PackedVector2Array = PackedVector2Array()
var _applied_pose: Pose = null
var _applied_frame: float = NAN
var _applied_blend: bool = false
var _pose: Pose
var _blend_from: Dictionary = {}   # snapshot {"r":..., "o":...} van de vorige pose
var _since_play: float = 0.0
var _warned_missing: Dictionary = {}
## Rekwisieten (PropEvent): texturen per prop-naam, sprites per event-index, laatste set.
var _prop_tex: Dictionary = {}     # naam -> {"tex": ImageTexture, "size": Vector2} (leeg = niet gevonden)
var _prop_sprites: Dictionary = {}   # slot-index -> Sprite2D
var _prop_sig: String = ""
var _props_now: Array = []
var _timed: bool = false           # play_timed actief: tick(frame) schaalt de pose naar de move-fases
var _t_startup: float = 0.0
var _t_active: float = 0.0
var _t_total: float = 1.0


func _ready() -> void:
	if character_id != "":
		reload()


func art_dir() -> String:
	if art_dir_override != "":
		return art_dir_override
	return CharacterLoader.dir(character_id).path_join("art")


## Bouwt het hele skelet + de sprites opnieuw op uit schijf. Veilig om vaak aan te roepen (hot reload).
## Houdt de huidige pose/frame vast. Geeft true terug als alle verplichte onderdelen geladen zijn.
func reload() -> bool:
	var keep_pose: String = current_pose
	var keep_frame: float = pose_frame
	_clear()
	errors = PackedStringArray()
	warnings = PackedStringArray()
	library = PoseLibrary.load_for(character_id)
	for e in library.errors:
		errors.append(e)
	_build_skeleton()
	_build_sprites()
	is_valid = errors.is_empty()
	for e in errors:
		push_error("[CharacterVisual:%s] %s" % [character_id, e])
	for w in warnings:
		push_warning("[CharacterVisual:%s] %s" % [character_id, w])
	_blend_from = {}
	_pose = null
	if keep_pose != "" and library.poses.has(keep_pose):
		play(keep_pose)
		pose_frame = keep_frame
		_blend_from = {}
		_since_play = 1000.0
		_apply_current()
	else:
		play("idle")
		_since_play = 1000.0
		_apply_current()
	if not _props_now.is_empty():
		var again: Array = _props_now
		_props_now = []
		set_props(again)
	reloaded.emit()
	return is_valid


func _clear() -> void:
	if _flip != null:
		_flip.queue_free()
	_flip = null
	skeleton = null
	bones.clear()
	sprites.clear()
	_prop_sprites.clear()
	_prop_tex.clear()
	_prop_sig = ""
	_bone_names.clear()
	_bone_nodes.clear()
	_bone_rest.clear()
	_bone_rot.clear()
	_bone_pos.clear()
	_applied_pose = null
	_applied_blend = false


func _build_skeleton() -> void:
	_flip = Node2D.new()
	_flip.name = "Flip"
	_flip.scale.x = float(facing)
	add_child(_flip)
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	_flip.add_child(skeleton)
	for def: Array in Rig.BONES:
		var b := Bone2D.new()
		b.name = def[0]
		b.position = def[2]
		b.rest = Transform2D(0.0, def[2])
		b.set_autocalculate_length_and_angle(false)
		b.set_length(16.0)
		var parent: Node = skeleton if def[1] == "" else bones[def[1]]
		parent.add_child(b)
		bones[def[0]] = b
		_bone_names.append(def[0])
		_bone_nodes.append(b)
		_bone_rest.append(def[2])
		_bone_rot.append(NAN)
		_bone_pos.append(Vector2(NAN, NAN))


func _build_sprites() -> void:
	var dir: String = art_dir()
	if not DirAccess.dir_exists_absolute(dir):
		errors.append("Art-map bestaat niet: %s" % dir)
		return
	var palette: Dictionary = Rig.PLAYER_PALETTES[clampi(player_index, 0, Rig.PLAYER_PALETTES.size() - 1)]
	for part: String in Rig.PARTS:
		var def: Dictionary = Rig.PARTS[part]
		if def["sides"]:
			for side in ["l", "r"]:
				var path: String = ""
				var own: String = dir.path_join("%s_%s.svg" % [part, side])
				var shared: String = dir.path_join("%s.svg" % part)
				if side == "l" and FileAccess.file_exists(own):
					path = own
				elif side == "r" and FileAccess.file_exists(own):
					path = own
				elif FileAccess.file_exists(shared):
					path = shared
				if path == "":
					errors.append("Verplicht onderdeel ontbreekt: %s (verwacht %s)" % [part, shared])
					continue
				_make_sprite("%s_%s" % [part, side], part, path, def, side, palette)
		else:
			var p: String = dir.path_join("%s.svg" % part)
			if not FileAccess.file_exists(p):
				if def["required"]:
					errors.append("Verplicht onderdeel ontbreekt: %s (verwacht %s)" % [part, p])
				continue
			_make_sprite(part, part, p, def, "", palette)


func _make_sprite(key: String, part: String, path: String, def: Dictionary, side: String, palette: Dictionary) -> void:
	var svg: String = FileAccess.get_file_as_string(path)
	if svg.is_empty():
		errors.append("Kan SVG niet lezen of leeg: %s" % path)
		return
	svg = recolor(svg, palette)
	var img := Image.new()
	var err: Error = img.load_svg_from_string(svg, Rig.SCALE_SUPERSAMPLE)
	if err != OK or img.is_empty():
		errors.append("SVG ongeldig (%s): %s" % [error_string(err), path])
		return
	var expected: Vector2i = def["size"]
	var got := Vector2i(roundi(img.get_width() / Rig.SCALE_SUPERSAMPLE), roundi(img.get_height() / Rig.SCALE_SUPERSAMPLE))
	if got != expected:
		warnings.append("%s heeft canvas %dx%d, rig verwacht %dx%d (pivot zit dan mogelijk verkeerd): %s" % [part, got.x, got.y, expected.x, expected.y, path])
	var bone_name: String = def["bone"] + side if side != "" else def["bone"]
	if not bones.has(bone_name):
		errors.append("Intern: bot %s bestaat niet voor onderdeel %s" % [bone_name, part])
		return
	var s := Sprite2D.new()
	s.name = key
	s.texture = ImageTexture.create_from_image(img)
	s.centered = false
	s.scale = Vector2.ONE / Rig.SCALE_SUPERSAMPLE
	s.offset = -Vector2(def["pivot"]) * Rig.SCALE_SUPERSAMPLE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var z: int = def["z"]
	if side == "r" and Rig.NEAR_Z_BONUS.has(part):
		z += Rig.NEAR_Z_BONUS[part]
	s.z_index = z
	if side == "l":
		s.modulate = Rig.FAR_TINT
	bones[bone_name].add_child(s)
	sprites[key] = s


## Vervangt de gereserveerde teamkleuren in een SVG-tekst door de kleuren van een speler.
static func recolor(svg: String, palette: Dictionary) -> String:
	var out: String = svg
	for pair in [[Rig.TEAM_MAIN, palette["main"]], [Rig.TEAM_DARK, palette["dark"]], [Rig.TEAM_LIGHT, palette["light"]]]:
		out = out.replacen(pair[0], pair[1])
	return out


func has_pose(pose_name: String) -> bool:
	return library != null and library.poses.has(pose_name)


## Start een pose (typisch: de state-naam van de fighter). Onbekende pose -> idle + één waarschuwing.
## restart=false: doet niets als dezelfde pose al speelt.
func play(pose_name: String, restart: bool = true) -> void:
	if library == null:
		return
	if not restart and pose_name == current_pose and _pose != null:
		return
	if not library.poses.has(pose_name):
		if not _warned_missing.has(pose_name):
			_warned_missing[pose_name] = true
			push_warning("[CharacterVisual:%s] pose '%s' bestaat niet, val terug op idle" % [character_id, pose_name])
		pose_name = "idle"
		if not library.poses.has(pose_name):
			return
	if _pose != null:
		_blend_from = _snapshot()
	_pose = library.poses[pose_name]
	_timed = false
	current_pose = pose_name
	pose_frame = 0.0
	_since_play = 0.0
	_apply_current()


## Start een aanvalspose geschaald naar de frame-data van een move (zie docs/rig.md sectie 6b).
##   startup: frames vóór het eerste actieve frame (= eerste actieve frame - 1 bij 1-based move-data)
##   active : aantal actieve frames;  total: totale duur van de move in frames
## Daarna tick(frame) elke sim-frame met de frames sinds het begin van de move (0-based).
func play_timed(pose_name: String, startup: int, active: int, total: int, restart: bool = true) -> void:
	play(pose_name, restart)
	_timed = true
	_t_startup = float(startup)
	_t_active = float(active)
	_t_total = float(maxi(total, 1))
	_apply_current()


## Zet de pose op een frame en past hem toe. De fighter roept dit elke sim-frame aan.
##   frame >= 0: expliciete frame in de pose (state-frame; deterministisch, werkt ook bij frame advance/rollback)
##   frame < 0 : loop één frame verder (+speed)
##   speed: tempo-factor, bv. voor walk/run-cyclus synchroon aan de snelheid.
func tick(frame: int = -1, speed: float = 1.0) -> void:
	if _pose == null:
		return
	if frame >= 0:
		pose_frame = float(frame) * speed
		if _timed:
			pose_frame = _pose.remap(float(frame), _t_startup, _t_active, _t_total)
		_since_play = float(frame)
	else:
		pose_frame += speed
		_since_play += 1.0
	_refresh_current()


func set_facing(dir: int) -> void:
	facing = dir


## Zet een speler-kleurenset en herlaadt.
func set_player(index: int) -> void:
	player_index = index


func pose_length(pose_name: String = "") -> float:
	var p: Pose = _pose if pose_name == "" else library.poses.get(pose_name)
	return p.length if p != null else 0.0


func _sample_current() -> Dictionary:
	_pose.sample_into(pose_frame, _scratch_r, _scratch_o)   # hergebruikte dictionaries: geen allocaties per frame
	var s: Dictionary = _scratch
	var blend: float = _pose.blend
	if _blend_from.is_empty() or blend <= 0.0 or _since_play >= blend:
		return s
	var a: float = _since_play / blend
	a = a * a * (3.0 - 2.0 * a)
	var out_r: Dictionary = {}
	var out_o: Dictionary = {}
	var from_r: Dictionary = _blend_from["r"]
	var from_o: Dictionary = _blend_from["o"]
	for b in bones:
		var to_r: float = s["r"].get(b, 0.0)
		var to_o: Vector2 = s["o"].get(b, Vector2.ZERO)
		var fr: float = from_r.get(b, 0.0)
		var fo: Vector2 = from_o.get(b, Vector2.ZERO)
		out_r[b] = lerpf(fr, to_r, a)
		out_o[b] = fo.lerp(to_o, a)
	return {"r": out_r, "o": out_o}


## Huidige rotaties/offsets (voor crossfade). Rotaties naar -180..180 genormaliseerd.
func _snapshot() -> Dictionary:
	var r: Dictionary = {}
	var o: Dictionary = {}
	for b in bones:
		var bone: Bone2D = bones[b]
		r[b] = wrapf(rad_to_deg(bone.rotation), -180.0, 180.0)
		o[b] = bone.position - bone.rest.origin
	return {"r": r, "o": o}


## Past de huidige pose toe zonder opnieuw te sampelen als niets veranderde (zelfde pose, zelfde frame, geen
## crossfade): vooral bij bevroren frames (hitlag) en lange houdposes.
func _refresh_current() -> void:
	if _pose == null:
		return
	if not _is_blending() and not _applied_blend and _applied_pose == _pose and _applied_frame == pose_frame:
		return
	_apply_current()


func _apply_current() -> void:
	_applied_blend = _is_blending()
	_apply(_sample_current())
	_applied_pose = _pose
	_applied_frame = pose_frame


func _is_blending() -> bool:
	return not (_blend_from.is_empty() or _pose.blend <= 0.0 or _since_play >= _pose.blend)


func _apply(s: Dictionary) -> void:
	var r: Dictionary = s["r"]
	var o: Dictionary = s["o"]
	for i in _bone_nodes.size():
		var n: String = _bone_names[i]
		var rot: float = deg_to_rad(r.get(n, 0.0))
		var pos: Vector2 = _bone_rest[i] + (o.get(n, Vector2.ZERO) as Vector2)
		# Alleen schrijven bij een verandering: elke set op een Bone2D laat de skeleton-transforms opnieuw doorrekenen.
		if rot != _bone_rot[i]:
			_bone_rot[i] = rot
			_bone_nodes[i].rotation = rot
		if pos != _bone_pos[i]:
			_bone_pos[i] = pos
			_bone_nodes[i].position = pos


## Zet de crossfade uit voor de huidige pose (handig voor previews: frame 0 toont dan echt de pose zelf).
func clear_blend() -> void:
	_blend_from = {}
	if _pose != null:
		_apply_current()


# =============================================================================================
# Rekwisieten (props): characters/<id>/art/props/<naam>.svg, zie docs/rig.md §9 en PropEvent.
# =============================================================================================

## Standaard prop-canvasmaat/pivot staan in docs/rig.md §9. Een prop zit in de bot-hiërarchie (meeschalen met
## visual_height en spiegelen met facing gaat vanzelf via de visual).
const PROP_Z: Dictionary = {"hand_r": 31, "hand_l": 6, "root": 32, "under_feet": 0}
const PROP_HAND_PIVOT_Y: float = 24.0
## Handprops hangen aan de palm (6 px onder de pols-bot, net als weapon_r); `offset` komt daar bovenop.
const PROP_HAND_PALM := Vector2(0.0, 6.0)


func props_dir() -> String:
	return props_dir_override if props_dir_override != "" else art_dir().path_join("props")


## Toont precies de gegeven prop-events (genormaliseerd door PropEvent.normalize) en verbergt de rest.
## Goedkoop als er niets verandert; elke fighter-tick aanroepen mag.
func set_props(events: Array) -> void:
	if events.is_empty() and _prop_sig == "[]":
		return   # snelle weg: geen props toen, geen props nu (str() per frame vermijden)
	var sig: String = str(events)
	if sig == _prop_sig:
		return
	_prop_sig = sig
	_props_now = events
	var used: Dictionary = {}
	for i in events.size():
		var ev: Dictionary = events[i]
		var spr: Sprite2D = _prop_sprite_for(i, ev)
		if spr != null:
			used[i] = true
			spr.visible = true
	for i: Variant in _prop_sprites:
		if not used.has(i):
			(_prop_sprites[i] as Sprite2D).visible = false


## Namen van de nu zichtbare props (tests/debug).
func visible_props() -> PackedStringArray:
	var out := PackedStringArray()
	for i: Variant in _prop_sprites:
		var s: Sprite2D = _prop_sprites[i]
		if is_instance_valid(s) and s.visible:
			out.append(s.name.get_slice("#", 0))
	out.sort()
	return out


## De sprite van een zichtbare prop (tests/debug); null als hij niet zichtbaar is.
func prop_sprite(prop_name: String) -> Sprite2D:
	for i: Variant in _prop_sprites:
		var s: Sprite2D = _prop_sprites[i]
		if is_instance_valid(s) and s.visible and s.name.get_slice("#", 0) == prop_name:
			return s
	return null


func _prop_sprite_for(slot: int, ev: Dictionary) -> Sprite2D:
	var data: Dictionary = _prop_data(String(ev["prop"]))
	if data.is_empty():
		return null
	var attach: String = String(ev["attach"])
	var bone_name: String = attach if attach.begins_with("hand_") else "root"
	if not bones.has(bone_name):
		return null
	var s: Sprite2D = _prop_sprites.get(slot)
	if s == null or not is_instance_valid(s):
		s = Sprite2D.new()
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_prop_sprites[slot] = s
	var bone: Node = bones[bone_name]
	if s.get_parent() != bone:
		if s.get_parent() != null:
			s.get_parent().remove_child(s)
		bone.add_child(s)
	if attach == "under_feet":
		bone.move_child(s, 0)
	s.name = "%s#%d" % [ev["prop"], slot]
	s.texture = data["tex"]
	var size: Vector2 = data["size"]
	var pivot: Vector2
	if ev.has("pivot"):
		pivot = ev["pivot"]
	elif data.has("pivot"):
		pivot = data["pivot"]
	elif attach.begins_with("hand_"):
		pivot = Vector2(size.x * 0.5, PROP_HAND_PIVOT_Y)
	else:
		pivot = Vector2(size.x * 0.5, size.y)   # root / under_feet: voeten-midden onderaan het canvas
	s.offset = -pivot * Rig.SCALE_SUPERSAMPLE
	s.scale = Vector2.ONE * (float(ev["scale"]) / Rig.SCALE_SUPERSAMPLE)
	s.rotation = deg_to_rad(float(ev["rotation"]))
	s.position = Vector2(ev["offset"]) + (PROP_HAND_PALM if attach.begins_with("hand_") else Vector2.ZERO)
	s.z_index = int(PROP_Z.get(attach, 31))
	return s


## Laadt (en cachet) de texture van een prop; leeg als het bestand ontbreekt/ongeldig is (één waarschuwing).
func _prop_data(prop_name: String) -> Dictionary:
	if _prop_tex.has(prop_name):
		return _prop_tex[prop_name]
	var path: String = props_dir().path_join(prop_name + ".svg")
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		push_warning("[CharacterVisual:%s] prop '%s' ontbreekt (verwacht %s)" % [character_id, prop_name, path])
	else:
		var palette: Dictionary = Rig.PLAYER_PALETTES[clampi(player_index, 0, Rig.PLAYER_PALETTES.size() - 1)]
		var img := Image.new()
		var err: Error = img.load_svg_from_string(recolor(FileAccess.get_file_as_string(path), palette), Rig.SCALE_SUPERSAMPLE)
		if err != OK or img.is_empty():
			push_warning("[CharacterVisual:%s] prop '%s' is geen geldige SVG (%s)" % [character_id, prop_name, error_string(err)])
		else:
			out = {"tex": ImageTexture.create_from_image(img),
				"size": Vector2(img.get_width(), img.get_height()) / Rig.SCALE_SUPERSAMPLE}
			var piv: Variant = _prop_pivot(prop_name, FileAccess.get_file_as_string(path))
			if piv is Vector2:
				out["pivot"] = piv
	_prop_tex[prop_name] = out
	return out


## Greeppunt (canvas-px) van een prop, in volgorde: `art/props/props.json` {"<naam>": {"pivot": [x, y]}},
## dan `data-pivot="x,y"` op het <svg>-element. null = standaard per attach (docs/rig.md §9).
func _prop_pivot(prop_name: String, svg_text: String) -> Variant:
	var meta_path: String = props_dir().path_join("props.json")
	if FileAccess.file_exists(meta_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if parsed is Dictionary and (parsed as Dictionary).get(prop_name) is Dictionary:
			var pv: Variant = ((parsed as Dictionary)[prop_name] as Dictionary).get("pivot")
			if pv is Array and (pv as Array).size() >= 2:
				return Vector2(float(pv[0]), float(pv[1]))
	var re := RegEx.new()
	re.compile('data-pivot\\s*=\\s*"\\s*(-?[0-9.]+)[ ,]+\\s*(-?[0-9.]+)\\s*"')
	var m: RegExMatch = re.search(svg_text.substr(0, 600))
	if m != null:
		return Vector2(float(m.get_string(1)), float(m.get_string(2)))
	return null
