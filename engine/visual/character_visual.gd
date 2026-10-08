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
var _pose: Pose
var _blend_from: Dictionary = {}   # snapshot {"r":..., "o":...} van de vorige pose
var _since_play: float = 0.0
var _warned_missing: Dictionary = {}


func _ready() -> void:
	if character_id != "":
		reload()


func art_dir() -> String:
	if art_dir_override != "":
		return art_dir_override
	return "res://characters/%s/art" % character_id


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
		_apply(_sample_current())
	else:
		play("idle")
		_since_play = 1000.0
		_apply(_sample_current())
	reloaded.emit()
	return is_valid


func _clear() -> void:
	if _flip != null:
		_flip.queue_free()
	_flip = null
	skeleton = null
	bones.clear()
	sprites.clear()


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
	current_pose = pose_name
	pose_frame = 0.0
	_since_play = 0.0
	_apply(_sample_current())


## Zet de pose op een frame en past hem toe. De fighter roept dit elke sim-frame aan.
##   frame >= 0: expliciete frame in de pose (state-frame; deterministisch, werkt ook bij frame advance/rollback)
##   frame < 0 : loop één frame verder (+speed)
##   speed: tempo-factor, bv. voor walk/run-cyclus synchroon aan de snelheid.
func tick(frame: int = -1, speed: float = 1.0) -> void:
	if _pose == null:
		return
	if frame >= 0:
		pose_frame = float(frame) * speed
		_since_play = float(frame)
	else:
		pose_frame += speed
		_since_play += 1.0
	_apply(_sample_current())


func set_facing(dir: int) -> void:
	facing = dir


## Zet een speler-kleurenset en herlaadt.
func set_player(index: int) -> void:
	player_index = index


func pose_length(pose_name: String = "") -> float:
	var p: Pose = _pose if pose_name == "" else library.poses.get(pose_name)
	return p.length if p != null else 0.0


func _sample_current() -> Dictionary:
	var s: Dictionary = _pose.sample(pose_frame)
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


func _apply(s: Dictionary) -> void:
	for b in bones:
		var bone: Bone2D = bones[b]
		bone.rotation = deg_to_rad(s["r"].get(b, 0.0))
		bone.position = bone.rest.origin + s["o"].get(b, Vector2.ZERO)


## Zet de crossfade uit voor de huidige pose (handig voor previews: frame 0 toont dan echt de pose zelf).
func clear_blend() -> void:
	_blend_from = {}
	if _pose != null:
		_apply(_sample_current())
