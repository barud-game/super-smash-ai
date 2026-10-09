class_name AirdodgeEffect
extends VfxEffect
## Airdodge: uitdijende ring + nabeelden die tegen de dodge-richting in wegvegen.

var color: Color = Color.WHITE
var dir: Vector2 = Vector2.RIGHT
var _has_dir: bool = true


## `angle_deg`: richting van de dodge (units-conventie); NAN = spotdodge-achtige ring zonder streep.
func setup(pos_px: Vector2, angle_deg: float, p_color: Color) -> void:
	position = pos_px
	color = p_color
	_has_dir = not is_nan(angle_deg)
	if _has_dir:
		dir = dir_from_deg(angle_deg)
	duration = 14
	z_index = -1


func _draw() -> void:
	var t: float = progress()
	var fade: float = 1.0 - t
	draw_ring(Vector2.ZERO, 18.0 + 46.0 * ease_out(t), 5.0 * fade + 1.0, with_alpha(color.lightened(0.5), fade))
	if _has_dir:
		for i in 4:
			var back: Vector2 = -dir * (10.0 + float(i) * 18.0 * (0.4 + t))
			var a: float = fade * (0.55 - float(i) * 0.12)
			var n := Vector2(-dir.y, dir.x)
			var r: float = 20.0 - float(i) * 3.0
			draw_colored_polygon(PackedVector2Array([back + dir * r, back + n * r * 0.55, back - dir * r * 1.6, back - n * r * 0.55]), with_alpha(color, a))
