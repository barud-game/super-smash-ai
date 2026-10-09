extends SceneTree
## Tests M4 verdediging: shield (op/af, lightshield, shieldstun, pushback, shield-HP, break + dizzy, shield poke,
## powershield), OoS-opties (grab, JC, spotdodge, roll, shield drop vanilla/UCF, up-B-hook), rolls/spotdodge
## (intangible + verplaatsing per lengte), grab/dash grab/whiff, pummel, grab-release, throws (richting, launch-frame,
## knockback, DI, geen SDI), throw -> tumble -> tech, special-hook, determinisme.
## Headless, gescripte input (eigen InputHistory per fighter), sandbox-stub, CombatSystem zelf gestept.
##   Godot_console.exe --headless --path . --script res://tests/test_defense.gd
## Exit code 0 = alles geslaagd, 1 = minstens één FAIL.

const A: int = InputFrame.BTN_ATTACK
const B: int = InputFrame.BTN_SPECIAL
const JUMP: int = InputFrame.BTN_JUMP
const SHIELD: int = InputFrame.BTN_SHIELD
const Z: int = InputFrame.BTN_Z
const PLATFORM_Y: float = 27.2

var _fails: int = 0
var _total: int = 0
var stage: SandboxStage
var combat := CombatSystem.new()


func _initialize() -> void:
	MeleeStick.fast_fall_while_rising = false
	_test_shield_on_off()
	_test_shieldstun()
	_test_lightshield()
	_test_shield_hp()
	_test_shield_break()
	_test_shield_poke()
	_test_powershield()
	_test_oos()
	_test_shield_drop()
	_test_rolls_spotdodge()
	_test_grab_whiff()
	_test_grab_connect()
	_test_pummel()
	_test_release()
	_test_throws()
	_test_throw_di()
	_test_throw_tumble_tech()
	_test_grab_break()
	_test_special_hook()
	_test_poses()
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


func make(at: Vector2, dir: int, id: String = "allrounder", player: int = 0, vh: float = 0.0) -> Fighter:
	var f := Fighter.new()
	f.use_visual = false
	f.auto_register = false
	f.player = player
	f.stats = Archetypes.load_stats(id)
	if vh > 0.0:
		f.stats = f.stats.duplicate()
		f.stats.visual_height = vh
	f.stage = stage
	f.input = InputHistory.new()
	f.tap_jump_override = 1
	f.pos = at
	f.facing = dir
	f.setup()
	return f


func fr(sx: int = 0, sy: int = 0, buttons: int = 0, cx: int = 0, cy: int = 0, trig: float = 0.0) -> InputFrame:
	var i := InputFrame.new()
	i.stick = Vector2i(sx, sy)
	i.cstick = Vector2i(cx, cy)
	i.buttons = buttons
	i.trigger_l = trig
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
		angle: float = 361.0, bkb: float = 10.0, kbg: float = 100.0) -> MoveData:
	var m := MoveData.new()
	m.move_name = n
	m.total_frames = total
	m.hitboxes = [MoveSet.make_hitbox(0, start, end, offset, radius, damage, angle, bkb, kbg)]
	return m


## Tick tot `cond` waar is (max n frames); geeft het aantal ticks of -1.
func until(fs: Array, inputs: Array, cond: Callable, n: int = 300) -> int:
	for i in n:
		tick(fs, inputs)
		if cond.call():
			return i + 1
	return -1


## P1 (attacker, x=0 kijkt rechts) en P2 (x=dx kijkt links) op de grond.
func pair(dx: float = 10.0, id1: String = "allrounder", id2: String = "allrounder", vh2: float = 0.0) -> Array:
	new_stage()
	var p1: Fighter = make(Vector2(0, 0), 1, id1, 0)
	var p2: Fighter = make(Vector2(dx, 0), -1, id2, 1, vh2)
	var fs: Array = [p1, p2]
	idle(fs, 3)
	return fs


## De laatste fighter in `fs` (P2, of de enige) houdt de shield (digitaal) tot hij in Guard staat.
func shield_up(fs: Array, p2_input: InputFrame = null) -> void:
	var inp: InputFrame = p2_input if p2_input != null else fr(0, 0, SHIELD)
	var inputs: Array = []
	inputs.resize(fs.size())
	inputs[fs.size() - 1] = inp
	for i in FighterConst.GUARD_ON_FRAMES + 2:
		tick(fs, inputs)


# --- shield ------------------------------------------------------------------------------------

func _test_shield_on_off() -> void:
	print("== shield op/af")
	new_stage()
	var f: Fighter = make(Vector2(0, 0), 1)
	idle([f], 3)
	tick([f], [fr(0, 0, SHIELD)])
	check("shield (digitaal) in Wait = GuardOn", f.state_name() == "GuardOn" and f.state.is_shielding())
	var t: CombatTarget = f.combat_target()
	check("CombatTarget: shielding + middelpunt + straal + analoog 1.0", t.shielding and near(t.shield_center.y, 7.5)
		and near(t.shield_radius, 0.62 * 15.0) and near(t.shield_analog, 1.0), "%s r %.2f" % [t.shield_center, t.shield_radius])
	for i in FighterConst.GUARD_ON_FRAMES:
		tick([f], [fr(0, 0, SHIELD)])
	check("na %d frames GuardOn -> Guard" % FighterConst.GUARD_ON_FRAMES, f.state_name() == "Guard")
	tick([f])
	check("loslaten = GuardOff (shield niet meer op)", f.state_name() == "GuardOff" and not f.combat_target().shielding)
	var n: int = until([f], [], func() -> bool: return f.state_name() == "Wait")
	check("GuardOff duurt %d frames" % FighterConst.GUARD_OFF_FRAMES, n == FighterConst.GUARD_OFF_FRAMES, str(n))
	# Analoog: 0.5 = lightshield, 0.2 = geen shield.
	idle([f], 2)
	tick([f], [fr(0, 0, 0, 0, 0, 0.2)])
	check("trigger 0.2 = geen shield", f.state_name() == "Wait")
	tick([f], [fr(0, 0, 0, 0, 0, 0.5)])
	check("trigger 0.5 = shield (licht)", f.state_name() == "GuardOn" and near(f.combat_target().shield_analog, 0.5))
	# Tap: 1 frame shield = toch de hele GuardOn, dan GuardOff.
	f.free()
	var tap: Fighter = make(Vector2(0, 0), 1)
	idle([tap], 3)
	tick([tap], [fr(0, 0, SHIELD)])
	var m: int = until([tap], [], func() -> bool: return tap.state_name() != "GuardOn")
	check("shield-tap: GuardOn volledig (%d) dan GuardOff" % FighterConst.GUARD_ON_FRAMES,
		m == FighterConst.GUARD_ON_FRAMES and tap.state_name() == "GuardOff", "%d %s" % [m, tap.state_name()])
	tap.free()
	# Shield vanuit Run (glijdt uit met traction) en vanuit SquatWait.
	var r: Fighter = make(Vector2(-60, 0), 1)
	idle([r], 3)
	for i in 30:
		tick([r], [fr(80, 0)])
	tick([r], [fr(80, 0, SHIELD)])
	check("Run + shield = GuardOn (shield stop)", r.state_name() == "GuardOn" and r.gr_vel > 0.0)
	r.free()
	var s: Fighter = make(Vector2(0, 0), 1)
	idle([s], 3)
	for i in 10:
		tick([s], [fr(0, -70)])
	tick([s], [fr(0, -70, SHIELD)])
	check("SquatWait + shield = GuardOn", s.state_name() == "GuardOn")
	s.free()
	# Lucht: shield = air dodge (geen shield).
	var air: Fighter = make(Vector2(0, 40), 1)
	tick([air])
	tick([air], [fr(0, 0, SHIELD)])
	check("in de lucht: shield = air dodge", air.state_name() == "EscapeAir")
	air.free()


## P1 slaat P2 (in Guard) met een move van `dmg` damage op `offset`; geeft [hit_tick, p2-hp vóór, p2-x bij hit].
func _shield_hit(fs: Array, dmg: float, p2_input: InputFrame, offset: Vector2 = Vector2(8, 8)) -> Dictionary:
	var p1: Fighter = fs[0]
	var p2: Fighter = fs[1]
	p1.moves["jab"] = move("jab", 30, 2, 3, offset, 3.0, dmg)
	tick(fs, [fr(0, 0, A), p2_input])
	var hp_before: float = p2.shield_hp
	var n: int = 0
	while n < 10 and p2.state_name() != "GuardSetOff":
		hp_before = p2.shield_hp
		tick(fs, [null, p2_input])
		n += 1
	return {"hp_before": hp_before, "x": p2.pos.x, "hitlag": p2.hitlag_frames, "p1_hitlag": p1.hitlag_frames}


func _test_shieldstun() -> void:
	print("== shieldstun voor de verdediger")
	var fs: Array = pair(10.0)
	var p1: Fighter = fs[0]
	var p2: Fighter = fs[1]
	shield_up(fs)
	check("P2 in Guard", p2.state_name() == "Guard")
	var info: Dictionary = _shield_hit(fs, 10.0, fr(0, 0, SHIELD))
	var stun: int = Knockback.shieldstun_frames(10.0, 1.0)
	var hl: int = Knockback.hitlag_frames(10.0, 0, 1.0, true, false)
	check("treffer op shield = GuardSetOff, geen percent", p2.state_name() == "GuardSetOff" and p2.percent == 0.0)
	check("shieldstun = floor(0.448d+2) = %d (d=10, vol)" % stun, int(p2.state.get("stun")) == stun and stun == int(floor(0.448 * 10 + 2)))
	check("hitlag verdediger = %d, aanvaller ook (geen hitfall)" % hl, int(info["hitlag"]) == hl
		and int(info["p1_hitlag"]) == Knockback.hitlag_frames(10.0) and not p1.hitfall_allowed)
	check("shield-schade = d × 0.7 (+ slijtage 0.28)", near(float(info["hp_before"]) - p2.shield_hp, 7.0 + FighterConst.SHIELD_DEPLETION, 0.0001),
		str(float(info["hp_before"]) - p2.shield_hp))
	var x0: float = float(info["x"])
	var n: int = until(fs, [null, fr(0, 0, SHIELD)], func() -> bool: return p2.state_name() == "Guard")
	check("GuardSetOff duurt hitlag + stun = %d frames" % (hl + stun), n == hl + stun, str(n))
	# Pushback: v0 = 0.3 + d·0.3·0.15, remt met traction ×1.
	var v: float = minf(FighterConst.SHIELD_PUSH_BASE + 10.0 * 0.3 * FighterConst.SHIELD_PUSH_PER_DAMAGE, FighterConst.SHIELD_PUSH_MAX)
	var expect: float = 0.0
	var vv: float = v
	for i in stun:
		vv = maxf(vv - p2.stats.traction, 0.0)
		expect += vv
	check("pushback weg van de aanvaller (%.2f units in de stun)" % expect, near(p2.pos.x - x0, expect, 0.01), str(p2.pos.x - x0))
	free_all(fs)


func _test_lightshield() -> void:
	print("== lightshield")
	var s: float = 0.5
	var fs: Array = pair(10.0)
	var p2: Fighter = fs[1]
	var light_in: InputFrame = fr(0, 0, 0, 0, 0, s)
	shield_up(fs, light_in)
	check("analoog 0.5 = Guard", p2.state_name() == "Guard")
	var lightness: float = 1.0 - Knockback.shield_norm(s)
	check("lightshield-bubble groter: × (1 + 0.3·licht)", near(p2.shield_radius(),
		0.62 * 15.0 * (FighterConst.SHIELD_MIN_SCALE + (1.0 - FighterConst.SHIELD_MIN_SCALE) * p2.shield_hp / 60.0) * (1.0 + 0.3 * lightness), 0.0001))
	var info: Dictionary = _shield_hit(fs, 10.0, light_in)
	var stun: int = Knockback.shieldstun_frames(10.0, s)
	check("lightshield: shieldstun met analoge stand (%d > %d)" % [stun, Knockback.shieldstun_frames(10.0, 1.0)],
		int(p2.state.get("stun")) == stun and stun > Knockback.shieldstun_frames(10.0, 1.0))
	var mult: float = 0.7 + 0.65 * lightness
	check("lightshield: shield-schade × %.3f" % mult, near(float(info["hp_before"]) - p2.shield_hp, 10.0 * mult + 0.28, 0.0001),
		str(float(info["hp_before"]) - p2.shield_hp))
	var x0: float = float(info["x"])
	until(fs, [null, light_in], func() -> bool: return p2.state_name() == "Guard")
	var light_push: float = p2.pos.x - x0
	free_all(fs)
	var fs2: Array = pair(10.0)
	shield_up(fs2)
	var info2: Dictionary = _shield_hit(fs2, 10.0, fr(0, 0, SHIELD))
	until(fs2, [null, fr(0, 0, SHIELD)], func() -> bool: return fs2[1].state_name() == "Guard")
	var full_push: float = fs2[1].pos.x - float(info2["x"])
	check("lightshield: meer pushback (%.2f > %.2f)" % [light_push, full_push], light_push > full_push * 1.5)
	free_all(fs2)


func _test_shield_hp() -> void:
	print("== shield-HP: slijten en herstellen")
	new_stage()
	var f: Fighter = make(Vector2(0, 0), 1)
	idle([f], 3)
	for i in 100:
		tick([f], [fr(0, 0, SHIELD)])
	# Het eerste frame (GuardOn start in de IASA) slijt nog niet: 99 frames × 0.28.
	check("100 frames vasthouden: 60 − 99·0.28 = 32.28", near(f.shield_hp, 60.0 - 99.0 * 0.28, 0.0001), str(f.shield_hp))
	var r_full: float = 0.62 * 15.0
	check("bubble krimpt met de HP", f.shield_radius() < r_full * 0.7 and f.shield_radius() > r_full * 0.4, str(f.shield_radius()))
	var hp: float = f.shield_hp
	for i in 100:
		tick([f])
	# Frame 1 los: nog Guard (slijt 0.28, dan GuardOff); daarna 99 frames + 0.07 (ook tijdens GuardOff).
	check("100 frames los: −0.28 + 99·0.07 (herstel ook tijdens GuardOff)", near(f.shield_hp, hp - 0.28 + 99.0 * 0.07, 0.0001),
		str(f.shield_hp - hp))
	for i in 1000:
		tick([f])
	check("herstel tot max 60", near(f.shield_hp, 60.0))
	f.free()


func _test_shield_break() -> void:
	print("== shield break + dizzy")
	new_stage()
	var f: Fighter = make(Vector2(0, 0), 1)
	f.percent = 50.0
	idle([f], 3)
	shield_up([f])
	for i in FighterConst.GUARD_ON_FRAMES + 2:
		tick([f], [fr(0, 0, SHIELD)])
	f.shield_hp = 1.0
	var n: int = until([f], [fr(0, 0, SHIELD)], func() -> bool: return f.state_name() == "ShieldBreak", 10)
	check("HP op door vasthouden = ShieldBreak (na 4 frames à 0.28)", n == 4, str(n))
	check("break: HP terug op 30", near(f.shield_hp, FighterConst.SHIELD_BREAK_RESET_HP))
	tick([f], [fr(0, 0, SHIELD)])
	check("break: omhoog gelanceerd, in de lucht", not f.grounded and f.vel.y > 0.0 and f.pos.y > 0.0)
	var top: float = 0.0
	var m: int = 0
	while f.state_name() == "ShieldBreak" and m < 300:
		tick([f], [fr(80, 0, A | JUMP)])
		top = maxf(top, f.pos.y)
		m += 1
	check("geen drift/acties tijdens de vlucht; landt -> ShieldBreakDown", f.state_name() == "ShieldBreakDown"
		and near(f.pos.x, 0.0, 0.01) and top > 20.0, "%s x %.2f top %.1f" % [f.state_name(), f.pos.x, top])
	var k: int = until([f], [], func() -> bool: return f.state_name() == "Dizzy")
	check("ShieldBreakDown %d frames -> Dizzy" % FighterConst.SHIELD_BREAK_DOWN_FRAMES, k == FighterConst.SHIELD_BREAK_DOWN_FRAMES, str(k))
	var dz: int = StateDizzy.duration_for(50.0)
	check("dizzy-duur bij 50%% = 400 − 50 = %d" % dz, dz == 350)
	check("dizzy korter bij hoger %%, minimum %d" % FighterConst.DIZZY_MIN, StateDizzy.duration_for(150.0) < dz
		and StateDizzy.duration_for(999.0) == FighterConst.DIZZY_MIN)
	var d: int = until([f], [fr(80, 0, A | SHIELD | JUMP)], func() -> bool: return f.state_name() != "Dizzy", 500)
	# Op het eindframe is hij actionable: Wait, en met de shield vast meteen GuardOn.
	check("dizzy: geen acties, %d frames, dan Wait (actionable)" % dz, d == dz
		and (f.state_name() == "Wait" or f.prev_state_name == "Wait"), "%d %s" % [d, f.state_name()])
	f.free()
	# Break door een treffer: HP laag, harde klap.
	var fs: Array = pair(10.0)
	var p2: Fighter = fs[1]
	shield_up(fs)
	p2.shield_hp = 5.0
	_shield_hit(fs, 12.0, fr(0, 0, SHIELD))
	idle(fs, 1)
	var broke: bool = p2.state_name() == "ShieldBreak"
	for i in 20:
		if p2.state_name() == "ShieldBreak":
			broke = true
		tick(fs, [null, fr(0, 0, SHIELD)])
	check("treffer die de HP opmaakt = shield break", broke, p2.state_name())
	free_all(fs)


func _test_shield_poke() -> void:
	print("== shield poke")
	var fs: Array = pair(10.0)
	var p2: Fighter = fs[1]
	shield_up(fs)
	p2.shield_hp = 6.0
	var r: float = p2.shield_radius()
	check("bubble bij 6 HP klein (%.2f units)" % r, r < 3.0)
	# Hitbox laag bij de voeten (y=1): buiten de bubble (midden y 7.5), wel op de benen -> HIT.
	fs[0].moves["jab"] = move("jab", 30, 2, 3, Vector2(9, 1), 2.0, 5.0)
	tick(fs, [fr(0, 0, A), fr(0, 0, SHIELD)])
	var hit: bool = false
	for i in 4:
		tick(fs, [null, fr(0, 0, SHIELD)])
		if p2.percent > 0.0:
			hit = true
			break
	check("hitbox buiten de gekrompen bubble raakt de hurtbox (shield poke)", hit and p2.state_name() == "Damage",
		"%s %.1f%%" % [p2.state_name(), p2.percent])
	free_all(fs)
	var fs2: Array = pair(10.0)
	shield_up(fs2)
	fs2[0].moves["jab"] = move("jab", 30, 2, 3, Vector2(9, 1), 2.0, 5.0)
	tick(fs2, [fr(0, 0, A), fr(0, 0, SHIELD)])
	for i in 4:
		tick(fs2, [null, fr(0, 0, SHIELD)])
	check("zelfde hitbox tegen volle bubble = shield", fs2[1].percent == 0.0 and fs2[1].state_name() == "GuardSetOff", fs2[1].state_name())
	free_all(fs2)


## P1 valt aan (hitbox actief op move-frame 2). P2 drukt shield op `press_rel` frames ná de A-druk (0 = zelfde frame),
## met `inp` als input op dat frame en daarna `hold`. Geeft P2.
func _ps_run(press_rel: int, inp: InputFrame, hold: InputFrame) -> Fighter:
	var fs: Array = pair(10.0)
	var p2: Fighter = fs[1]
	fs[0].moves["jab"] = move("jab", 30, 2, 3, Vector2(8, 8), 3.0, 10.0)
	var pressed: bool = false
	for t in range(-12, 12):
		var a_in: InputFrame = fr(0, 0, A) if t == 0 else null
		var p2_in: InputFrame = null
		if t == press_rel:
			p2_in = inp
			pressed = true
		elif pressed:
			p2_in = hold
		tick(fs, [a_in, p2_in])
		if t == 2:
			break
	fs[0].free()
	return p2


func _test_powershield() -> void:
	print("== powershield")
	var p: Fighter = _ps_run(2, fr(0, 0, SHIELD), fr(0, 0, SHIELD))
	check("digitale klik op het hit-frame = powershield: geen stun, geen schade, geen hitlag",
		p.state_name() == "GuardOn" and near(p.shield_hp, 60.0) and p.hitlag_frames == 0, "%s hp %.2f hl %d" % [p.state_name(), p.shield_hp, p.hitlag_frames])
	p.free()
	p = _ps_run(-1, fr(0, 0, SHIELD), fr(0, 0, SHIELD))
	check("klik 3 frames vóór de hit (binnen venster %d) = powershield" % FighterConst.POWERSHIELD_WINDOW,
		p.state_name() == "GuardOn" and p.shield_hp > 59.0 and p.hitlag_frames == 0, "%s hp %.2f" % [p.state_name(), p.shield_hp])
	p.free()
	p = _ps_run(-2, fr(0, 0, SHIELD), fr(0, 0, SHIELD))
	check("klik 4 frames vóór de hit = gewone shield (GuardSetOff)", p.state_name() == "GuardSetOff", p.state_name())
	p.free()
	p = _ps_run(2, fr(0, 0, 0, 0, 0, 0.6), fr(0, 0, 0, 0, 0, 0.6))
	check("alleen analoog (geen klik) = geen powershield", p.state_name() == "GuardSetOff", p.state_name())
	p.free()


# --- OoS ---------------------------------------------------------------------------------------

## Fighter in Guard (alleen), daarna `inputs` (met shield vast tenzij anders); geeft de fighter.
func _oos(inputs: Array, at: Vector2 = Vector2(0, 0)) -> Fighter:
	new_stage()
	var f: Fighter = make(at, 1)
	idle([f], 3)
	shield_up([f])
	for i: InputFrame in inputs:
		tick([f], [i])
	return f


func _test_oos() -> void:
	print("== uit shield (OoS)")
	var f: Fighter = _oos([fr(0, 0, SHIELD | A)])
	check("shield + A = grab", f.state_name() == "Grab" and not bool(f.state.get("dash")))
	f.free()
	f = _oos([fr(0, 0, SHIELD | Z)])
	check("shield + Z = grab", f.state_name() == "Grab")
	f.free()
	f = _oos([fr(0, 0, SHIELD | JUMP)])
	check("shield + jump = jumpsquat (KneeBend)", f.state_name() == "KneeBend")
	f.free()
	f = _oos([fr(0, 80, SHIELD)])
	check("shield + tap jump (stick omhoog) = KneeBend", f.state_name() == "KneeBend")
	f.free()
	f = _oos([fr(0, 0, SHIELD | JUMP), fr(0, 80, SHIELD | A)])
	check("OoS usmash via jump-cancel (shield, jump, A + omhoog)", f.state_name() == "Attack" and String(f.state.get("move_name")) == "usmash")
	f.free()
	f = _oos([fr(0, 0, SHIELD | JUMP), fr(0, 0, SHIELD | A)])
	check("JC grab uit shield (jump, A met shield vast) = staande grab", f.state_name() == "Grab")
	f.free()
	f = _oos([fr(0, -80, SHIELD)])
	check("shield + omlaag-flick = spotdodge (EscapeN)", f.state_name() == "EscapeN")
	f.free()
	f = _oos([fr(80, 0, SHIELD)])
	check("shield + flick vooruit = roll vooruit", f.state_name() == "Escape" and int(f.state.get("rel")) == 1)
	f.free()
	f = _oos([fr(-80, 0, SHIELD)])
	check("shield + flick achteruit = roll achteruit", f.state_name() == "Escape" and int(f.state.get("rel")) == -1)
	f.free()
	f = _oos([fr(30, 0, SHIELD), fr(40, 0, SHIELD), fr(50, 0, SHIELD), fr(55, 0, SHIELD), fr(60, 0, SHIELD), fr(64, 0, SHIELD),
		fr(80, 0, SHIELD)])
	check("langzaam opzij duwen in shield = geen roll", f.state_name() == "Guard", f.state_name())
	f.free()
	f = _oos([fr(0, -40, SHIELD)])
	check("tilt omlaag in shield = geen spotdodge", f.state_name() == "Guard")
	f.free()


func _test_shield_drop() -> void:
	print("== shield drop (platform)")
	var at := Vector2(38, PLATFORM_Y)
	var f: Fighter = _oos([fr(0, -55, SHIELD)], at)
	check("vanilla notch (y = -55/80) op platform = shield drop (Fall door het platform)",
		f.state_name() == "Fall" and f.ignore_platform >= 0, f.state_name())
	idle([f], 15)
	check("valt door het platform", f.pos.y < PLATFORM_Y - 1.0, str(f.pos.y))
	f.free()
	f = _oos([fr(0, -80, SHIELD)], at)
	check("recht omlaag op platform = spotdodge (geen drop)", f.state_name() == "EscapeN")
	f.free()
	f = _oos([fr(-40, -64, SHIELD)], at)
	check("UCF: schuin omlaag op platform = shield drop", f.state_name() == "Fall")
	f.free()
	new_stage()
	var v: Fighter = make(at, 1)
	v.ucf_shield_drop = false
	idle([v], 3)
	shield_up([v])
	tick([v], [fr(-40, -64, SHIELD)])
	check("zonder UCF: schuin omlaag = spotdodge", v.state_name() == "EscapeN", v.state_name())
	v.free()
	f = _oos([fr(0, -55, SHIELD)])
	check("notch op de hoofdstage (solid) = geen drop", f.state_name() == "Guard", f.state_name())
	f.free()


# --- rolls en spotdodge ------------------------------------------------------------------------

func _test_rolls_spotdodge() -> void:
	print("== rolls en spotdodge per archetype en lengte")
	for id: String in Archetypes.IDS:
		for vh: float in [8.0, 15.0, 30.0]:
			for rel: int in [1, -1]:
				new_stage()
				var f: Fighter = make(Vector2(0, 0), 1, id, 0, vh)
				idle([f], 3)
				shield_up([f])
				var x0: float = f.pos.x
				tick([f], [fr(80 * rel, 0, SHIELD)])
				var intang: Array[int] = []
				var n: int = 0
				while f.state_name() == "Escape" and n < 200:
					if f.is_intangible():
						intang.append(f.state_frame + 1)
					tick([f])
					n += 1
				var st: FighterStats = f.stats
				var want: Array[int] = []
				for k in range(st.roll_intangible_start, st.roll_intangible_end + 1):
					want.append(k)
				var dist: float = st.roll_distance_ratio * vh
				var label: String = "%s h%.0f roll %s" % [id, vh, "F" if rel > 0 else "B"]
				check("%s: %d frames, intangible %d-%d, %.1f units%s" % [label, st.roll_frames, st.roll_intangible_start,
					st.roll_intangible_end, dist, ", omgedraaid" if rel > 0 else ""],
					n == st.roll_frames and intang == want and near(f.pos.x - x0, dist * rel, 0.01)
					and f.facing == (-1 if rel > 0 else 1) and f.state_name() == "Wait",
					"n %d x %.2f int %s facing %d" % [n, f.pos.x - x0, str(intang), f.facing])
				f.free()
			new_stage()
			var s: Fighter = make(Vector2(0, 0), 1, id, 0, vh)
			idle([s], 3)
			shield_up([s])
			tick([s], [fr(0, -80, SHIELD)])
			var sx0: float = s.pos.x
			var si: Array[int] = []
			var m: int = 0
			while s.state_name() == "EscapeN" and m < 200:
				if s.is_intangible():
					si.append(s.state_frame + 1)
				tick([s])
				m += 1
			var ss: FighterStats = s.stats
			check("%s h%.0f spotdodge: %d frames, intangible %d-%d, blijft staan" % [id, vh, ss.spotdodge_frames,
				ss.spotdodge_intangible_start, ss.spotdodge_intangible_end],
				m == ss.spotdodge_frames and si.size() == ss.spotdodge_intangible_end - ss.spotdodge_intangible_start + 1
				and si[0] == ss.spotdodge_intangible_start and near(s.pos.x, sx0), "n %d int %s" % [m, str(si)])
			s.free()
	# Roll stopt aan de rand.
	new_stage()
	var e: Fighter = make(Vector2(80, 0), 1)
	idle([e], 3)
	shield_up([e])
	tick([e], [fr(80, 0, SHIELD)])
	idle([e], 40)
	check("roll stopt aan de rand (blijft op de stage)", e.grounded and e.pos.x <= SandboxStage.MAIN_HALF_WIDTH + 0.001, str(e.pos))
	e.free()
	# Roll ontwijkt een aanval (intangible): P2 rolt door de hitbox heen.
	var fs: Array = pair(10.0)
	shield_up(fs)
	fs[0].moves["jab"] = move("jab", 30, 6, 12, Vector2(8, 8), 4.0, 10.0)
	tick(fs, [fr(0, 0, A), fr(-80, 0, SHIELD)])
	idle(fs, 14)
	check("intangible roll wordt niet geraakt", fs[1].percent == 0.0 and fs[1].state_name() == "Escape", "%.1f %s" % [fs[1].percent, fs[1].state_name()])
	free_all(fs)


# --- grab --------------------------------------------------------------------------------------

func _test_grab_whiff() -> void:
	print("== grab whiff / dash grab")
	for id: String in Archetypes.IDS:
		new_stage()
		var f: Fighter = make(Vector2(0, 0), 1, id)
		idle([f], 3)
		var total: int = f.get_move("grab").total_frames
		tick([f], [fr(0, 0, Z)])
		check("%s: Z = staande grab" % id, f.state_name() == "Grab")
		var n: int = until([f], [], func() -> bool: return f.state_name() != "Grab")
		check("%s: whiff duurt total_frames = %d" % [id, total], n == total and f.state_name() == "Wait", str(n))
		f.free()
	new_stage()
	var d: Fighter = make(Vector2(-40, 0), 1)
	idle([d], 3)
	tick([d], [fr(80, 0)])
	tick([d], [fr(80, 0, Z)])
	check("Dash + Z = dash grab", d.state_name() == "Grab" and bool(d.state.get("dash")))
	var g: MoveData = d.get_move("grab")
	var first: int = 99
	for h: HitboxData in g.hitboxes:
		first = mini(first, h.start_frame)
	var active_at: int = -1
	var box_x: float = 0.0
	var x_at: float = 0.0
	var n2: int = 0
	while d.state_name() == "Grab" and n2 < 100:
		var hb: Array[ActiveHitbox] = d.state.hitboxes()
		if active_at < 0 and not hb.is_empty():
			active_at = d.state_frame
			x_at = d.pos.x
			for a: ActiveHitbox in hb:
				box_x = maxf(box_x, a.pos.x - d.pos.x)
			check("grab-hitbox is een grab (negeert shield)", hb[0].is_grab)
		tick([d], [fr(80, 0)])
		n2 += 1
	check("dash grab: hitbox %d frames later (f%d)" % [FighterConst.DASH_GRAB_DELAY, first + FighterConst.DASH_GRAB_DELAY],
		active_at == first + FighterConst.DASH_GRAB_DELAY, str(active_at))
	check("dash grab: bereik × %.1f" % FighterConst.DASH_GRAB_REACH, near(box_x, 9.0 * FighterConst.DASH_GRAB_REACH, 0.001), str(box_x))
	check("dash grab whiff = total + %d" % FighterConst.DASH_GRAB_DELAY, n2 == g.total_frames + FighterConst.DASH_GRAB_DELAY, str(n2))
	check("dash grab glijdt door", x_at > -40.0 + 2.0)
	d.free()
	new_stage()
	var r: Fighter = make(Vector2(-60, 0), 1)
	idle([r], 3)
	for i in 30:
		tick([r], [fr(80, 0)])
	tick([r], [fr(80, 0, Z)])
	check("Run + Z = dash grab", r.state_name() == "Grab" and bool(r.state.get("dash")))
	r.free()
	new_stage()
	var aerial: Fighter = make(Vector2(0, 30), 1)
	tick([aerial])
	tick([aerial], [fr(0, 0, Z)])
	check("Z in de lucht = geen grab", aerial.state_name() != "Grab")
	aerial.free()


func _grab(fs: Array, p2_hold: InputFrame = null) -> int:
	tick(fs, [fr(0, 0, Z), p2_hold])
	return until(fs, [null, p2_hold], func() -> bool: return fs[0].state_name() == "GrabHold", 30)


func _test_grab_connect() -> void:
	print("== grab raakt")
	for vh: float in [8.0, 15.0, 30.0]:
		var fs: Array = pair(10.0, "allrounder", "allrounder", vh)
		var p1: Fighter = fs[0]
		var p2: Fighter = fs[1]
		var n: int = _grab(fs)
		var want_x: float = 9.0 + FighterConst.GRAB_HOLD_BODY_RATIO * vh
		check("victim h%.0f: GrabHold/Grabbed op state-frame %d (start_frame grab)" % [vh, n], p1.state_name() == "GrabHold"
			and p2.state_name() == "Grabbed" and n == 6, "%d %s/%s" % [n, p1.state_name(), p2.state_name()])
		check("victim h%.0f: op grab-tip + 0.1·h = %.1f, kijkt naar de holder, op de grond" % [vh, want_x],
			near(p2.pos.x - p1.pos.x, want_x) and p2.facing == -1 and p2.grounded, "%.2f" % (p2.pos.x - p1.pos.x))
		check("victim h%.0f: grab-timer = 90 + 1.7·%% = 90" % vh, p2.grab_timer <= 90 and p2.grab_timer >= 85)
		check("victim niet opnieuw grijpbaar", not p2.combat_target().grabbable)
		free_all(fs)
	# Grab door shield heen.
	var fs2: Array = pair(10.0)
	shield_up(fs2)
	_grab(fs2, fr(0, 0, SHIELD))
	check("grab negeert de shield", fs2[1].state_name() == "Grabbed")
	free_all(fs2)
	# Intangible (spotdodge) = geen grab.
	var fs3: Array = pair(10.0)
	shield_up(fs3)
	tick(fs3, [fr(0, 0, Z), fr(0, -80, SHIELD)])
	idle(fs3, 30)
	check("spotdodge ontwijkt de grab", fs3[1].state_name() != "Grabbed" and fs3[0].state_name() != "GrabHold", fs3[0].state_name())
	free_all(fs3)
	# Te ver weg = whiff.
	var fs4: Array = pair(30.0)
	_grab(fs4)
	check("buiten bereik = whiff", fs4[1].state_name() == "Wait" and fs4[0].state_name() != "GrabHold")
	free_all(fs4)
	# Victim in de lucht (vlak boven de grond) grijpen.
	new_stage()
	var p1: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var p2: Fighter = make(Vector2(10, 3), -1, "allrounder", 1)
	var fs5: Array = [p1, p2]
	idle(fs5, 1)
	p2.pos = Vector2(10, 3)
	p2.vel = Vector2.ZERO
	tick(fs5, [fr(0, 0, Z)])
	for i in 8:
		p2.pos.y = maxf(p2.pos.y, 3.0)
		p2.vel = Vector2.ZERO
		tick(fs5)
	check("victim in de lucht gegrepen (airborne)", p2.state_name() == "Grabbed" and p2.grabbed_airborne, p2.state_name())
	free_all(fs5)


func _test_pummel() -> void:
	print("== pummel")
	var fs: Array = pair(10.0)
	var p1: Fighter = fs[0]
	var p2: Fighter = fs[1]
	_grab(fs)
	tick(fs, [fr(0, 0, A)])
	check("A vóór GRAB_PULL_FRAMES = niets", p1.state_name() == "GrabHold")
	idle(fs, FighterConst.GRAB_PULL_FRAMES)
	tick(fs, [fr(0, 0, A)])
	check("A in GrabHold = Pummel", p1.state_name() == "Pummel")
	var n: int = until(fs, [], func() -> bool: return p2.percent > 0.0, 30)
	check("pummel-damage %.0f op frame %d (kan niet missen)" % [p1.stats.pummel_damage, FighterConst.PUMMEL_HIT_FRAME],
		near(p2.percent, p1.stats.pummel_damage) and n == FighterConst.PUMMEL_HIT_FRAME, "%d %.1f" % [n, p2.percent])
	var hl: int = Knockback.hitlag_frames(p1.stats.pummel_damage)
	check("pummel: hitlag voor beiden (%d), victim blijft Grabbed" % hl, p1.hitlag_frames == hl and p2.hitlag_frames == hl
		and p2.state_name() == "Grabbed")
	var x2: float = p2.pos.x
	var m: int = until(fs, [null, fr(80, 0)], func() -> bool: return p1.state_name() == "GrabHold", 60)
	check("pummel duurt %d frames (+ hitlag), terug naar GrabHold" % FighterConst.PUMMEL_FRAMES,
		m == FighterConst.PUMMEL_FRAMES - FighterConst.PUMMEL_HIT_FRAME + hl, str(m))
	check("geen SDI bij pummel", near(p2.pos.x, x2))
	free_all(fs)
	var fs2: Array = pair(10.0, "fast_faller", "allrounder")
	_grab(fs2)
	idle(fs2, FighterConst.GRAB_PULL_FRAMES)
	tick(fs2, [fr(0, 0, A)])
	idle(fs2, 12)
	check("fast_faller pummel = %.0f%%" % fs2[0].stats.pummel_damage, near(fs2[1].percent, fs2[0].stats.pummel_damage))
	free_all(fs2)


func _test_release() -> void:
	print("== grab release")
	for pct: float in [0.0, 50.0]:
		var fs: Array = pair(10.0)
		var p1: Fighter = fs[0]
		var p2: Fighter = fs[1]
		p2.percent = pct
		_grab(fs)
		var want: int = int(FighterConst.GRAB_TIMER_BASE + FighterConst.GRAB_TIMER_PER_PERCENT * pct)
		var n: int = until(fs, [], func() -> bool: return p2.state_name() != "Grabbed", 400)
		check("%.0f%%: zonder mashen los na 90 + 1.7·%% = %d frames" % [pct, want], n == want, str(n))
		check("%.0f%%: grond-release = beide GrabRelease, uit elkaar geduwd" % pct, p1.state_name() == "GrabRelease"
			and p2.state_name() == "GrabRelease" and p2.gr_vel > 0.0 and p1.gr_vel < 0.0)
		var k: int = until(fs, [], func() -> bool: return p2.state_name() == "Wait", 60)
		check("%.0f%%: GrabRelease %d frames" % [pct, FighterConst.GRAB_RELEASE_FRAMES], k == FighterConst.GRAB_RELEASE_FRAMES, str(k))
		free_all(fs)
	# Mashen: knoppen om de beurt + stick heen en weer.
	var fm: Array = pair(10.0)
	fm[1].percent = 50.0
	_grab(fm)
	var mash: Array[InputFrame] = [fr(0, 0, A), fr(80, 0), fr(0, 0, JUMP), fr(-80, 0)]
	var t: int = 0
	while fm[1].state_name() == "Grabbed" and t < 400:
		tick(fm, [null, mash[t % mash.size()]])
		t += 1
	var full: int = int(FighterConst.GRAB_TIMER_BASE + FighterConst.GRAB_TIMER_PER_PERCENT * 50.0)
	check("mashen verkort de grab (%d < %d frames)" % [t, full], t < full / 3, str(t))
	free_all(fm)
	# Lucht-release: victim gegrepen in de lucht.
	new_stage()
	var p1: Fighter = make(Vector2(0, 0), 1, "allrounder", 0)
	var p2: Fighter = make(Vector2(10, 3), -1, "allrounder", 1)
	var fa: Array = [p1, p2]
	idle(fa, 1)
	tick(fa, [fr(0, 0, Z)])
	for i in 8:
		if p2.state_name() != "Grabbed":
			p2.pos.y = maxf(p2.pos.y, 3.0)
			p2.vel = Vector2.ZERO
		tick(fa)
	until(fa, [], func() -> bool: return p2.state_name() != "Grabbed", 200)
	check("lucht-release: victim springt omhoog weg (Fall, vy > 0)", p2.state_name() == "Fall" and p2.vel.y > 0.0
		and p1.state_name() == "GrabRelease", "%s vy %.2f" % [p2.state_name(), p2.vel.y])
	free_all(fa)


## Grab en gooi in richting `stick` (wereld; P1 kijkt rechts). Geeft [fs, ticks tot de launch].
func _throw(stick: Vector2i, pct: float = 0.0, victim_stick: InputFrame = null, p1_id: String = "allrounder") -> Array:
	var fs: Array = pair(10.0, p1_id, "allrounder")
	fs[1].percent = pct
	_grab(fs)
	idle(fs, FighterConst.GRAB_PULL_FRAMES)
	tick(fs, [fr(stick.x, stick.y), victim_stick])
	var start: int = fs[0].tick_count
	var n: int = until(fs, [null, victim_stick], func() -> bool: return fs[1].state_name() != "Thrown", 120)
	return [fs, n, start]


func _test_throws() -> void:
	print("== throws")
	for id: String in Archetypes.IDS:
		for c: Array in [["fthrow", Vector2i(80, 0)], ["bthrow", Vector2i(-80, 0)], ["uthrow", Vector2i(0, 80)],
				["dthrow", Vector2i(0, -80)]]:
			var name: String = c[0]
			var r: Array = _throw(c[1], 60.0, null, id)
			var fs: Array = r[0]
			var p1: Fighter = fs[0]
			var p2: Fighter = fs[1]
			var m: MoveData = p1.get_move(name)
			var hb: HitboxData = StateThrow.launch_hitbox(m)
			var lf: int = StateThrow.launch_frame_for(m)
			var label: String = "%s %s" % [id, name]
			check("%s: Throw met de juiste move" % label, p1.state_name() == "Throw" and String(p1.state.get("move_name")) == name,
				"%s %s" % [p1.state_name(), String(p1.state.get("move_name"))])
			check("%s: launch op frame %d (= start_frame throw-hitbox, ~total/2 = %d)" % [label, lf, int(round(m.total_frames * 0.5))],
				int(r[1]) == lf and absi(lf - int(round(m.total_frames * 0.5))) <= 1, str(r[1]))
			check("%s: damage %.0f (kan niet missen)" % [label, hb.damage], near(p2.percent, 60.0 + hb.damage))
			var kb: KnockbackResult = Knockback.compute(hb, hb.damage, 60.0, p2.stats.weight, true, false, 1)
			while p2.hitlag_frames > 0:
				tick(fs)
			var lv: Vector2 = p2.kb_vel if p2.kb_vel != Vector2.ZERO else Vector2(p2.gr_vel, 0.0)
			check("%s: knockback = throw-hitbox (hoek %.0f°, KB %.1f)" % [label, kb.angle, kb.kb],
				lv.distance_to(kb.launch_vel) < 0.001, "%s vs %s" % [lv, kb.launch_vel])
			var dir_ok: bool = false
			match name:
				"fthrow":
					dir_ok = lv.x > 0.0 and lv.y > 0.0
				"bthrow":
					dir_ok = lv.x < 0.0 and lv.y > 0.0 and p2.pos.x < p1.pos.x
				"uthrow":
					dir_ok = lv.y > absf(lv.x)
				"dthrow":
					dir_ok = lv.y > 0.0
			check("%s: richting klopt (%s)" % [label, lv], dir_ok, "victim x %.1f holder x %.1f" % [p2.pos.x, p1.pos.x])
			until(fs, [], func() -> bool: return p1.state_name() != "Throw", 120)
			var dur: int = p1.tick_count - int(r[2])
			check("%s: throw duurt total_frames (%d), holder heeft geen hitlag" % [label, m.total_frames], dur == m.total_frames, str(dur))
			free_all(fs)
	# C-stick werkt ook.
	var fs: Array = pair(10.0)
	_grab(fs)
	idle(fs, FighterConst.GRAB_PULL_FRAMES)
	tick(fs, [fr(0, 0, 0, 0, 80)])
	check("C-stick omhoog = uthrow", fs[0].state_name() == "Throw" and String(fs[0].state.get("move_name")) == "uthrow")
	free_all(fs)


func _test_throw_di() -> void:
	print("== DI en geen SDI bij throws")
	var r0: Array = _throw(Vector2i(80, 0), 80.0)
	var fs0: Array = r0[0]
	while fs0[1].hitlag_frames > 0:
		tick(fs0)
	var base: Vector2 = fs0[1].kb_vel
	free_all(fs0)
	# Loodrecht op 45° (omhoog-links) = DI tegen de klok in.
	var di_in: InputFrame = fr(-56, 56)
	var r1: Array = _throw(Vector2i(80, 0), 80.0, di_in)
	var fs1: Array = r1[0]
	var x_hit: Vector2 = fs1[1].pos
	var moved: bool = false
	while fs1[1].hitlag_frames > 0:
		tick(fs1, [null, fr(80, 0) if fs1[1].hitlag_frames % 2 == 0 else fr(-80, 0)])
		if fs1[1].hitlag_frames > 0 and fs1[1].pos != x_hit:
			moved = true
	check("geen SDI tijdens de throw-hitlag", not moved)
	free_all(fs1)
	var r2: Array = _throw(Vector2i(80, 0), 80.0, di_in)
	var fs2: Array = r2[0]
	while fs2[1].hitlag_frames > 0:
		tick(fs2, [null, di_in])
	var lv: Vector2 = fs2[1].kb_vel
	var delta: float = rad_to_deg(base.angle_to(lv))
	var want: float = Knockback.di_angle_delta(base, di_in.stick_f())
	check("DI op een throw: hoek %.1f° verschoven (verwacht %.1f°)" % [delta, want], near(delta, want, 0.05) and absf(delta) > 10.0)
	free_all(fs2)


func _test_throw_tumble_tech() -> void:
	print("== throw -> tumble -> tech")
	for do_tech: bool in [true, false]:
		var fs: Array = pair(10.0)
		var p1: Fighter = fs[0]
		var p2: Fighter = fs[1]
		# Lage hoek, vaste KB 85 (tumble, hitstun 34): landt tijdens de hitstun.
		var m: MoveData = move("fthrow", 40, 20, 20, Vector2(9, 8), 3.0, 4.0, 20.0, 85.0, 0.0)
		p1.moves["fthrow"] = m
		_grab(fs)
		idle(fs, FighterConst.GRAB_PULL_FRAMES)
		tick(fs, [fr(80, 0)])
		until(fs, [], func() -> bool: return p2.state_name() != "Thrown", 60)
		check("throw KB 85 = tumble (DamageFly)", p2.state_name() == "DamageFly")
		while p2.hitlag_frames > 0:
			tick(fs)
		tick(fs)
		check("throw-launch: van de grond af", not p2.grounded)
		var pressed: bool = false
		var n: int = 0
		while not p2.grounded and n < 200:
			var inp: InputFrame = null
			if do_tech and not pressed and p2.hitlag_frames == 0 and p2.pos.y < 3.0 and p2.vel.y + p2.kb_vel.y < 0.0:
				inp = fr(0, 0, SHIELD)
				pressed = true
			tick(fs, [null, inp])
			n += 1
		if do_tech:
			check("tumble + shield vlak voor de grond = tech", p2.state_name() == "Tech", p2.state_name())
		else:
			check("tumble zonder tech = missed tech (DownBound): tech chase", p2.state_name() == "DownBound", p2.state_name())
		free_all(fs)


func _test_grab_break() -> void:
	print("== grab verbroken")
	var fs: Array = pair(10.0)
	var p1: Fighter = fs[0]
	var p2: Fighter = fs[1]
	_grab(fs)
	# Holder wordt geraakt (handmatig event, zoals een derde speler of projectiel).
	var ev := HitEvent.new()
	ev.kind = HitEvent.Kind.HIT
	ev.attacker = 7
	ev.defender = 0
	ev.damage = 5.0
	var hb: HitboxData = MoveSet.make_hitbox(0, 0, 0, Vector2.ZERO, 3.0, 5.0, 361.0, 30.0, 50.0)
	ev.hitbox = ActiveHitbox.make(hb, 7, 1, p1.pos, -1)
	ev.knockback = Knockback.compute(hb, 5.0, 0.0, 87.0, true, false, -1)
	ev.defender_hitlag = 5
	p1.receive_hit(ev)
	check("holder geraakt = grab los, victim GrabRelease", p1.grab_partner == null and p2.grab_partner == null
		and p2.state_name() == "GrabRelease", p2.state_name())
	free_all(fs)
	# KO van de victim tijdens de grab: holder komt los.
	var fs2: Array = pair(10.0)
	_grab(fs2)
	fs2[1].change_state("Dead")
	check("victim weg = holder GrabRelease", fs2[0].state_name() == "GrabRelease" and fs2[0].grab_partner == null)
	free_all(fs2)


func _test_special_hook() -> void:
	print("== special-hook")
	new_stage()
	var f: Fighter = make(Vector2(0, 0), 1)
	idle([f], 3)
	var got: Array = []
	tick([f], [fr(0, 0, B)])
	check("zonder hook: B doet niets", f.state_name() == "Wait" and got.is_empty())
	idle([f], 2)
	f.special_hook = func(fi: Fighter, inp: Dictionary) -> bool:
		got.append([fi.state_name(), inp])
		return true
	# Stick eerst omhoog (tilt, geen tap jump), dan B: up-B.
	for i in 5:
		tick([f], [fr(0, 45)])
	tick([f], [fr(0, 70)])
	tick([f], [fr(0, 70, B)])
	check("Wait + B + omhoog -> hook(dir up, grounded)", got.size() == 1 and got[0][1]["dir"] == "up" and got[0][1]["grounded"],
		str(got))
	idle([f], 2)
	tick([f], [fr(-70, 0, B)])
	check("B + stick achteruit -> side, back", got.size() == 2 and got[1][1]["dir"] == "side" and got[1][1]["back"], str(got))
	tick([f])
	tick([f], [fr(0, 0, B)])
	check("B neutraal -> neutral", got.size() == 3 and got[2][1]["dir"] == "neutral", str(got))
	f.free()
	# Up-B uit shield via jumpsquat.
	var g: Fighter = _oos([fr(0, 0, SHIELD | JUMP)])
	var got2: Array = []
	g.special_hook = func(fi: Fighter, inp: Dictionary) -> bool:
		got2.append([fi.state_name(), inp])
		return true
	tick([g], [fr(0, 80, SHIELD | B)])
	check("up-B OoS: hook vanuit KneeBend (dir up)", got2.size() == 1 and got2[0][0] == "KneeBend" and got2[0][1]["dir"] == "up")
	g.free()
	# Lucht.
	new_stage()
	var a: Fighter = make(Vector2(0, 40), 1)
	var got3: Array = []
	a.special_hook = func(_fi: Fighter, inp: Dictionary) -> bool:
		got3.append(inp)
		return true
	tick([a])
	tick([a], [fr(0, -70, B)])
	check("Fall + B + omlaag -> hook(dir down, in de lucht)", got3.size() == 1 and got3[0]["dir"] == "down" and not got3[0]["grounded"])
	a.free()


func _test_poses() -> void:
	print("== poses in het rig")
	var lib: PoseLibrary = PoseLibrary.load_for("_dummy")
	for p: String in ["shield", "shield_stun", "roll_forward", "roll_back", "spotdodge", "shield_break_dizzy", "grabbed",
			"thrown", "atk_grab", "atk_grab_dash", "atk_grab_hold", "atk_pummel", "atk_fthrow", "atk_bthrow", "atk_uthrow",
			"atk_dthrow", "tumble", "missed_tech_lie", "damage_low"]:
		check("pose %s bestaat" % p, lib.poses.has(p))


func _test_determinism() -> void:
	print("== determinisme")
	var a: Array = _det_run()
	var b: Array = _det_run()
	check("shield/grab/pummel/throw-reeks twee keer identiek (%d frames)" % a.size(), a == b and a.size() > 100)


func _det_run() -> Array:
	var fs: Array = pair(10.0)
	var out: Array = []
	fs[0].moves["jab"] = move("jab", 30, 2, 3, Vector2(8, 8), 3.0, 9.0)
	for t in 260:
		var i1: InputFrame = null
		var i2: InputFrame = fr(0, 0, 0, 0, 0, 0.7) if t < 40 else null
		if t == 15:
			i1 = fr(0, 0, A)
		if t == 60:
			i1 = fr(0, 0, Z)
		if t == 75 or t == 105:
			i1 = fr(0, 0, A)
		if t == 140:
			i1 = fr(0, 80)
		if t > 70 and t % 3 == 0:
			i2 = fr(80 if t % 2 == 0 else -80, 0)
		tick(fs, [i1, i2])
		out.append(fs[0].snapshot() + fs[1].snapshot())
	free_all(fs)
	return out
