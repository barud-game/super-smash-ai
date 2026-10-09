class_name VfxEffect
extends Node2D
## Basis van alle VFX. Puur visueel; de timing loopt op Sim-frames: de `VfxLayer` roept
## elke sim-frame `vfx_tick(frame)` aan. Er is geen _process-timing, dus pauze en frame advance
## bevriezen effecten vanzelf. Tekenen gebeurt in `_draw()` op basis van `age`.
##
## Posities zijn in pixels (de layer rekent Melee-units om met `Units.to_px`).

## Totale duur in frames; daarna ruimt de layer het effect op.
var duration: int = 12
## Frames die dit effect al leeft (0 = spawn-frame).
var age: int = 0
var finished: bool = false
var rng := RandomNumberGenerator.new()


func seed_rng(s: int) -> void:
	rng.seed = s


## Eén sim-frame vooruit. Subclasses overschrijven `_on_tick()`.
func vfx_tick(_frame: int) -> void:
	if finished:
		return
	_on_tick()
	age += 1
	if age >= duration:
		finished = true
	queue_redraw()


func _on_tick() -> void:
	pass


## Voortgang 0..1 over de levensduur.
func progress() -> float:
	return clampf(float(age) / float(maxi(duration, 1)), 0.0, 1.0)


# ---- tekenhulpen ----

static func ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func ease_out3(t: float) -> float:
	var u: float = 1.0 - t
	return 1.0 - u * u * u


static func dir_from_deg(deg: float) -> Vector2:
	# Units-conventie: 0 = rechts, 90 = omhoog (y omhoog) -> Godot-px (y omlaag).
	var r: float = deg_to_rad(deg)
	return Vector2(cos(r), -sin(r))


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))


## Dunne spike (driehoek) vanaf `from` in richting `dir`.
func draw_spike(from: Vector2, dir: Vector2, length: float, half_width: float, col: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([from + n * half_width, from + dir * length, from - n * half_width]), col)


## Ster met `points` punten.
func draw_star(center: Vector2, points: int, r_out: float, r_in: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a: float = rot + PI * float(i) / float(points)
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


func draw_ring(center: Vector2, radius: float, width: float, col: Color) -> void:
	if radius <= 0.5:
		return
	draw_arc(center, radius, 0.0, TAU, 40, col, width, true)


## Gevulde cirkel (draw_circle met alpha).
func disc(center: Vector2, radius: float, col: Color) -> void:
	if radius > 0.3 and col.a > 0.01:
		draw_circle(center, radius, col)
