extends SceneTree
## Tests M3-integratie: aanvallen in de fighter, hitlag, knockback, hitstun, DI, crouch cancel, tech,
## L-cancel, auto-cancel, hitfall, één hit per move-instantie, determinisme.
## Headless, gescripte input (eigen InputHistory per fighter), sandbox-stub, CombatSystem zelf gestept.
##   Godot_console.exe --headless --path . --script res://tests/test_fighter_combat.gd
## Exit code 0 = alles geslaagd, 1 = minstens één FAIL.

const A: int = InputFrame.BTN_ATTACK
const JUMP: int = InputFrame.BTN_JUMP
const SHIELD: int = InputFrame.BTN_SHIELD
const Z: int = InputFrame.BTN_Z

var _fails: int = 0
var _total: int = 0
var stage: SandboxStage
var combat := CombatSystem.new()


func _initialize() -> void:
	MeleeStick.fast_fall_while_rising = false
	_test_moveset_loading()
	_test_input_mapping()
	_test_air_mapping()
	_test_jc_usmash()
	_test_jab_combo()
	_test_smash_charge()
	_test_landing_lag_lcancel()
	_test_hit_basics()
	_test_tumble_vs_flinch()
	_test_di()
	_test_crouch_cancel()
	_test_tech()
	_test_hitfall()
	_test_one_hit_per_instance()
	_test_ledge_and_getup_attack()
	_test_directions()
	_test_determinism()
	if stage != null:
		stage.free()
	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func check(name: String, cond: bool, detail: String = "") -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, ("   (" + detail + ")") if detail != "" else "")


func near(a: float, b: float, tol: float = 0.001) -> bool:
	return absf(a - b) <= tol


# --- harnas ------------------------------------------------------------------------------------

func new_stage() -> SandboxStage:
	if stage != null:
		stage.free()
	stage = SandboxStage.new()
	return stage


func make(at: Vector2, dir: int, id: String = "allrounder", player: int = 0) -> Fighter:
	var f := Fighter.new()
	f.use_visual = false
	f.auto_register = false
	f.player = player
	f.stats = Archetypes.load_stats(id)
	f.stage = stage
	f.input = InputHistory.new()
	f.tap_jump_override = 1
	f.pos = at
	f.facing = dir
	f.setup()
	return f


func fr(sx: int = 0, sy: int = 0, buttons: int = 0, cx: int = 0, cy: int = 0) -> InputFrame:
	var i := InputFrame.new()
	i.stick = Vector2i(sx, sy)
	i.cstick = Vector2i(cx, cy)
	i.buttons = buttons
	return i


## Eén sim-frame voor alle fighters (inputs per fighter, null = neutraal) + combat-stap.
func tick(fs: Array, inputs: Array = []) -> void:
	for i in fs.size():
		var inp: InputFrame = inputs[i] if i < inputs.size() and inputs[i] != null else InputFrame.new()
		(fs[i] as Fighter).input.push(inp)
	for f: Fighter in fs:
		f.sim_tick(0)
	combat.step(fs)


func idle(fs: Array, n: int) -> void:
	for i in n:
		tick(fs)


func free_all(fs: Array) -> void:
	for f: Fighter in fs:
		f.free()


## MoveData met één hitbox (frames 0-based).
func move(n: String, total: int, start: int, end: int, offset: Vector2, radius: float, damage: float,
		angle: float = 361.0, bkb: float = 10.0, kbg: float = 100.0, aerial: bool = false) -> MoveData:
	var m := MoveData.new()
	m.move_name = n
	m.total_frames = total
	m.aerial = aerial
	m.grounded = not aerial
	m.hitboxes = [MoveSet.make_hitbox(0, start, end, offset, radius, damage, angle, bkb, kbg)]
	return m


## Fighter in Wait met een verse neutrale geschiedenis.
func settle(fs: Array) -> void:
	idle(fs, 3)


# --- tests -------------------------------------------------------------------------------------

func _test_moveset_loading() -> void:
	print("== moveset laden")
	new_stage()
	var names: Array[String] = ["jab", "ftilt", "utilt", "dtilt", "dash_attack", "fsmash", "usmash", "dsmash",
		"nair", "fair", "bair", "uair", "dair"]
	for id: String in Archetypes.IDS:
		var f: Fighter = make(Vector2(0, 0), 1, id)
		var ok: bool = true
		for n in names:
			if not f.has_move(n):
				ok = false
		check("%s: archetype-id afgeleid uit stats" % id, f.resolved_archetype() == id, f.resolved_archetype())
		check("%s: alle normals geladen" % id, ok)
		check("%s: ingebouwde ledge/getup attack" % id, f.has_move("ledge_attack") and f.has_move("getup_attack"))
		f.free()
	var g: Fighter = make(Vector2(0, 0), 1)
	g.stats = FighterStats.new()
	g.character_id = "_bestaat_niet"
	check("onbekend: valt terug op allrounder", g.resolved_archetype() == "allrounder")
	g.archetype_id = "floaty"
	check("expliciet archetype_id wint", g.resolved_archetype() == "floaty")
	g.free()


func _attack_after(f: Fighter, inputs: Array) -> String:
	settle([f])
	for i: InputFrame in inputs:
		tick([f], [i])
	return f.state.debug_name() if f.state_name() in ["Attack", "AttackAir"] else f.state_name()


func _move_of(f: Fighter) -> String:
	return String(f.state.get("move_name")) if f.state_name() in ["Attack", "AttackAir"] else f.state_name()


func _test_input_mapping() -> void:
	print("== input -> grondaanval")
	new_stage()
	var cases: Array = [
		["A neutraal = jab", [fr(0, 0, A)], "jab", 1],
		["A + tilt vooruit = ftilt", [fr(40, 0, A)], "ftilt", 1],
		["A + tilt achteruit = ftilt omgedraaid", [fr(-40, 0, A)], "ftilt", -1],
		["A + tilt omhoog = utilt", [fr(0, 40, A)], "utilt", 1],
		["A + tilt omlaag = dtilt", [fr(0, -40, A)], "dtilt", 1],
		["flick vooruit + A = fsmash", [fr(80, 0, A)], "fsmash", 1],
		["flick achteruit + A = fsmash omgedraaid", [fr(-80, 0, A)], "fsmash", -1],
		["flick omhoog + A = usmash", [fr(0, 80, A)], "usmash", 1],
		["flick omlaag + A = dsmash", [fr(0, -80, A)], "dsmash", 1],
		["flick in 3 frames + A = fsmash (Xbox-venster)", [fr(30, 0), fr(60, 0), fr(80, 0, A)], "fsmash", 1],
		["langzaam vooruit (6 fr) + A = ftilt", [fr(30, 0), fr(40, 0), fr(50, 0), fr(60, 0), fr(70, 0), fr(80, 0), fr(80, 0, A)], "ftilt", 1],
		["C-stick vooruit = fsmash", [fr(0, 0, 0, 80, 0)], "fsmash", 1],
		["C-stick achteruit = fsmash omgedraaid", [fr(0, 0, 0, -80, 0)], "fsmash", -1],
		["C-stick omhoog = usmash", [fr(0, 0, 0, 0, 80)], "usmash", 1],
		["C-stick omlaag = dsmash", [fr(0, 0, 0, 0, -80)], "dsmash", 1],
	]
	for c: Array in cases:
		var f: Fighter = make(Vector2(0, 0), 1)
		settle([f])
		for i: InputFrame in c[1]:
			tick([f], [i])
			if f.state_name() == "Attack":
				break
		check(c[0], _move_of(f) == c[2] and f.facing == c[3], "%s facing %d" % [_move_of(f), f.facing])
		f.free()
	# Dash attack uit Dash en Run.
	var d: Fighter = make(Vector2(-40, 0), 1)
	settle([d])
	tick([d], [fr(80, 0)])
	check("flick = Dash", d.state_name() == "Dash")
	tick([d], [fr(80, 0, A)])
	check("Dash + A = dash_attack", _move_of(d) == "dash_attack")
	d.free()
	var r: Fighter = make(Vector2(-60, 0), 1)
	settle([r])
	for i in 30:
		tick([r], [fr(80, 0)])
	check("rennen", r.state_name() == "Run")
	tick([r], [fr(80, 0, A)])
	check("Run + A = dash_attack", _move_of(r) == "dash_attack")
	r.free()
	# Z = grab (M4); shield + A = grab uit shield, nooit een jab (details in tests/test_defense.gd).
	var z: Fighter = make(Vector2(0, 0), 1)
	settle([z])
	tick([z], [fr(0, 0, Z)])
	check("Z = grab (M4)", z.state_name() == "Grab")
	z.free()
	var sa: Fighter = make(Vector2(0, 0), 1)
	settle([sa])
	tick([sa], [fr(0, 0, SHIELD)])
	tick([sa], [fr(0, 0, SHIELD | A)])
	check("shield + A = grab (M4), geen jab", sa.state_name() == "Grab")
	sa.free()
	# Jab vanuit crouch-houding: stick omlaag + A = dtilt.
	var s: Fighter = make(Vector2(0, 0), 1)
	settle([s])
	for i in 10:
		tick([s], [fr(0, -70)])
	check("hurken", s.state_name() == "SquatWait")
	tick([s], [fr(0, -70, A)])
	check("SquatWait + A = dtilt", _move_of(s) == "dtilt")
	s.free()


func _airborne(f: Fighter) -> void:
	settle([f])
	tick([f], [fr(0, 0, JUMP)])
	for i in 8:
		tick([f], [fr(0, 0, JUMP)])
	check("in de lucht (%s)" % f.state_name(), not f.grounded)


func _test_air_mapping() -> void:
	print("== input -> aerial")
	new_stage()
	var cases: Array = [
		["A neutraal = nair", fr(0, 0, A), "nair"],
		["A + vooruit = fair", fr(50, 0, A), "fair"],
		["A + achteruit = bair", fr(-50, 0, A), "bair"],
		["A + omhoog = uair", fr(0, 50, A), "uair"],
		["A + omlaag = dair", fr(0, -50, A), "dair"],
		["C-stick vooruit = fair", fr(0, 0, 0, 80, 0), "fair"],
		["C-stick achteruit = bair", fr(0, 0, 0, -80, 0), "bair"],
		["C-stick omhoog = uair", fr(0, 0, 0, 0, 80), "uair"],
		["C-stick omlaag = dair", fr(0, 0, 0, 0, -80), "dair"],
	]
	for c: Array in cases:
		var f: Fighter = make(Vector2(0, 0), 1)
		_airborne(f)
		tick([f], [c[1]])
		check(c[0], f.state_name() == "AttackAir" and _move_of(f) == c[2], _move_of(f))
		f.free()


func _test_jc_usmash() -> void:
	print("== jump-cancel usmash")
	new_stage()
	var f: Fighter = make(Vector2(0, 0), 1)
	settle([f])
	tick([f], [fr(0, 80)])   # tap jump
	check("tap jump -> KneeBend", f.state_name() == "KneeBend")
	tick([f], [fr(0, 80, A)])
	check("KneeBend + A + omhoog = usmash op de grond", _move_of(f) == "usmash" and f.grounded)
	f.free()
	var g: Fighter = make(Vector2(0, 0), 1)
	settle([g])
	tick([g], [fr(0, 0, JUMP)])
	tick([g], [fr(0, 0, JUMP, 0, 80)])
	check("KneeBend + C-stick omhoog = usmash", _move_of(g) == "usmash")
	g.free()


func _test_jab_combo() -> void:
	print("== jab-combo")
	new_stage()
	var j1: MoveData = move("jab", 20, 2, 3, Vector2(8, 8), 3, 3)
	var j2: MoveData = move("jab2", 22, 2, 4, Vector2(8, 8), 3, 3)
	var f: Fighter = make(Vector2(0, 0), 1)
	f.moves["jab"] = j1
	f.moves["jab2"] = j2
	settle([f])
	tick([f], [fr(0, 0, A)])
	var inst: int = f.move_instance
	tick([f])
	tick([f], [fr(0, 0, A)])     # opnieuw A tijdens jab 1
	var seen_j2: int = -1
	for i in 10:
		tick([f])
		if _move_of(f) == "jab2" and seen_j2 < 0:
			seen_j2 = i
	check("A opnieuw tijdens jab -> jab2", seen_j2 >= 0)
	check("jab2 = nieuwe move-instantie", f.move_instance == inst + 1)
	var g: Fighter = make(Vector2(0, 0), 1)
	g.moves["jab"] = j1
	g.moves["jab2"] = j2
	settle([g])
	tick([g], [fr(0, 0, A)])
	var n: int = 0
	while g.state_name() == "Attack" and n < 40:
		tick([g])
		n += 1
	check("zonder tweede A: jab 1 eindigt na total_frames (20)", n == 20 and g.state_name() == "Wait", "n=%d" % n)
	f.free()
	g.free()


func _smash_hit(charge_frames: int) -> float:
	new_stage()
	var p1: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var p2: Fighter = make(Vector2(10, 0), -1, "allrounder", 1)
	p1.moves["fsmash"] = move("fsmash", 50, 12, 14, Vector2(9, 8), 4, 15)
	var fs: Array = [p1, p2]
	settle(fs)
	tick(fs, [fr(80, 0, A)])
	for i in charge_frames:
		tick(fs, [fr(0, 0, A)])
	for i in 40:
		tick(fs)
	var p: float = p2.percent
	free_all(fs)
	return p


func _test_smash_charge() -> void:
	print("== smash charge")
	var p0: float = _smash_hit(0)
	var p30: float = _smash_hit(32)
	var p60: float = _smash_hit(80)
	check("ongeladen fsmash = 15%", near(p0, 15.0), str(p0))
	check("half geladen ~ ×1.18", near(p30, 15.0 * (1.0 + 0.3671 * 30.0 / 60.0), 0.01), str(p30))
	check("vol geladen (max 60 f) = ×1.3671", near(p60, 15.0 * 1.3671, 0.001), str(p60))


## Short hop + aerial; landt. Druk shield `lc_before` frames vóór de landing (-1 = niet). Geeft de landing lag.
func _aerial_land(m: MoveData, lc_before: int, land_tick: int = -1) -> Array:
	new_stage()
	var f: Fighter = make(Vector2(0, 0), 1)
	f.moves["nair"] = m
	settle([f])
	var t: int = 0
	tick([f], [fr(0, 0, JUMP)])
	var landed: int = -1
	var lag: int = -1
	var lc: bool = false
	for i in 120:
		t += 1
		var b: int = 0
		if t == 6:
			b = A
		if land_tick >= 0 and t == land_tick - lc_before:
			b |= SHIELD
		tick([f], [fr(0, 0, b)])
		if f.state_name() == "Landing" and landed < 0:
			landed = t
			lag = int(f.state.get("lag"))
			lc = bool(f.state.get("lcancel"))
			break
	f.free()
	return [landed, lag, lc]


func _test_landing_lag_lcancel() -> void:
	print("== aerial landing lag, L-cancel, auto-cancel")
	var m: MoveData = move("nair", 60, 3, 40, Vector2(0, 7), 3, 5, 361.0, 10.0, 100.0, true)
	m.landing_lag = 20
	m.lcancel_lag = 10
	var base: Array = _aerial_land(m, -1)
	check("short hop + nair landt in de aerial", base[0] > 0, str(base))
	check("aerial landing lag = 20", base[1] == 20, str(base))
	var lc3: Array = _aerial_land(m, 3, base[0])
	check("L-cancel 3 f vóór landing halveert (10)", lc3[1] == 10 and lc3[2], str(lc3))
	var lc6: Array = _aerial_land(m, 6, base[0])
	check("L-cancel 6 f vóór landing (venster 7) telt", lc6[1] == 10, str(lc6))
	var lc8: Array = _aerial_land(m, 8, base[0])
	check("L-cancel 8 f vóór landing te vroeg", lc8[1] == 20, str(lc8))
	var m2: MoveData = m.duplicate(true)
	m2.lcancel_lag = 0
	m2.landing_lag = 21
	var lcf: Array = _aerial_land(m2, 2, base[0])
	check("zonder lcancel_lag: floor(21/2) = 10", lcf[1] == 10, str(lcf))
	var m3: MoveData = m.duplicate(true)
	m3.autocancel_after = 4
	var ac: Array = _aerial_land(m3, -1)
	var normal: int = Archetypes.load_stats("allrounder").normal_landing_lag
	check("auto-cancel: normale landing lag", ac[1] == normal, str(ac))
	check("auto-cancel: geen L-cancel nodig", not ac[2])


## P1 raakt P2 (op x = 10) met `m` (jab-slot). Geeft [p1, p2] na de hit-frame (hitlag gestart).
func _setup_hit(m: MoveData, p2_percent: float = 0.0, p2_input_fn: Callable = Callable()) -> Array:
	new_stage()
	var p1: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var p2: Fighter = make(Vector2(10, 0), -1, "allrounder", 1)
	p1.moves["jab"] = m
	p2.percent = p2_percent
	var fs: Array = [p1, p2]
	settle(fs)
	tick(fs, [fr(0, 0, A)])
	for i in 30:
		if p2.hitlag_frames > 0:
			break
		tick(fs)
	return fs


func _test_hit_basics() -> void:
	print("== treffer: percent, hitlag, knockback, hitstun")
	var m: MoveData = move("jab", 30, 2, 4, Vector2(8, 8), 4, 9, 361.0, 30.0, 100.0)
	var signals: Array = [0]
	var fs: Array = _setup_hit(m, 20.0)
	var p1: Fighter = fs[0]
	var p2: Fighter = fs[1]
	p2.percent_changed.connect(func(_v: float) -> void: signals[0] += 1)
	check("percent stijgt met damage (20 -> 29)", near(p2.percent, 29.0), str(p2.percent))
	var hl: int = Knockback.hitlag_frames(9.0)
	check("hitlag slachtoffer = floor(d/3+3) = %d" % hl, p2.hitlag_frames == hl, str(p2.hitlag_frames))
	check("hitlag aanvaller = zelfde", p1.hitlag_frames == hl, str(p1.hitlag_frames))
	check("hitfall-vlag na echte treffer", p1.hitfall_allowed)
	check("slachtoffer in Damage", p2.state_name() == "Damage" or p2.state_name() == "DamageFly")
	var sf1: int = p1.state_frame
	var pos2: Vector2 = p2.pos
	var frozen: int = 0
	while p1.hitlag_frames > 0 and frozen < 50:
		tick(fs)
		frozen += 1
	check("hitlag duurt %d frames (freeze)" % hl, frozen == hl, str(frozen))
	check("aanvaller bevroren tijdens hitlag", p1.state_frame == sf1)
	check("slachtoffer bewoog niet tijdens hitlag (geen SDI)", p2.pos == pos2)
	var exp: KnockbackResult = Knockback.compute(m.hitboxes[0], 9.0, 20.0, p2.stats.weight, true, false, 1)
	check("launch-snelheid = KB·0.03 (%.4f)" % exp.speed, not p2.grounded and near(p2.kb_vel.length(), exp.speed, 0.0001),
		"%s vs %.4f" % [p2.kb_vel, exp.speed])
	check("launch-richting = 44° (Sakurai, grond, KB >= 32)", near(rad_to_deg(p2.kb_vel.angle()), 44.0, 0.01),
		str(rad_to_deg(p2.kb_vel.angle())))
	var n: int = 0
	while p2.state_name() == "Damage" and n < 200:
		tick(fs)
		n += 1
	check("hitstun = floor(KB·0.4) = %d" % exp.hitstun, n == exp.hitstun + 1, "n=%d" % n)
	check("percent_changed uitgezonden (0 extra na de hit)", signals[0] == 0)
	free_all(fs)
	# Signaal bij de hit zelf.
	new_stage()
	var a: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var b: Fighter = make(Vector2(10, 0), -1, "allrounder", 1)
	a.moves["jab"] = m
	var got: Array = [0, 0.0]
	b.percent_changed.connect(func(v: float) -> void:
		got[0] += 1
		got[1] = v)
	settle([a, b])
	tick([a, b], [fr(0, 0, A)])
	idle([a, b], 6)
	check("percent_changed bij de hit (1×, 9%)", got[0] == 1 and near(got[1], 9.0), str(got))
	check("last_hit_by = P1", b.last_hit_by == 0)
	free_all([a, b])


func _test_tumble_vs_flinch() -> void:
	print("== tumble vs flinch")
	var weak: MoveData = move("jab", 30, 2, 4, Vector2(8, 8), 4, 3, 361.0, 0.0, 50.0)
	var fs: Array = _setup_hit(weak)
	check("zwakke hit (KB < 80) = Damage (flinch)", fs[1].state_name() == "Damage" and not fs[1].pending_kb.tumble)
	free_all(fs)
	var strong: MoveData = move("jab", 30, 2, 4, Vector2(8, 8), 4, 15, 45.0, 90.0, 100.0)
	fs = _setup_hit(strong, 50.0)
	check("sterke hit (KB >= 80) = DamageFly", fs[1].state_name() == "DamageFly" and fs[1].pending_kb.tumble)
	idle(fs, 20)
	check("tumble: de lucht in", not fs[1].grounded)
	for i in 200:
		if fs[1].state_name() == "DamageFall":
			break
		tick(fs)
	check("na hitstun -> DamageFall (tumble)", fs[1].state_name() == "DamageFall")
	tick(fs, [null, fr(0, 0, A)])
	check("tumble: aerial mag", fs[1].state_name() == "AttackAir")
	free_all(fs)
	# Grond, KB < 32, 361 -> 0°: blijft op de grond en glijdt.
	var tiny: MoveData = move("jab", 30, 2, 4, Vector2(8, 8), 4, 2, 361.0, 0.0, 30.0)
	fs = _setup_hit(tiny)
	idle(fs, 10)
	check("KB < 32 op de grond: blijft grounded (0°)", fs[1].grounded and fs[1].kb_vel == Vector2.ZERO)
	free_all(fs)


func _test_di() -> void:
	print("== DI")
	var m: MoveData = move("jab", 30, 2, 4, Vector2(8, 8), 4, 12, 45.0, 60.0, 100.0)
	var res: Array = []
	for stick: Vector2i in [Vector2i.ZERO, Vector2i(-56, 56), Vector2i(56, -56), Vector2i(80, 0)]:
		var fs: Array = _setup_hit(m, 30.0)
		while fs[1].hitlag_frames > 0:
			tick(fs, [null, fr(stick.x, stick.y)])
		res.append(rad_to_deg(fs[1].kb_vel.angle()))
		free_all(fs)
	check("zonder DI: 45°", near(res[0], 45.0, 0.01), str(res[0]))
	var d1: float = res[1] - res[0]
	var d2: float = res[2] - res[0]
	check("DI loodrecht (omhoog-links) ≈ +18°", near(d1, 18.0, 0.6), str(d1))
	check("DI loodrecht (omlaag-rechts) ≈ −18°", near(d2, -18.0, 0.6), str(d2))
	check("DI nooit meer dan 18°", absf(d1) <= 18.001 and absf(d2) <= 18.001 and absf(res[3] - res[0]) <= 18.001)
	# SDI: verse flick tijdens hitlag verplaatst 6 units.
	var fs2: Array = _setup_hit(m, 30.0)
	var x0: float = fs2[1].pos.x
	tick(fs2, [null, fr(80, 0)])
	check("SDI: flick tijdens hitlag = 6 units", near(fs2[1].pos.x - x0, Knockback.SDI_DISTANCE, 0.001), str(fs2[1].pos.x - x0))
	free_all(fs2)


func _test_crouch_cancel() -> void:
	print("== crouch cancel")
	var m: MoveData = move("jab", 30, 2, 4, Vector2(8, 4), 4, 4, 361.0, 10.0, 60.0)
	new_stage()
	var p1: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var p2: Fighter = make(Vector2(10, 0), -1, "allrounder", 1)
	p1.moves["jab"] = m
	var fs: Array = [p1, p2]
	settle(fs)
	for i in 10:
		tick(fs, [null, fr(0, -70)])
	check("P2 hurkt", p2.state_name() == "SquatWait")
	tick(fs, [fr(0, 0, A), fr(0, -70)])
	for i in 10:
		if p2.hitlag_frames > 0:
			break
		tick(fs, [null, fr(0, -70)])
	var exp: KnockbackResult = Knockback.compute(m.hitboxes[0], 4.0, 0.0, p2.stats.weight, true, true, 1)
	var full: KnockbackResult = Knockback.compute(m.hitboxes[0], 4.0, 0.0, p2.stats.weight, true, false, 1)
	check("crouch cancel: KB × 2/3", p2.pending_kb != null and near(p2.pending_kb.kb, full.kb * 2.0 / 3.0, 0.0001))
	check("crouch cancel: blijft in crouch", p2.state_name() == "SquatWait")
	while p2.hitlag_frames > 0:
		tick(fs, [null, fr(0, -70)])
	var exp_x: float = Knockback.apply_di(exp.launch_vel, Vector2(0, -70) / 80.0).x
	check("crouch cancel: glijdt met de lagere snelheid (na DI)", near(p2.gr_vel, exp_x, 0.0001) and p2.grounded,
		"%.4f vs %.4f" % [p2.gr_vel, exp_x])
	free_all(fs)


## Fighter in DamageFall net boven de grond; `press_at` = frame (vanaf 1) waarop shield gedrukt wordt (-1 = niet).
func _tumble_land(press_at: int, sx: int = 0) -> Fighter:
	new_stage()
	var f: Fighter = make(Vector2(0, 0), 1)
	settle([f])
	f.leave_ground(Vector2.ZERO)
	f.pos = Vector2(0, 8)
	f.vel = Vector2(0, -1.0)
	f.change_state("DamageFly", {"kb": _tumble_kb()})
	for i in 30:
		var b: int = SHIELD if i + 1 == press_at else 0
		tick([f], [fr(sx, 0, b)])
		if f.grounded:
			break
	return f


func _test_tech() -> void:
	print("== tech / missed tech / getup")
	var land: Fighter = _tumble_land(-1)
	var land_frame: int = land.tick_count
	check("missed tech -> DownBound", land.state_name() == "DownBound")
	for i in FighterConst.DOWN_BOUND_FRAMES + 1:
		tick([land])
	check("DownBound -> DownWait (liggen)", land.state_name() == "DownWait")
	check("liggen: lage hurtbox", land.state.hurtbox_shape() == "lie")
	tick([land], [fr(0, 0, A)])
	check("liggen + A = getup attack", land.state_name() == "DownGetup" and land.state.get("kind") == "attack")
	var hit_seen: bool = false
	for i in 60:
		tick([land])
		if not land.state.hitboxes().is_empty():
			hit_seen = true
	check("getup attack heeft hitboxes", hit_seen)
	check("getup attack eindigt in Wait", land.state_name() == "Wait")
	land.free()
	var t: Fighter = _tumble_land(3)
	check("shield vlak vóór de landing = tech in place", t.state_name() == "Tech" and int(t.state.get("dir")) == 0)
	check("tech: intangible", t.is_intangible())
	for i in FighterConst.TECH_FRAMES + 1:
		tick([t])
	check("tech -> Wait", t.state_name() == "Wait")
	t.free()
	var tr: Fighter = _tumble_land(3, 80)
	var x0: float = tr.pos.x
	check("shield + stick rechts = tech roll", tr.state_name() == "Tech" and int(tr.state.get("dir")) == 1)
	for i in FighterConst.TECH_ROLL_FRAMES + 1:
		tick([tr])
	check("tech roll verplaatst ~%.0f units" % FighterConst.TECH_ROLL_DISTANCE, near(tr.pos.x - x0, FighterConst.TECH_ROLL_DISTANCE, 0.5), str(tr.pos.x - x0))
	tr.free()
	var late: Fighter = _tumble_land(-1)
	late.free()
	var early: Fighter = _tumble_land(1)
	# Landing op ~frame 8; druk op frame 1 is binnen 20 frames: nog tech. Test het venster expliciet:
	early.free()
	new_stage()
	var w: Fighter = make(Vector2(0, 0), 1)
	settle([w])
	w.leave_ground(Vector2.ZERO)
	w.pos = Vector2(70, 60)
	w.vel = Vector2(0, -1.0)
	w.change_state("DamageFly", {"kb": _tumble_kb()})
	tick([w], [fr(0, 0, SHIELD)])
	var n: int = 0
	while not w.grounded and n < 100:
		tick([w])
		n += 1
	check("tech-druk > 20 frames vóór de landing = missed tech (%d f)" % n, n >= 20 and w.state_name() == "DownBound", "%d %s" % [n, w.state_name()])
	w.free()


func _test_hitfall() -> void:
	print("== hitfall")
	var air: MoveData = move("nair", 40, 1, 12, Vector2(7, 4), 6, 6, 361.0, 10.0, 60.0, true)
	new_stage()
	var p1: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var p2: Fighter = make(Vector2(7, 0), -1, "allrounder", 1)
	p1.moves["nair"] = air
	var fs: Array = [p1, p2]
	settle(fs)
	tick(fs, [fr(0, 0, JUMP)])
	for i in 4:
		tick(fs, [fr(0, 0, JUMP)])
	var ok_air: bool = not p1.grounded and p1.vel.y > 0.0
	tick(fs, [fr(0, 0, A)])
	var guard: int = 0
	while p1.hitlag_frames == 0 and guard < 15:
		tick(fs)
		guard += 1
	check("P1 raakt P2 tijdens het stijgen", ok_air and p1.hitlag_frames > 0 and p1.vel.y > 0.0, "vy %.3f hl %d" % [p1.vel.y, p1.hitlag_frames])
	check("hitfall toegestaan na echte treffer", p1.hitfall_allowed)
	tick(fs, [fr(0, -80)])
	while p1.hitlag_frames > 0:
		tick(fs)
	tick(fs)
	check("hitfall: fast fall tijdens stijgen na de hitlag", p1.fastfalling and near(p1.vel.y, -p1.stats.fast_fall_velocity),
		"ff %s vy %.3f" % [p1.fastfalling, p1.vel.y])
	free_all(fs)
	# Whiff: flick omlaag tijdens het stijgen = geen fast fall (Melee, na de apex pas).
	new_stage()
	var w: Fighter = make(Vector2(0, 0), 1)
	w.moves["nair"] = air
	settle([w])
	tick([w], [fr(0, 0, JUMP)])
	for i in 4:
		tick([w], [fr(0, 0, JUMP)])
	tick([w], [fr(0, 0, A)])
	tick([w])
	tick([w], [fr(0, -80)])
	tick([w])
	check("whiff: geen fast fall tijdens stijgen", not w.fastfalling and w.vel.y > 0.0)
	w.free()
	# Clank: hitlag maar geen hitfall.
	new_stage()
	var c: Fighter = make(Vector2(0, 0), 1)
	c.moves["nair"] = air
	settle([c])
	tick([c], [fr(0, 0, JUMP)])
	for i in 4:
		tick([c], [fr(0, 0, JUMP)])
	tick([c], [fr(0, 0, A)])
	c.on_clank(5, false)
	tick([c], [fr(0, -80)])
	while c.hitlag_frames > 0:
		tick([c])
	tick([c])
	check("clank: hitlag maar geen hitfall", not c.hitfall_allowed and not c.fastfalling and c.vel.y > 0.0)
	c.free()
	# Shield-hit: HitEvent zegt geen hitfall.
	var ev := HitEvent.new()
	ev.kind = HitEvent.Kind.SHIELD
	ev.attacker_hitfall_allowed = false
	ev.attacker_hitlag = 4
	new_stage()
	var s: Fighter = make(Vector2(0, 0), 1)
	s.on_hit_landed(ev)
	check("shield-hit: geen hitfall", not s.hitfall_allowed and s.hitlag_frames == 4)
	s.free()


func _test_one_hit_per_instance() -> void:
	print("== één hit per move-instantie")
	var m: MoveData = move("jab", 40, 2, 20, Vector2(8, 8), 5, 2, 361.0, 0.0, 10.0)
	var fs: Array = _setup_hit(m)
	idle(fs, 40)
	check("lange actieve hitbox raakt maar één keer", near(fs[1].percent, 2.0), str(fs[1].percent))
	free_all(fs)
	var mh: MoveData = move("jab", 40, 2, 3, Vector2(8, 8), 5, 2, 361.0, 0.0, 10.0)
	mh.hitboxes.append(MoveSet.make_hitbox(0, 12, 13, Vector2(8, 8), 5, 3, 361.0, 0.0, 10.0, 1))
	fs = _setup_hit(mh)
	idle(fs, 60)
	check("multi-hit: groep 0 + groep 1 = 2 hits (5%)", near(fs[1].percent, 5.0), str(fs[1].percent))
	fs[1].pos = Vector2(10, 0)
	tick(fs, [fr(0, 0, A)])
	idle(fs, 40)
	check("nieuwe instantie raakt opnieuw", fs[1].percent > 5.5, str(fs[1].percent))
	free_all(fs)
	# Intangible doelwit wordt niet geraakt.
	var fs3: Array = _setup_hit(move("jab", 30, 6, 8, Vector2(8, 8), 5, 2))
	check("setup", true)
	free_all(fs3)
	new_stage()
	var a: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var b: Fighter = make(Vector2(10, 0), -1, "allrounder", 1)
	a.moves["jab"] = move("jab", 30, 2, 4, Vector2(8, 8), 5, 2)
	settle([a, b])
	b.intangible_frames = 30
	tick([a, b], [fr(0, 0, A)])
	idle([a, b], 10)
	check("intangible doelwit: geen hit", near(b.percent, 0.0))
	free_all([a, b])
	# Een hit zet de ledge-lock (Melee: één ledge_cooldown = 30, ook na geraakt worden).
	var fs4: Array = _setup_hit(move("jab", 30, 2, 4, Vector2(8, 8), 5, 2))
	free_all(fs4)
	new_stage()
	var c: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var d: Fighter = make(Vector2(10, 0), -1, "allrounder", 1)
	c.moves["jab"] = move("jab", 30, 2, 4, Vector2(8, 8), 5, 2)
	settle([c, d])
	tick([c, d], [fr(0, 0, A)])
	idle([c, d], 5)
	check("hit zet de ledge-lock (ledge_cooldown 30)", d.ledge_cooldown_frames > 0 and d.ledge_cooldown_frames <= d.stats.ledge_cooldown, "cd %d" % d.ledge_cooldown_frames)
	free_all([c, d])


func _test_ledge_and_getup_attack() -> void:
	print("== ledge attack hitbox")
	new_stage()
	var f: Fighter = make(Vector2(SandboxStage.MAIN_HALF_WIDTH + 8.0, 10.0), -1)
	f.leave_ground(Vector2.ZERO)
	f.change_state("Fall")
	var n: int = 0
	while f.state_name() != "CliffWait" and n < 120:
		tick([f])
		n += 1
	check("ledge gegrepen", f.state_name() == "CliffWait")
	idle([f], 2)
	tick([f], [fr(0, 0, A)])
	check("A aan de ledge = CliffAttack", f.state_name() == "CliffAttack")
	var hit: int = int(f.state.get("opt")["hit"])
	var seen: int = -1
	for i in 60:
		if f.state_name() != "CliffAttack":
			break
		if not f.state.hitboxes().is_empty() and seen < 0:
			seen = f.state_frame
		tick([f])
	check("ledge-attack-hitbox actief vanaf frame %d" % hit, seen == hit, str(seen))
	f.free()


func _scenario() -> Array:
	new_stage()
	var p1: Fighter = make(Vector2(-10, 0), 1, "allrounder", 0)
	var p2: Fighter = make(Vector2(5, 0), -1, "fast_faller", 1)
	var fs: Array = [p1, p2]
	var log: Array = []
	for t in 240:
		var i1 := InputFrame.new()
		var i2 := InputFrame.new()
		if t == 5:
			i1.stick = Vector2i(80, 0)
			i1.buttons = A
		if t >= 60 and t < 64:
			i1.buttons = JUMP
		if t == 70:
			i1.cstick = Vector2i(80, 0)
		if t >= 20 and t < 40:
			i2.stick = Vector2i(-50, 50)
		if t == 90:
			i2.buttons = A
		tick(fs, [i1, i2])
		log.append([p1.snapshot(), p2.snapshot()])
	free_all(fs)
	return log


func _test_determinism() -> void:
	print("== determinisme")
	var a: Array = _scenario()
	var b: Array = _scenario()
	check("zelfde input -> zelfde posities/percent/states (240 frames)", a == b)
	var any_hit: bool = false
	for e: Array in a:
		if e[1][12] > 0.0 or e[0][12] > 0.0:
			any_hit = true
	check("scenario bevat een treffer", any_hit)


## Tumble-hitstun die nog loopt bij de landing (in DamageFall zou shield een air dodge geven, zoals Melee).
func _tumble_kb() -> KnockbackResult:
	var k := KnockbackResult.new()
	k.kb = 100.0
	k.tumble = true
	k.hitstun = 80
	return k


func _test_directions() -> void:
	print("== richting: hoek t.o.v. de kijkrichting van de aanvaller")
	for dir: int in [1, -1]:
		new_stage()
		var p1: Fighter = make(Vector2(0, 0), dir, "allrounder", 0)
		var p2: Fighter = make(Vector2(-10 * dir, 0), dir, "allrounder", 1)
		p1.moves["jab"] = move("jab", 30, 2, 4, Vector2(-8, 8), 5, 10, 135.0, 60.0, 100.0)
		var fs: Array = [p1, p2]
		settle(fs)
		tick(fs, [fr(0, 0, A)])
		idle(fs, 25)
		check("achterwaartse hoek 135° (facing %d) lanceert naar achteren" % dir, p2.pos.x * dir < -11.0 and p2.pos.y > 0.0,
			str(p2.pos))
		free_all(fs)
	# Echte archetype-fair: kort springen naast P2 (100%), fair raakt en lanceert vooruit.
	for dir: int in [1, -1]:
		new_stage()
		var a: Fighter = make(Vector2(0, 0), dir, "allrounder", 0)
		var b: Fighter = make(Vector2(14 * dir, 0), -dir, "allrounder", 1)
		b.percent = 100.0
		var fs2: Array = [a, b]
		settle(fs2)
		tick(fs2, [fr(0, 0, JUMP)])
		for i in 10:
			if not a.grounded:
				break
			tick(fs2)
		tick(fs2, [fr(50 * dir, 0, A)])
		idle(fs2, 30)
		check("archetype-fair (facing %d) raakt en lanceert vooruit" % dir, b.percent > 100.0 and (b.pos.x - 14 * dir) * dir > 5.0,
			"%.1f%% x %.1f" % [b.percent, b.pos.x])
		free_all(fs2)
