class_name CosmicBackground
extends Control
## Donkere kosmische achtergrond: verloop, nevel, twinkelende sterren en een planeet-ring.
## Vult het hele scherm; puur decoratie (de klok hier is alleen visueel, geen gameplay).

const STAR_COUNT: int = 220

var _stars: Array = []   # [pos(0..1), radius, phase, speed, tint]
var _nebulae: Array = [] # [pos(0..1), radius_px, color]
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	var tints: Array[Color] = [Color("ffffff"), Color("bfe6ff"), Color("e3c9ff")]
	for i in STAR_COUNT:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.6, 2.0),
			rng.randf() * TAU, rng.randf_range(0.4, 1.6), tints[rng.randi() % 3]])
	_nebulae = [
		[Vector2(0.18, 0.28), 360.0, Color(0.42, 0.20, 0.85, 0.05)],
		[Vector2(0.82, 0.70), 420.0, Color(0.10, 0.45, 0.85, 0.05)],
		[Vector2(0.55, 0.10), 300.0, Color(0.85, 0.20, 0.55, 0.035)],
	]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([UiStyle.BG_TOP, UiStyle.BG_TOP, UiStyle.BG_BOTTOM, UiStyle.BG_BOTTOM]))
	for n: Array in _nebulae:
		var c: Vector2 = Vector2(n[0].x * s.x, n[0].y * s.y)
		var col: Color = n[2]
		for k in 14:
			var f: float = 1.0 - float(k) / 14.0
			draw_circle(c, n[1] * f, col)
	# Planeet met ringen rechtsonder.
	var pc := Vector2(s.x * 0.88, s.y * 1.02)
	for k in 6:
		draw_arc(pc, 330.0 + k * 22.0, PI, TAU, 96, Color(0.45, 0.6, 1.0, 0.07 - k * 0.01), 2.0, true)
	draw_circle(pc, 300.0, Color(0.06, 0.07, 0.16, 0.9))
	draw_arc(pc, 300.0, PI, TAU, 96, Color(0.5, 0.7, 1.0, 0.35), 3.0, true)
	for st: Array in _stars:
		var p: Vector2 = Vector2(st[0].x * s.x, st[0].y * s.y)
		var a: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * st[3] + st[2]))
		var col: Color = st[4]
		draw_circle(p, st[1], Color(col.r, col.g, col.b, a))
