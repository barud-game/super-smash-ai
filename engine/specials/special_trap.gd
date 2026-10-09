class_name SpecialTrap
extends SpecialEntity
## Trap/persistente entity (bouwsteen 18): plaatsen (drop/stick/throw_arc), arm-timer, triggers
## (contact_enemy / proximity / timer / owner_signal), explosie-hitboxes, cap per owner, opruimen.
## Altijd zichtbaar (director: onzichtbare traps verboden). Zie docs/special-sjablonen.md §13.

## "falling" -> "armed" (na arm_time) -> "exploding" -> dood.
var phase: String = "falling"
var phase_frame: int = 0
## "drop" / "stick" / "throw_arc".
var place_mode: String = "drop"
var arm_time: int = 30
## "contact_enemy" / "proximity" / "timer" / "owner_signal".
var trigger: String = "contact_enemy"
var trigger_radius: float = 8.0
var explode_frames: int = 6
var owner_can_trigger: bool = false
## Vijandelijke hits vernietigen de trap na `hp` damage (<= 0 = niet stuk te slaan).
var hp: float = 0.0
## Ontploffing raakt andere traps van dezelfde eigenaar -> die ontploffen ook.
var chain: bool = false
## ⚠️ Valsnelheid bij drop.
var fall_gravity: float = 0.1
var armed: bool = false
var landed: bool = false
var _explode_start: int = -1


func _init() -> void:
	kind = "trap"
	reflectable = false
	absorbable = false
	transcendent = true
	color = Color(1.0, 0.35, 0.25)


func tick() -> bool:
	if not super.tick():
		return false
	phase_frame += 1
	match phase:
		"falling", "armed":
			_move()
			if not armed and age >= arm_time:
				armed = true
				phase = "armed"
			if trigger == "timer" and lifetime >= 0 and age >= lifetime - 1:
				explode()
		"exploding":
			if phase_frame >= explode_frames:
				kill("exploded")
				return false
	if alive and world != null and SpecialGeometry.outside_blast(world.stage, pos):
		kill("blast_zone")
		return false
	return alive


func _move() -> void:
	if landed or place_mode == "stick":
		return
	var segs: Array = world.segs if world != null else []
	vel.y = maxf(vel.y - fall_gravity, -3.0)
	var to: Vector2 = pos + vel
	var cross: Dictionary = SpecialGeometry.crossing_top(segs, pos, to, true)
	if cross["hit"]:
		pos = cross["point"]
		vel = Vector2.ZERO
		landed = true
		return
	if SpecialGeometry.inside_solid(segs, to):
		vel.x = 0.0
		to = Vector2(pos.x, to.y)
	pos = to


## Ontploffen (trigger, timer, owner_signal, chain). Idempotent.
func explode() -> void:
	if not alive or phase == "exploding":
		return
	phase = "exploding"
	phase_frame = 0
	_explode_start = age


func hit_clock() -> int:
	return age - _explode_start if phase == "exploding" else -1


func hitboxes_live() -> bool:
	return alive and phase == "exploding"


## Trap raakt een fighter alleen tijdens de explosie; daarna blijft de explosie lopen tot het einde.
func on_hit_target(_ev: HitEvent) -> void:
	pass


func on_shield(_ev: HitEvent) -> void:
	pass


func body_radius() -> float:
	return maxf(draw_radius, 2.0)


func _draw() -> void:
	if not alive:
		return
	var k: float = Units.UNIT_TO_PX
	if phase == "exploding":
		var r: float = 0.0
		for h: HitboxData in hit_list:
			r = maxf(r, h.radius)
		draw_circle(Vector2.ZERO, r * k, Color(1.0, 0.6, 0.2, 0.6))
		return
	var s: float = draw_radius * k
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
	draw_colored_polygon(pts, Color(color, 0.9 if armed else 0.5))
	# Verplichte telegraaf: knipperen zodra hij scherp staat.
	if armed and (age / 8) % 2 == 0:
		draw_arc(Vector2.ZERO, s * 1.6, 0.0, TAU, 16, Color(1, 1, 1, 0.8), 2.0)
