class_name ClankEffect
extends VfxEffect
## Clank (twee hitboxes botsen): gekruiste vonken, geel/wit, kort en hard.


func setup(pos_px: Vector2) -> void:
	position = pos_px
	duration = 14
	z_index = 21


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * VfxConst.CLANK_SCALE)
	var t: float = progress()
	var grow: float = ease_out3(minf(t * 2.5, 1.0))
	var fade: float = 1.0 - t * t
	for k in 2:
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		var d := Vector2(cos(a), sin(a))
		draw_spike(Vector2.ZERO, d, 58.0 * grow, 6.0 * (1.0 - t), with_alpha(Color(1.0, 0.95, 0.5), fade))
		draw_spike(Vector2.ZERO, -d, 58.0 * grow, 6.0 * (1.0 - t), with_alpha(Color(1.0, 0.95, 0.5), fade))
	draw_star(Vector2.ZERO, 8, 30.0 * (1.0 - t * 0.6), 9.0, 0.2, with_alpha(Color.WHITE, fade))
	draw_ring(Vector2.ZERO, 14.0 + 40.0 * ease_out(t), 3.0, with_alpha(Color(1, 1, 0.8), 1.0 - t))
