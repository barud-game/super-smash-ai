class_name HitEffect
extends VfxEffect
## Melee-achtige hit-flits: harde witte kern, radiale spikes, schokring en een streep in de
## knockback-richting. Element bepaalt kleur en extra vormen. `strength` 0..1 schaalt grootte/duur.

var element: int = VfxConst.EL_NORMAL
var strength: float = 0.5
var dir: Vector2 = Vector2.RIGHT
var radius: float = 40.0
var kill: bool = false
var _spikes: Array[Dictionary] = []   # {ang, len, w}
var _bolts: Array[PackedVector2Array] = []
var _bolt_seed: int = 0
var _bits: Array[Dictionary] = []     # {dir, speed, size}


func setup(pos_px: Vector2, p_strength: float, p_element: int, angle_deg: float, p_kill: bool = false) -> void:
	position = pos_px
	strength = clampf(p_strength, 0.0, 1.0)
	element = p_element
	dir = dir_from_deg(angle_deg)
	kill = p_kill
	radius = lerpf(26.0, 96.0, strength) * (1.25 if kill else 1.0)
	duration = int(lerpf(9.0, 17.0, strength)) + (4 if kill else 0)
	z_index = 20
	var n: int = 8 + int(strength * 8.0)
	for i in n:
		var base: float = TAU * float(i) / float(n)
		_spikes.append({"ang": base + rng.randf_range(-0.12, 0.12),
			"len": radius * rng.randf_range(0.7, 1.35), "w": rng.randf_range(2.5, 5.0) * (0.6 + strength)})
	var bits: int = 5 + int(strength * 9.0)
	for i in bits:
		var a: float = rng.randf() * TAU
		_bits.append({"dir": Vector2(cos(a), sin(a)), "speed": rng.randf_range(0.6, 1.4) * radius * 0.07,
			"size": rng.randf_range(3.0, 7.0) * (0.7 + strength)})
	_bolt_seed = rng.randi()
	_make_bolts()


func _make_bolts() -> void:
	_bolts.clear()
	var r := RandomNumberGenerator.new()
	r.seed = _bolt_seed + age / 2
	for b in 5 + int(strength * 4.0):
		var a: float = TAU * float(b) / 5.0 + r.randf_range(-0.3, 0.3)
		var pts := PackedVector2Array([Vector2.ZERO])
		var d := Vector2(cos(a), sin(a))
		var p := Vector2.ZERO
		var total: float = radius * r.randf_range(0.9, 1.5)
		var seg: int = 5
		for k in seg:
			p += d * (total / seg) + Vector2(-d.y, d.x) * r.randf_range(-1.0, 1.0) * radius * 0.16
			pts.append(p)
		_bolts.append(pts)


func _on_tick() -> void:
	if element == VfxConst.EL_ELECTRIC and age % 2 == 0:
		_make_bolts()


func _palette() -> Dictionary:
	match element:
		VfxConst.EL_FIRE:
			return {"core": Color(1.0, 0.95, 0.65), "a": Color(1.0, 0.55, 0.1), "b": Color(0.95, 0.2, 0.05), "ring": Color(1.0, 0.7, 0.2)}
		VfxConst.EL_ELECTRIC:
			return {"core": Color(1.0, 1.0, 0.8), "a": Color(1.0, 0.95, 0.3), "b": Color(0.5, 0.8, 1.0), "ring": Color(1.0, 0.95, 0.4)}
		VfxConst.EL_ICE:
			return {"core": Color(0.95, 1.0, 1.0), "a": Color(0.6, 0.9, 1.0), "b": Color(0.3, 0.6, 1.0), "ring": Color(0.7, 0.95, 1.0)}
		VfxConst.EL_DARK:
			return {"core": Color(0.95, 0.8, 1.0), "a": Color(0.7, 0.2, 0.9), "b": Color(0.2, 0.05, 0.35), "ring": Color(0.75, 0.3, 0.95)}
		VfxConst.EL_SLASH:
			return {"core": Color(1.0, 1.0, 1.0), "a": Color(0.9, 0.95, 1.0), "b": Color(0.55, 0.65, 0.95), "ring": Color(0.9, 0.95, 1.0)}
		_:
			return {"core": Color(1.0, 1.0, 1.0), "a": Color(1.0, 0.97, 0.75), "b": Color(1.0, 0.8, 0.35), "ring": Color(1.0, 1.0, 0.9)}


func _draw() -> void:
	var t: float = progress()
	var pal: Dictionary = _palette()
	var fade: float = 1.0 - t * t
	var grow: float = ease_out3(minf(t * 2.2, 1.0))
	draw_ring(Vector2.ZERO, radius * (0.3 + 1.0 * ease_out3(t)), maxf(1.5, radius * 0.08 * (1.0 - t)), with_alpha(pal["ring"], 1.0 - t * t * 1.2))
	var streak: float = radius * (1.5 + strength) * grow
	draw_spike(-dir * radius * 0.2, dir, streak, radius * 0.17 * (1.0 - t), with_alpha(pal["a"], fade))
	draw_spike(dir * radius * 0.2, -dir, streak * 0.5, radius * 0.1 * (1.0 - t), with_alpha(pal["b"], fade * 0.8))
	draw_star(Vector2.ZERO, 6, radius * 0.95 * grow, radius * 0.3, dir.angle(), with_alpha(pal["a"], 0.75 * fade))
	var idx: int = 0
	for s: Dictionary in _spikes:
		var d := Vector2(cos(s["ang"]), sin(s["ang"]))
		var l: float = s["len"] * grow
		var from: float = radius * 0.12 + l * 0.15 * t
		var col: Color = pal["a"] if idx % 2 == 0 else pal["b"]
		draw_spike(d * from, d, l, s["w"] * 1.7 * (1.0 - t * 0.6), with_alpha(col, minf(fade * 1.3, 1.0)))
		idx += 1
	match element:
		VfxConst.EL_ELECTRIC:
			for pts: PackedVector2Array in _bolts:
				draw_polyline(pts, with_alpha(pal["b"], fade), 5.0 * (1.0 - t) + 1.0, true)
				draw_polyline(pts, with_alpha(pal["core"], fade), 2.0, true)
		VfxConst.EL_FIRE:
			for b: Dictionary in _bits:
				var p: Vector2 = b["dir"] * b["speed"] * float(age) * 3.0 + Vector2(0, -float(age) * float(age) * 0.35)
				var sz: float = b["size"] * (1.0 - t) * 1.3
				draw_circle(p, maxf(sz, 0.1), with_alpha(pal["a"] if t < 0.5 else pal["b"], fade))
				draw_circle(p + Vector2(0, -sz * 0.9), maxf(sz * 0.55, 0.1), with_alpha(pal["core"], fade * 0.8))
		VfxConst.EL_ICE:
			for b: Dictionary in _bits:
				var bd: Vector2 = b["dir"]
				var p2: Vector2 = bd * b["speed"] * float(age) * 3.4
				var sz2: float = b["size"] * 1.8 * (1.0 - t * 0.6)
				var n2 := Vector2(-bd.y, bd.x)
				draw_colored_polygon(PackedVector2Array([p2 + bd * sz2 * 1.6, p2 + n2 * sz2 * 0.5, p2 - bd * sz2 * 0.8, p2 - n2 * sz2 * 0.5]), with_alpha(pal["a"], fade))
				draw_colored_polygon(PackedVector2Array([p2 + bd * sz2 * 1.2, p2 + n2 * sz2 * 0.2, p2 - bd * sz2 * 0.3]), with_alpha(pal["core"], fade))
		VfxConst.EL_SLASH, VfxConst.EL_DARK:
			var sd := Vector2(-dir.y, dir.x)
			if element == VfxConst.EL_SLASH:
				sd = dir.rotated(0.6)
			var sl: float = radius * 2.2 * grow
			draw_spike(Vector2.ZERO, sd, sl, radius * 0.1 * (1.0 - t), with_alpha(pal["core"], fade))
			draw_spike(Vector2.ZERO, -sd, sl, radius * 0.1 * (1.0 - t), with_alpha(pal["core"], fade))
			if element == VfxConst.EL_DARK:
				disc(Vector2.ZERO, radius * 0.55 * (1.0 - t), with_alpha(pal["b"], 0.9))
	var core_r: float = radius * 0.6 * (1.0 - ease_out(t) * 0.92) + 2.0
	if age < 2:
		core_r *= 1.35
	disc(Vector2.ZERO, core_r * 1.4, with_alpha(pal["a"], 0.55 * fade))
	disc(Vector2.ZERO, core_r, with_alpha(pal["core"], 1.0))
