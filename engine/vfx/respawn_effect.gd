class_name RespawnEffect
extends VfxEffect
## Respawn: lichtpilaar en opstijgende ringen in spelerskleur.

var color: Color = Color(0.6, 0.85, 1.0)


func setup(pos_px: Vector2, p_color: Color) -> void:
	position = pos_px
	color = p_color
	duration = 36
	z_index = -1


func _draw() -> void:
	var t: float = progress()
	var fade: float = 1.0 - t
	var w: float = 46.0 * (1.0 - ease_out(t) * 0.7)
	var h: float = 260.0 * ease_out3(minf(t * 3.0, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(-w * 0.4, -h), Vector2(w * 0.4, -h), Vector2(w, 0)]), with_alpha(color, 0.35 * fade))
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.45, 0), Vector2(-w * 0.15, -h * 0.9), Vector2(w * 0.15, -h * 0.9), Vector2(w * 0.45, 0)]), with_alpha(Color.WHITE, 0.7 * fade))
	for i in 3:
		var tt: float = clampf(t * 1.6 - float(i) * 0.18, 0.0, 1.0)
		if tt > 0.0 and tt < 1.0:
			var y: float = -tt * 150.0
			draw_arc(Vector2(0, y), 36.0 * (1.0 - tt * 0.3), 0.0, TAU, 32, with_alpha(color.lightened(0.4), 1.0 - tt), 4.0, true)
