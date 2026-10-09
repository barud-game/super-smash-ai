class_name DustEffect
extends VfxEffect
## Stofwolkjes voor landen, springen en dashen. Puffs vliegen uit elkaar, worden groter en vervagen.

enum Kind { LAND, JUMP, DASH }

var kind: int = Kind.LAND
var _puffs: Array[Dictionary] = []   # {pos, vel, r0, r1, life}
var tint: Color = Color(0.86, 0.84, 0.8)


## `facing`: +1 rechts / -1 links (alleen DASH: stof blijft achter, dus tegengesteld).
func setup(pos_px: Vector2, p_kind: int, heavy: bool = false, facing: int = 1) -> void:
	position = pos_px
	kind = p_kind
	z_index = -1
	match kind:
		Kind.LAND:
			var n: int = 8 if heavy else 4
			duration = 24 if heavy else 16
			for i in n:
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var sp: float = rng.randf_range(1.2, 3.2) * (1.5 if heavy else 1.0)
				_add(Vector2(side * rng.randf_range(2.0, 12.0), -3.0), Vector2(side * sp, rng.randf_range(-0.6, -0.1)),
					rng.randf_range(5.0, 9.0) * (1.4 if heavy else 1.0), rng.randf_range(13.0, 22.0) * (1.4 if heavy else 1.0))
		Kind.JUMP:
			duration = 16
			for i in 4:
				var side2: float = -1.0 if i % 2 == 0 else 1.0
				_add(Vector2(side2 * rng.randf_range(2.0, 8.0), -3.0), Vector2(side2 * rng.randf_range(0.8, 2.0), rng.randf_range(-0.4, 0.0)),
					rng.randf_range(4.0, 7.0), rng.randf_range(10.0, 16.0))
		Kind.DASH:
			duration = 16
			var back: float = -float(facing)
			for i in 3:
				_add(Vector2(back * rng.randf_range(0.0, 14.0), -3.0 - rng.randf_range(0.0, 3.0)), Vector2(back * rng.randf_range(0.8, 2.2), rng.randf_range(-0.7, -0.2)),
					rng.randf_range(4.0, 7.0), rng.randf_range(11.0, 17.0))


func _add(p: Vector2, v: Vector2, r0: float, r1: float) -> void:
	_puffs.append({"pos": p, "vel": v, "r0": r0, "r1": r1})


func _draw() -> void:
	var t: float = progress()
	for pf: Dictionary in _puffs:
		var drag: float = 1.0 - pow(1.0 - t, 2.0)   # snelle start, dan uitrollen
		var p: Vector2 = pf["pos"] + pf["vel"] * (drag * float(duration) * 0.55)
		var r: float = lerpf(pf["r0"], pf["r1"], ease_out(t))
		var a: float = (1.0 - t) * 0.85
		disc(p, r, with_alpha(tint.darkened(0.12), a * 0.6))
		disc(p + Vector2(0, -r * 0.12), r * 0.82, with_alpha(tint, a))
