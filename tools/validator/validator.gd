extends RefCounted
## Validator-kern: beoordeelt MoveData tegen de scores en het budget. Zie docs/validator.md.
## Puur (geen SceneTree nodig); validate.gd is de CLI eromheen.

const CT := preload("res://tools/validator/conversion_table.gd")
const SV := preload("res://tools/validator/special_validator.gd")

const ARCHETYPES_DIR := "res://engine/fighter/archetypes"
const CHARACTERS_DIR := "res://characters"
## 0-based MoveData-frame -> 1-based frame uit move-conversie.md (startup = start_frame + FRAME_BASE).
const FRAME_BASE := 1

const ARCHETYPE_ALIASES := {
	"allrounder": "allrounder",
	"fast_faller": "fast_faller", "fastfaller": "fast_faller",
	"floaty": "floaty",
	"heavyweight": "heavyweight", "zwaargewicht": "heavyweight",
	"lightweight": "lightweight", "lichtgewicht": "lightweight",
}

var arch_root: String = ARCHETYPES_DIR
var char_root: String = CHARACTERS_DIR


# ---------------------------------------------------------------- helpers

static func _hint(table: Array, measured: float, tol: float) -> String:
	var hits: PackedStringArray = []
	for i in table.size():
		if absf(float(table[i]) - measured) <= tol:
			hits.append(str(i))
	return "" if hits.is_empty() else " (past bij score %s)" % ",".join(hits)


## Voegt een check toe. `table` = waarden per score (index = score). Fout als |measured - table[score]| > tol.
static func _cmp(res: Dictionary, label: String, measured: float, table: Array, score: int,
		tol: float = 0.0, level: String = "fail", axis: String = "") -> void:
	var expected: float = float(table[score])
	res["measured"][label] = measured
	if absf(measured - expected) <= tol:
		return
	var msg := "%s %s, verwacht %s voor %s=%d%s" % [label, _fmt(measured), _fmt(expected), axis, score,
			_hint(table, measured, tol)]
	_add(res, level, msg)


static func _add(res: Dictionary, level: String, msg: String) -> void:
	if level == "fail":
		res["fails"].append(msg)
	else:
		res["warns"].append(msg)


static func _fmt(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%.2f" % v


static func _new_result(scope: String, move: String, scores: Dictionary) -> Dictionary:
	return {"scope": scope, "move": move, "scores": scores, "measured": {}, "fails": [], "warns": [], "status": "PASS"}


static func _finish(res: Dictionary) -> Dictionary:
	res["status"] = "FAIL" if not res["fails"].is_empty() else ("WARN" if not res["warns"].is_empty() else "PASS")
	return res


static func _score(scores: Dictionary, axis: String) -> int:
	return int(scores.get(axis, 0))


## Hit-blokken: hitboxen met overlappende/aansluitende intervallen (gap <= BLOCK_MAX_GAP) vormen één blok.
## Geeft (start, end) (0-based) van het eerste blok.
static func _first_block(hbs: Array) -> Vector2i:
	var iv: Array = []
	for h in hbs:
		iv.append([h.start_frame, h.end_frame])
	iv.sort_custom(func(a, b): return a[0] < b[0])
	var s: int = iv[0][0]
	var e: int = iv[0][1]
	for i in range(1, iv.size()):
		if iv[i][0] - e - 1 <= CT.BLOCK_MAX_GAP:
			e = maxi(e, iv[i][1])
		else:
			break
	return Vector2i(s, e)


## Hoofd-hitbox: in de laatste hit-groep (multi-hit: kracht geldt voor de laatste hit) de hoogste damage.
static func _main_box(hbs: Array) -> HitboxData:
	var last_group: int = -999999
	for h in hbs:
		last_group = maxi(last_group, h.group)
	var best: HitboxData = null
	for h in hbs:
		if h.group != last_group:
			continue
		if best == null or h.damage > best.damage or (h.damage == best.damage and h.id < best.id):
			best = h
	return best


## Late hit: de hitbox die op de laatste actieve frame nog actief is (laagste damage bij meerdere).
static func _late_box(hbs: Array, last_active0: int) -> HitboxData:
	var best: HitboxData = null
	for h in hbs:
		if h.end_frame != last_active0:
			continue
		if best == null or h.damage < best.damage:
			best = h
	return best


## Reach in referentie-units: positie langs de as gedeeld door `scale` (= visual_height / 15), plus radius (niet geschaald).
static func _reach(move: String, hbs: Array, scale: float = 1.0) -> float:
	var dir: String = CT.REACH_DIR.get(move, "fwd")
	var best: float = -INF
	for h in hbs:
		var v: float
		match dir:
			"fwd": v = h.offset.x / scale + h.radius
			"back": v = -h.offset.x / scale + h.radius
			"side": v = absf(h.offset.x) / scale + h.radius
			"up": v = h.offset.y / scale + h.radius
			_: v = -h.offset.y / scale + h.radius
		best = maxf(best, v)
	return best


## Offset van de verste hitbox (grab-tip) van een grab-MoveData; null als er geen hitbox is.
static func grab_tip(grab: MoveData) -> Variant:
	if grab == null or grab.hitboxes.is_empty():
		return null
	var best: HitboxData = grab.hitboxes[0]
	for h in grab.hitboxes:
		if h.offset.x > best.offset.x:
			best = h
	return best.offset


static func _angle_ok(move: String, angle: float) -> bool:
	for r in CT.ANGLES.get(move, [[0, 360]]):
		if angle >= r[0] - 0.01 and angle <= r[1] + 0.01:
			return true
	return false


# ---------------------------------------------------------------- score-controles

## Controleert de scores zelf: assen aanwezig, binnen 0..5, geen alles-0, geen S/K/B/V alle 5.
static func check_scores(res: Dictionary, move: String, scores: Dictionary) -> void:
	var axes: Array = CT.axes_for(move)
	var all_zero := true
	var all_five := true
	for a in axes:
		if not scores.has(a):
			_add(res, "fail", "score %s ontbreekt" % a)
			continue
		var v: int = int(scores[a])
		if v < 0 or v > CT.SCORE_MAX:
			_add(res, "fail", "score %s=%d buiten 0..%d" % [a, v, CT.SCORE_MAX])
		if v != 0:
			all_zero = false
		if v != CT.SCORE_MAX:
			all_five = false
	if all_zero:
		_add(res, "fail", "alle assen 0 (balans.md: geen move met alles 0)")
	if all_five and axes.size() == 4:
		_add(res, "fail", "S/K/B/V allemaal 5 (balans.md: verboden)")


# ---------------------------------------------------------------- move-validatie

## Valideert één MoveData van type `move` (jab, fair, ...) tegen `scores` ({"S":..,"K":..,"B":..,"V":..}).
## `visual_height` = lengte van het character (afspraak 9: posities schalen met visual_height / 15, radius niet).
## `grab` = de grab-MoveData van hetzelfde character (voor de throw-hitbox-positie op de grab-tip); mag null zijn.
func validate_move(scope: String, move: String, md: MoveData, scores: Dictionary,
		visual_height: float = CT.REFERENCE_HEIGHT, grab: MoveData = null) -> Dictionary:
	var res := _new_result(scope, move, scores)
	var scale: float = maxf(visual_height, 0.001) / CT.REFERENCE_HEIGHT
	check_scores(res, move, scores)
	if md == null:
		_add(res, "fail", "MoveData kon niet geladen worden")
		return _finish(res)
	_sanity(res, move, md)
	var hbs: Array = md.hitboxes
	if hbs.is_empty():
		return _finish(res)
	var sn: int = clampi(_score(scores, "S"), 0, 5)
	var kr: int = clampi(_score(scores, "K"), 0, 5)
	var be: int = clampi(_score(scores, "B"), 0, 5)
	var ve: int = clampi(_score(scores, "V"), 0, 5)
	var group: String = CT.group_of(move)
	var main: HitboxData = _main_box(hbs)
	var blk: Vector2i = _first_block(hbs)
	var last_active: int = md.last_active_frame() + FRAME_BASE  # 1-based
	var first_active: int = 1 << 20
	for h in hbs:
		first_active = mini(first_active, h.start_frame + FRAME_BASE)
	res["measured"]["startup"] = first_active
	res["measured"]["last_active"] = last_active

	if CT.is_throw(move):
		_validate_throw(res, move, md, main, sn, kr, scores, grab, scale)
		_check_back_angles(res, move, hbs)
		return _finish(res)

	if scores.has("S") and CT.STARTUP.has(move):
		_cmp(res, "startup", first_active, CT.STARTUP[move], sn, 0.0, "fail", "S")
	if scores.has("B"):
		var rmax: float = 0.0
		for h in hbs:
			rmax = maxf(rmax, h.radius)
		_cmp(res, "radius", rmax, CT.RADIUS, be, CT.RADIUS_TOL, "fail", "B")
		if CT.REACH.has(move):
			_cmp(res, "reach", _reach(move, hbs, scale), CT.REACH[move], be, CT.REACH_TOL, "fail", "B")
		if CT.ACTIVE.has(move):
			_cmp(res, "active", blk.y - blk.x + 1, CT.ACTIVE[move], be, 0.0, "fail", "B")
		var disjoint_any := false
		for h in hbs:
			disjoint_any = disjoint_any or h.disjoint
		if be >= CT.DISJOINT_MIN_BE and not disjoint_any and move != "grab":
			_add(res, "warn", "B=%d verwacht disjoint hitbox (geen hitbox met disjoint=true)" % be)
		if be < CT.DISJOINT_MIN_BE and disjoint_any:
			_add(res, "warn", "B=%d verwacht geen disjoint hitbox" % be)

	_check_height(res, move, hbs, visual_height)
	if move == "grab":
		_validate_grab(res, main, md, last_active)
		return _finish(res)

	if move in CT.AROUND_MOVES:
		_check_around(res, move, hbs)
	if scores.has("K"):
		_check_power(res, move, group, main, hbs, kr)
	_check_multi_hit(res, move, main, hbs)
	var back_warned := _check_back_angles(res, move, hbs)
	if not back_warned and not _angle_ok(move, main.angle):
		_add(res, "warn", "angle %s niet in standaard/variant (move-conversie §6)" % _fmt(main.angle))
	if scores.has("V"):
		if CT.is_aerial(move):
			_validate_aerial(res, md, blk, last_active, ve)
		else:
			_validate_ground_safety(res, move, md, hbs, last_active, ve)
	return _finish(res)


func _check_power(res: Dictionary, move: String, group: String, main: HitboxData, hbs: Array, kr: int) -> void:
	_cmp(res, "damage", main.damage, CT.DAMAGE[group], kr, 0.001, "fail", "K")
	_cmp(res, "BKB", main.base_kb, CT.BKB[group], kr, 0.001, "fail", "K")
	_cmp(res, "KBG", main.kb_growth, CT.KBG[group], kr, 0.001, "fail", "K")
	if main.set_kb > 0.0:
		_add(res, "warn", "set_kb gebruikt; conversietabel gaat uit van gewone knockback")
	var ceil_v: int = CT.TILT_CEILING if move in ["ftilt", "utilt", "dtilt", "dash_attack"] else int(CT.DAMAGE_CEILING[group])
	for h in hbs:
		if h.damage > ceil_v + 0.001:
			_add(res, "fail", "hitbox %d damage %s boven plafond %d" % [h.id, _fmt(h.damage), ceil_v])
	# Sourspots/late hits (afspraak 5 en 7): damage x0,7 (afronden), BKB -10 (min 0), KBG gelijk, per hit-groep
	# t.o.v. de sterkste box van die groep. Zelfde positie + later in de tijd = "sterk begin, zwak einde" (sex kick).
	var tops := {}
	for h in hbs:
		var t: HitboxData = tops.get(h.group, null)
		if t == null or h.damage > t.damage or (h.damage == t.damage and h.id < t.id):
			tops[h.group] = h
	for h in hbs:
		var top: HitboxData = tops[h.group]
		if h == top:
			continue
		var late_sib: bool = h.start_frame > top.start_frame and h.offset.is_equal_approx(top.offset) 				and is_equal_approx(h.radius, top.radius)
		if not late_sib and absf(h.damage - top.damage) < 0.001 and absf(h.base_kb - top.base_kb) < 0.001:
			continue
		var sd: float = roundf(top.damage * CT.SOURSPOT_DAMAGE_MULT)
		var sb: float = maxf(0.0, top.base_kb - CT.SOURSPOT_BKB_MINUS)
		if absf(h.damage - sd) > 0.5 or absf(h.base_kb - sb) > 0.5 or absf(h.kb_growth - top.kb_growth) > 0.5:
			var kind := "sex-kick late blok" if late_sib else "sourspot"
			_add(res, "warn", "%s hitbox %d: %s/%s/%s, verwacht %s/%s/%s (d/b/g, afspraak 5)" % [kind, h.id,
					_fmt(h.damage), _fmt(h.base_kb), _fmt(h.kb_growth), _fmt(sd), _fmt(sb), _fmt(top.kb_growth)])


## Afspraak 6: multi-hit. Alle groepen voor de laatste zijn kleine hits (d 1-2, BKB <= 10, hoek 361 of naar de
## finisher toe: gelijk aan de hoek van de finisher, of 270-290 bij een drill-dair).
func _check_multi_hit(res: Dictionary, move: String, main: HitboxData, hbs: Array) -> void:
	var last_group: int = main.group
	var multi := false
	for h in hbs:
		if h.group != last_group:
			multi = true
	if not multi:
		return
	for h in hbs:
		if h.group >= last_group:
			continue
		var bad: PackedStringArray = []
		if h.damage < CT.MULTI_DAMAGE_MIN - 0.001 or h.damage > CT.MULTI_DAMAGE_MAX + 0.001:
			bad.append("damage %s (verwacht %d-%d)" % [_fmt(h.damage), int(CT.MULTI_DAMAGE_MIN), int(CT.MULTI_DAMAGE_MAX)])
		if h.base_kb > CT.MULTI_BKB_MAX + 0.001:
			bad.append("BKB %s (verwacht <= %d)" % [_fmt(h.base_kb), int(CT.MULTI_BKB_MAX)])
		var ang_ok: bool = is_equal_approx(h.angle, CT.SAKURAI) or is_equal_approx(h.angle, main.angle) \
				or (move == "dair" and h.angle >= 270.0 and h.angle <= 290.0)
		if not ang_ok:
			bad.append("angle %s (verwacht 361 of richting de finisher)" % _fmt(h.angle))
		if not bad.is_empty():
			_add(res, "warn", "multi-hit hitbox %d (groep %d): %s (afspraak 6)" % [h.id, h.group, ", ".join(bad)])


## Afspraak 1: een hitbox die achter de fighter zit (of een bthrow) moet naar achteren lanceren: hoek > 90.
## 361 geldt als vooruit (relatief aan de kijkrichting). Geeft true als er een WARN is gegeven.
func _check_back_angles(res: Dictionary, move: String, hbs: Array) -> bool:
	var warned := false
	for h in hbs:
		var is_back: bool = h.offset.x < -0.001 or move == "bthrow"
		if move == "grab" or CT.is_throw(move) and move != "bthrow":
			is_back = false
		if not is_back:
			continue
		if h.angle <= CT.BACK_ANGLE_MIN or h.angle >= 360.0:
			_add(res, "warn", "achterwaartse hitbox %d (%s) heeft angle %s; achterwaarts lanceren = > 90 (afspraak 1)" % [
					h.id, move, _fmt(h.angle)])
			warned = true
	return warned


## Afspraak 10: rondom-moves hebben minimaal een box voor (x > 0) en een achter (x < 0).
func _check_around(res: Dictionary, move: String, hbs: Array) -> void:
	var front := false
	var back := false
	for h in hbs:
		front = front or h.offset.x > 0.001
		back = back or h.offset.x < -0.001
	if not (front and back):
		_add(res, "fail", "%s is een rondom-move maar heeft %s (afspraak 10)" % [move,
				"geen box achter" if front else ("geen box voor" if back else "geen box voor en achter")])


## Afspraak 8: hoogtes (WARN). Horizontale grondmoves ~55% van visual_height, dtilt/dsmash op y = 2.
## Aerials nair/fair/bair: elke box op 15-40% van visual_height, de onderste box hooguit 35% (onder de heup).
func _check_height(res: Dictionary, move: String, hbs: Array, vh: float) -> void:
	if move in ["nair", "fair", "bair"]:
		var lowest: float = INF
		for h in hbs:
			var frac: float = h.offset.y / maxf(vh, 0.001)
			lowest = minf(lowest, frac)
			if frac < CT.HEIGHT_AERIAL_MIN or frac > CT.HEIGHT_AERIAL_MAX:
				_add(res, "warn", "hitbox %d y=%s (%d%% van visual_height %s), verwacht %d-%d%% (afspraak 8)" % [h.id,
						_fmt(h.offset.y), roundi(frac * 100.0), _fmt(vh), roundi(CT.HEIGHT_AERIAL_MIN * 100.0),
						roundi(CT.HEIGHT_AERIAL_MAX * 100.0)])
				return
		if lowest > CT.HEIGHT_AERIAL_LOWEST_MAX:
			_add(res, "warn", "onderste box y=%s (%d%% van visual_height %s), moet onder de heup zitten: <= %d%% (afspraak 8)" % [
					_fmt(lowest * vh), roundi(lowest * 100.0), _fmt(vh), roundi(CT.HEIGHT_AERIAL_LOWEST_MAX * 100.0)])
		return
	var target: float = -1.0
	var tol: float = vh * CT.HEIGHT_TOL
	if move in ["jab", "ftilt", "dash_attack", "fsmash", "grab"]:
		target = vh * CT.HEIGHT_HORIZONTAL
	elif move in ["dtilt", "dsmash"]:
		target = CT.HEIGHT_LOW
		tol = CT.HEIGHT_LOW_TOL
	if target < 0.0:
		return
	for h in hbs:
		if absf(h.offset.y - target) > tol:
			_add(res, "warn", "hitbox %d y=%s, verwacht ~%s voor visual_height %s (afspraak 8)" % [h.id, _fmt(h.offset.y),
					_fmt(target), _fmt(vh)])
			return


func _validate_ground_safety(res: Dictionary, move: String, md: MoveData, hbs: Array, last_active: int, ve: int) -> void:
	var fam: String = CT.ADV_FAMILY.get(move, "")
	if fam == "":
		return
	var late: HitboxData = _late_box(hbs, last_active - FRAME_BASE)
	var endlag: int = md.iasa_frame() - last_active
	var adv: int = CT.shieldstun(late.damage) - endlag
	res["measured"]["endlag"] = endlag
	res["measured"]["shield_adv"] = adv
	var table: Array = CT.ADV_TARGET[fam]
	if absi(adv - int(table[ve])) > CT.ADV_TOL:
		_add(res, "fail", "shield-advantage %d (endlag %d, late d %s), verwacht %d ±%d voor V=%d%s" % [adv, endlag,
				_fmt(late.damage), int(table[ve]), CT.ADV_TOL, ve, _hint(table, adv, CT.ADV_TOL)])


func _validate_aerial(res: Dictionary, md: MoveData, blk: Vector2i, last_active: int, ve: int) -> void:
	_cmp(res, "landing_lag", md.landing_lag, CT.LANDING_LAG, ve, 0.0, "fail", "V")
	_cmp(res, "lcancel_lag", md.lcancel_lag, CT.LCANCEL_LAG, ve, 0.0, "fail", "V")
	_cmp(res, "air_endlag", md.total_frames - last_active, CT.AIR_ENDLAG, ve, CT.AIR_ENDLAG_TOL, "fail", "V")
	if md.lcancel_lag != md.landing_lag / 2:
		_add(res, "fail", "lcancel_lag %d != floor(landing_lag/2) = %d" % [md.lcancel_lag, md.landing_lag / 2])
	# Auto-cancel (⚠️): niet tijdens de hitbox-frames.
	if md.autocancel_before > blk.x:
		_add(res, "fail", "autocancel_before %d ligt na eerste actieve frame %d" % [md.autocancel_before, blk.x])
	if md.autocancel_after >= 0 and md.autocancel_after < md.last_active_frame():
		_add(res, "fail", "autocancel_after %d ligt voor laatste actieve frame %d" % [md.autocancel_after, md.last_active_frame()])
	if md.autocancel_after < 0 and md.autocancel_before < 0:
		_add(res, "warn", "geen auto-cancel ingesteld (verwacht < start en > last_active+%d)" % CT.AUTOCANCEL_AFTER_OFFSET)


## Grab (afspraak 2): geen damage, ignores_shield, en whiff-duur = laatste actieve frame (1-based) + 23.
func _validate_grab(res: Dictionary, main: HitboxData, md: MoveData, last_active: int) -> void:
	if main.damage != 0.0:
		_add(res, "fail", "grab-hitbox damage %s, verwacht 0" % _fmt(main.damage))
	if main.base_kb != CT.GRAB_BKB or main.kb_growth != CT.GRAB_KBG:
		_add(res, "warn", "grab BKB/KBG %s/%s, verwacht %d/%d" % [_fmt(main.base_kb), _fmt(main.kb_growth), CT.GRAB_BKB, CT.GRAB_KBG])
	if not main.ignores_shield:
		_add(res, "fail", "grab-hitbox moet ignores_shield=true hebben")
	var want: int = last_active + CT.GRAB_WHIFF_AFTER
	res["measured"]["whiff_total"] = md.total_frames
	if md.total_frames != want:
		_add(res, "fail", "grab-whiff total %d, verwacht %d (laatste actieve frame %d + %d, afspraak 2)" % [
				md.total_frames, want, last_active, CT.GRAB_WHIFF_AFTER])


## Worp (afspraken 1 en 3): duur uit S, kracht uit K, launch-frame round(total*0,5), launch-hitbox radius 3.0 op de
## grab-tip (positie geschaald met `scale`; alleen gecontroleerd als de grab bekend is).
func _validate_throw(res: Dictionary, move: String, md: MoveData, main: HitboxData, sn: int, kr: int, scores: Dictionary,
		grab: MoveData, scale: float) -> void:
	if scores.has("S"):
		_cmp(res, "total", md.total_frames, CT.THROW_TOTAL, sn, 0.0, "fail", "S")
	if scores.has("K"):
		_check_power(res, move, "throw", main, md.hitboxes, kr)
	var launch: int = int(roundf(md.total_frames * CT.THROW_LAUNCH_FRACTION))
	var got: int = main.start_frame + FRAME_BASE
	res["measured"]["launch_frame"] = got
	if got != launch:
		_add(res, "warn", "worp-lanceerframe %d, verwacht round(total*0,5) = %d" % [got, launch])
	if absf(main.radius - CT.THROW_RADIUS) > CT.RADIUS_TOL:
		_add(res, "fail", "worp-hitbox radius %s, verwacht %s (afspraak 3)" % [_fmt(main.radius), _fmt(CT.THROW_RADIUS)])
	var tip: Variant = grab_tip(grab)
	if tip != null and (main.offset - (tip as Vector2)).length() > CT.THROW_POS_TOL:
		_add(res, "warn", "worp-hitbox op (%s, %s), verwacht op de grab-tip (%s, %s) (afspraak 3)" % [
				_fmt(main.offset.x), _fmt(main.offset.y), _fmt((tip as Vector2).x), _fmt((tip as Vector2).y)])
	if move == "bthrow":
		if main.angle <= CT.BACK_ANGLE_MIN or main.angle >= 360.0:
			return  # _check_back_angles meldt dit
	if not _angle_ok(move, main.angle):
		_add(res, "warn", "angle %s niet in standaard/variant (§6)" % _fmt(main.angle))

## Sanity die niet van de scores afhangt.
func _sanity(res: Dictionary, move: String, md: MoveData) -> void:
	if md.total_frames <= 0:
		_add(res, "fail", "total_frames %d <= 0" % md.total_frames)
	elif md.total_frames < CT.MIN_TOTAL_FRAMES:
		_add(res, "fail", "total_frames %d < minimum %d" % [md.total_frames, CT.MIN_TOTAL_FRAMES])
	if md.iasa >= 0 and md.iasa > md.total_frames:
		_add(res, "fail", "iasa %d > total_frames %d" % [md.iasa, md.total_frames])
	if md.landing_lag < 0 or md.lcancel_lag < 0:
		_add(res, "fail", "negatieve landing lag")
	if md.hitboxes.is_empty():
		_add(res, "fail", "geen hitboxen (throws/grab: een throw-/grab-hitbox is verplicht)")
		return
	var ids := {}
	for h in md.hitboxes:
		if h == null:
			_add(res, "fail", "null-hitbox in lijst")
			return
		var lbl := "hitbox %d" % h.id
		if h.start_frame < 0 or h.end_frame < h.start_frame:
			_add(res, "fail", "%s frames %d..%d ongeldig" % [lbl, h.start_frame, h.end_frame])
		if h.end_frame >= md.total_frames:
			_add(res, "fail", "%s eindigt op frame %d, buiten move-duur %d" % [lbl, h.end_frame, md.total_frames])
		if md.iasa >= 0 and h.end_frame >= md.iasa:
			_add(res, "fail", "%s actief tot %d, voorbij iasa %d" % [lbl, h.end_frame, md.iasa])
		if h.damage < 0.0 or h.base_kb < 0.0 or h.kb_growth < 0.0 or h.set_kb < 0.0 or h.shield_damage < 0.0 \
				or h.hitlag_mult < 0.0:
			_add(res, "fail", "%s heeft negatieve waarde (damage/BKB/KBG/set_kb/shield_damage/hitlag)" % lbl)
		if h.radius <= 0.0:
			_add(res, "fail", "%s radius %s <= 0" % [lbl, _fmt(h.radius)])
		if is_nan(h.offset.x) or is_nan(h.offset.y) or is_nan(h.damage) or is_nan(h.radius):
			_add(res, "fail", "%s bevat NaN" % lbl)
		if ids.has(h.id):
			_add(res, "warn", "hitbox-id %d niet uniek" % h.id)
		ids[h.id] = true
		# Facing-onafhankelijk: offsets zijn voor facing = +1 (x wordt gespiegeld door de engine).
		if move == "bair" and h.offset.x > h.radius:
			_add(res, "fail", "%s offset.x %s ligt vóór de fighter bij bair (offsets gelden voor facing=+1)" % [lbl, _fmt(h.offset.x)])
		if move in ["jab", "ftilt", "dtilt", "dash_attack", "fsmash", "fair", "grab"] and h.offset.x < -h.radius:
			_add(res, "fail", "%s offset.x %s ligt achter de fighter (offsets gelden voor facing=+1)" % [lbl, _fmt(h.offset.x)])
	if CT.is_aerial(move):
		if not md.aerial:
			_add(res, "fail", "aerial=false bij aerial")
		if md.grounded:
			_add(res, "warn", "grounded=true bij aerial")
		if md.landing_lag <= 0:
			_add(res, "fail", "aerial heeft geen landing lag")
	else:
		if md.aerial:
			_add(res, "fail", "aerial=true bij grondmove")
		if md.landing_lag != 0 or md.lcancel_lag != 0:
			_add(res, "warn", "landing lag ingesteld bij grondmove")


# ---------------------------------------------------------------- budget

## Kosten van één normal uit zijn scores (throws S+K, grab S+B, rest S+K+B+V).
static func move_cost(move: String, scores: Dictionary) -> int:
	var s := 0
	for a in CT.axes_for(move):
		s += int(scores.get(a, 0))
	return s


static func special_cost(scores: Dictionary) -> int:
	var s := 0
	for a in ["S", "K", "B", "V", "U"]:
		s += int(scores.get(a, 0))
	return s


## Totaal van alle normals in `all_scores` ({move: {S,K,B,V}}).
static func normals_total(all_scores: Dictionary) -> int:
	var t := 0
	for m in CT.NORMAL_MOVES:
		if all_scores.has(m) and all_scores[m] is Dictionary:
			t += move_cost(m, all_scores[m])
	return t


## Lengte-regel (docs/balans.md): kleiner dan het archetype kost HEIGHT_COST_PER_UNIT punten per unit; groter kost niets.
const HEIGHT_COST_PER_UNIT: float = 2.0


static func height_cost(archetype_height_: float, height: float) -> int:
	if height >= archetype_height_:
		return 0
	return roundi((archetype_height_ - height) * HEIGHT_COST_PER_UNIT)


## Movement-extras: waarden zijn punten t.o.v. het budget (extra_jump -15 = kost 15). Kosten = -som.
static func extras_cost(extras: Dictionary) -> int:
	var s := 0
	for k in extras:
		s -= int(extras[k])
	return s


## Budget voor een character: {normals, specials, extras, total, op, status, msg}.
static func character_budget(all_scores: Dictionary, specials: Dictionary, extras: Dictionary, op: bool,
		height_cost: int = 0) -> Dictionary:
	var n := normals_total(all_scores)
	var sp := 0
	for k in specials:
		sp += special_cost(specials[k])
	var ex := extras_cost(extras)
	var total := n + sp + ex + height_cost
	var out := {"normals": n, "specials": sp, "extras": ex, "height": height_cost, "total": total, "op": op, "status": "PASS", "msg": ""}
	var hint := " + lengte %d" % height_cost if height_cost != 0 else ""
	if total > CT.BUDGET:
		if op:
			out["msg"] = "OP: %d punten (> %d), toegestaan (normals %d + specials %d + extras %d%s)" % [total, CT.BUDGET, n, sp, ex, hint]
		else:
			out["status"] = "FAIL"
			out["msg"] = "budget %d > %d (normals %d + specials %d + extras %d%s)" % [total, CT.BUDGET, n, sp, ex, hint]
	else:
		out["msg"] = "budget %d/%d (normals %d + specials %d + extras %d%s)" % [total, CT.BUDGET, n, sp, ex, hint]
	return out


# ---------------------------------------------------------------- bestanden

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


static func _load_move(path: String) -> MoveData:
	var r: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return r as MoveData


static func normalize_archetype(raw: String) -> String:
	var k := raw.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	return ARCHETYPE_ALIASES.get(k, k)


func archetype_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for d in DirAccess.get_directories_at(arch_root):
		ids.append(d)
	for f in DirAccess.get_files_at(arch_root):
		if f.ends_with(".tres"):
			var id := f.get_basename()
			if not ids.has(id):
				ids.append(id)
	ids.sort()
	return ids


func character_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for d in DirAccess.get_directories_at(char_root):
		if not d.begins_with("_"):
			ids.append(d)
	ids.sort()
	return ids


## Valideert alle moves in `<arch_root>/<id>/moves/`. Geeft {scope, results:[], budget:{}}.
func validate_archetype(id: String) -> Dictionary:
	var dir := "%s/%s/moves" % [arch_root, id]
	var scope := "archetype/" + id
	var out := {"scope": scope, "results": [], "budget": {}}
	var scores_all: Variant = _read_json(dir + "/scores.json")
	if not (scores_all is Dictionary):
		var r := _new_result(scope, "(alle moves)", {})
		_add(r, "fail", "scores.json ontbreekt of is ongeldig in %s" % dir)
		out["results"].append(_finish(r))
		return out
	var vh: float = archetype_height(id)
	var grab_md: MoveData = _load_move(dir + "/grab.tres") if ResourceLoader.exists(dir + "/grab.tres") else null
	for m in CT.NORMAL_MOVES:
		out["results"].append(_validate_one(scope, m, "%s/%s.tres" % [dir, m], scores_all.get(m, null), vh, grab_md))
	var n := normals_total(scores_all)
	out["budget"] = {"normals": n, "total": n, "op": false,
			"status": "PASS" if n <= CT.BUDGET else "FAIL", "msg": "normals %d/%d" % [n, CT.BUDGET]}
	return out


## visual_height van een archetype (engine/fighter/archetypes/<id>.tres); 15 als dat ontbreekt.
func archetype_height(id: String) -> float:
	var path := "%s/%s.tres" % [arch_root, id]
	if not ResourceLoader.exists(path):
		return CT.REFERENCE_HEIGHT
	var r: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if r == null:
		return CT.REFERENCE_HEIGHT
	var v: Variant = r.get("visual_height")
	return float(v) if v != null else CT.REFERENCE_HEIGHT


func _validate_one(scope: String, move: String, path: String, scores: Variant,
		vh: float = CT.REFERENCE_HEIGHT, grab: MoveData = null) -> Dictionary:
	if not (scores is Dictionary):
		var r := _new_result(scope, move, {})
		_add(r, "fail", "geen scores voor %s in scores.json" % move)
		return _finish(r)
	if not ResourceLoader.exists(path):
		var r2 := _new_result(scope, move, scores)
		check_scores(r2, move, scores)
		_add(r2, "fail", "move-bestand ontbreekt: %s" % path)
		return _finish(r2)
	return validate_move(scope, move, _load_move(path), scores, vh, grab)


## Valideert een character: eigen moves tegen eigen scores, plus budget over (eigen of archetype-)scores.
func validate_character(id: String) -> Dictionary:
	var base := "%s/%s" % [char_root, id]
	var scope := "character/" + id
	var out := {"scope": scope, "results": [], "budget": {}}
	var info: Variant = _read_json(base + "/character.json")
	var cs: Variant = _read_json(base + "/scores.json")
	if not (info is Dictionary):
		var r := _new_result(scope, "(character.json)", {})
		_add(r, "fail", "character.json ontbreekt of is ongeldig")
		out["results"].append(_finish(r))
		return out
	if not (cs is Dictionary):
		var r2 := _new_result(scope, "(scores.json)", {})
		_add(r2, "fail", "scores.json ontbreekt of is ongeldig")
		out["results"].append(_finish(r2))
		return out
	var arch := normalize_archetype(str(info.get("archetype", "")))
	var arch_scores: Variant = _read_json("%s/%s/moves/scores.json" % [arch_root, arch])
	if not (arch_scores is Dictionary):
		var r3 := _new_result(scope, "(archetype)", {})
		_add(r3, "fail", "archetype '%s' heeft geen scores.json" % arch)
		out["results"].append(_finish(r3))
		return out
	var vh: float = archetype_height(arch)
	if info.has("visual_height"):
		vh = float(info["visual_height"])
	var grab_path := "%s/moves/grab.tres" % base
	if not ResourceLoader.exists(grab_path):
		grab_path = "%s/%s/moves/grab.tres" % [arch_root, arch]
	var grab_md: MoveData = _load_move(grab_path) if ResourceLoader.exists(grab_path) else null
	var merged := {}
	for m in CT.NORMAL_MOVES:
		var own_path := "%s/moves/%s.tres" % [base, m]
		var own_scores: Variant = cs.get(m, null)
		if ResourceLoader.exists(own_path):
			out["results"].append(_validate_one(scope, m, own_path, own_scores, vh, grab_md))
			merged[m] = own_scores if own_scores is Dictionary else arch_scores.get(m, {})
		elif own_scores is Dictionary:
			var r4 := _new_result(scope, m, own_scores)
			_add(r4, "fail", "scores.json overschrijft %s maar moves/%s.tres ontbreekt" % [m, m])
			out["results"].append(_finish(r4))
			merged[m] = own_scores
		elif arch_scores.has(m):
			merged[m] = arch_scores[m]
	var specials: Dictionary = {}
	var sp: Variant = cs.get("specials", {})
	if sp is Dictionary:
		specials = sp
	for k in specials:
		var r5 := _new_result(scope, "special/" + str(k), specials[k])
		_check_special(r5, str(k), specials[k])
		out["results"].append(_finish(r5))
	_validate_special_defs(out, scope, base, specials)
	var extras: Dictionary = {}
	var ex: Variant = cs.get("movement_extras", {})
	if ex is Dictionary:
		extras = ex
	var hcost: int = height_cost(archetype_height(arch), vh)
	_validate_character_fields(out, scope, base, info, cs, vh, arch)
	out["budget"] = character_budget(merged, specials, extras, bool(cs.get("op", info.get("op", false))), hcost)
	return out


static func _check_special(res: Dictionary, name: String, s: Dictionary) -> void:
	if not (name in CT.SPECIAL_MOVES):
		_add(res, "fail", "onbekende special '%s' (verwacht %s)" % [name, ", ".join(CT.SPECIAL_MOVES)])
	var all_zero := true
	var all_five := true
	for a in ["S", "K", "B", "V"]:
		if not s.has(a):
			_add(res, "fail", "score %s ontbreekt" % a)
			continue
		var v := int(s[a])
		if v < 0 or v > CT.SCORE_MAX:
			_add(res, "fail", "score %s=%d buiten 0..%d" % [a, v, CT.SCORE_MAX])
		if v != 0:
			all_zero = false
		if v != CT.SCORE_MAX:
			all_five = false
	var u := int(s.get("U", 0))
	if u < 0 or u > CT.UTILITY_MAX:
		_add(res, "fail", "score U=%d buiten 0..%d" % [u, CT.UTILITY_MAX])
	if u != 0:
		all_zero = false
	if all_zero:
		_add(res, "fail", "alle assen 0")
	if all_five:
		_add(res, "fail", "S/K/B/V allemaal 5")


## Special-definities (`characters/<id>/specials/<slot>.tres`): special_validator.gd, plus: scores in de .tres en in
## scores.json (`<slot>_b`) gelijk (WARN), en minstens één recovery (WARN). Zie docs/specials.md.
func _validate_special_defs(out: Dictionary, scope: String, base: String, json_specials: Dictionary) -> void:
	var sv: RefCounted = SV.new()
	var defs: Dictionary = {}
	for slot: String in SpecialDef.SLOTS:
		var path := "%s/specials/%s.tres" % [base, slot]
		if not ResourceLoader.exists(path):
			continue
		var r: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (r is SpecialDef):
			var bad := _new_result(scope, "special_def/" + slot, {})
			_add(bad, "fail", "%s is geen SpecialDef" % path)
			out["results"].append(_finish(bad))
			continue
		var d: SpecialDef = r
		defs[slot] = d
		var res: Dictionary = sv.validate_def(scope, d)
		for ev in d.prop_events:
			_check_prop_event(res, base, ev)
		var js: Variant = json_specials.get(slot + "_b")
		if js is Dictionary:
			for a in ["S", "K", "B", "V", "U"]:
				if int(js.get(a, -1)) != int(d.scores.get(a, -1)):
					_add(res, "warn", "score %s in scores.json (%d) != %s.tres (%d)" % [a, int(js.get(a, -1)), slot,
						int(d.scores.get(a, -1))])
		out["results"].append(_finish(res))
	if not defs.is_empty():
		var w: String = SV.recovery_warning(defs)
		if w != "":
			var rr := _new_result(scope, "special_def/(recovery)", {})
			_add(rr, "warn", w)
			out["results"].append(_finish(rr))


## Velden van de character-pipeline (docs/character-creatie.md): visual_height, taunt, taunt-props, movement_extras, stats.tres.
## Eén resultaat per onderwerp onder `character_fields/<naam>`.
func _validate_character_fields(out: Dictionary, scope: String, base: String, info: Dictionary, cs: Dictionary,
		vh: float, arch: String) -> void:
	# visual_height
	var rh := _new_result(scope, "character_fields/visual_height", {})
	if info.has("visual_height"):
		var raw := float(info["visual_height"])
		if raw < FighterStats.VISUAL_HEIGHT_MIN or raw > FighterStats.VISUAL_HEIGHT_MAX:
			_add(rh, "fail", "visual_height %s buiten %.0f-%.0f" % [_fmt(raw), FighterStats.VISUAL_HEIGHT_MIN,
				FighterStats.VISUAL_HEIGHT_MAX])
		else:
			var ah := archetype_height(arch)
			var hc := height_cost(ah, raw)
			if hc > 0:
				_add(rh, "warn", "lengte %s < archetype %s: kost %d punten (-%d per unit)" % [_fmt(raw), _fmt(ah), hc,
					int(HEIGHT_COST_PER_UNIT)])
	out["results"].append(_finish(rh))
	# taunt
	var rt := _new_result(scope, "character_fields/taunt", {})
	var text := str(info.get("taunt_text", ""))
	if text == "":
		_add(rt, "warn", "taunt_text ontbreekt (geen tekstwolkje)")
	elif text.length() > 28:
		_add(rt, "warn", "taunt_text is %d tekens; langer dan 28 past slecht in het wolkje" % text.length())
	if info.has("taunt_frames"):
		var tf := int(info["taunt_frames"])
		if tf < FighterConst.TAUNT_FRAMES_MIN or tf > FighterConst.TAUNT_FRAMES_MAX:
			_add(rt, "fail", "taunt_frames %d buiten %d-%d" % [tf, FighterConst.TAUNT_FRAMES_MIN, FighterConst.TAUNT_FRAMES_MAX])
	var tprops: Variant = info.get("taunt_props", [])
	if tprops is Array:
		for ev: Variant in tprops:
			_check_prop_event(rt, base, ev)
	else:
		_add(rt, "fail", "taunt_props moet een lijst zijn")
	out["results"].append(_finish(rt))
	# movement_extras en stats.tres
	var rx := _new_result(scope, "character_fields/movement", {})
	var extras: Variant = cs.get("movement_extras", {})
	if extras is Dictionary:
		for k in extras:
			if CharacterLoader.canonical_extra(str(k)) == "":
				_add(rx, "warn", "onbekende movement_extra '%s' (bekend: %s)" % [k, ", ".join(CharacterLoader.EXTRAS.keys())])
	var stats_path := base + "/stats.tres"
	if ResourceLoader.exists(stats_path):
		var sr: Resource = ResourceLoader.load(stats_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (sr is FighterStats):
			_add(rx, "fail", "stats.tres is geen FighterStats")
		else:
			_add(rx, "warn", "stats.tres overschrijft preset, visual_height en movement_extras volledig")
			var sh: float = (sr as FighterStats).visual_height
			if sh < FighterStats.VISUAL_HEIGHT_MIN or sh > FighterStats.VISUAL_HEIGHT_MAX:
				_add(rx, "fail", "stats.tres visual_height %s buiten %.0f-%.0f" % [_fmt(sh), FighterStats.VISUAL_HEIGHT_MIN,
					FighterStats.VISUAL_HEIGHT_MAX])
	out["results"].append(_finish(rx))


## Eén prop-event (taunt of special): formaat via PropEvent.problems, plus bestaat art/props/<prop>.svg.
func _check_prop_event(res: Dictionary, base: String, ev: Variant) -> void:
	for p in PropEvent.problems(ev):
		_add(res, "fail", p)
	if ev is Dictionary and str((ev as Dictionary).get("prop", "")) != "":
		var path := "%s/art/props/%s.svg" % [base, str((ev as Dictionary)["prop"])]
		if not FileAccess.file_exists(path):
			_add(res, "fail", "prop-bestand ontbreekt: %s" % path)
