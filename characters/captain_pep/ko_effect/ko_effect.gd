extends KoEffect
## KO-effect van Captain Pep: een uitbarsting van glitterpoeder in paars, gifgroen en spelerskleur,
## rondtollende twee-kleurige cartoon-capsules, een paar sterretjes, een zachte poederwolk en een korte
## witte "pling"-flits aan het begin. Puur visueel; geen gameplay, geen audio, geen tekst of merken.

const GLITTER_COUNT: int = 70
const PILL_COUNT: int = 14
const STAR_COUNT: int = 6
const CLOUD_COUNT: int = 9

var _glitter: Array[Dictionary] = []
var _pills: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _cloud: Array[Dictionary] = []


func _on_ko_setup() -> void:
	duration = 80
	var palette: Array[Color] = [primary(), secondary(), player_color]
	for i in GLITTER_COUNT:
		_glitter.append({
			"dir": dir.rotated(rng.randf_range(-1.25, 1.25)),
			"speed": rng.randf_range(6.0, 16.0),
			"size": rng.randf_range(2.5, 5.0),
			"col": palette[rng.randi_range(0, 2)].lerp(Color.WHITE, rng.randf_range(0.0, 0.35)),
			"delay": rng.randi_range(0, 5),
			"phase": rng.randf() * TAU,
			"glint": i % 4 == 0,
		})
	for i in PILL_COUNT:
		var ia: int = rng.randi_range(0, 2)
		var ib: int = (ia + rng.randi_range(1, 2)) % 3
		_pills.append({
			"dir": dir.rotated(rng.randf_range(-1.0, 1.0)),
			"speed": rng.randf_range(5.0, 11.0),
			"len": rng.randf_range(22.0, 32.0),
			"w": rng.randf_range(11.0, 14.0),
			"ang0": rng.randf() * TAU,
			"spin": rng.randf_range(-0.35, 0.35),
			"ca": palette[ia],
			"cb": palette[ib],
			"delay": rng.randi_range(0, 4),
		})
	for i in STAR_COUNT:
		var star_col: Color = Color.WHITE if i % 2 == 0 else secondary()
		_stars.append({
			"pos": dir.rotated(rng.randf_range(-1.0, 1.0)) * rng.randf_range(90.0, 230.0),
			"size": rng.randf_range(14.0, 24.0),
			"rot": rng.randf() * TAU,
			"spin": rng.randf_range(-0.12, 0.12),
			"life": rng.randi_range(26, 36),
			"delay": rng.randi_range(3, 18),
			"col": star_col,
		})
	for i in CLOUD_COUNT:
		_cloud.append({
			"dir": dir.rotated(rng.randf_range(-1.1, 1.1)),
			"speed": rng.randf_range(2.0, 5.0),
			"r": rng.randf_range(18.0, 40.0),
		})


func _draw_ko(t: float, f: int) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * VfxConst.KO_SCALE)
	var fade: float = pow(1.0 - t, 1.3)
	var pc: Color = player_color
	var purple: Color = primary()

	# 1) poederwolk: zachte paarse wolk die de stage in drijft
	for c: Dictionary in _cloud:
		var cdir: Vector2 = c["dir"]
		var cp: Vector2 = cdir * float(c["speed"]) * float(f) * 0.8
		var cr: float = float(c["r"]) * (0.5 + ease_out(t))
		disc(cp, cr, with_alpha(purple.lightened(0.15), 0.22 * fade))

	# 2) bloom-ringen: de "pling" bij het begin en een tweede golf
	for k in 2:
		var tt: float = clampf(t * 1.6 - float(k) * 0.2, 0.0, 1.0)
		if tt > 0.0 and tt < 1.0:
			draw_ring(Vector2.ZERO, 40.0 + 300.0 * ease_out3(tt), 12.0 * (1.0 - tt) + 2.0, with_alpha(pc.lerp(Color.WHITE, 0.3), 1.0 - tt))

	# 3) glitterpoeder: stuifdeeltjes die uitwaaieren, twinkelen en licht zakken
	for g: Dictionary in _glitter:
		var e: int = f - int(g["delay"])
		if e < 0:
			continue
		var gd: Vector2 = g["dir"]
		var p: Vector2 = gd * float(g["speed"]) * float(e) * (1.0 - float(e) * 0.01) * 0.9 + Vector2(0.0, float(e * e) * 0.006)
		var tw: float = 0.55 + 0.45 * sin(float(f) * 0.6 + float(g["phase"]))
		var a: float = fade * tw
		var gc: Color = g["col"]
		var sz: float = float(g["size"]) * (1.0 - t * 0.5)
		disc(p, sz, with_alpha(gc, a))
		if bool(g["glint"]) and tw > 0.85:
			draw_star(p, 4, sz * 2.4, sz * 0.5, 0.0, with_alpha(Color.WHITE, a))

	# 4) rondtollende cartoon-capsules, twee kleuren
	for pl: Dictionary in _pills:
		var e2: int = f - int(pl["delay"])
		if e2 < 0:
			continue
		var pd: Vector2 = pl["dir"]
		var pos: Vector2 = pd * float(pl["speed"]) * float(e2) * (1.0 - float(e2) * 0.009) * 1.2 + Vector2(0.0, float(e2 * e2) * 0.008)
		var ang: float = float(pl["ang0"]) + float(pl["spin"]) * float(e2)
		var grow: float = ease_out3(minf(float(e2) / 4.0, 1.0)) * (1.0 - t * t)
		var ca: Color = pl["ca"]
		var cb: Color = pl["cb"]
		_capsule(pos, ang, float(pl["len"]) * grow, float(pl["w"]) * grow, with_alpha(ca, fade), with_alpha(cb, fade))

	# 5) sterretjes die openpoppen en wegzakken
	for st: Dictionary in _stars:
		var e3: int = f - int(st["delay"])
		if e3 < 0:
			continue
		var k3: float = float(e3) / float(st["life"])
		if k3 >= 1.0:
			continue
		var sz3: float = float(st["size"]) * sin(PI * k3)
		if sz3 < 0.5:
			continue
		var sp: Vector2 = st["pos"]
		var sc: Color = st["col"]
		draw_star(sp, 4, sz3, sz3 * 0.28, float(st["rot"]) + float(st["spin"]) * float(e3), with_alpha(sc, fade))

	# 6) witte flits bij het begin, krimpt snel
	var flash: float = clampf(float(f) / 9.0, 0.0, 1.0)
	var core: float = 115.0 * (1.0 - ease_out(flash))
	disc(Vector2.ZERO, core * 1.6, with_alpha(pc, 0.35 * fade))
	disc(Vector2.ZERO, core, with_alpha(Color.WHITE, 1.0 - flash))
	if core > 6.0:
		draw_star(Vector2.ZERO, 4, core * 1.5, core * 0.2, 0.0, with_alpha(Color.WHITE, 0.9 * (1.0 - flash)))


## Cartoon-capsule: rechthoek met ronde uiteinden, de ene helft in `col_a`, de andere in `col_b`.
func _capsule(c: Vector2, ang: float, length: float, width: float, col_a: Color, col_b: Color) -> void:
	if width < 0.5 or length < width:
		return
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var r: float = width * 0.5
	var h: float = maxf(length * 0.5 - r, 0.0)
	var a_end: Vector2 = c - d * h
	var b_end: Vector2 = c + d * h
	draw_colored_polygon(PackedVector2Array([a_end + n * r, c + n * r, c - n * r, a_end - n * r]), col_a)
	disc(a_end, r, col_a)
	draw_colored_polygon(PackedVector2Array([c + n * r, b_end + n * r, b_end - n * r, c - n * r]), col_b)
	disc(b_end, r, col_b)
