class_name Stage
extends Node2D
## Tekent een StageData (achtergrond in parallax-lagen + platform) en biedt een data-API.
## Geen physics: fighters vragen alleen data op. Alles in Melee-units; tekenen via Units.to_px.

@export var data: StageData

# Kleuren (donker, laag contrast achtergrond zodat characters afsteken)
const SKY_TOP := Color("05071a")
const SKY_BOTTOM := Color("1b1038")
const HULL_TOP := Color("3a4570")
const HULL_BOTTOM := Color("0d1024")
const RIM := Color("7fd0ff")

var _time: float = 0.0
var _nebulae: Array[Node2D] = []
var _debug: _DebugDraw


func _ready() -> void:
	if data == null:
		push_error("Stage: geen StageData ingesteld")
		return
	_build_sky()
	_add_stars(0.04, 260, 1.2, Color(0.75, 0.8, 1.0, 0.55), 11)
	_add_nebula(0.08, 21, [Color(0.35, 0.2, 0.7, 0.20), Color(0.15, 0.3, 0.7, 0.16), Color(0.55, 0.15, 0.5, 0.12)])
	_add_stars(0.12, 160, 1.8, Color(0.85, 0.9, 1.0, 0.75), 12)
	_add_stars(0.25, 70, 2.6, Color(1.0, 1.0, 1.0, 0.9), 13)
	var body := _StageBody.new()
	body.data = data
	add_child(body)
	_debug = _DebugDraw.new()
	_debug.data = data
	_debug.z_index = 100
	add_child(_debug)


func _process(delta: float) -> void:
	# Alleen visueel: trage nevel-drift. Geen gameplay.
	_time += delta
	for i in _nebulae.size():
		_nebulae[i].position = Vector2(sin(_time * 0.05 + i) * 90.0, cos(_time * 0.04 + i * 2.0) * 40.0)
	if _debug != null and _debug.shown != Sim.debug_hitboxes:
		_debug.shown = Sim.debug_hitboxes
		_debug.queue_redraw()


# --- API (geen physics, alleen data) ---

func get_ground_segments() -> Array[StageSegment]:
	return data.ground_segments


func get_ledges() -> Array[StageLedge]:
	return data.ledges


## Blast zone als Rect2 in Melee-units (position = links/onder, size = breedte/hoogte).
func get_blast_zone() -> Rect2:
	return data.blast_zone


func get_camera_bounds() -> Rect2:
	return data.camera_bounds


## Spawnpositie (Melee-units) voor speler i (0-based).
func get_spawn(i: int) -> Vector2:
	return data.spawns[i % data.spawns.size()]


func get_respawn(i: int) -> Vector2:
	return data.respawns[i % data.respawns.size()]


# --- Achtergrond ---

func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var g := Gradient.new()
	g.colors = PackedColorArray([SKY_TOP, SKY_BOTTOM])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)


func _parallax(scale: float, z: int) -> Parallax2D:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scale, scale)
	p.z_index = z
	add_child(p)
	return p


func _add_stars(scale: float, count: int, size: float, col: Color, seed_value: int) -> void:
	var p := _parallax(scale, -50)
	var s := _Stars.new()
	s.count = count
	s.size = size
	s.color = col
	s.seed_value = seed_value
	p.add_child(s)


func _add_nebula(scale: float, seed_value: int, colors: Array) -> void:
	var p := _parallax(scale, -60)
	var holder := Node2D.new()
	p.add_child(holder)
	_nebulae.append(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	for i in 14:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.modulate = colors[i % colors.size()]
		sp.position = Vector2(rng.randf_range(-1400, 1400), rng.randf_range(-900, 700))
		var sc: float = rng.randf_range(4.0, 9.0)
		sp.scale = Vector2(sc * rng.randf_range(0.8, 1.6), sc)
		holder.add_child(sp)


class _Stars extends Node2D:
	var count: int = 100
	var size: float = 1.5
	var color: Color = Color.WHITE
	var seed_value: int = 1

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in count:
			var pos := Vector2(rng.randf_range(-2600, 2600), rng.randf_range(-1800, 1400))
			var b: float = rng.randf_range(0.4, 1.0)
			var c := Color(color.r, color.g, color.b, color.a * b)
			draw_circle(pos, size * rng.randf_range(0.6, 1.2), c)


class _StageBody extends Node2D:
	var data: StageData

	func _draw() -> void:
		for seg: StageSegment in data.ground_segments:
			_draw_segment(seg)

	func _draw_segment(seg: StageSegment) -> void:
		var l: float = minf(seg.a.x, seg.b.x)
		var r: float = maxf(seg.a.x, seg.b.x)
		var y: float = seg.a.y
		# Romp: stappen naar binnen en omlaag (eigen vorm, in units)
		var pts_u: Array[Vector2] = [
			Vector2(l, y), Vector2(r, y), Vector2(r, y - 7),
			Vector2(r - 14, y - 15), Vector2(r - 38, y - 24), Vector2(r - 62, y - 31), Vector2(r - 80, y - 42),
			Vector2(l + 80, y - 42), Vector2(l + 62, y - 31), Vector2(l + 38, y - 24),
			Vector2(l + 14, y - 15), Vector2(l, y - 7),
		]
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for p: Vector2 in pts_u:
			pts.append(Units.to_px(p))
			cols.append(HULL_TOP.lerp(HULL_BOTTOM, clampf((y - p.y) / 42.0, 0.0, 1.0)))
		# zachte gloed onder het platform
		for k in 6:
			var rad: float = 140.0 + k * 55.0
			draw_circle(Units.to_px(Vector2((l + r) * 0.5, y - 45)) + Vector2(0, 30), rad, Color(0.3, 0.45, 1.0, 0.018))
		draw_polygon(pts, cols)
		# panelen-lijnen
		for k in 4:
			var yy: float = y - 8.0 - k * 8.0
			draw_line(Units.to_px(Vector2(l + k * 14.0 + 6, yy)), Units.to_px(Vector2(r - k * 14.0 - 6, yy)), Color(0.0, 0.0, 0.0, 0.22), 2.0)
		# gloeiende bovenrand (meerdere lagen)
		var a: Vector2 = Units.to_px(Vector2(l, y))
		var b: Vector2 = Units.to_px(Vector2(r, y))
		for w: Array in [[22.0, 0.05], [14.0, 0.08], [8.0, 0.14], [4.0, 0.3]]:
			draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(RIM.r, RIM.g, RIM.b, w[1]), w[0])
		draw_line(a, b, Color(0.9, 0.97, 1.0, 0.95), 2.0)
		# gloed langs de zijranden
		var outline := PackedVector2Array()
		for i in range(1, pts.size()):
			outline.append(pts[i])
		outline.append(pts[0])
		draw_polyline(outline, Color(RIM.r, RIM.g, RIM.b, 0.18), 3.0)


class _DebugDraw extends Node2D:
	var data: StageData
	var shown: bool = false

	func _draw() -> void:
		if not shown:
			return
		_rect(data.blast_zone, Color(1, 0.2, 0.2, 0.9))
		_rect(data.camera_bounds, Color(0.2, 1, 0.4, 0.9))
		for led: StageLedge in data.ledges:
			var p: Vector2 = Units.to_px(led.position)
			draw_circle(p, 6.0, Color(1, 0.9, 0.1))
			draw_line(p, p + Vector2(led.side * 24.0, 0), Color(1, 0.9, 0.1), 2.0)
		for seg: StageSegment in data.ground_segments:
			draw_line(Units.to_px(seg.a), Units.to_px(seg.b), Color(0.2, 0.9, 1.0), 2.0)
		for p_u: Vector2 in data.spawns:
			draw_circle(Units.to_px(p_u), 4.0, Color(1, 1, 1))

	func _rect(r: Rect2, col: Color) -> void:
		var tl: Vector2 = Units.to_px(Vector2(r.position.x, r.position.y + r.size.y))
		var br: Vector2 = Units.to_px(Vector2(r.position.x + r.size.x, r.position.y))
		draw_rect(Rect2(tl, br - tl), col, false, 3.0)
