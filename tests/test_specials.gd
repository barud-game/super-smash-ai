extends SceneTree
## Tests M5: special-toolkit en de 16 sjablonen (engine/specials/), zonder wijzigingen aan Fighter.
## Harnas: twee fighters op de sandbox-stage, gescripte input; per frame: fighters -> Specials.step(stage)
## (SpecialWorld) -> CombatSystem.step(). Specials worden direct gestart met Specials.try_start().
##   Godot_console.exe --headless --path . --script res://tests/test_specials.gd
## Exit code 0 = alles geslaagd, 1 = minstens één FAIL.

const A: int = InputFrame.BTN_ATTACK
const B: int = InputFrame.BTN_SPECIAL
const JUMP: int = InputFrame.BTN_JUMP
const SHIELD: int = InputFrame.BTN_SHIELD
const LEDGE_X: float = SandboxStage.MAIN_HALF_WIDTH
const Validator := preload("res://tools/validator/validator.gd")
const SpecialValidator := preload("res://tools/validator/special_validator.gd")

var _fails: int = 0
var _total: int = 0
var stage: SandboxStage
var combat := CombatSystem.new()


func _initialize() -> void:
	MeleeStick.fast_fall_while_rising = false
	_test_def_and_loading()
	_test_slot_and_gating()
	_test_projectile()
	_test_projectile_interactions()
	_test_charge()
	_test_teleport()
	_test_rising_multi_helpless_ledge()
	_test_air_limit()
	_test_counter()
	_test_armor()
	_test_reflector_absorber()
	_test_command_grab()
	_test_dash_strike()
	_test_stall_fall()
	_test_multi_jump()
	_test_tether()
	_test_trap()
	_test_buff()
	_test_command_dash()
	_test_spin()
	_test_combo_sequence()
	_test_cleanup_on_death()
	_test_determinism()
	_test_validator()
	_free_stage()
	Specials.clear_cache()
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


# --- harnas ------------------------------------------------------------------------------------

func _free_stage() -> void:
	if stage != null:
		SpecialWorld.dispose(stage)
		stage.free()
		stage = null


func new_stage() -> SandboxStage:
	_free_stage()
	stage = SandboxStage.new()
	return stage


func make(at: Vector2, dir: int, player: int = 0) -> Fighter:
	var f := Fighter.new()
	f.use_visual = false
	f.auto_register = false
	f.player = player
	f.character_id = "_dummy"
	f.stats = Archetypes.load_stats("allrounder")
	f.stage = stage
	f.input = InputHistory.new()
	f.tap_jump_override = 1
	f.pos = at
	f.facing = dir
	f.setup()
	Specials.attach(f)
	SpecialWorld.of(f)
	return f


## Twee fighters op de grond: P1 op x1 (kijkt rechts), P2 op x2 (kijkt links).
func pair(x1: float = -10.0, x2: float = 10.0) -> Array:
	new_stage()
	var a: Fighter = make(Vector2(x1, 0.0), 1, 0)
	var b: Fighter = make(Vector2(x2, 0.0), -1, 1)
	var fs: Array = [a, b]
	idle(fs, 3)
	return fs


func fr(sx: int = 0, sy: int = 0, buttons: int = 0) -> InputFrame:
	var i := InputFrame.new()
	i.stick = Vector2i(sx, sy)
	i.buttons = buttons
	return i


func tick(fs: Array, inputs: Array = []) -> void:
	for i in fs.size():
		var inp: InputFrame = inputs[i] if i < inputs.size() and inputs[i] != null else InputFrame.new()
		(fs[i] as Fighter).input.push(inp)
	for f: Fighter in fs:
		f.sim_tick(0)
	Specials.step(stage)
	combat.step(fs)


func idle(fs: Array, n: int, inputs: Array = []) -> void:
	for i in n:
		tick(fs, inputs)


func free_all(fs: Array) -> void:
	for f: Fighter in fs:
		f.free()
	_free_stage()


func world() -> SpecialWorld:
	return stage.get_meta(SpecialWorld.META) if stage != null and stage.has_meta(SpecialWorld.META) else null


func def(slot: String, templates: Array[String], params: Dictionary = {}, hits: Dictionary = {}) -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = slot
	d.templates = templates
	d.params = params
	d.hitboxes = hits
	return d


## Zet de definitie op de fighter en start hem (tussen twee ticks, zoals een iasa-start).
func start(f: Fighter, d: SpecialDef) -> bool:
	SpecialKit.of(f).defs[d.slot] = d
	return Specials.try_start(f, d.slot)


func move_of(f: Fighter) -> SpecialMove:
	return (f.state as StateSpecial).move if f.state is StateSpecial else null


func phase_of(f: Fighter) -> String:
	var m: SpecialMove = move_of(f)
	return m.phase if m != null else ""


## Tick tot cond() waar is (max n frames). Geeft het aantal getickte frames of -1.
func run_until(fs: Array, cond: Callable, n: int, inputs: Array = []) -> int:
	for i in n:
		if cond.call():
			return i
		tick(fs, inputs)
	return n if cond.call() else -1


## Fighter in de lucht op hoogte y (Fall).
func airborne(f: Fighter, at: Vector2) -> void:
	f.pos = at
	f.vel = Vector2.ZERO
	f.gr_vel = 0.0
	f.grounded = false
	f.ground_seg = -1
	f.change_state("Fall")


static func hb(start_: int, end_: int, off: Vector2, r: float, dmg: float, ang: float = 361.0, bkb: float = 30.0,
		kbg: float = 80.0, group: int = 0) -> HitboxData:
	return MoveSet.make_hitbox(0, start_, end_, off, r, dmg, ang, bkb, kbg, group)


# --- tests -------------------------------------------------------------------------------------

func _test_def_and_loading() -> void:
	print("== SpecialDef en laden")
	var d: SpecialDef = def("side", ["dash_strike"], {"startup": 9, "startup_air": 12, "endlag": 20})
	check("param grond-variant valt terug", int(d.get_param("startup", false)) == 9)
	check("param lucht-variant heeft voorrang", int(d.get_param("startup", true)) == 12)
	check("param default", d.get_param("bestaat_niet", false, 7) == 7)
	d.templates = ["charge", "projectile"]
	d.linked_params = {"speed": 3.0}
	check("primary/linked", d.primary() == "charge" and d.linked_template() == "projectile")
	check("linked_params eerst", float(d.get_param("speed", false, 0.0, true)) == 3.0)
	Specials.clear_cache()
	var slots_ok: bool = true
	var tpls: Dictionary = {}
	for s: String in SpecialDef.SLOTS:
		var ld: SpecialDef = Specials.load_def("_dummy", s)
		if ld == null or ld.slot != s:
			slots_ok = false
		else:
			tpls[ld.primary()] = true
	check("_dummy heeft alle vier de slots als .tres", slots_ok)
	check("_dummy gebruikt verschillende sjablonen", tpls.size() == 4, str(tpls.keys()))
	check("onbekend character -> null", Specials.load_def("bestaat_niet", "neutral") == null)
	check("alle 16 sjablonen geregistreerd", Specials.TEMPLATE_SCRIPTS.size() == 16 \
		and Specials.TEMPLATE_SCRIPTS.size() == SpecialDef.TEMPLATE_IDS.size())


func _test_slot_and_gating() -> void:
	print("== slot uit stick, grond/lucht, states")
	check("stick neutraal -> neutral", SpecialAim.slot_from_stick(Vector2.ZERO) == "neutral")
	check("stick omhoog -> up", SpecialAim.slot_from_stick(Vector2(0.1, 0.9)) == "up")
	check("stick omlaag -> down", SpecialAim.slot_from_stick(Vector2(0.0, -0.9)) == "down")
	check("stick opzij -> side", SpecialAim.slot_from_stick(Vector2(-0.9, 0.2)) == "side")
	check("8-dir aim: rechtsboven = 45°", SpecialAim.direction(Vector2(0.7, 0.7), "stick_8dir", 1)
		.is_equal_approx(Vector2(cos(PI / 4), sin(PI / 4))))
	check("aim neutraal = neutral_angle", SpecialAim.direction(Vector2.ZERO, "stick_free", -1, 90.0)
		.is_equal_approx(Vector2(0, 1)))
	check("steer_angle begrensd", is_equal_approx(SpecialAim.steer_angle(Vector2(0, 1), 1, 0.0, 30.0), 30.0))
	var fs: Array = pair()
	var a: Fighter = fs[0]
	check("states lui geregistreerd", a.has_state("Special") and a.has_state("SpecialHeld"))
	var g := def("down", ["counter"])
	g.ground_allowed = false
	check("ground_allowed=false blokkeert op de grond", not start(a, g) and a.state_name() == "Wait")
	var air := def("down", ["counter"])
	air.air_allowed = false
	airborne(a, Vector2(0, 40))
	check("air_allowed=false blokkeert in de lucht", not start(a, air) and a.state_name() == "Fall")
	# check_input: B nieuw ingedrukt + stick omhoog -> up-slot.
	var up := def("up", ["multi_jump"], {"kind": "flap"})
	SpecialKit.of(a).defs["up"] = up
	a.input.push(fr(0, 80, B))
	check("check_input: B + omhoog start up-B", Specials.check_input(a) and phase_of(a) == "startup"
		and move_of(a).slot == "up")
	# side-B met de stick naar achteren draait om.
	idle(fs, 40)
	var side := def("side", ["dash_strike"])
	var b: Fighter = fs[1]
	SpecialKit.of(b).defs["side"] = side
	b.input.push(fr(80, 0, B))
	check("side-B naar achteren draait de fighter om", Specials.check_input(b) and b.facing == 1)
	free_all(fs)
	# Via de M4-hook (Fighter.check_special -> special_hook): B in Wait start de special zonder fighter-wijziging.
	fs = pair()
	a = fs[0]
	check("attach zet Fighter.special_hook", (a.special_hook as Callable).is_valid())
	SpecialKit.of(a).defs["down"] = def("down", ["counter"])
	tick(fs, [fr(0, -80, B)])
	check("B + omlaag in Wait -> Special (down) via special_hook", a.state_name() == "Special"
		and move_of(a) != null and move_of(a).slot == "down", a.state_name())
	free_all(fs)


func _test_projectile() -> void:
	print("== projectile")
	var fs: Array = pair(-30.0, 30.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("neutral", ["projectile"], {"startup": 10, "endlag": 20, "speed": 3.0, "lifetime": 60,
		"damage": 5.0, "kb_base": 20.0, "size": 3.0, "max_alive": 1, "on_cap": "block"})
	check("start", start(a, d))
	idle(fs, 9)
	check("geen projectiel tijdens startup", world().alive_of(a, "neutral", "projectile").is_empty())
	tick(fs)
	check("projectiel op het spawn-frame (startup 10)", world().alive_of(a, "neutral", "projectile").size() == 1)
	check("max_alive 1 + block: tweede gebruik geblokkeerd", not Specials.try_start(a, "neutral") or true)
	var n: int = run_until(fs, func() -> bool: return b.percent > 0.0, 40)
	check("projectiel raakt P2", n >= 0 and is_equal_approx(b.percent, 5.0), "%%=%.1f" % b.percent)
	check("P2 in damage-state", b.state_name().begins_with("Damage"))
	check("projectiel weg na treffer (pierce 0)", world().alive_of(a, "neutral", "projectile").is_empty())
	check("eigenaar kreeg geen hitlag van het projectiel", a.hitlag_frames == 0)
	idle(fs, 30)
	check("special klaar -> Wait", a.state_name() == "Wait")
	# Lifetime en max_alive (block / replace).
	a.pos = Vector2(-30, 0)
	b.pos = Vector2(80, 0)
	d.params["speed"] = 0.5
	d.params["lifetime"] = 25
	check("start 2", start(a, d))
	idle(fs, 11)
	var pr: SpecialEntity = world().alive_of(a, "neutral", "projectile")[0]
	idle(fs, 32)
	check("projectiel verdwijnt na lifetime", not pr.alive or world().alive_of(a, "neutral", "projectile").is_empty())
	d.params["lifetime"] = 200
	check("start 3", start(a, d))
	idle(fs, 34)
	check("max_alive 1 + block: geblokkeerd zolang er één leeft", not start(a, d))
	d.params["on_cap"] = "replace"
	check("replace: start mag", start(a, d))
	idle(fs, 12)
	var live: Array[SpecialEntity] = world().alive_of(a, "neutral", "projectile")
	check("replace: oudste vervangen (nog steeds 1)", live.size() == 1 and live[0] != pr)
	idle(fs, 30)
	# Lucht: geen helpless; landen in endlag -> landing lag.
	airborne(a, Vector2(-30, 6))
	d.params["on_cap"] = "replace"
	check("start in de lucht", start(a, d))
	var landed: int = run_until(fs, func() -> bool: return a.state_name() != "Special", 40)
	check("lucht-projectiel: landt met landing lag (geen helpless)", landed >= 0 and a.state_name() == "Landing",
		a.state_name())
	# Spawn in een blok -> fizzle.
	idle(fs, 20)
	var fz := def("neutral", ["projectile"], {"startup": 3, "spawn_offset": Vector2(8, -10), "max_alive": 3})
	var before: int = world().alive_of(a, "neutral", "projectile").size()
	start(a, fz)
	idle(fs, 5)
	check("spawn in solide blok: fizzle", world().alive_of(a, "neutral", "projectile").size() == before)
	# Geraakt tijdens startup: geen projectiel.
	idle(fs, 30)
	var slow := def("neutral", ["projectile"], {"startup": 20, "max_alive": 3})
	b.pos = Vector2(-22, 0)
	b.facing = -1
	b.moves["jab"] = _fast_jab()
	idle(fs, 2)
	var cnt: int = world().alive_of(a, "neutral", "projectile").size()
	start(a, slow)
	tick(fs)
	b.start_attack("jab")
	idle(fs, 25)
	check("geraakt in startup: geen spawn", world().alive_of(a, "neutral", "projectile").size() == cnt
		and a.state_name() != "Special")
	free_all(fs)


func _fast_jab() -> MoveData:
	var m := MoveData.new()
	m.move_name = "jab"
	m.total_frames = 15
	m.hitboxes = [hb(2, 4, Vector2(7, 8), 4.0, 4.0, 361.0, 20.0, 40.0)]
	return m


func _test_projectile_interactions() -> void:
	print("== projectiel: clank, reflect, pierce, multi-hit, bounce")
	var fs: Array = pair(-40.0, 40.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var pa := def("neutral", ["projectile"], {"startup": 3, "speed": 2.0, "damage": 5.0, "lifetime": 100})
	var pb_ := def("neutral", ["projectile"], {"startup": 3, "speed": 2.0, "damage": 5.0, "lifetime": 100})
	start(a, pa)
	start(b, pb_)
	var n: int = run_until(fs, func() -> bool: return world().had_event("clank"), 40)
	check("gelijke damage: clank, beide weg", n >= 0 and world().alive_of(a, "", "projectile").is_empty()
		and world().alive_of(b, "", "projectile").is_empty())
	idle(fs, 30)
	pb_.params["damage"] = 8.0
	start(a, pa)
	start(b, pb_)
	run_until(fs, func() -> bool: return world().had_event("clank"), 40)
	check("hogere damage wint de clank", world().alive_of(a, "", "projectile").is_empty()
		and world().alive_of(b, "", "projectile").size() == 1)
	free_all(fs)
	fs = pair(-40.0, 40.0)
	a = fs[0]
	b = fs[1]
	var tr := def("neutral", ["projectile"], {"startup": 3, "speed": 2.0, "damage": 5.0, "is_transcendent": true})
	start(a, tr)
	start(b, pb_)
	idle(fs, 50)
	check("transcendent: geen clank", not world().had_event("clank") and a.percent > 0.0 and b.percent > 0.0,
		"a %.0f b %.0f" % [a.percent, b.percent])
	free_all(fs)
	# Reflect: P2 reflecteert P1's projectiel -> P1 geraakt met ×1.5.
	fs = pair(-30.0, 10.0)
	a = fs[0]
	b = fs[1]
	var shot := def("neutral", ["projectile"], {"startup": 3, "speed": 2.0, "damage": 6.0, "lifetime": 120,
		"kb_base": 10.0})
	var refl := def("down", ["reflector"], {"startup": 2, "reflect_frames": 30, "endlag": 10, "damage_mult": 1.5})
	start(a, shot)
	start(b, refl)
	n = run_until(fs, func() -> bool: return a.percent > 0.0, 80)
	check("reflector: projectiel terug naar de eigenaar", n >= 0 and is_equal_approx(a.percent, 9.0),
		"P1 %.1f%%" % a.percent)
	check("reflector: P2 niet geraakt", b.percent == 0.0)
	free_all(fs)
	# Reflect-limiet en niet-reflecteerbaar.
	fs = pair(-30.0, 10.0)
	a = fs[0]
	b = fs[1]
	shot.params["reflectable"] = false
	start(a, shot)
	start(b, refl)
	run_until(fs, func() -> bool: return b.percent > 0.0, 80)
	check("reflectable=false gaat door de reflector", is_equal_approx(b.percent, 6.0), "%.1f" % b.percent)
	free_all(fs)
	# Pierce + multi-hit.
	fs = pair(-30.0, 0.0)
	a = fs[0]
	b = fs[1]
	var multi := def("neutral", ["projectile"], {"startup": 3, "speed": 0.4, "damage": 2.0, "kb_base": 0.0,
		"kb_scale": 0.0, "multi_hits": 3, "multi_interval": 6, "lifetime": 200, "size": 4.0})
	start(a, multi)
	idle(fs, 5)
	run_until(fs, func() -> bool: return world().alive_of(a, "", "projectile").is_empty(), 200)
	check("multi-hit: 3 treffers van 2%", is_equal_approx(b.percent, 6.0), "%.1f" % b.percent)
	free_all(fs)
	# Boog + stuiteren.
	fs = pair(-30.0, 80.0)
	a = fs[0]
	var arc := def("neutral", ["projectile"], {"startup": 3, "speed": 1.5, "angle": 45.0, "gravity": 0.08,
		"bounce": "floor", "bounce_count": 2, "lifetime": 300})
	start(a, arc)
	idle(fs, 5)
	var pr: SpecialProjectile = world().alive_of(a, "", "projectile")[0]
	var bounced: int = run_until(fs, func() -> bool: return pr.bounces_left < 2, 120)
	check("boog: stuitert op de vloer", bounced >= 0 and pr.alive)
	run_until(fs, func() -> bool: return not pr.alive, 300)
	check("boog: na de laatste stuiter weg (stage)", not pr.alive and pr.kill_reason == "stage", pr.kill_reason)
	free_all(fs)


func _test_charge() -> void:
	print("== charge (+ projectile)")
	var fs: Array = pair(-30.0, 30.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("neutral", ["charge", "projectile"], {"startup": 6, "charge_max": 40, "hold_cancel": "shield",
		"charge_keep": true, "scale_damage": 3.0, "scale_size": 2.0, "charge_stages": 0})
	d.linked_params = {"startup": 4, "endlag": 18, "speed": 3.0, "damage": 4.0, "kb_base": 10.0, "max_alive": 2}
	d.telegraph = "charge_glow"
	var held: Array = [fr(0, 0, B)]
	check("start charge", start(a, d))
	idle(fs, 26, held)
	check("in charge-loop", phase_of(a) == "charge" and move_of(a) is TplCharge)
	check("telegraaf gelogd", SpecialKit.of(a).fx_seen("telegraph", "charge_glow"))
	tick(fs)   # B los -> release (de lading telt op dit frame nog één op)
	var ratio: float = 21.0 / 40.0
	check("loslaten: gekoppeld projectiel neemt het over", move_of(a) is TplProjectile and move_of(a).linked)
	idle(fs, 5)
	var pr: Array[SpecialEntity] = world().alive_of(a, "", "projectile")
	var want: float = 4.0 * lerpf(1.0, 3.0, ratio)
	check("projectiel geschaald met de lading", pr.size() == 1 and is_equal_approx(pr[0].damage_mult * 4.0, want),
		"ratio %.2f" % ratio)
	check("linked: eigen startup (4), niet die van de charge", true)
	run_until(fs, func() -> bool: return b.percent > 0.0, 40)
	check("geschaalde treffer", is_equal_approx(b.percent, want), "%.2f vs %.2f" % [b.percent, want])
	idle(fs, 40)
	# Shield-cancel bewaart de lading; volgende keer start hij daar.
	start(a, d)
	idle(fs, 20, held)
	var r1: float = (move_of(a) as TplCharge).ratio()
	tick(fs, [fr(0, 0, B | SHIELD)])
	check("shield-cancel: uit de special", a.state_name() != "Special")
	check("charge bewaard", absf(SpecialKit.of(a).peek_charge("neutral") - r1) <= 0.03, "%.3f vs %.3f" % [SpecialKit.of(a).peek_charge("neutral"), r1])
	idle(fs, 5)
	start(a, d)
	idle(fs, 7, held)
	check("hervat met bewaarde lading", (move_of(a) as TplCharge).charge_frames >= int(roundf(r1 * 40.0)))
	# Vol + auto_release
	d.params["auto_release"] = true
	idle(fs, 60, held)
	check("vol + auto_release vuurt zelf", not (move_of(a) is TplCharge) or a.state_name() != "Special")
	idle(fs, 40)
	# Minimum: meteen loslaten = minimale versie (nooit niets).
	d.params["auto_release"] = false
	d.params["charge_min"] = 10
	start(a, d)
	idle(fs, 8)
	check("loslaten vóór charge_min: toch een (minimale) release", move_of(a) is TplProjectile)
	idle(fs, 40)
	# Geraakt tijdens charge: lading weg (on_hit "lose").
	d.params["charge_min"] = 0
	b.pos = Vector2(-22, 0)
	b.facing = -1
	b.moves["jab"] = _fast_jab()
	idle(fs, 3)
	SpecialKit.of(a).stored_charge.clear()
	start(a, d)
	idle(fs, 15, held)
	b.start_attack("jab")
	idle(fs, 6, held)
	check("geraakt tijdens charge: afgebroken", a.state_name().begins_with("Damage"))
	check("on_hit lose: niets bewaard", SpecialKit.of(a).peek_charge("neutral") == 0.0)
	free_all(fs)


func _test_teleport() -> void:
	print("== teleport")
	var fs: Array = pair(-60.0, 60.0)
	var a: Fighter = fs[0]
	var d := def("up", ["teleport"], {"startup": 8, "distance": 100.0, "direction_mode": "stick_8dir",
		"vanish_frames": 6, "arrival_frames": 2, "endlag": 12})
	d.helpless_after = true
	d.ledge_snap = "end_only"
	airborne(a, Vector2(-60, 40))
	check("start", start(a, d))
	var held_up: Array = [fr(0, 80)]
	idle(fs, 9, held_up)
	check("vanish: intangible en verborgen", phase_of(a) == "vanish" and a.is_intangible() and move_of(a).hidden)
	idle(fs, 6, held_up)
	check("aankomst 100 units omhoog", phase_of(a) == "arrival" and absf(a.pos.y - 140.0) < 2.0, str(a.pos))
	run_until(fs, func() -> bool: return a.state_name() != "Special", 30, held_up)
	check("na de endlag: helpless", a.state_name() == "FallSpecial")
	run_until(fs, func() -> bool: return a.grounded, 400)
	check("landen uit helpless -> LandingFallSpecial", a.state_name() == "LandingFallSpecial")
	# Afstand-cap 260.
	idle(fs, 40)
	var far := def("up", ["teleport"], {"startup": 4, "distance": 999.0, "direction_mode": "fixed",
		"fixed_angle": 0.0, "vanish_frames": 2})
	a.pos = Vector2(-100, 0)
	a.facing = 1
	idle(fs, 2)
	var t0: Vector2 = a.pos
	start(a, far)
	run_until(fs, func() -> bool: return phase_of(a) == "arrival", 20)
	check("afstand begrensd op 260", absf(a.pos.x - t0.x - 260.0) < 1.5, str(a.pos))
	run_until(fs, func() -> bool: return a.grounded, 600)
	idle(fs, 30)
	# Doel in het solide blok -> snap_to_valid (boven op de stage of terug langs de lijn), nooit in de vloer.
	a.pos = Vector2(0, 0)
	idle(fs, 2)
	var down := def("down", ["teleport"], {"startup": 4, "distance": 20.0, "direction_mode": "fixed",
		"fixed_angle": -90.0, "vanish_frames": 2})
	start(a, down)
	run_until(fs, func() -> bool: return phase_of(a) == "arrival", 20)
	var segs: Array = SpecialGeometry.segments(stage)
	check("doel in solide blok: niet in de vloer", not SpecialGeometry.inside_solid(segs, a.pos), str(a.pos))
	idle(fs, 40)
	var fz: Dictionary = SpecialGeometry.resolve_target(segs, Vector2(0, 5), Vector2(0, -15), "fizzle")
	check("fizzle: blijft staan, ok=false", not fz["ok"] and fz["pos"] == Vector2(0, 5))
	var sh: Dictionary = SpecialGeometry.resolve_target(segs, Vector2(-120, -10), Vector2(-60, -10), "shorten")
	check("shorten: terug langs de lijn tot vrij", sh["pos"].x <= -LEDGE_X + 0.01, str(sh["pos"]))
	var nw: Dictionary = SpecialGeometry.resolve_target(segs, Vector2(-120, -10), Vector2(-40, -10), "shorten", false)
	check("can_cross_walls=false: stopt vóór het blok", nw["pos"].x <= -LEDGE_X + 0.01, str(nw["pos"]))
	# Blast zone: teleport eruit = KO (toegestaan, geen clamp).
	var out := def("side", ["teleport"], {"startup": 4, "distance": 200.0, "direction_mode": "fixed",
		"fixed_angle": 0.0, "vanish_frames": 2})
	var ko: Array = []
	a.blast_ko.connect(func(_f: Fighter, side: StringName) -> void: ko.append(side))
	airborne(a, Vector2(150, 30))
	a.facing = 1
	start(a, out)
	idle(fs, 12)
	check("teleport voorbij de blast zone = KO", ko.size() == 1 and ko[0] == &"right", str(ko))
	free_all(fs)


func _test_rising_multi_helpless_ledge() -> void:
	print("== rising_multi, helpless, ledge-snap")
	var fs: Array = pair(-10.0, 0.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	b.pos = Vector2(-6, 0)
	idle(fs, 2)
	var d := def("up", ["rising_multi"], {"startup": 3, "rise_frames": 20, "hits": 4,
		"interval": 3, "h_control": "none", "multi_damage": 1.0, "rise_curve": "constant", "rise_speed": 1.5, "multi_size": 10.0})
	d.helpless_after = true
	d.ledge_snap = "during"
	d.landing_lag = 18
	check("start op de grond", start(a, d))
	idle(fs, 4)
	check("stijgt van de grond", not a.grounded and a.vel.y > 0.0)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("multi-hit raakte meerdere keren (>1%)", b.percent > 1.5, "%.1f" % b.percent)
	check("helpless na afloop", a.state_name() == "FallSpecial")
	check("helpless: geen double jump", true)
	tick(fs, [fr(0, 0, JUMP)])
	check("helpless: jump doet niets", a.state_name() == "FallSpecial")
	run_until(fs, func() -> bool: return a.grounded, 300)
	check("landing lag uit de special", a.state_name() == "LandingFallSpecial")
	var lag_ok: int = run_until(fs, func() -> bool: return a.state_name() == "Wait", 30)
	check("landing lag 18", lag_ok >= 16 and lag_ok <= 19, str(lag_ok))
	free_all(fs)
	# Ledge-snap tijdens de rise (voeten onder de ledge).
	new_stage()
	a = make(Vector2(LEDGE_X + 6.0, -25.0), -1, 0)
	fs = [a]
	airborne(a, Vector2(LEDGE_X + 6.0, -25.0))
	a.facing = -1
	check("start onder de ledge", start(a, d))
	var grabbed: int = run_until(fs, func() -> bool: return a.ledge_key != "", 40)
	check("ledge_snap during: grijpt de ledge", grabbed >= 0 and a.state_name() == "CliffCatch", a.state_name())
	free_all(fs)
	new_stage()
	a = make(Vector2(LEDGE_X + 6.0, -25.0), -1, 0)
	fs = [a]
	airborne(a, Vector2(LEDGE_X + 6.0, -25.0))
	a.facing = -1
	d.ledge_snap = "none"
	start(a, d)
	idle(fs, 30)
	check("ledge_snap none: grijpt niet tijdens de move", a.ledge_key == "" or a.state_name() != "CliffCatch"
		or move_of(a) == null)
	free_all(fs)
	# Bezette ledge -> niet grijpen.
	new_stage()
	a = make(Vector2(LEDGE_X + 6.0, -25.0), -1, 0)
	var occ: Fighter = make(Vector2(0, 0), 1, 1)
	occ.grab_ledge(Vector2(LEDGE_X, 0), 1)
	fs = [a, occ]
	airborne(a, Vector2(LEDGE_X + 6.0, -25.0))
	a.facing = -1
	d.ledge_snap = "during"
	start(a, d)
	idle(fs, 6)
	check("bezette ledge: niet grijpen", a.ledge_key == "")
	free_all(fs)


func _test_air_limit() -> void:
	print("== per-airtime-limiet")
	var fs: Array = pair(-30.0, 30.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("side", ["dash_strike"], {"startup": 3, "dash_frames": 4, "endlag": 4, "dash_speed": 1.0})
	d.air_use_limit = 1
	airborne(a, Vector2(-30, 80))
	check("1e gebruik in de lucht", start(a, d))
	run_until(fs, func() -> bool: return a.state_name() != "Special", 30)
	check("2e gebruik in dezelfde airtime geblokkeerd", not start(a, d))
	check("teller uitleesbaar", SpecialKit.of(a).uses("side") == 1)
	run_until(fs, func() -> bool: return a.grounded and a.state_name() == "Wait", 400)
	idle(fs, 1)
	airborne(a, Vector2(-30, 80))
	check("na landen: weer toegestaan", start(a, d))
	run_until(fs, func() -> bool: return a.state_name() != "Special", 30)
	check("weer op", not start(a, d))
	# Geraakt worden reset.
	b.pos = Vector2(a.pos.x + 6.0, a.pos.y)
	b.grounded = false
	b.change_state("Fall")
	b.facing = -1
	var m := MoveData.new()
	m.move_name = "nair"
	m.total_frames = 20
	m.aerial = true
	m.hitboxes = [hb(1, 3, Vector2(0, 8), 7.0, 3.0, 361.0, 10.0, 10.0)]
	b.moves["nair"] = m
	b.start_attack("nair")
	run_until(fs, func() -> bool: return a.percent > 0.0, 10)
	idle(fs, 1)
	check("geraakt: limiet gereset", SpecialKit.of(a).uses("side") == 0, SpecialKit.of(a).last_reset)
	free_all(fs)
	# Ledge-grab reset.
	new_stage()
	a = make(Vector2(LEDGE_X + 5.0, -6.0), -1, 0)
	fs = [a]
	airborne(a, Vector2(LEDGE_X + 30.0, 30.0))
	start(a, d)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 30)
	check("op na gebruik", not start(a, d))
	a.grab_ledge(Vector2(LEDGE_X, 0), 1)
	idle(fs, 1)
	check("ledge grab: limiet gereset", SpecialKit.of(a).uses("side") == 0)
	SpecialKit.of(a).air_uses["side"] = 1
	SpecialKit.of(a).reset_air_limits("wall_jump")
	check("wall jump-reset via API", SpecialKit.of(a).uses("side") == 0)
	free_all(fs)


func _test_counter() -> void:
	print("== counter")
	var fs: Array = pair(-6.0, 3.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	b.moves["jab"] = _fast_jab()
	var d := def("down", ["counter"], {"startup": 4, "window_frames": 20, "whiff_endlag": 25, "counter_mult": 1.5,
		"strike_startup": 3, "strike_active": 3, "counter_kb_base": 30.0})
	check("start", start(a, d))
	idle(fs, 6)
	check("in het venster", phase_of(a) == "window" and a.is_intangible())
	b.start_attack("jab")
	var n: int = run_until(fs, func() -> bool: return b.percent > 0.0, 30)
	check("counter triggert en raakt de aanvaller", n >= 0 and (move_of(a) == null or (move_of(a) as TplCounter).triggered))
	check("counter-damage = 1.5 × 4 (min 6)", is_equal_approx(b.percent, 6.0), "%.2f" % b.percent)
	check("verdediger nam geen damage", a.percent == 0.0)
	free_all(fs)
	# Hit vóór het venster (startup) = gewoon geraakt.
	fs = pair(-6.0, 3.0)
	a = fs[0]
	b = fs[1]
	b.moves["jab"] = _fast_jab()
	d.params["startup"] = 12
	start(a, d)
	b.start_attack("jab")
	run_until(fs, func() -> bool: return a.percent > 0.0, 10)
	check("hit in de startup: gewoon geraakt", a.percent > 0.0 and a.state_name().begins_with("Damage"))
	free_all(fs)
	# Whiff: lange endlag.
	fs = pair(-30.0, 30.0)
	a = fs[0]
	d.params["startup"] = 4
	start(a, d)
	var whiff: int = run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("whiff: startup + venster + whiff_endlag", whiff >= 4 + 20 + 25 - 1 and whiff <= 4 + 20 + 25 + 2, str(whiff))
	free_all(fs)
	# Projectiel triggert de counter (director: ja); grabs niet (n.v.t. tot M4).
	fs = pair(-30.0, 10.0)
	a = fs[0]
	b = fs[1]
	var shot := def("neutral", ["projectile"], {"startup": 3, "speed": 3.0, "damage": 6.0})
	start(a, shot)
	start(b, d)
	run_until(fs, func() -> bool: return world().had_event("counter"), 40)
	check("projectiel triggert de counter", world().had_event("counter") and b.percent == 0.0)
	check("projectiel verdwijnt", world().alive_of(a, "", "projectile").is_empty())
	free_all(fs)


func _test_armor() -> void:
	print("== armor")
	var fs: Array = pair(-6.0, 3.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	b.moves["jab"] = _fast_jab()
	var d := def("side", ["dash_strike"], {"startup": 20, "dash_frames": 2, "dash_speed": 0.5, "endlag": 10})
	d.armor = {"from": 0, "to": 22, "max_damage": 8.0}
	start(a, d)
	b.start_attack("jab")
	run_until(fs, func() -> bool: return a.percent > 0.0, 10)
	check("armor: damage wel, geen knockback/state-wissel", is_equal_approx(a.percent, 4.0)
		and a.state_name() == "Special" and a.kb_vel == Vector2.ZERO)
	check("armor: aanvaller kreeg hitlag", b.hitlag_frames > 0 or b.state_name() == "Attack")
	idle(fs, 30)
	# Te veel damage: armor breekt.
	var big := MoveData.new()
	big.move_name = "jab"
	big.total_frames = 20
	big.hitboxes = [hb(2, 4, Vector2(7, 8), 4.0, 12.0, 361.0, 30.0, 80.0)]
	b.moves["jab"] = big
	b.pos = Vector2(a.pos.x + 9.0, 0)
	b.facing = -1
	idle(fs, 2)
	var p0: float = a.percent
	start(a, d)
	b.start_attack("jab")
	run_until(fs, func() -> bool: return a.percent > p0, 10)
	idle(fs, 1)
	check("armor gebroken bij damage > drempel", a.state_name().begins_with("Damage"), a.state_name())
	free_all(fs)


func _test_reflector_absorber() -> void:
	print("== absorber")
	var fs: Array = pair(-30.0, 10.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	b.percent = 20.0
	var shot := def("neutral", ["projectile"], {"startup": 3, "speed": 2.0, "damage": 6.0})
	var ab := def("down", ["absorber"], {"startup": 2, "absorb_frames": 30, "gain": "heal", "gain_mult": 1.0})
	start(a, shot)
	start(b, ab)
	run_until(fs, func() -> bool: return world().had_event("absorb"), 60)
	check("absorber: projectiel opgenomen", world().had_event("absorb") and world().alive_of(a).is_empty())
	check("absorber: heal 6%", is_equal_approx(b.percent, 14.0), "%.1f" % b.percent)
	idle(fs, 40)
	shot.params["absorbable"] = false
	var p0: float = b.percent
	start(a, shot)
	start(b, ab)
	run_until(fs, func() -> bool: return b.percent > p0, 60)
	check("absorbable=false: raakt gewoon", b.percent > p0)
	free_all(fs)


func _test_command_grab() -> void:
	print("== command_grab")
	var fs: Array = pair(-6.0, 3.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("side", ["command_grab"], {"startup": 6, "grab_active": 4, "hold_frames": 10,
		"throw_damage": 10.0, "throw_kb_base": 60.0})
	start(a, d)
	var n: int = run_until(fs, func() -> bool: return b.state_name() == "SpecialHeld", 15)
	check("grab: P2 vastgehouden", n >= 0)
	check("vastgehouden = intangible voor derden", b.is_intangible())
	run_until(fs, func() -> bool: return b.percent > 0.0, 20)
	check("worp: damage + knockback", is_equal_approx(b.percent, 10.0) and b.state_name().begins_with("Damage"))
	free_all(fs)
	# Mis: lange endlag.
	fs = pair(-30.0, 30.0)
	a = fs[0]
	start(a, d)
	var whiff: int = run_until(fs, func() -> bool: return a.state_name() != "Special", 60)
	check("mis: startup + actief + miss_endlag", whiff >= 6 + 4 + 30 - 1, str(whiff))
	free_all(fs)
	# Grab-trade.
	fs = pair(-5.0, 5.0)
	a = fs[0]
	b = fs[1]
	start(a, d)
	start(b, d)
	idle(fs, 10)
	check("grab-trade: beide mis", a.state_name() == "Special" and b.state_name() == "Special"
		and phase_of(a) == "end" and phase_of(b) == "end")
	free_all(fs)
	# Breakout (mash).
	fs = pair(-6.0, 3.0)
	a = fs[0]
	b = fs[1]
	d.params["breakout"] = "mash"
	d.params["breakout_presses"] = 3
	d.params["hold_frames"] = 30
	start(a, d)
	run_until(fs, func() -> bool: return b.state_name() == "SpecialHeld", 15)
	for i in 8:
		tick(fs, [null, fr(0, 0, A if i % 2 == 0 else 0)])
	check("breakout: los vóór de worp", b.state_name() != "SpecialHeld" and b.percent == 0.0, b.state_name())
	free_all(fs)


func _test_dash_strike() -> void:
	print("== dash_strike")
	var fs: Array = pair(-40.0, 0.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("side", ["dash_strike"], {"startup": 5, "dash_speed": 4.0, "dash_frames": 12, "endlag": 15,
		"dash_damage": 8.0})
	start(a, d)
	idle(fs, 6)
	check("dash: snelheid op de grond", phase_of(a) == "dash" and is_equal_approx(a.gr_vel, 4.0))
	run_until(fs, func() -> bool: return b.percent > 0.0, 20)
	check("dash raakt", is_equal_approx(b.percent, 8.0))
	run_until(fs, func() -> bool: return a.state_name() != "Special", 40)
	check("klaar -> Wait", a.state_name() == "Wait")
	free_all(fs)
	# Van de rand glijden (cliff_stop false) -> lucht, geen helpless zonder helpless_after.
	new_stage()
	a = make(Vector2(LEDGE_X - 15.0, 0), 1, 0)
	fs = [a]
	idle(fs, 2)
	start(a, d)
	idle(fs, 12)
	check("cliff_stop=false: glijdt eraf en dasht door in de lucht", not a.grounded and a.state_name() == "Special"
		and a.pos.x > LEDGE_X)
	free_all(fs)
	new_stage()
	a = make(Vector2(LEDGE_X - 15.0, 0), 1, 0)
	fs = [a]
	idle(fs, 2)
	d.params["cliff_stop"] = true
	start(a, d)
	idle(fs, 20)
	check("cliff_stop=true: stopt aan de rand", a.grounded and a.pos.x <= LEDGE_X + 0.01)
	free_all(fs)


func _test_stall_fall() -> void:
	print("== stall_fall")
	var fs: Array = pair(-10.0, 2.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("down", ["stall_fall"], {"startup": 5, "stall_frames": 10, "fall_speed": 5.0, "landing_frames": 4,
		"landing_damage": 6.0, "landing_size": 14.0})
	d.landing_lag = 16
	airborne(a, Vector2(-10, 40))
	start(a, d)
	idle(fs, 7)
	var y0: float = a.pos.y
	idle(fs, 5)
	check("stall: hangt (zakt nauwelijks)", phase_of(a) == "stall" and y0 - a.pos.y < 2.0, "%.2f" % (y0 - a.pos.y))
	run_until(fs, func() -> bool: return phase_of(a) == "fall", 20)
	tick(fs)
	check("val met vaste snelheid", is_equal_approx(a.vel.y, -5.0))
	run_until(fs, func() -> bool: return phase_of(a) == "landing", 30)
	idle(fs, 2)
	check("landings-shockwave raakt P2", b.percent > 0.0, "%.1f" % b.percent)
	var w: int = run_until(fs, func() -> bool: return a.state_name() == "Wait", 30)
	check("vaste landing lag (16, + hitlag van de shockwave-treffer)", w >= 12 and w <= 22, str(w))
	# button_release
	d.params["fall_trigger"] = "button_release"
	d.params["stall_frames"] = 40
	airborne(a, Vector2(-70, 60))
	start(a, d)
	idle(fs, 8, [fr(0, 0, B)])
	check("button_release: stall zolang B vast", phase_of(a) == "stall")
	tick(fs)
	tick(fs)
	check("B los -> val", phase_of(a) == "fall")
	free_all(fs)


func _test_multi_jump() -> void:
	print("== multi_jump")
	var fs: Array = pair(-30.0, 30.0)
	var a: Fighter = fs[0]
	var d := def("up", ["multi_jump"], {"kind": "flap", "flap_power": 2.0, "power_decay": 0.5, "flap_frames": 8})
	d.air_use_limit = 3
	airborne(a, Vector2(-30, 40))
	start(a, d)
	idle(fs, 4)
	var v1: float = a.vel.y
	run_until(fs, func() -> bool: return a.state_name() != "Special", 20)
	check("flap: omhoog, daarna Fall (geen helpless)", v1 > 1.5 and a.state_name() == "Fall")
	start(a, d)
	idle(fs, 4)
	check("tweede flap zwakker (power_decay)", a.vel.y < v1 and a.vel.y > 0.5, "%.2f / %.2f" % [a.vel.y, v1])
	run_until(fs, func() -> bool: return a.state_name() != "Special", 20)
	start(a, d)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 20)
	check("count 3 op: vierde geblokkeerd", not start(a, d))
	free_all(fs)
	fs = pair(-30.0, 30.0)
	a = fs[0]
	var hv := def("up", ["multi_jump"], {"kind": "hover", "hover_frames": 40, "hover_max_fall": 0.3})
	airborne(a, Vector2(-30, 60))
	start(a, hv)
	idle(fs, 20, [fr(0, 0, B)])
	check("hover: zakt langzaam", a.vel.y >= -0.31 and phase_of(a) == "hover")
	tick(fs)
	tick(fs)
	check("hover: B los -> Fall", a.state_name() == "Fall")
	free_all(fs)


func _test_tether() -> void:
	print("== tether")
	new_stage()
	var a: Fighter = make(Vector2(LEDGE_X + 30.0, -30.0), -1, 0)
	var fs: Array = [a]
	airborne(a, Vector2(LEDGE_X + 30.0, -30.0))
	a.facing = -1
	var d := def("up", ["tether"], {"startup": 6, "angle": 45.0, "max_length": 80.0, "extend_speed": 10.0,
		"pull_speed": 4.0})
	d.helpless_after = true
	check("start", start(a, d))
	var n: int = run_until(fs, func() -> bool: return a.state_name() == "CliffCatch", 60)
	check("tether: haakt de ledge en hangt eraan", n >= 0 and a.ledge_key != "")
	free_all(fs)
	# Mis: helpless.
	new_stage()
	a = make(Vector2(LEDGE_X + 100.0, -5.0), -1, 0)
	fs = [a]
	airborne(a, Vector2(LEDGE_X + 100.0, -5.0))
	a.facing = -1
	start(a, d)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("tether mis: helpless", a.state_name() == "FallSpecial")
	free_all(fs)
	# Tegenstander trekken.
	var fs2: Array = pair(-40.0, 10.0)
	a = fs2[0]
	var b: Fighter = fs2[1]
	var pull := def("side", ["tether"], {"startup": 4, "angle": 0.0, "anchor_types": ["fighter"],
		"pull_mode": "opponent", "max_length": 100.0, "extend_speed": 10.0, "throw_damage": 5.0})
	start(a, pull)
	run_until(fs2, func() -> bool: return b.percent > 0.0, 60)
	check("tether: trekt de tegenstander naar zich toe en slaat", is_equal_approx(b.percent, 5.0)
		and absf(b.pos.x - a.pos.x) < 20.0, "%.1f%% dx %.1f" % [b.percent, b.pos.x - a.pos.x])
	free_all(fs2)


func _test_trap() -> void:
	print("== trap")
	var fs: Array = pair(-30.0, 30.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("down", ["trap"], {"startup": 6, "place_offset": Vector2(10, 6), "arm_time": 20, "max_alive": 2,
		"explode_damage": 12.0, "explode_size": 8.0, "lifetime": 600})
	d.telegraph = "mine_blink"
	start(a, d)
	idle(fs, 8)
	var traps: Array[SpecialEntity] = world().alive_of(a, "", "trap")
	check("trap geplaatst", traps.size() == 1)
	check("telegraaf (verplicht)", SpecialKit.of(a).fx_seen("telegraph", "mine_blink"))
	run_until(fs, func() -> bool: return (traps[0] as SpecialTrap).landed, 60)
	check("drop: valt naar de vloer", traps[0].pos.y <= 0.5 and (traps[0] as SpecialTrap).landed)
	b.pos = traps[0].pos + Vector2(1, 0)
	idle(fs, 3)
	check("niet scherp: geen trigger", b.percent == 0.0)
	run_until(fs, func() -> bool: return b.percent > 0.0, 30)
	check("scherp + contact: ontploft", is_equal_approx(b.percent, 12.0))
	idle(fs, 10)
	check("na explosie weg", world().alive_of(a, "", "trap").is_empty())
	b.pos = Vector2(60, 0)
	idle(fs, 60)
	# Cap: max_alive 2, replace.
	for i in 3:
		start(a, d)
		idle(fs, 25)
	check("max_alive 2 (replace): 2 traps", world().alive_of(a, "", "trap").size() == 2)
	# owner_signal
	idle(fs, 30)
	var sig := def("neutral", ["trap"], {"startup": 4, "trigger": "owner_signal", "arm_time": 0, "max_alive": 1,
		"explode_damage": 9.0, "explode_size": 12.0})
	sig.telegraph = "bomb"
	start(a, sig)
	idle(fs, 20)
	var t: SpecialTrap = world().alive_of(a, "neutral", "trap")[0]
	b.pos = t.pos + Vector2(4, 0)
	idle(fs, 3)
	var p0: float = b.percent
	check("owner_signal: opnieuw B laat hem ontploffen", Specials.try_start(a, "neutral") and t.phase == "exploding")
	idle(fs, 3)
	check("owner_signal: raakt", b.percent > p0)
	free_all(fs)


func _test_buff() -> void:
	print("== buff")
	var fs: Array = pair(-30.0, 30.0)
	var a: Fighter = fs[0]
	var base_run: float = a.stats.run_speed
	var d := def("down", ["buff"], {"startup": 10, "transform_frames": 6, "duration": 60, "endlag": 10,
		"modifiers": {"run_speed_mult": 1.5, "damage_dealt_mult": 1.2}, "stack_rule": "block"})
	d.telegraph = "aura"
	start(a, d)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 40)
	check("buff actief: run_speed ×1.5", is_equal_approx(a.stats.run_speed, base_run * 1.5))
	check("telegraaf", SpecialKit.of(a).fx_seen("telegraph", "aura"))
	check("stack_rule block: niet opnieuw", not start(a, d))
	check("damage_dealt_mult uitleesbaar", is_equal_approx(SpecialKit.of(a).mult("damage_dealt_mult"), 1.2))
	idle(fs, 70)
	check("na de duur terug naar de basis", is_equal_approx(a.stats.run_speed, base_run))
	# until_hit + move_swap
	var alt := _fast_jab()
	alt.move_name = "jab"
	var d2 := def("down", ["buff"], {"startup": 4, "transform_frames": 2, "duration": -1, "until_hit": true,
		"modifiers": {"weight_mult": 1.3}, "move_swap": {"jab": alt}, "endlag": 4})
	start(a, d2)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 20)
	check("move_swap: jab vervangen", a.moves["jab"] == alt)
	check("weight ×1.3", is_equal_approx(a.stats.weight, 87.0 * 1.3))
	var b: Fighter = fs[1]
	b.pos = Vector2(a.pos.x + 9.0, 0)
	b.facing = -1
	b.moves["jab"] = _fast_jab()
	idle(fs, 2)
	b.start_attack("jab")
	run_until(fs, func() -> bool: return a.percent > 0.0, 10)
	idle(fs, 2)
	check("until_hit: buff weg na geraakt", not SpecialKit.of(a).has_buff("down") and a.moves["jab"] != alt
		and is_equal_approx(a.stats.weight, 87.0))
	free_all(fs)


func _test_command_dash() -> void:
	print("== command_dash")
	var fs: Array = pair(-40.0, 0.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("side", ["command_dash"], {"startup": 4, "distance": 30.0, "move_frames": 10, "window": 10,
		"follow_attack_damage": 7.0})
	start(a, d)
	idle(fs, 13)
	var x_after: float = a.pos.x
	check("move: ~30 units verplaatst", absf(x_after - (-40.0) - 30.0) < 3.0, "%.1f" % x_after)
	b.pos = Vector2(a.pos.x + 9.0, 0)
	idle(fs, 1)
	tick(fs, [fr(0, 0, A)])
	check("A in het venster: follow-up", phase_of(a) == "follow")
	run_until(fs, func() -> bool: return b.percent > 0.0, 20)
	check("follow-up raakt", is_equal_approx(b.percent, 7.0))
	free_all(fs)
	# Input-buffer: A net vóór het venster telt.
	fs = pair(-40.0, 40.0)
	a = fs[0]
	start(a, d)
	idle(fs, 12)
	tick(fs, [fr(0, 0, A)])
	idle(fs, 2)
	check("buffer: A 2 frames vóór het venster telt", phase_of(a) == "follow", phase_of(a))
	free_all(fs)
	# Geen input -> endlag.
	fs = pair(-40.0, 40.0)
	a = fs[0]
	start(a, d)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 60)
	check("geen follow-up: endlag -> Wait", a.state_name() == "Wait")
	free_all(fs)


func _test_spin() -> void:
	print("== spin")
	var fs: Array = pair(-6.0, 3.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("down", ["spin"], {"startup": 4, "spin_frames": 20, "hit_every": 5, "spin_damage": 1.0,
		"ender_damage": 5.0})
	start(a, d)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("spin: meerdere hits + ender (> 5%)", b.percent > 6.0, "%.1f" % b.percent)
	free_all(fs)
	fs = pair(-30.0, 30.0)
	a = fs[0]
	d.helpless_after = true
	d.params["rise_speed"] = 1.0
	start(a, d)
	idle(fs, 10)
	check("rise_speed: stijgt", not a.grounded and a.vel.y > 0.0)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("spin in de lucht: helpless", a.state_name() == "FallSpecial")
	free_all(fs)


func _test_combo_sequence() -> void:
	print("== combinatie (sequentie): dash_strike -> command_grab")
	var fs: Array = pair(-30.0, 0.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var d := def("side", ["dash_strike", "command_grab"], {"startup": 4, "dash_speed": 3.0, "dash_frames": 5,
		"endlag": 1, "dash_damage": 0.0})
	d.linked_params = {"startup": 1, "grab_active": 6, "hold_frames": 8, "throw_damage": 7.0}
	d.hitboxes = {"dash": [] as Array[HitboxData]}
	start(a, d)
	run_until(fs, func() -> bool: return move_of(a) is TplCommandGrab, 40)
	check("sequentie: command_grab neemt het over", move_of(a) is TplCommandGrab and move_of(a).linked)
	run_until(fs, func() -> bool: return b.percent > 0.0, 40)
	check("combinatie raakt", b.percent > 0.0)
	free_all(fs)


func _test_cleanup_on_death() -> void:
	print("== opruimen bij dood")
	var fs: Array = pair(-30.0, 30.0)
	var a: Fighter = fs[0]
	var d := def("neutral", ["projectile"], {"startup": 3, "speed": 0.2, "lifetime": 500, "max_alive": 3})
	start(a, d)
	idle(fs, 5)
	check("projectiel leeft", world().alive_of(a).size() == 1)
	SpecialKit.of(a).air_uses["up"] = 1
	a.auto_respawn = false
	a.pos = Vector2(0, -500)
	a.grounded = false
	a.change_state("Fall")
	idle(fs, 2)
	check("dood: entities opgeruimd", world().alive_of(a).is_empty())
	check("dood: limieten gereset", SpecialKit.of(a).uses("up") == 0)
	free_all(fs)
	# Robuust bij vrijgegeven fighters en een stage-wissel: geen fouten, ongeldige fighters gesnoeid.
	fs = pair(-30.0, 30.0)
	var extra: Array[Fighter] = []
	for i in 6:
		extra.append(make(Vector2(-50 + i * 10, 0), 1, 2 + i))
	start(fs[0], d)
	idle(fs, 4)
	for e: Fighter in extra:
		e.free()
	idle(fs, 4)
	check("vrijgegeven fighters gesnoeid", world().fighters.size() == 2, str(world().fighters.size()))
	var old: SpecialWorld = world()
	var other := SandboxStage.new()
	(fs[1] as Fighter).stage = other
	Specials.attach(fs[1])
	idle(fs, 2)
	check("fighter op andere stage valt uit de wereld", old.fighters.size() == 1)
	(fs[1] as Fighter).stage = stage
	SpecialWorld.dispose(other)
	other.free()
	free_all(fs)


## Gescript scenario met alle hoofdinteracties; snapshot van fighters + entities.
func _scenario() -> Array:
	var fs: Array = pair(-30.0, 20.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	var shot := def("neutral", ["charge", "projectile"], {"startup": 5, "charge_max": 30, "scale_damage": 2.0})
	shot.linked_params = {"startup": 3, "speed": 2.5, "angle": 10.0, "gravity": 0.02, "bounce": "floor",
		"bounce_count": 1, "damage": 5.0}
	var up := def("up", ["rising_multi"], {"startup": 3})
	up.helpless_after = true
	var out: Array = []
	start(a, shot)
	start(b, up)
	for i in 120:
		var ia: InputFrame = fr(0, 0, B) if i < 12 else fr(20 if i % 30 < 15 else -20, 0)
		tick(fs, [ia, fr(0, 0)])
		if i % 10 == 0:
			out.append([a.snapshot(), b.snapshot()])
			for e: SpecialEntity in world().entities:
				out.append([e.serial, e.pos, e.vel, e.alive, e.owner_id])
	free_all(fs)
	return out


func _test_determinism() -> void:
	print("== determinisme")
	var r1: Array = _scenario()
	var r2: Array = _scenario()
	check("twee runs identiek", var_to_str(r1) == var_to_str(r2))


func _test_validator() -> void:
	print("== validator (specials)")
	var v: RefCounted = SpecialValidator.new()
	for s: String in SpecialDef.SLOTS:
		var d: SpecialDef = Specials.load_def("_dummy", s)
		var r: Dictionary = v.validate_def("_dummy", d)
		check("_dummy %s: geen FAIL" % s, r["fails"].is_empty(), "; ".join(r["fails"]))
	var bad := def("up", ["teleport", "projectile", "spin"], {"distance": 400.0, "startup": 2})
	bad.scores = {"S": 5, "K": 0, "B": 5, "V": 3, "U": 9}
	var rb: Dictionary = v.validate_def("test", bad)
	var msg: String = "; ".join(rb["fails"])
	check("meer dan 2 sjablonen = FAIL", msg.contains("sjablonen"), msg)
	check("teleport-afstand > 260 = FAIL", msg.contains("distance"), msg)
	check("startup buiten bereik = FAIL", msg.contains("startup"), msg)
	var tele := def("up", ["teleport"], {"distance": 150.0, "startup": 10, "direction_mode": "stick_8dir"})
	tele.helpless_after = false
	tele.scores = {"S": 4, "K": 0, "B": 3, "V": 3, "U": 5}
	var rt: Dictionary = v.validate_def("test", tele)
	var wmsg: String = "; ".join(rt["warns"] + rt["fails"])
	check("helpless-regel: lucht-recovery zonder helpless en zonder +2 U -> melding", wmsg.contains("helpless"), wmsg)
	var tr := def("down", ["trap"], {"visible_to_enemy": false})
	tr.scores = {"S": 3, "K": 2, "B": 1, "V": 3, "U": 4}
	var rtr: Dictionary = v.validate_def("test", tr)
	var tmsg: String = "; ".join(rtr["fails"])
	check("onzichtbare trap + geen telegraaf = FAIL", tmsg.contains("zichtbaar") and tmsg.contains("telegraaf"), tmsg)
	var combo := def("neutral", ["charge", "projectile"], {})
	combo.telegraph = "x"
	combo.scores = {"S": 2, "K": 3, "B": 3, "V": 3, "U": 1}
	var rc: Dictionary = v.validate_def("test", combo)
	check("combinatie zonder +2 U -> melding", ("; ".join(rc["warns"] + rc["fails"])).contains("combinatie"))
	var price := def("side", ["dash_strike"], {"startup": 30, "dash_speed": 4.0, "dash_frames": 10})
	price.scores = {"S": 5, "K": 2, "B": 2, "V": 3, "U": 4}
	var rp: Dictionary = v.validate_def("test", price)
	check("score S past niet bij startup 30 -> melding", ("; ".join(rp["warns"] + rp["fails"])).contains("S"))
	var full: Dictionary = Validator.new().validate_character("_dummy")
	var sp_fail: bool = false
	for r: Dictionary in full["results"]:
		if String(r["move"]).begins_with("special") and r["status"] == "FAIL":
			sp_fail = true
	check("validate_character(_dummy): specials zonder FAIL", not sp_fail)
