class_name HitboxDraw
extends RefCounted
## Debug-tekenhulp voor hitboxen en hurtboxes; te gebruiken in _draw() als Sim.debug_hitboxes aan staat.
## `origin` = wereldpositie (units) die op de canvas-oorsprong valt (Vector2.ZERO voor een canvas op de
## wereldoorsprong, fighter.pos voor tekenen in een Fighter-node).

const HIT_COLOR := Color(1.0, 0.15, 0.15, 0.4)
const HIT_LATE_COLOR := Color(1.0, 0.85, 0.2, 0.4)
const HURT_COLOR := Color(1.0, 1.0, 0.2, 0.3)
const HURT_INTANGIBLE_COLOR := Color(0.3, 0.6, 1.0, 0.4)
const SHIELD_COLOR := Color(0.5, 0.4, 1.0, 0.3)


static func draw_hitboxes(canvas: CanvasItem, active: Array, origin: Vector2 = Vector2.ZERO) -> void:
	for h in active:
		var ah: ActiveHitbox = h
		var col: Color = HIT_LATE_COLOR if ah.late else HIT_COLOR
		_circle(canvas, ah.pos - origin, ah.data.radius, col)


static func draw_hurtboxes(canvas: CanvasItem, target: CombatTarget, origin: Vector2 = Vector2.ZERO) -> void:
	for hb in target.hurtboxes:
		var col: Color = HURT_INTANGIBLE_COLOR if (hb.intangible or target.intangible) else HURT_COLOR
		var a: Vector2 = hb.world_a(target.origin, target.facing) - origin
		var b: Vector2 = hb.world_b(target.origin, target.facing) - origin
		_capsule(canvas, a, b, hb.radius, col)
	if target.shielding:
		_circle(canvas, target.shield_center - origin, target.shield_radius, SHIELD_COLOR)


static func _circle(canvas: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var k: float = Units.UNIT_TO_PX
	var p: Vector2 = Units.to_px(c)
	canvas.draw_circle(p, r * k, col)
	canvas.draw_arc(p, r * k, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.9), 1.5)


static func _capsule(canvas: CanvasItem, a: Vector2, b: Vector2, r: float, col: Color) -> void:
	var k: float = Units.UNIT_TO_PX
	var pa: Vector2 = Units.to_px(a)
	var pb: Vector2 = Units.to_px(b)
	var line_col := Color(col.r, col.g, col.b, 0.9)
	canvas.draw_circle(pa, r * k, col)
	canvas.draw_circle(pb, r * k, col)
	canvas.draw_arc(pa, r * k, 0.0, TAU, 20, line_col, 1.5)
	canvas.draw_arc(pb, r * k, 0.0, TAU, 20, line_col, 1.5)
	var d: Vector2 = pb - pa
	if d.length() > 0.01:
		var n: Vector2 = Vector2(-d.y, d.x).normalized() * r * k
		canvas.draw_colored_polygon(PackedVector2Array([pa + n, pb + n, pb - n, pa - n]), col)
		canvas.draw_line(pa + n, pb + n, line_col, 1.5)
		canvas.draw_line(pa - n, pb - n, line_col, 1.5)
