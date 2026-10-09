extends KoEffect
## KO-effect van Sonny Daylight: een felle zonsopgang-flits aan de rand, een halve zon die de stage in
## komt, goudkleurige zonnestralen, en rondvliegende knoflookblaadjes (papierachtig crème met een paarse
## waas en een dun aderlijntje). Het "ba-dum-tss"-drumritme is als drie ringen-stoten vertaald: "ba" en
## "dum" zijn zachte golven, "tss" is een korte scherpe stoot met een sterretje. Puur visueel.

const RAY_COUNT: int = 12
const PETAL_COUNT: int = 22
## Beat-frames van "ba", "dum" en "tss".
const BEAT_FRAMES: Array[int] = [0, 9, 18]
const BEAT_LEN: int = 14

var _rays: Array[Dictionary] = []
var _petals: Array[Dictionary] = []


func _on_ko_setup() -> void:
	duration = 78
	var gold: Color = primary()
	var purple: Color = secondary()
	for i in RAY_COUNT:
		_rays.append({
			"ang": rng.randf_range(-1.15, 1.15),
			"len": rng.randf_range(190.0, 330.0),
			"hw": rng.randf_range(7.0, 13.0),
			"col": gold if i % 2 == 0 else gold.lerp(Color.WHITE, 0.5),
		})
	for i in PETAL_COUNT:
		var base: Color = Color(0.96, 0.94, 0.88).lerp(purple, rng.randf_range(0.05, 0.22))
		_petals.append({
			"dir": dir.rotated(rng.randf_range(-1.3, 1.3)),
			"travel": rng.randf_range(150.0, 300.0),
			"len": rng.randf_range(14.0, 22.0),
			"w": rng.randf_range(6.0, 9.5),
			"phase": rng.randf() * TAU,
			"tumble": rng.randf_range(0.18, 0.34),
			"wobble": rng.randf_range(0.2, 0.35),
			"delay": rng.randi_range(0, 10),
			"col": base,
			"col_b": base.lerp(Color.WHITE, 0.35),
		})


func _draw_ko(t: float, f: int) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * VfxConst.KO_SCALE)
	var fade: float = pow(1.0 - t, 1.3)
	var gold: Color = primary()
	var purple: Color = secondary()
	var sun_grow: float = ease_out(clampf(float(f) / 10.0, 0.0, 1.0))
	var beat: float = _beat_envelope(f)

	# zonsopkomst: de zon schuift van de rand de stage in en groeit
	var sun_c: Vector2 = dir * (-14.0 + 70.0 * ease_out(t))
	var sun_r: float = (80.0 + 30.0 * sun_grow) * (1.0 - t * t * 0.5) * (1.0 + 0.08 * beat)

	# 1) paarse gloed rond de zon (de nacht die wijkt)
	disc(sun_c, sun_r * 2.6, with_alpha(purple, 0.22 * fade))

	# 2) gouden zonnestralen die uit de zon waaieren
	for ray: Dictionary in _rays:
		var rd: Vector2 = dir.rotated(float(ray["ang"]))
		var rlen: float = float(ray["len"]) * ease_out3(clampf(float(f) / 12.0, 0.0, 1.0)) * (1.0 - t * 0.4)
		var rcol: Color = ray["col"]
		draw_spike(sun_c, rd, rlen, float(ray["hw"]) * (1.0 - t * 0.5), with_alpha(rcol, 0.85 * fade))

	# 3) de zon zelf: buitenrand, kern, en witte hitte die op de beats oplicht
	disc(sun_c, sun_r * 1.2, with_alpha(gold, 0.45 * fade))
	disc(sun_c, sun_r, with_alpha(gold, fade))
	disc(sun_c, sun_r * 0.6, with_alpha(gold.lerp(Color.WHITE, 0.5 + 0.5 * beat), fade))

	# 4) zonsopgang-flits: witte flits bij het begin, krimpt snel
	var flash: float = clampf(float(f) / 7.0, 0.0, 1.0)
	disc(Vector2.ZERO, 300.0 * ease_out3(flash) * (1.0 - t), with_alpha(gold.lerp(Color.WHITE, 0.4), 0.2 * (1.0 - flash) * fade))
	disc(Vector2.ZERO, 120.0 * (1.0 - ease_out(flash)), with_alpha(Color.WHITE, 1.0 - flash))

	# 5) drumritme "ba-dum-tss": ringen-stoten; "tss" is korter en scherper
	for k in BEAT_FRAMES.size():
		var e: int = f - BEAT_FRAMES[k]
		if e < 0 or e >= BEAT_LEN:
			continue
		var bt: float = float(e) / float(BEAT_LEN)
		var is_tss: bool = k == BEAT_FRAMES.size() - 1
		var radius: float = (60.0 if is_tss else 40.0) + (250.0 if is_tss else 190.0) * ease_out3(bt)
		var width: float = (12.0 if is_tss else 7.0) * (1.0 - bt) + 2.0
		var col: Color = Color.WHITE.lerp(gold, 0.3 if is_tss else 0.6)
		draw_ring(Vector2.ZERO, radius, width, with_alpha(col, (1.0 - bt) * fade))
	# de "tss": een korte scherpe sterstoot in de zon
	var tss_e: int = f - BEAT_FRAMES[BEAT_FRAMES.size() - 1]
	if tss_e >= 0 and tss_e < 7:
		var sk: float = float(tss_e) / 7.0
		draw_star(sun_c, 6, 110.0 * (1.0 - sk) + 20.0, 16.0 * (1.0 - sk), 0.0, with_alpha(Color.WHITE, 0.9 * (1.0 - sk)))

	# 6) knoflookblaadjes die de stage in vliegen en wiebelen
	for p: Dictionary in _petals:
		var e2: int = f - int(p["delay"])
		if e2 < 0:
			continue
		var pdir: Vector2 = p["dir"]
		var pperp := Vector2(-pdir.y, pdir.x)
		var ph: float = float(p["phase"])
		var travel: float = float(p["travel"]) * ease_out(clampf(float(e2) / 40.0, 0.0, 1.0))
		var wob: float = sin(float(e2) * float(p["wobble"]) + ph) * 7.0
		var pos: Vector2 = pdir * travel + pperp * wob
		var ang: float = atan2(pdir.y, pdir.x) + sin(float(e2) * 0.12 + ph) * 0.8
		var tumble: float = 0.35 + 0.65 * absf(cos(float(e2) * float(p["tumble"]) + ph))
		var pw: float = float(p["w"]) * tumble
		var plen: float = float(p["len"]) * ease_out3(clampf(float(e2) / 4.0, 0.0, 1.0))
		var pcol: Color = p["col"]
		_petal(pos, ang, plen, pw, with_alpha(pcol, fade), with_alpha(p["col_b"], fade))


## Ritme-envelop: piek op elke beat, zacht uitdovend. Geeft 0..1.
func _beat_envelope(f: int) -> float:
	var best: float = 0.0
	for bf in BEAT_FRAMES:
		var e: int = f - bf
		if e >= 0 and e < 6:
			best = maxf(best, 1.0 - float(e) / 6.0)
	return best


## Knoflookblaadje: lensvormige schil (twee bogen die bij de punten samenkomen) met een dunne ader.
## `col` is de schil, `col_b` de ader-tint.
func _petal(c: Vector2, ang: float, length: float, width: float, col: Color, col_b: Color) -> void:
	if length < 1.0 or width < 0.6:
		return
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	const STEPS: int = 8
	var outline := PackedVector2Array()
	# eerst de ene boog van punt A naar punt B...
	for i in range(STEPS + 1):
		var u: float = float(i) / float(STEPS)
		var half: float = width * 0.5 * pow(maxf(sin(PI * u), 0.0), 0.8)
		outline.append(c + d * ((u - 0.5) * length) + n * half)
	# ...dan de andere boog terug van B naar A
	for i in range(STEPS, -1, -1):
		var u: float = float(i) / float(STEPS)
		var half: float = width * 0.5 * pow(maxf(sin(PI * u), 0.0), 0.8)
		outline.append(c + d * ((u - 0.5) * length) - n * half)
	draw_colored_polygon(outline, col)
	# dunne ader langs het midden
	draw_line(c - d * (length * 0.36), c + d * (length * 0.36), with_alpha(col_b, col.a * 0.7), 1.0)
