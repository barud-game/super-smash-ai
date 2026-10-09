extends SceneTree
## Puur geometrische/physica-test: raakt een short-hop-aerial een staande tegenstander? (afspraak 8)
## Per archetype wordt de short-hop-boog gesimuleerd met de stats-formules (eerste luchtframe zonder gravity, zoals
## FighterStats.jump_height); hitbox-posities komen uit de archetype-moves, hurtboxes uit HurtboxData.default_for_height
## (zelfde als Fighter.hurtboxes() in de stand "stand"). Geen fighter-code gewijzigd of gebruikt.
## Run: Godot --headless --path . --script res://tests/test_aerial_reach.gd
## Argument `-- --table` print de hoogte van de aanvaller en de afstand per geval.

const ARCHETYPES: Array[String] = ["allrounder", "fast_faller", "floaty", "heavyweight", "lightweight"]

var _fails: int = 0
var _total: int = 0
var _verbose: bool = false


func _initialize() -> void:
	_verbose = "--table" in OS.get_cmdline_user_args()
	var victims: Dictionary = {}
	for a in ARCHETYPES:
		victims[a] = _stats(a).visual_height
	for a in ARCHETYPES:
		_test_archetype(a, victims)
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _stats(a: String) -> FighterStats:
	return load("res://engine/fighter/archetypes/%s.tres" % a) as FighterStats


func _move(a: String, m: String) -> MoveData:
	return load("res://engine/fighter/archetypes/%s/moves/%s.tres" % [a, m]) as MoveData


## Hoogte van de voeten per luchtframe n (n = 0: eerste frame in de lucht) van een short hop.
## `ff_from` >= 0: vanaf dat frame fast fall (vy = -fast_fall_velocity), anders gewoon gravity.
func _heights(s: FighterStats, ff_from: int = -1) -> Array[float]:
	var ys: Array[float] = []
	var y: float = 0.0
	var v: float = s.hop_v_initial_velocity
	for n in 120:
		ys.append(y)
		y += v
		if ff_from >= 0 and n >= ff_from:
			v = -s.fast_fall_velocity
		else:
			v = maxf(v - s.gravity, -s.terminal_velocity)
		if y < 0.0 and n > 0:
			break
	return ys


func _apex_frame(s: FighterStats) -> int:
	var ys: Array[float] = _heights(s)
	var best: int = 0
	for i in ys.size():
		if ys[i] > ys[best]:
			best = i
	return best


## Raakt een cirkel (c, r) een staande hurtbox (hoogte vh) waarvan de as op x = vx staat?
func _hits(c: Vector2, r: float, vx: float, vh: float) -> bool:
	for hb in HurtboxData.default_for_height(vh):
		if HitResolver.circle_hits_capsule(c, r, hb.a + Vector2(vx, 0), hb.b + Vector2(vx, 0), hb.radius):
			return true
	return false


## Raakt de move (aanvaller kijkt naar +x, aanvaller-x = 0) een staande tegenstander op `victim_x`,
## als de aerial wordt ingevoerd op luchtframe `t0` met hoogtes `ys`?
func _move_hits(m: MoveData, ys: Array[float], t0: int, victim_x: float, vh: float) -> bool:
	for hb in m.hitboxes:
		for f in range(hb.start_frame, hb.end_frame + 1):
			var n: int = t0 + f
			if n >= ys.size():
				break
			if _hits(Vector2(hb.offset.x, ys[n] + hb.offset.y), hb.radius, victim_x, vh):
				return true
	return false


## Voorste/achterste box (grootste |x|) = waar de tegenstander "op de punt" staat; hij staat op de x van die box.
func _tip_x(m: MoveData, back: bool) -> float:
	var best: float = 0.0
	for hb in m.hitboxes:
		if (hb.offset.x < 0.0) == back and absf(hb.offset.x) > absf(best):
			best = hb.offset.x
	return best


## Aantal invoer-frames t0 (luchtframe, 1 .. landing) waarop de move raakt; de active frames moeten vóór de landing vallen.
func _hit_window(m: MoveData, ys: Array[float], apex: int, victim_x: float, vh: float) -> int:
	var count: int = 0
	for t0 in range(1, ys.size()):
		if _move_hits(m, ys, t0, victim_x, vh):
			count += 1
	return count


func _test_archetype(a: String, victims: Dictionary) -> void:
	var s: FighterStats = _stats(a)
	var apex: int = _apex_frame(s)
	var ys: Array[float] = _heights(s)
	# Fast fall: een omlaag-flick direct na de top (past_apex in Fighter.apply_air_vertical).
	var ys_ff: Array[float] = _heights(s, apex)
	if _verbose:
		print("%s: apex frame %d, hoogte %.1f (visual_height %.1f)" % [a, apex, ys[apex], s.visual_height])
	_check("%s: short hop eindigt op de grond" % a, ys.size() < 120)
	for v in ARCHETYPES:
		var vh: float = victims[v]
		for mv in ["nair", "fair", "bair"]:
			var m: MoveData = _move(a, mv)
			var x: float = _tip_x(m, mv == "bair")
			var label: String = "%s %s -> staande %s" % [a, mv, v]
			var w: int = _hit_window(m, ys, apex, x, vh)
			if _verbose:
				print("  %s: raakt bij %d van %d invoer-frames (punt x=%.1f)" % [label, w, ys.size() - 1, x])
			# Meer dan een toevalstreffer: minstens 3 opeenvolgende-ish invoerframes (of 1/4 van de opgaande boog).
			_check("%s: SH-%s raakt (%d invoer-frames, punt op %.1f)" % [label, mv, w, x],
					w >= 3)
			if mv == "fair":
				var wf: int = _hit_window(m, ys_ff, apex, x, vh)
				_check("%s: fast-fall SH-fair raakt (%d invoer-frames)" % [label, wf], wf >= 1)
		var dair: MoveData = _move(a, "dair")
		var wd: int = _hit_window(dair, ys, apex, 0.0, vh)
		_check("%s dair -> staande %s: SH-dair raakt (%d invoer-frames)" % [a, v, wd], wd >= 3)
	# Hoogte-afspraak zelf: onderste box van elke nair/fair/bair onder de heup.
	for mv in ["nair", "fair", "bair"]:
		var m2: MoveData = _move(a, mv)
		var lowest: float = INF
		for hb in m2.hitboxes:
			lowest = minf(lowest, hb.offset.y)
		_check("%s %s: onderste box (y=%.1f) onder de heup (<= 35%% van %.1f)" % [a, mv, lowest, s.visual_height],
				lowest <= 0.35 * s.visual_height)
	# Vroege invoer (luchtframe 2, "SH-aerial meteen"): raakt een staande tegenstander van het eigen archetype
	# en (behalve de zware, hoge sprong) de allrounder. Aerials met startup > 8 zijn hierop uitgezonderd.
	for mv in ["nair", "fair", "bair"]:
		var me: MoveData = _move(a, mv)
		if me.hitboxes.is_empty() or me.hitboxes[0].start_frame > 8:
			continue
		for v in ([a] if a == "heavyweight" else [a, "allrounder"]):
			_check("%s %s -> staande %s: vroege SH-aerial (invoer op luchtframe 2) raakt" % [a, mv, v],
					_move_hits(me, ys, 2, _tip_x(me, mv == "bair"), victims[v]))
