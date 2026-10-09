class_name MatchCamera
extends Camera2D
## Melee-achtige camera: volgt targets, zoomt zodat ze allemaal in beeld zijn (met marge),
## smooth, en blijft binnen de camera bounds. Presentatie, geen gameplay.
##
## Bounds komen als Rect2 in Melee-units (position = links/onder, size = breedte/hoogte).

@export var margin_units: float = 28.0
@export var min_zoom: float = 0.4
@export var max_zoom: float = 1.4
## Smoothing per physics-frame (0..1, groter = sneller).
@export var pos_smooth: float = 0.08
@export var zoom_smooth: float = 0.05

var targets: Array[Node2D] = []
var bounds_units: Rect2 = Rect2()
var _has_bounds: bool = false
var _snap: bool = true

# --- screenshake (puur visueel, via Camera2D.offset; deterministisch, los van gameplay) ---
const SHAKE_SEED: int = 0xCA3E
var _shake_rng := RandomNumberGenerator.new()
var _shake_amp_units: float = 0.0
var _shake_total: int = 0
var _shake_left: int = 0
var _shake_connected: bool = false


func _ready() -> void:
	_shake_rng.seed = SHAKE_SEED
	# Shake tikt op sim-frames (pauze/frame advance bevriezen hem). Zonder Sim (tests) tikt de aanroeper.
	var sim: Node = get_node_or_null("/root/Sim")
	if sim != null and not _shake_connected:
		sim.frame_advanced.connect(_on_sim_frame)
		_shake_connected = true


func _on_sim_frame(_frame: int) -> void:
	shake_tick()


## Schud het beeld: `intensity_units` = startamplitude in Melee-units (0.5 klein, 2 hard, 4 KO),
## lineair uitdovend over `frames` sim-frames. Een nieuwe shake vervangt de lopende als hij sterker is.
func shake(intensity_units: float, frames: int) -> void:
	if frames <= 0 or intensity_units <= 0.0:
		return
	if intensity_units < shake_amplitude_units():
		return
	_shake_amp_units = intensity_units
	_shake_total = frames
	_shake_left = frames


## Hitlag-shake: schaalt met de hitlag-duur (frames) en een 0..1 sterkte; roept `shake` aan.
func hitlag_shake(hitlag_frames: int, strength: float = 0.5) -> void:
	shake(0.2 + clampf(strength, 0.0, 1.0) * 1.0, hitlag_frames)


## Huidige amplitude in units (0 als er niet geschud wordt).
func shake_amplitude_units() -> float:
	if _shake_left <= 0:
		return 0.0
	return _shake_amp_units * float(_shake_left) / float(_shake_total)


## Eén sim-frame shake vooruit; zet `offset`. Eigen seeded RNG, dus herhaalbaar.
func shake_tick() -> void:
	if _shake_left <= 0:
		offset = Vector2.ZERO
		return
	var amp_px: float = shake_amplitude_units() * Units.UNIT_TO_PX / maxf(zoom.x, 0.01)
	offset = Vector2(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0)) * amp_px
	_shake_left -= 1


## Zet de shake en zijn RNG terug (nieuwe match / determinisme-test).
func reset_shake() -> void:
	_shake_rng.seed = SHAKE_SEED
	_shake_left = 0
	_shake_total = 0
	_shake_amp_units = 0.0
	offset = Vector2.ZERO


func set_bounds_units(r: Rect2) -> void:
	bounds_units = r
	_has_bounds = true


func set_targets(list: Array[Node2D]) -> void:
	targets = list


func snap_next() -> void:
	_snap = true


func _physics_process(_delta: float) -> void:
	var goal: Dictionary = compute_goal()
	if goal.is_empty():
		return
	var gz: float = goal["zoom"]
	var gp: Vector2 = goal["pos"]
	if _snap:
		zoom = Vector2(gz, gz)
		global_position = gp
		_snap = false
	else:
		var z: float = lerpf(zoom.x, gz, zoom_smooth)
		zoom = Vector2(z, z)
		global_position = global_position.lerp(gp, pos_smooth)
	global_position = _clamp_pos(global_position, zoom.x)


## Doelpositie en -zoom (pixels) zonder smoothing; los testbaar.
func compute_goal() -> Dictionary:
	var pts: Array[Vector2] = []
	for t: Node2D in targets:
		if is_instance_valid(t):
			pts.append(t.global_position)
	if pts.is_empty():
		return {}
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p: Vector2 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var m: float = margin_units * Units.UNIT_TO_PX
	lo -= Vector2(m, m)
	hi += Vector2(m, m)
	var vp: Vector2 = get_viewport_rect().size
	var size: Vector2 = hi - lo
	var z: float = minf(vp.x / maxf(size.x, 1.0), vp.y / maxf(size.y, 1.0))
	z = clampf(z, min_zoom, max_zoom)
	if _has_bounds:
		var bpx: Rect2 = bounds_px()
		z = maxf(z, maxf(vp.x / bpx.size.x, vp.y / bpx.size.y))
	var pos: Vector2 = (lo + hi) * 0.5
	return {"pos": _clamp_pos(pos, z), "zoom": z}


func bounds_px() -> Rect2:
	var tl: Vector2 = Units.to_px(Vector2(bounds_units.position.x, bounds_units.position.y + bounds_units.size.y))
	var br: Vector2 = Units.to_px(Vector2(bounds_units.position.x + bounds_units.size.x, bounds_units.position.y))
	return Rect2(tl, br - tl)


func _clamp_pos(pos: Vector2, z: float) -> Vector2:
	if not _has_bounds:
		return pos
	var b: Rect2 = bounds_px()
	var half: Vector2 = get_viewport_rect().size / z * 0.5
	var lo: Vector2 = b.position + half
	var hi: Vector2 = b.end - half
	var x: float = clampf(pos.x, lo.x, hi.x) if lo.x <= hi.x else b.get_center().x
	var y: float = clampf(pos.y, lo.y, hi.y) if lo.y <= hi.y else b.get_center().y
	return Vector2(x, y)
