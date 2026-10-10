class_name GenericSpecialFx
extends RefCounted
## Registry van generieke special-effecten (`VfxLayer.spawn_special_fx`). Alle maten in Melee-units
## (een character is 11-19 units hoog, allrounder 15). Params gelden voor alle effecten: `color`, `size`, `duration`;
## effect-specifieke params staan bij de klasse. Alleen visueel, deterministisch (geseed `rng`), duur <= 90 frames.

const MAX_PARTICLES: int = 48

## Naam -> effectklasse.
static var REGISTRY: Dictionary = {
	"sparks": Sparks,
	"smoke_puff": SmokePuff,
	"burst": Burst,
	"speed_lines": SpeedLines,
	"charge_glow": ChargeGlow,
	"shockwave": Shockwave,
	"counter_flash": CounterFlash,
	"reflect_shine": ReflectShine,
	"teleport_poof": TeleportPoof,
	"dust_kick": DustKick,
}

## Alias -> [doelnaam, standaard-params]. Param van de aanroeper wint.
static var ALIASES: Dictionary = {
	"explosion": ["burst", {"size": 1.7, "color": Color(1.0, 0.55, 0.15), "smoke": true}],
	"trail": ["speed_lines", {}],
	"telegraph": ["charge_glow", {}],
	"aura": ["charge_glow", {}],
	"mine_blink": ["counter_flash", {"size": 0.4}],
	"purple_sparks": ["sparks", {"color": Color("#7b2fbf"), "count": 26}],
}


## [doelnaam, standaard-params] of [] als de naam onbekend is.
static func resolve(fx_name: String) -> Array:
	if REGISTRY.has(fx_name):
		return [fx_name, {}]
	if ALIASES.has(fx_name):
		return ALIASES[fx_name]
	return []


static func _pf(p: Dictionary, key: String, default: float) -> float:
	return float(p.get(key, default))


# ---------------------------------------------------------------------------------------------

## Vonkenregen. Params: `count` (12, max 48), `reach` (units, 6), `angle`/`spread_deg` (richting in graden + waaier; standaard rondom).
class Sparks extends SpecialFx:
	var _dir := PackedVector2Array()
	var _reach := PackedFloat32Array()
	var _w := PackedFloat32Array()

	func _on_fx_setup() -> void:
		duration = 18
		var n: int = clampi(int(params.get("count", 12)), 1, GenericSpecialFx.MAX_PARTICLES)
		var reach: float = GenericSpecialFx._pf(params, "reach", 6.0)
		var base: float = GenericSpecialFx._pf(params, "angle", 90.0)
		var spread: float = GenericSpecialFx._pf(params, "spread_deg", 360.0)
		for i in n:
			var a: float = base + (rng.randf() - 0.5) * spread
			_dir.append(SpecialFx.dir_deg(a))
			_reach.append(reach * rng.randf_range(0.45, 1.0))
			_w.append(rng.randf_range(0.3, 0.55))

	func _draw_fx(t: float, _f: int) -> void:
		var fade: float = 1.0 - t * t
		var hot: Color = SpecialFx.bright(color, 0.65)
		for i in _dir.size():
			var head: Vector2 = _dir[i] * _reach[i] * ease_out3(t)
			var tail: Vector2 = _dir[i] * _reach[i] * ease_out3(maxf(t - 0.3, 0.0))
			var w: float = _w[i] * (1.0 - t * 0.7)
			draw_line(tail, head, with_alpha(color, fade), w)
			draw_line(tail.lerp(head, 0.4), head, with_alpha(hot, fade), w * 0.45)
		if t < 0.25:
			disc(Vector2.ZERO, 1.8 * (1.0 - t * 4.0), with_alpha(hot, 0.9))


## Rookwolkje. Params: `count` (5), `tint`.
class SmokePuff extends SpecialFx:
	var _pos := PackedVector2Array()
	var _vel := PackedVector2Array()
	var _r := PackedFloat32Array()

	func _on_fx_setup() -> void:
		duration = 26
		var n: int = clampi(int(params.get("count", 5)), 1, 12)
		for i in n:
			_pos.append(Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.0)))
			_vel.append(Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.9, -0.3)))
			_r.append(rng.randf_range(1.0, 1.8))

	func _draw_fx(t: float, _f: int) -> void:
		var tint: Color = params.get("tint", Color(0.78, 0.78, 0.8))
		var a: float = (1.0 - t) * 0.8
		for i in _pos.size():
			var p: Vector2 = _pos[i] + _vel[i] * (ease_out(t) * float(duration) * 0.5)
			var r: float = _r[i] * (1.0 + 1.6 * ease_out(t))
			disc(p, r, with_alpha(tint.darkened(0.15), a * 0.6))
			disc(p + Vector2(0, -r * 0.1), r * 0.8, with_alpha(tint, a))


## Flits + schokring + stralen. Params: `smoke` (true = rookwolkjes erbij, voor explosion). Straal ~5 units (size 1), explosion ~8.5.
class Burst extends SpecialFx:
	var _puffs := PackedVector2Array()
	var _rot: float = 0.0

	func _on_fx_setup() -> void:
		duration = 20 if params.get("smoke", false) else 14
		_rot = rng.randf() * TAU
		if params.get("smoke", false):
			for i in 6:
				_puffs.append(SpecialFx.dir_deg(rng.randf() * 360.0) * rng.randf_range(2.0, 5.0))

	func _draw_fx(t: float, _f: int) -> void:
		var fade: float = 1.0 - t
		var hot: Color = SpecialFx.bright(color, 0.7)
		for p in _puffs:
			disc(p * ease_out(t), 1.4 + 1.8 * t, with_alpha(Color(0.3, 0.28, 0.3), fade * 0.5))
		disc(Vector2.ZERO, 5.0 * ease_out3(minf(t * 1.6, 1.0)), with_alpha(color, fade * 0.55))
		draw_ring(Vector2.ZERO, 1.0 + 5.0 * ease_out3(t), 0.7 * fade + 0.1, with_alpha(hot, fade))
		draw_star(Vector2.ZERO, 8, 6.0 * ease_out3(minf(t * 2.0, 1.0)) * (1.0 - t * 0.5), 1.8, _rot, with_alpha(color, fade))
		if t < 0.4:
			disc(Vector2.ZERO, 3.0 * (1.0 - t * 2.5), with_alpha(Color.WHITE, 0.95))


## Snelheidsstrepen achter een dash. Params: `lines` (7), `length` (units, 8). Beweegt tegen de kijkrichting in.
class SpeedLines extends SpecialFx:
	var _y := PackedFloat32Array()
	var _x0 := PackedFloat32Array()
	var _len := PackedFloat32Array()

	func _on_fx_setup() -> void:
		duration = 14
		var n: int = clampi(int(params.get("lines", 7)), 1, 16)
		var L: float = GenericSpecialFx._pf(params, "length", 8.0)
		for i in n:
			_y.append(lerpf(-6.0, 6.0, (float(i) + rng.randf() * 0.8) / float(n)))
			_x0.append(rng.randf_range(0.0, 4.0))
			_len.append(L * rng.randf_range(0.5, 1.0))

	func _draw_fx(t: float, _f: int) -> void:
		var col: Color = SpecialFx.bright(color, 0.7)
		var back: float = -float(facing)
		var fade: float = 1.0 - t
		for i in _y.size():
			var head: float = back * (_x0[i] + 9.0 * ease_out(t))
			var tail: float = head - back * _len[i] * (1.0 - t * 0.5)
			draw_line(Vector2(tail, _y[i]), Vector2(head, _y[i]), with_alpha(col, fade), 0.3 + 0.2 * fade)


## Opladen: pulserende gloed + deeltjes die naar binnen trekken. Telegraaf; wordt vaak herhaald. Straal ~5 units.
class ChargeGlow extends SpecialFx:
	var _ang := PackedFloat32Array()
	var _ph := PackedFloat32Array()

	func _on_fx_setup() -> void:
		duration = 24
		for i in 8:
			_ang.append(rng.randf() * 360.0)
			_ph.append(rng.randf())

	func _draw_fx(t: float, f: int) -> void:
		var env: float = minf(t * 5.0, 1.0) * (1.0 - pow(t, 4.0))
		var pulse: float = 0.5 + 0.5 * sin(float(f) * 0.9)
		var hot: Color = SpecialFx.bright(color, 0.6)
		disc(Vector2.ZERO, 5.0 + pulse, with_alpha(color, 0.18 * env))
		disc(Vector2.ZERO, 3.2 + pulse * 0.6, with_alpha(color, 0.3 * env))
		disc(Vector2.ZERO, 1.6, with_alpha(hot, 0.7 * env))
		for i in _ang.size():
			var k: float = fposmod(t * 1.6 + _ph[i], 1.0)
			var p: Vector2 = SpecialFx.dir_deg(_ang[i] + t * 90.0) * lerpf(7.0, 1.0, k)
			disc(p, 0.45 * (1.0 - k * 0.5), with_alpha(hot, env * k))


## Landing-schokgolf op de grond (voet). Params: `reach` (units, 10).
class Shockwave extends SpecialFx:
	func _on_fx_setup() -> void:
		duration = 16
		at_feet = true

	func _draw_fx(t: float, _f: int) -> void:
		var reach: float = GenericSpecialFx._pf(params, "reach", 10.0)
		var fade: float = 1.0 - t
		var e: float = ease_out3(t)
		var hot: Color = SpecialFx.bright(color, 0.7)
		# platte ellips: y gecomprimeerd t.o.v. de x
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(Units.UNIT_TO_PX * size_mult, Units.UNIT_TO_PX * size_mult * 0.3))
		disc(Vector2.ZERO, reach * e, with_alpha(color, 0.18 * fade))
		draw_ring(Vector2.ZERO, reach * e, 1.1 * fade + 0.2, with_alpha(hot, fade))
		draw_ring(Vector2.ZERO, reach * e * 0.65, 0.7 * fade, with_alpha(color, fade * 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (Units.UNIT_TO_PX * size_mult))
		for s in [-1.0, 1.0]:
			draw_line(Vector2(s * reach * e * 0.5, -0.3), Vector2(s * reach * e, -0.3 - 1.2 * fade), with_alpha(hot, fade), 0.3)


## Counter geraakt: witte flits + ring + kruisster. Straal ~8 units; standaard goudgeel.
class CounterFlash extends SpecialFx:
	func _on_fx_setup() -> void:
		duration = 14
		if not params.has("color"):
			color = Color(1.0, 0.9, 0.4)

	func _draw_fx(t: float, _f: int) -> void:
		var fade: float = 1.0 - t
		if t < 0.3:
			disc(Vector2.ZERO, 6.0 * (1.0 - t * 2.0), with_alpha(Color.WHITE, 0.85))
		draw_ring(Vector2.ZERO, 1.5 + 6.5 * ease_out3(t), 0.9 * fade + 0.1, with_alpha(color, fade))
		var s: float = 8.0 * ease_out3(minf(t * 2.5, 1.0)) * (1.0 - t * 0.4)
		draw_star(Vector2.ZERO, 4, s, 0.9, PI * 0.25, with_alpha(SpecialFx.bright(color, 0.6), fade))


## Reflector: glanzende bel + schuine glans die erlangs veegt. Straal ~6 units; standaard lichtblauw.
class ReflectShine extends SpecialFx:
	func _on_fx_setup() -> void:
		duration = 16
		if not params.has("color"):
			color = Color(0.55, 0.85, 1.0)

	func _draw_fx(t: float, _f: int) -> void:
		var fade: float = 1.0 - t * t
		var r: float = 5.0 + 1.2 * ease_out(t)
		disc(Vector2.ZERO, r, with_alpha(color, 0.18 * fade))
		draw_ring(Vector2.ZERO, r, 0.5, with_alpha(SpecialFx.bright(color, 0.5), fade))
		var x: float = lerpf(-r, r, clampf(t * 1.4, 0.0, 1.0))
		var half: float = sqrt(maxf(r * r - x * x, 0.0))
		draw_line(Vector2(x - half * 0.3, half * 0.7), Vector2(x + half * 0.3, -half * 0.7), with_alpha(Color.WHITE, fade), 0.9)
		draw_star(Vector2(x, 0.0), 4, 1.8 * fade, 0.3, 0.0, with_alpha(Color.WHITE, fade))


## Teleport: ring klapt in, dan rookpoef + glinsters. Straal ~7 units; standaard paarsblauw.
class TeleportPoof extends SpecialFx:
	var _puff := PackedVector2Array()
	var _tw := PackedVector2Array()

	func _on_fx_setup() -> void:
		duration = 22
		if not params.has("color"):
			color = Color(0.6, 0.5, 1.0)
		for i in 6:
			_puff.append(SpecialFx.dir_deg(rng.randf() * 360.0) * rng.randf_range(1.0, 3.5))
		for i in 5:
			_tw.append(SpecialFx.dir_deg(rng.randf() * 360.0) * rng.randf_range(2.0, 6.5))

	func _draw_fx(t: float, f: int) -> void:
		var fade: float = 1.0 - t
		if t < 0.45:
			var k: float = t / 0.45
			draw_ring(Vector2.ZERO, 7.0 * (1.0 - ease_out(k)) + 0.5, 0.8, with_alpha(SpecialFx.bright(color, 0.5), 1.0 - k * 0.5))
		var u: float = clampf((t - 0.3) / 0.7, 0.0, 1.0)
		for p in _puff:
			disc(p * (0.5 + ease_out(u)), 1.2 + 1.6 * u, with_alpha(color.lerp(Color(0.85, 0.85, 0.9), 0.5), (1.0 - u) * 0.7))
		for i in _tw.size():
			var tw: float = sin((float(f) + float(i) * 2.0) * 0.8) * 0.5 + 0.5
			draw_star(_tw[i], 4, 1.1 * tw * fade, 0.2, 0.0, with_alpha(Color.WHITE, fade))


## Stofschop bij de voeten, tegen de kijkrichting in (remmen/afzetten/fietsen). Puffs ~1-2.5 units. Params: `count` (5), `tint`.
class DustKick extends SpecialFx:
	var _pos := PackedVector2Array()
	var _vel := PackedVector2Array()
	var _r := PackedFloat32Array()

	func _on_fx_setup() -> void:
		duration = 20
		at_feet = true
		var n: int = clampi(int(params.get("count", 5)), 1, 12)
		for i in n:
			var back: float = -float(facing)
			_pos.append(Vector2(back * rng.randf_range(0.0, 3.0), -0.6))
			_vel.append(Vector2(back * rng.randf_range(0.2, 0.7), rng.randf_range(-0.25, -0.05)))
			_r.append(rng.randf_range(0.8, 1.4))

	func _draw_fx(t: float, _f: int) -> void:
		var tint: Color = params.get("tint", Color(0.86, 0.84, 0.8))
		var a: float = (1.0 - t) * 0.85
		for i in _pos.size():
			var p: Vector2 = _pos[i] + _vel[i] * (ease_out(t) * float(duration) * 0.6)
			var r: float = _r[i] * (1.0 + 1.2 * ease_out(t))
			disc(p, r, with_alpha(tint.darkened(0.12), a * 0.6))
			disc(p + Vector2(0, -r * 0.12), r * 0.82, with_alpha(tint, a))
