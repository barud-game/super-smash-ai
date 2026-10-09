extends KoEffect
## KO-effect van de Houten Pop: houtsplinters die de stage in vliegen, een zaagselwolk en een
## band in spelerskleur die over de rand veegt. Voorbeeld voor de ko-effect-builder.

var _splinters: Array[Dictionary] = []
var _dust: Array[Dictionary] = []


func _on_ko_setup() -> void:
	duration = 75
	for i in 34:
		var spread: float = rng.randf_range(-1.1, 1.1)
		_splinters.append({
			"dir": dir.rotated(spread),
			"speed": rng.randf_range(7.0, 18.0),
			"len": rng.randf_range(34.0, 84.0),
			"w": rng.randf_range(6.0, 13.0),
			"rot0": rng.randf() * TAU,
			"spin": rng.randf_range(-0.4, 0.4),
			"dark": rng.randf() < 0.4,
			"delay": rng.randi_range(0, 6),
		})
	for i in 14:
		_dust.append({"dir": dir.rotated(rng.randf_range(-1.3, 1.3)), "speed": rng.randf_range(2.0, 7.0), "r": rng.randf_range(10.0, 26.0)})


func _draw_ko(t: float, f: int) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * VfxConst.KO_SCALE)
	var fade: float = 1.0 - t
	var wood: Color = primary()
	var dark: Color = secondary()
	# zaagselwolk
	for d: Dictionary in _dust:
		var p: Vector2 = d["dir"] * d["speed"] * float(f) * 1.8
		var r: float = float(d["r"]) * (0.6 + ease_out(t) * 1.4)
		disc(p, r, with_alpha(wood.lightened(0.25), 0.5 * fade))
	# band in spelerskleur: veegt langs de rand en drijft de stage in
	var band: float = ease_out3(minf(float(f) / 8.0, 1.0))
	var half_len: float = 330.0 * band
	var thick: float = 30.0 * pow(1.0 - t, 1.5)
	var drift: Vector2 = dir * float(f) * 2.2
	for k in 3:
		var sc: float = 1.0 - float(k) * 0.3
		var c: Color = player_color.lerp(Color.WHITE, 0.35 * float(k))
		draw_colored_polygon(PackedVector2Array([
			drift - perp * half_len * sc, drift + dir * thick * sc,
			drift + perp * half_len * sc, drift - dir * thick * sc]), with_alpha(c, 0.9 * fade * (0.6 + 0.2 * float(k))))
	# splinters
	for s: Dictionary in _splinters:
		var e: int = f - int(s["delay"])
		if e < 0:
			continue
		var sd: Vector2 = s["dir"]
		var p2: Vector2 = sd * s["speed"] * float(e) * (1.0 - float(e) * 0.006) * 1.5 + Vector2(0, float(e) * float(e) * 0.12)
		var ang: float = float(s["rot0"]) + float(s["spin"]) * float(e)
		var d2 := Vector2(cos(ang), sin(ang))
		var n2 := Vector2(-d2.y, d2.x)
		var l: float = s["len"]
		var w: float = s["w"]
		var col: Color = (dark if s["dark"] else wood)
		var a: float = minf(fade * 1.6, 1.0)
		draw_colored_polygon(PackedVector2Array([p2 - d2 * l * 0.5 + n2 * w * 0.5, p2 + d2 * l * 0.5, p2 - d2 * l * 0.5 - n2 * w * 0.5]), with_alpha(col, a))
		draw_line(p2 - d2 * l * 0.4, p2 + d2 * l * 0.45, with_alpha(col.lightened(0.4), a), 2.0)
	# impact-flits
	var core: float = 110.0 * (1.0 - ease_out(t))
	disc(Vector2.ZERO, core * 1.4, with_alpha(player_color, 0.45 * fade))
	disc(Vector2.ZERO, core, with_alpha(Color(1.0, 0.97, 0.88), 1.0))
	draw_star(Vector2.ZERO, 8, core * 1.7, core * 0.4, 0.2, with_alpha(Color.WHITE, 0.85 * fade))
