extends SceneTree
## Tests Captain Pep: zijn vier specials (characters/captain_pep/specials/) op grond en in de lucht: fases, props op de
## juiste frames, hits op een dummy, helpless / ledge-snap / landing lag, up-B grab + explosie.
##   Godot_console.exe --headless --path . --script res://tests/test_captain_pep.gd
## Exit code 0 = alles geslaagd, 1 = minstens één FAIL.

const B: int = InputFrame.BTN_SPECIAL
const JUMP: int = InputFrame.BTN_JUMP
const LEDGE_X: float = SandboxStage.MAIN_HALF_WIDTH
const ID: String = "captain_pep"

var _fails: int = 0
var _total: int = 0
var stage: SandboxStage
var _combat := CombatSystem.new()


func _initialize() -> void:
	MeleeStick.fast_fall_while_rising = false
	Specials.clear_cache()
	_test_defs()
	_test_neutral()
	_test_side()
	_test_up()
	_test_down()
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


func make(at: Vector2, dir: int, player: int, char_id: String) -> Fighter:
	var f := Fighter.new()
	f.use_visual = false
	f.auto_register = false
	f.player = player
	f.character_id = char_id
	f.stats = CharacterLoader.stats_for(ID) if char_id == ID else Archetypes.load_stats("allrounder")
	f.stage = stage
	f.input = InputHistory.new()
	f.tap_jump_override = 1
	f.pos = at
	f.facing = dir
	f.setup()
	Specials.attach(f)
	SpecialWorld.of(f)
	return f


## Pep (P1, kijkt rechts) op x1 en een dummy (P2) op x2.
func pair(x1: float, x2: float) -> Array:
	_free_stage()
	stage = SandboxStage.new()
	var a: Fighter = make(Vector2(x1, 0.0), 1, 0, ID)
	var b: Fighter = make(Vector2(x2, 0.0), -1, 1, "_dummy")
	var fs: Array = [a, b]
	idle(fs, 3)
	return fs


func solo(at: Vector2, dir: int) -> Array:
	_free_stage()
	stage = SandboxStage.new()
	var a: Fighter = make(at, dir, 0, ID)
	return [a]


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
	_combat.step(fs)


func idle(fs: Array, n: int, inputs: Array = []) -> void:
	for i in n:
		tick(fs, inputs)


func free_all(fs: Array) -> void:
	for f: Fighter in fs:
		f.free()
	_free_stage()


func run_until(fs: Array, cond: Callable, n: int, inputs: Array = []) -> int:
	for i in n:
		if cond.call():
			return i
		tick(fs, inputs)
	return n if cond.call() else -1


func airborne(f: Fighter, at: Vector2) -> void:
	f.pos = at
	f.vel = Vector2.ZERO
	f.gr_vel = 0.0
	f.grounded = false
	f.ground_seg = -1
	f.change_state("Fall")


func move_of(f: Fighter) -> SpecialMove:
	return (f.state as StateSpecial).move if f.state is StateSpecial else null


func phase_of(f: Fighter) -> String:
	var m: SpecialMove = move_of(f)
	return m.phase if m != null else ""


func props_of(f: Fighter) -> PackedStringArray:
	var out := PackedStringArray()
	if f.state is StateSpecial:
		for ev: Dictionary in (f.state as StateSpecial).props():
			out.append(String(ev["prop"]))
	return out


func started(f: Fighter, slot: String) -> bool:
	return Specials.try_start(f, slot)


func rng_min(a: Array[int]) -> int:
	return a.min() if not a.is_empty() else -1


func rng_max(a: Array[int]) -> int:
	return a.max() if not a.is_empty() else -1


# --- tests -------------------------------------------------------------------------------------

func _test_defs() -> void:
	print("== definities")
	for s: String in SpecialDef.SLOTS:
		var d: SpecialDef = Specials.load_def(ID, s)
		check("%s: .tres geladen" % s, d != null and d.slot == s)
	check("neutral/side = dash_strike", Specials.load_def(ID, "neutral").primary() == "dash_strike"
		and Specials.load_def(ID, "side").primary() == "dash_strike")
	var up: SpecialDef = Specials.load_def(ID, "up")
	check("up = rising_multi + command_grab", up.templates == ["rising_multi", "command_grab"])
	check("down = stall_fall", Specials.load_def(ID, "down").primary() == "stall_fall")
	var fs: Array = solo(Vector2.ZERO, 1)
	var a: Fighter = fs[0]
	var kinds: Dictionary = {}
	for s: String in SpecialDef.SLOTS:
		kinds[s] = Specials.make_runner(Specials.load_def(ID, s), a, 0).get_script().resource_path.get_file()
	check("eigen runners voor neutral/up/down, sjabloon voor side", kinds["neutral"] == "neutral.gd"
		and kinds["up"] == "up.gd" and kinds["down"] == "down.gd" and kinds["side"] == "tpl_dash_strike.gd", str(kinds))
	free_all(fs)


## Neutral-B "Last Shot".
func _test_neutral() -> void:
	print("== neutral: Last Shot")
	var fs: Array = pair(-6.0, 4.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	check("start (grond)", started(a, "neutral") and a.state_name() == "Special")
	# Props per frame sinds de knopdruk (state_frame).
	var burger: Array[int] = []
	var salt: Array[int] = []
	var other: bool = false
	var dash_at: int = -1
	for i in 60:
		var fn: int = a.state_frame
		var p: PackedStringArray = props_of(a)
		if p.has("hamburger"):
			burger.append(fn)
		if p.has("zoutvaatje"):
			salt.append(fn)
		for n: String in p:
			if n != "hamburger" and n != "zoutvaatje":
				other = true
		if phase_of(a) == "dash" and dash_at < 0:
			dash_at = fn
		tick(fs)
	check("hamburger zichtbaar 6..27 en alleen daar", rng_min(burger) == 6 and rng_max(burger) == 27
		and burger.size() == 22, "%d..%d (%d)" % [rng_min(burger), rng_max(burger), burger.size()])
	check("zoutvaatje zichtbaar 6..22 en alleen daar", rng_min(salt) == 6 and rng_max(salt) == 22
		and salt.size() == 17, "%d..%d (%d)" % [rng_min(salt), rng_max(salt), salt.size()])
	check("hamburger weg (opgegeten) vóór de klap", rng_max(burger) < dash_at, "klap f%d" % dash_at)
	check("geen andere props", not other)
	check("lange startup: klap pas rond frame 40", dash_at >= 39 and dash_at <= 42, str(dash_at))
	check("klap raakte de dummy (reuze damage)", b.percent >= 25.0, "%.1f" % b.percent)
	check("dummy in damage-state met knockback", b.state_name().begins_with("Damage"), b.state_name())
	free_all(fs)
	# Endlag (hijgen) is lang en props zijn dan weg.
	fs = pair(-6.0, 4.0)
	a = fs[0]
	b = fs[1]
	b.percent = 40.0
	started(a, "neutral")
	run_until(fs, func() -> bool: return b.state_name().begins_with("Damage"), 80)
	check("op 40%: 26 damage erbij (66%)", is_equal_approx(b.percent, 66.0), "%.1f" % b.percent)
	check("props weg tijdens de klap", props_of(a).is_empty())
	var endlag: int = run_until(fs, func() -> bool: return a.state_name() == "Wait", 160)
	check("hijgen: lange endlag (>= 40 frames na de klap)", endlag >= 40, str(endlag))
	free_all(fs)
	# Omdraaien in de startup (stick achteruit).
	fs = pair(-6.0, 4.0)
	a = fs[0]
	started(a, "neutral")
	idle(fs, 5)
	check("kijkt eerst naar rechts", a.facing == 1)
	tick(fs, [fr(-80, 0)])
	check("stick achteruit in de startup draait om", a.facing == -1 and a.state_name() == "Special")
	tick(fs, [fr(-80, 0)])
	check("geen dubbele flip meteen erna (cooldown)", a.facing == -1)
	free_all(fs)
	# Omgedraaid raakt hij een dummy achter zich.
	fs = pair(4.0, -6.0)
	a = fs[0]
	b = fs[1]
	b.facing = 1
	started(a, "neutral")
	idle(fs, 3, [fr(-80, 0)])
	check("omgedraaid", a.facing == -1)
	run_until(fs, func() -> bool: return b.percent > 0.0, 70)
	check("raakt wie hij nu aankijkt (achter zich)", b.percent >= 25.0, "%.1f" % b.percent)
	free_all(fs)
	# Lucht: dezelfde klap, geen helpless.
	fs = pair(-60.0, -50.0)
	a = fs[0]
	b = fs[1]
	airborne(a, Vector2(-60.0, 110.0))
	check("start (lucht)", started(a, "neutral"))
	run_until(fs, func() -> bool: return phase_of(a) == "dash", 80)
	check("lucht: klap-fase in de lucht met hitbox", not a.grounded and not move_of(a).hitboxes().is_empty())
	airborne(b, Vector2(-50.0, a.pos.y))
	b.vel = Vector2.ZERO
	run_until(fs, func() -> bool: return b.percent > 0.0, 6)
	check("lucht: dezelfde klap raakt", b.percent >= 25.0, "%.1f" % b.percent)
	free_all(fs)
	fs = pair(-40.0, 40.0)
	a = fs[0]
	airborne(a, Vector2(-40.0, 140.0))
	started(a, "neutral")
	run_until(fs, func() -> bool: return phase_of(a) == "end", 80)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("lucht: geen helpless na afloop", a.state_name() != "FallSpecial" and a.state_name() != "LandingFallSpecial", a.state_name())
	free_all(fs)
	# Landen tijdens de endlag in de lucht -> landing lag.
	fs = pair(-40.0, 40.0)
	a = fs[0]
	airborne(a, Vector2(-40.0, 40.0))
	started(a, "neutral")
	run_until(fs, func() -> bool: return a.state_name() == "Landing" or a.state_name() == "LandingFallSpecial", 200)
	check("lucht-neutral: landen levert gewone landing lag (geen helpless-landing)", a.state_name() == "Landing"
		or a.state_name() == "Wait", a.state_name())
	free_all(fs)


## Side-B "Panic Rush".
func _test_side() -> void:
	print("== side: Panic Rush")
	var fs: Array = pair(-40.0, 10.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	check("start (grond)", started(a, "side"))
	var frames_with_bike: int = 0
	var frames_total: int = 0
	var x0: float = a.pos.x
	for i in 90:
		if a.state_name() == "Special":
			frames_total += 1
			if props_of(a).has("racefiets"):
				frames_with_bike += 1
		else:
			break
		tick(fs)
	check("racefiets zichtbaar tijdens de hele move", frames_total > 30 and frames_with_bike == frames_total,
		"%d/%d" % [frames_with_bike, frames_total])
	check("fiets weg na de move", props_of(a).is_empty() and a.state_name() == "Wait", a.state_name())
	check("één harde klap bij contact", b.percent >= 12.0 and b.percent <= 14.0, "%.1f" % b.percent)
	check("scheurt naar voren", a.pos.x > x0 + 30.0, "%.1f" % (a.pos.x - x0))
	check("grond: geen helpless", a.state_name() == "Wait")
	free_all(fs)
	# Mis op de grond: glijdt door de hele dash (>= 100 units).
	fs = pair(-60.0, 200.0)
	a = fs[0]
	x0 = a.pos.x
	started(a, "side")
	run_until(fs, func() -> bool: return a.state_name() != "Special", 120)
	check("mis: lange rush (>= 100 units)", a.pos.x - x0 >= 100.0, "%.1f" % (a.pos.x - x0))
	free_all(fs)
	# Lucht: licht stijgend, daarna helpless.
	fs = pair(-40.0, 200.0)
	a = fs[0]
	airborne(a, Vector2(-75.0, 160.0))
	check("start (lucht)", started(a, "side"))
	run_until(fs, func() -> bool: return phase_of(a) == "dash", 40)
	var y0: float = a.pos.y
	idle(fs, 8)
	check("lucht-dash stijgt licht", a.pos.y > y0 + 4.0 and a.vel.y > 0.0, "%.2f" % (a.pos.y - y0))
	check("fiets ook in de lucht", props_of(a).has("racefiets"))
	run_until(fs, func() -> bool: return a.state_name() != "Special", 120)
	check("lucht: helpless na afloop", a.state_name() == "FallSpecial", a.state_name())
	check("fiets weg in helpless", props_of(a).is_empty())
	run_until(fs, func() -> bool: return a.grounded, 400)
	check("helpless landing: landing lag", a.state_name() == "LandingFallSpecial", a.state_name())
	free_all(fs)
	# Luchtlimiet: één keer per airtime.
	fs = pair(-40.0, 200.0)
	a = fs[0]
	airborne(a, Vector2(-75.0, 150.0))
	started(a, "side")
	run_until(fs, func() -> bool: return phase_of(a) == "end", 120)
	a.change_state("Fall")
	check("tweede rush in dezelfde airtime geblokkeerd", not started(a, "side"))
	free_all(fs)
	# Ledge-snap tijdens de rush.
	fs = solo(Vector2(LEDGE_X + 40.0, -4.0), -1)
	a = fs[0]
	airborne(a, Vector2(LEDGE_X + 40.0, -4.0))
	a.facing = -1
	started(a, "side")
	var got: int = run_until(fs, func() -> bool: return a.ledge_key != "", 100)
	check("ledge-snap tijdens de rush", got >= 0 and a.state_name() == "CliffCatch", "%s %s" % [a.state_name(), a.pos])
	free_all(fs)


## Up-B "Grabby Hands".
func _test_up() -> void:
	print("== up: Grabby Hands")
	# Grond: grijpt de dummy vlak voor hem.
	var fs: Array = pair(-6.0, 3.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	check("start (grond)", started(a, "up"))
	var n: int = run_until(fs, func() -> bool: return b.state_name() == "SpecialHeld", 60)
	check("grijpt de dummy tijdens het stijgen", n >= 0, str(n))
	check("vastgehouden = intangible voor derden", b.is_intangible())
	check("Pep staat in de hold-fase", phase_of(a) == "hold", phase_of(a))
	var kit: SpecialKit = SpecialKit.of(a)
	var m: int = run_until(fs, func() -> bool: return b.percent > 0.0, 40)
	check("explosie: damage + knockback", m >= 0 and b.percent >= 13.0 and b.state_name().begins_with("Damage"),
		"%.1f %s" % [b.percent, b.state_name()])
	var vfx_seen: bool = false
	for e: Dictionary in kit.fx_log:
		if String(e["name"]) == "purple_sparks":
			vfx_seen = true
	check("paarse-vonken-VFX aangeroepen (toolkit-hook)", vfx_seen)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("grab geslaagd: GEEN helpless (recovery)", a.state_name() in ["Fall", "Wait", "Landing"], a.state_name())
	free_all(fs)
	# Lucht: dummy in de lucht gegrepen.
	fs = pair(-6.0, 3.0)
	a = fs[0]
	b = fs[1]
	airborne(a, Vector2(-6.0, 40.0))
	started(a, "up")
	n = -1
	for i in 60:
		if b.state_name() != "SpecialHeld":
			airborne(b, Vector2(3.0, 46.0))
		else:
			n = i
			break
		tick(fs)
	check("lucht: grijpt een zwevende dummy", n >= 0, str(n))
	run_until(fs, func() -> bool: return b.percent > 0.0, 40)
	check("lucht: explosie raakt", b.percent >= 13.0)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("lucht + raak: geen helpless", a.state_name() in ["Fall", "Wait", "Landing"], a.state_name())
	free_all(fs)
	# Mis: helpless.
	fs = pair(-40.0, 60.0)
	a = fs[0]
	airborne(a, Vector2(-40.0, 40.0))
	started(a, "up")
	var y0: float = a.pos.y
	idle(fs, 30)
	var ymax: float = a.pos.y
	run_until(fs, func() -> bool:
		ymax = maxf(ymax, a.pos.y)
		return a.state_name() != "Special", 80)
	check("stijgt (recovery) ~32-38 units", ymax - y0 >= 30.0 and ymax - y0 <= 40.0, "%.1f" % (ymax - y0))
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("mis in de lucht: helpless", a.state_name() in ["FallSpecial", "LandingFallSpecial"], a.state_name())
	free_all(fs)
	# Mis op de grond: helpless na afloop, landing lag bij landen.
	fs = pair(-40.0, 60.0)
	a = fs[0]
	started(a, "up")
	run_until(fs, func() -> bool: return a.state_name() != "Special", 100)
	check("mis (grond): helpless (landing lag bij landen)", a.state_name() in ["FallSpecial", "LandingFallSpecial"], a.state_name())
	run_until(fs, func() -> bool: return a.grounded, 300)
	check("mis: landing lag bij landen", a.state_name() == "LandingFallSpecial", a.state_name())
	free_all(fs)
	# Per-airtime-limiet.
	fs = pair(-40.0, 60.0)
	a = fs[0]
	airborne(a, Vector2(-40.0, 50.0))
	started(a, "up")
	run_until(fs, func() -> bool: return phase_of(a) == "end", 100)
	a.change_state("Fall")
	check("tweede up-B in dezelfde airtime geblokkeerd", not started(a, "up"))
	free_all(fs)
	# Ledge-snap.
	fs = solo(Vector2(LEDGE_X + 6.0, -25.0), -1)
	a = fs[0]
	airborne(a, Vector2(LEDGE_X + 6.0, -25.0))
	a.facing = -1
	started(a, "up")
	var got: int = run_until(fs, func() -> bool: return a.ledge_key != "", 80)
	check("ledge-snap tijdens de rise", got >= 0 and a.state_name() == "CliffCatch", a.state_name())
	free_all(fs)
	# Grab negeert shield.
	fs = pair(-6.0, 3.0)
	a = fs[0]
	b = fs[1]
	started(a, "up")
	var sh: int = run_until(fs, func() -> bool: return b.state_name() == "SpecialHeld", 60,
		[null, fr(0, 0, InputFrame.BTN_SHIELD)])
	check("grab negeert shield", sh >= 0)
	free_all(fs)


## Down-B "Stumble Kick".
func _test_down() -> void:
	print("== down: Stumble Kick")
	var fs: Array = pair(-14.0, 6.0)
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	check("start (grond)", started(a, "down"))
	idle(fs, 6)
	check("grond: geen sprong (blijft op de vloer)", a.grounded and phase_of(a) == "startup", phase_of(a))
	var x0: float = a.pos.x
	run_until(fs, func() -> bool: return phase_of(a) == "slide", 20)
	idle(fs, 4)
	check("glijdt naar voren", a.grounded and a.pos.x > x0 + 4.0)
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("glijdende trap raakt", b.percent >= 7.0, "%.1f" % b.percent)
	check("grond: klaar -> Wait, geen helpless", a.state_name() == "Wait", a.state_name())
	free_all(fs)
	# Stopt aan de rand (geen val).
	fs = solo(Vector2(LEDGE_X - 10.0, 0.0), 1)
	a = fs[0]
	idle(fs, 3)
	started(a, "down")
	run_until(fs, func() -> bool: return a.state_name() != "Special", 80)
	check("slide stopt aan de rand", a.grounded and a.pos.x <= LEDGE_X + 0.01, "%.1f" % a.pos.x)
	free_all(fs)
	# Lucht: stall, dan schuine duik.
	fs = pair(-14.0, 6.0)
	a = fs[0]
	b = fs[1]
	airborne(a, Vector2(-14.0, 26.0))
	check("start (lucht)", started(a, "down"))
	run_until(fs, func() -> bool: return phase_of(a) == "stall", 30)
	var ys: float = a.pos.y
	idle(fs, 8)
	check("stall: hangt bijna stil", ys - a.pos.y < 3.0, "%.2f" % (ys - a.pos.y))
	run_until(fs, func() -> bool: return phase_of(a) == "fall", 30)
	tick(fs)
	check("duik is schuin (x vooruit, y omlaag)", a.vel.x > 2.0 and a.vel.y < -2.0, str(a.vel))
	var landed: int = run_until(fs, func() -> bool: return phase_of(a) == "landing" or a.state_name() == "Landing", 60)
	check("landt", landed >= 0)
	var lag: int = run_until(fs, func() -> bool: return a.state_name() == "Wait", 60)
	check("landing lag (~24 + hitlag)", lag >= 18, str(lag))
	check("duiktrap raakte de dummy", b.percent > 0.0, "%.1f" % b.percent)
	free_all(fs)
	# Lucht: niet helpless na afloop.
	fs = solo(Vector2(0.0, 200.0), 1)
	a = fs[0]
	airborne(a, Vector2(-LEDGE_X - 80.0, 120.0))
	started(a, "down")
	run_until(fs, func() -> bool: return a.state_name() != "Special", 30)
	check("lucht: geen helpless-toestand ingegaan", a.state_name() != "FallSpecial")
	free_all(fs)
	# Ledge-snap tijdens de duik (terug naar de ledge).
	fs = solo(Vector2(LEDGE_X + 18.0, -8.0), -1)
	a = fs[0]
	airborne(a, Vector2(LEDGE_X + 18.0, -8.0))
	a.facing = -1
	started(a, "down")
	var got: int = run_until(fs, func() -> bool: return a.ledge_key != "", 90)
	check("ledge-snap tijdens stall/duik", got >= 0 and a.state_name() == "CliffCatch", "%s %s" % [a.state_name(), a.pos])
	free_all(fs)
	# Per-airtime-limiet.
	fs = pair(-40.0, 60.0)
	a = fs[0]
	airborne(a, Vector2(-40.0, 120.0))
	started(a, "down")
	run_until(fs, func() -> bool: return phase_of(a) == "fall", 60)
	a.change_state("Fall")
	check("tweede down-B in dezelfde airtime geblokkeerd", not started(a, "down"))
	free_all(fs)
