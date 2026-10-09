class_name DefaultKoEffect
extends KoEffect
## Standaard KO-effect (fallback): Melee-achtige lichtexplosie op de rand met een pilaar de stage in,
## draaiende lichtstralen, schokringen en vonken, in spelerskleur.

var _rays: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []


func _on_ko_setup() -> void:
	duration = 70
	for i in 14:
		_rays.append({"ang": TAU * float(i) / 14.0 + rng.randf_range(-0.1, 0.1), "len": rng.randf_range(160.0, 340.0), "w": rng.randf_range(10.0, 22.0)})
	for i in 26:
		var spread: float = rng.randf_range(-0.9, 0.9)
		var d: Vector2 = dir.rotated(spread)
		_sparks.append({"dir": d, "speed": rng.randf_range(7.0, 17.0), "size": rng.randf_range(3.0, 8.0), "delay": rng.randi_range(0, 8)})


func _draw_ko(t: float, f: int) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * VfxConst.KO_SCALE)
	var fade: float = 1.0 - t
	var pc: Color = player_color
	var bright: Color = pc.lerp(Color.WHITE, 0.55)
	# 1) pilaar de stage in
	var grow: float = ease_out3(minf(float(f) / 10.0, 1.0))
	var length: float = 620.0 * grow
	var width: float = 70.0 * (1.0 - ease_out(clampf((t - 0.15) / 0.85, 0.0, 1.0)))
	_beam(length, width * 1.7, with_alpha(pc, 0.30 * fade))
	_beam(length * 0.9, width, with_alpha(bright, 0.55 * fade))
	_beam(length * 0.8, width * 0.4, with_alpha(Color.WHITE, 0.9 * fade))
	# 2) stralen die rond de kern draaien
	var rot: float = float(f) * 0.03
	for r: Dictionary in _rays:
		var a: float = r["ang"] + rot
		var d := Vector2(cos(a), sin(a))
		# alleen stralen die de stage in wijzen of zijdelings; achter de rand zit buiten beeld
		var l: float = r["len"] * ease_out3(minf(float(f) / 8.0, 1.0)) * (1.0 - t * 0.6)
		draw_spike(Vector2.ZERO, d, l, r["w"] * fade, with_alpha(bright, 0.8 * fade))
	# 3) schokringen
	for k in 2:
		var tt: float = clampf(t * 1.4 - float(k) * 0.18, 0.0, 1.0)
		if tt > 0.0 and tt < 1.0:
			draw_ring(Vector2.ZERO, 40.0 + 300.0 * ease_out3(tt), 10.0 * (1.0 - tt) + 2.0, with_alpha(pc.lerp(Color.WHITE, 0.3), 1.0 - tt))
	# 4) vonken
	for s: Dictionary in _sparks:
		var e: int = f - int(s["delay"])
		if e < 0:
			continue
		var p: Vector2 = s["dir"] * s["speed"] * float(e) * (1.0 - float(e) * 0.004) * 1.6
		var sz: float = s["size"] * maxf(1.0 - t, 0.0)
		disc(p, sz, with_alpha(bright, fade))
		draw_line(p, p - s["dir"] * sz * 5.0, with_alpha(pc, fade), maxf(sz * 0.6, 1.0))
	# 5) kern: harde witte flits, krimpt snel
	var core: float = 150.0 * (1.0 - ease_out(t) * ease_out(t))
	disc(Vector2.ZERO, core * 1.5, with_alpha(pc, 0.4 * fade))
	disc(Vector2.ZERO, core, with_alpha(Color.WHITE, 1.0 if f > 1 else 0.9))
	draw_star(Vector2.ZERO, 10, core * 1.6, core * 0.45, rot * 2.0, with_alpha(Color.WHITE, 0.9 * fade))


func _beam(length: float, width: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		-perp * width, perp * width, dir * length + perp * width * 0.25, dir * length - perp * width * 0.25]), col)
