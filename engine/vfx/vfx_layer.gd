class_name VfxLayer
extends Node2D
## Laag waarin alle VFX leven. Zet hem in de wereld (op de oorsprong, zonder transform), zodat
## effectposities direct wereld-pixels zijn. Gameplay-code roept alleen de `spawn_*`-API aan.
##
## Timing: de layer registreert zich bij `Sim` en tickt effecten elke sim-frame (`sim_tick`), dus pauze
## en frame advance bevriezen alles. Zet `auto_register = false` om zelf `vfx_tick(frame)` aan te roepen
## (tests, preview-tool). Alle posities zijn Melee-units (y omhoog).

const BASE_SEED: int = 0x5EED
const DEFAULT_PLAYER_COLORS: Array[Color] = [Color(1.0, 0.35, 0.3), Color(0.35, 0.55, 1.0), Color(1.0, 0.85, 0.3), Color(0.4, 0.9, 0.45)]

@export var auto_register: bool = true
## Optioneel: camera voor screenshake bij harde hits en KO's.
var camera: MatchCamera = null
## Optioneel: KO-effecten worden op deze rect (Melee-units, bv. camera bounds) geklemd, zodat ze in beeld
## blijven ook al ligt de blast zone ver erbuiten. Leeg (size 0) = niet klemmen.
var ko_clamp_rect_units: Rect2 = Rect2()
## Zet uit om alleen detail-effecten (stof) te dempen.
var dust_enabled: bool = true

var _effects: Array[VfxEffect] = []
var _spawn_count: int = 0
var _sim: Node = null
var _frame: int = 0
var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _flash_color: Color = Color.WHITE
var _flash_total: int = 0
var _flash_left: int = 0
var _flash_alpha: float = 0.0


func _ready() -> void:
	if auto_register:
		_sim = get_node_or_null("/root/Sim")
		if _sim != null:
			_sim.register(self)


func _exit_tree() -> void:
	if _sim != null and is_instance_valid(_sim):
		_sim.unregister(self)


# ---------- tick ----------

## Door `Sim` aangeroepen.
func sim_tick(frame: int) -> void:
	vfx_tick(frame)


func vfx_tick(frame: int) -> void:
	_frame = frame
	var i: int = 0
	while i < _effects.size():
		var e: VfxEffect = _effects[i]
		if not is_instance_valid(e):
			_effects.remove_at(i)
			continue
		e.vfx_tick(frame)
		if e.finished:
			_effects.remove_at(i)
			e.queue_free()
		else:
			i += 1
	_tick_flash()


func active_count() -> int:
	return _effects.size()


## Ruim alles op (nieuwe match, tests).
func clear() -> void:
	for e: VfxEffect in _effects:
		if is_instance_valid(e):
			e.queue_free()
	_effects.clear()
	_flash_left = 0
	_apply_flash()


func _add(e: VfxEffect) -> VfxEffect:
	_spawn_count += 1
	e.seed_rng(BASE_SEED + _spawn_count * 7919)
	return e


func _launch(e: VfxEffect) -> void:
	add_child(e)
	_effects.append(e)


# ---------- spawn-API ----------

## `strength` 0..1 (bv. uit damage/knockback), `element` = VfxConst.EL_* (gelijk aan HitboxData.Element),
## `angle_deg` = knockback-richting (units-conventie), `kill` = dit is de slotslag (screen-flash).
func spawn_hit(pos_units: Vector2, strength: float, element: int = 0, angle_deg: float = 0.0, kill: bool = false, hitbox_radius_units: float = -1.0) -> HitEffect:
	var e := HitEffect.new()
	_add(e)
	e.setup(Units.to_px(pos_units), strength, element, angle_deg, kill, hitbox_radius_units)
	_launch(e)
	if kill:
		flash_screen(Color(1, 1, 1), 8, 0.45)
	if camera != null:
		var s: float = clampf(strength, 0.0, 1.0)
		if kill:
			camera.shake(0.9 + s * 0.6, 12)
		elif s > 0.45:
			camera.shake(0.15 + (s - 0.45) * 0.8, 5 + int(s * 5.0))
	return e


func spawn_shield_hit(pos_units: Vector2, strength: float, color: Color = Color(0.5, 0.8, 1.0), angle_deg: float = 0.0) -> ShieldHitEffect:
	var e := ShieldHitEffect.new()
	_add(e)
	e.setup(Units.to_px(pos_units), strength, color, angle_deg)
	_launch(e)
	return e


func spawn_clank(pos_units: Vector2) -> ClankEffect:
	var e := ClankEffect.new()
	_add(e)
	e.setup(Units.to_px(pos_units))
	_launch(e)
	return e


func spawn_land_dust(pos_units: Vector2, heavy: bool = false) -> DustEffect:
	return _dust(pos_units, DustEffect.Kind.LAND, heavy, 1)


func spawn_jump_dust(pos_units: Vector2) -> DustEffect:
	return _dust(pos_units, DustEffect.Kind.JUMP, false, 1)


func spawn_dash_dust(pos_units: Vector2, facing: int) -> DustEffect:
	return _dust(pos_units, DustEffect.Kind.DASH, false, facing)


func _dust(pos_units: Vector2, kind: int, heavy: bool, facing: int) -> DustEffect:
	if not dust_enabled:
		return null
	var e := DustEffect.new()
	_add(e)
	e.setup(Units.to_px(pos_units), kind, heavy, facing)
	_launch(e)
	return e


## `angle_deg`: dodge-richting; NAN voor een ring zonder streep.
func spawn_airdodge_trail(pos_units: Vector2, angle_deg: float = NAN, color: Color = Color(0.8, 0.9, 1.0)) -> AirdodgeEffect:
	var e := AirdodgeEffect.new()
	_add(e)
	e.setup(Units.to_px(pos_units), angle_deg, color)
	_launch(e)
	return e


## Rookspoor achter een gelanceerde fighter; volgt `target` (Node2D) `frames` sim-frames lang.
func spawn_launch_trail(target: Node2D, frames: int, color: Color = Color(0.92, 0.9, 0.95)) -> LaunchTrailEffect:
	var e := LaunchTrailEffect.new()
	_add(e)
	e.setup(target, frames, color)
	_launch(e)
	return e


func spawn_respawn(pos_units: Vector2, player_color: Color = Color(0.6, 0.85, 1.0)) -> RespawnEffect:
	var e := RespawnEffect.new()
	_add(e)
	e.setup(Units.to_px(pos_units), player_color)
	_launch(e)
	return e


## KO-effect van `character_id` (valt terug op `DefaultKoEffect`). `pos_units` = waar de fighter de blast zone
## uitvloog, `side` = VfxConst.SIDE_*. `colors` leeg = lezen uit characters/<id>/character.json.
func spawn_ko(character_id: String, pos_units: Vector2, side: int, player_color: Color, colors: PackedColorArray = PackedColorArray()) -> KoEffect:
	if ko_clamp_rect_units.size != Vector2.ZERO:
		var r: Rect2 = ko_clamp_rect_units
		pos_units = Vector2(clampf(pos_units.x, r.position.x, r.position.x + r.size.x),
			clampf(pos_units.y, r.position.y, r.position.y + r.size.y))
	if colors.is_empty():
		colors = character_colors(character_id)
	var e: KoEffect = load_ko_effect(character_id)
	_add(e)
	e.setup_ko(Units.to_px(pos_units), side, player_color, colors, character_id)
	_launch(e)
	flash_screen(player_color.lerp(Color.WHITE, 0.6), 10, 0.3)
	if camera != null:
		camera.shake(1.5, 18)
	return e


func spawn_ko_fallback(pos_units: Vector2, side: int, player_color: Color) -> KoEffect:
	return spawn_ko("", pos_units, side, player_color)


# ---------- KO-effect laden ----------

static func ko_effect_path(character_id: String) -> String:
	return "res://characters/%s/ko_effect/ko_effect" % character_id


## Geeft een nieuwe KoEffect-instantie: eigen effect (.tscn of .gd) als dat bestaat en klopt, anders de fallback.
static func load_ko_effect(character_id: String) -> KoEffect:
	if character_id != "":
		var base: String = ko_effect_path(character_id)
		for ext: String in [".tscn", ".gd"]:
			if ResourceLoader.exists(base + ext):
				var res: Resource = load(base + ext)
				var inst: Object = null
				if res is PackedScene:
					inst = (res as PackedScene).instantiate()
				elif res is Script and (res as Script).can_instantiate():
					inst = (res as Script).new()
				if inst is KoEffect:
					return inst as KoEffect
				if inst is Node:
					(inst as Node).free()
				push_warning("VfxLayer: %s%s is geen KoEffect, fallback gebruikt" % [base, ext])
	return DefaultKoEffect.new()


## Kleuren uit characters/<id>/character.json (`colors`: primary, secondary, ...). Nooit leeg.
static func character_colors(character_id: String) -> PackedColorArray:
	var out := PackedColorArray()
	var path: String = "res://characters/%s/character.json" % character_id
	if character_id != "" and FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and (data as Dictionary).get("colors") is Dictionary:
			var cols: Dictionary = (data as Dictionary)["colors"]
			for k: String in ["primary", "secondary", "accent"]:
				if cols.has(k):
					out.append(Color.html(String(cols[k])))
	if out.is_empty():
		out = PackedColorArray([Color(0.9, 0.9, 0.95), Color(0.5, 0.5, 0.6)])
	return out


# ---------- screen flash ----------

## Korte schermvlak-flits; alpha daalt lineair naar 0 over `frames`.
func flash_screen(color: Color, frames: int, max_alpha: float = 0.4) -> void:
	if max_alpha < current_flash_alpha():
		return
	_flash_color = color
	_flash_total = maxi(frames, 1)
	_flash_left = _flash_total
	_flash_alpha = max_alpha
	_apply_flash()


func current_flash_alpha() -> float:
	if _flash_left <= 0:
		return 0.0
	return _flash_alpha * float(_flash_left) / float(_flash_total)


func _tick_flash() -> void:
	if _flash_left > 0:
		_flash_left -= 1
		_apply_flash()


func _apply_flash() -> void:
	if _flash_left <= 0 and _flash_rect == null:
		return
	if _flash_rect == null:
		_flash_layer = CanvasLayer.new()
		_flash_layer.layer = 90
		_flash_rect = ColorRect.new()
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_layer.add_child(_flash_rect)
		add_child(_flash_layer)
	_flash_rect.color = Color(_flash_color.r, _flash_color.g, _flash_color.b, current_flash_alpha())
	_flash_rect.visible = _flash_left > 0
