class_name ShieldHitEffect
extends VfxEffect
## Schildhit: zeshoekige rimpel + vonkjes in de kleur van de schild-eigenaar.

var strength: float = 0.5
var color: Color = Color(0.5, 0.8, 1.0)
var dir: Vector2 = Vector2.RIGHT


func setup(pos_px: Vector2, p_strength: float, p_color: Color, angle_deg: float) -> void:
	position = pos_px
	strength = clampf(p_strength, 0.0, 1.0)
	color = p_color
	dir = dir_from_deg(angle_deg)
	duration = 10 + int(strength * 6.0)
	z_index = 19


func _draw() -> void:
	var t: float = progress()
	var r: float = lerpf(22.0, 60.0, strength) * (0.5 + 0.6 * ease_out(t))
	var hex := PackedVector2Array()
	for i in 6:
		var a: float = PI / 6.0 + TAU * float(i) / 6.0
		hex.append(Vector2(cos(a), sin(a)) * r)
	hex.append(hex[0])
	draw_polyline(hex, with_alpha(Color.WHITE.lerp(color, t), 1.0 - t), 4.0 * (1.0 - t) + 1.0, true)
	disc(Vector2.ZERO, r * 0.8, with_alpha(color, 0.25 * (1.0 - t)))
	for i in 6:
		var a2: float = dir.angle() + (float(i) - 2.5) * 0.35
		var d := Vector2(cos(a2), sin(a2))
		draw_spike(d * r * 0.6, d, r * (0.5 + 0.8 * t), 2.0 * (1.0 - t), with_alpha(Color.WHITE, 1.0 - t))
