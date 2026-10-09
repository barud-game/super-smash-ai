class_name SpecialHook
extends SpecialEntity
## Tether-haak (bouwsteen 19, eenvoudig): vliegt vanaf de hand van de eigenaar in `dir` tot `max_length`,
## haakt aan een ledge (niet bezet; Melee-regels via het gedeelde ledge-systeem) of een fighter, en wordt
## door de tether-runner uitgelezen (latched_*). Verdwijnt als de runner stopt of bij max lengte (miss).

## "extend" -> "latched" | "miss".
var state: String = "extend"
var dir: Vector2 = Vector2.RIGHT
var extend_speed: float = 8.0
var max_length: float = 120.0
var length: float = 0.0
## Hand-offset t.o.v. de voeten van de eigenaar (x gespiegeld met facing).
var hand_offset: Vector2 = Vector2(4.0, 8.0)
## Anker-typen: "ledge", "fighter".
var anchor_types: Array = ["ledge"]
## Extra grijpbereik rond de ledge (units) ⚠️.
var ledge_catch_radius: float = 6.0
var latched_kind: String = ""
var latched_ledge: Dictionary = {}
var latched_fighter: Fighter = null
var _prev_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	kind = "hook"
	reflectable = false
	absorbable = false
	transcendent = true
	lifetime = -1
	color = Color(0.8, 0.85, 0.95)


func hand() -> Vector2:
	if owner_fighter == null or not is_instance_valid(owner_fighter):
		return pos
	return owner_fighter.pos + Vector2(hand_offset.x * owner_fighter.facing, hand_offset.y)


func tick() -> bool:
	if not super.tick():
		return false
	if state != "extend":
		if state == "latched" and latched_kind == "fighter" and latched_fighter != null:
			pos = latched_fighter.pos + Vector2(0.0, latched_fighter.stats.visual_height * 0.5)
		return true
	var prev: Vector2 = pos
	length = minf(length + extend_speed, max_length)
	pos = hand() + dir * length
	_prev_pos = prev
	if "ledge" in anchor_types and _try_ledge():
		return true
	if "fighter" in anchor_types and _try_fighter():
		return true
	if length >= max_length:
		state = "miss"
	return true


func _try_ledge() -> bool:
	if world == null:
		return false
	for l: Dictionary in SpecialGeometry.ledges(world.stage):
		var lp: Vector2 = l["pos"]
		# Afstand tot het afgelegde stuk van deze frame (de haak kan anders over de ledge heen springen).
		if HitResolver.point_segment_dist(lp, _prev_pos, pos) > ledge_catch_radius + body_radius():
			continue
		# Bezette ledge: v1 grijpt niet (docs/special-sjablonen.md §11).
		if owner_fighter != null and owner_fighter.ledge_occupied_by_other(lp, l["side"]):
			continue
		state = "latched"
		latched_kind = "ledge"
		latched_ledge = l
		pos = lp
		return true
	return false


func _try_fighter() -> bool:
	if world == null:
		return false
	for f: Fighter in world.fighters:
		if f == owner_fighter or not f.active or f.is_intangible():
			continue
		var t: CombatTarget = f.combat_target()
		if t.shielding:
			continue
		for hb: HurtboxData in t.hurtboxes:
			if HitResolver.circle_hits_capsule(pos, body_radius(), hb.world_a(t.origin, t.facing),
					hb.world_b(t.origin, t.facing), hb.radius):
				state = "latched"
				latched_kind = "fighter"
				latched_fighter = f
				return true
	return false


func _draw() -> void:
	if not alive:
		return
	var k: float = Units.UNIT_TO_PX
	var h: Vector2 = Units.to_px(hand()) - Units.to_px(pos)
	draw_line(h, Vector2.ZERO, Color(0.85, 0.85, 0.9, 0.9), 2.0)
	draw_circle(Vector2.ZERO, body_radius() * k, Color(color, 0.9))
