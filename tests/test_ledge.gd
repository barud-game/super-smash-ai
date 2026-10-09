extends SceneTree
## Tests M2: ledge-mechaniek, teeter, KO-API (blast_ko, auto_respawn, respawn_at, percent) en intangibility.
## Headless, gescripte input (eigen InputHistory), sandbox-stub en de echte Eindpunt-stage.
##   Godot_console.exe --headless --path . --script res://tests/test_ledge.gd
## Exit code 0 = alles geslaagd, 1 = minstens één FAIL.

const JUMP: int = InputFrame.BTN_JUMP
const SHIELD: int = InputFrame.BTN_SHIELD
const ATTACK: int = InputFrame.BTN_ATTACK
const LEDGE_X: float = SandboxStage.MAIN_HALF_WIDTH

var _fails: int = 0
var _total: int = 0
var stage: SandboxStage


## Zelfde API als engine/stage/stage.gd (dat de Sim-autoload refereert en dus niet in --script-modus compileert):
## dunne wrapper om StageData. De echte Stage-node wordt in de sandbox (F6) en stage_test.tscn getest.
class DataStage extends RefCounted:
	var data: StageData

	func _init(d: StageData) -> void:
		data = d

	func get_ground_segments() -> Array[StageSegment]:
		return data.ground_segments

	func get_ledges() -> Array[StageLedge]:
		return data.ledges

	func get_blast_zone() -> Rect2:
		return data.blast_zone

	func get_respawn(i: int) -> Vector2:
		return data.respawns[i % data.respawns.size()]


func _initialize() -> void:
	_test_grab_conditions()
	_test_hang_and_catch()
	_test_max_hang()
	_test_getups()
	_test_high_percent()
	_test_drop()
	_test_stale_stick()
	_test_intangibility()
	_test_regrab_and_cooldown()
	_test_steal()
	_test_teeter()
	_test_ko_signals()
	_test_auto_respawn()
	_test_respawn_platform()
	_test_percent()
	_test_real_stage()
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

## Verse stage per scenario (het ledge-register hangt aan de stage).
func new_stage() -> SandboxStage:
	if stage != null:
		stage.free()
	stage = SandboxStage.new()
	return stage


func make(at: Vector2, dir: int, id: String = "allrounder", st: Object = null) -> Fighter:
	var f := Fighter.new()
	f.use_visual = false
	f.auto_register = false
	f.stats = Archetypes.load_stats(id)
	f.stage = st if st != null else stage
	f.input = InputHistory.new()
	f.tap_jump_override = 1
	f.pos = at
	f.facing = dir
	f.setup()
	return f


func step(f: Fighter, sx: int = 0, sy: int = 0, buttons: int = 0) -> void:
	var fr := InputFrame.new()
	fr.stick = Vector2i(sx, sy)
	fr.buttons = buttons
	f.input.push(fr)
	f.sim_tick(0)


func idle(f: Fighter, n: int) -> void:
	for i in n:
		step(f)


## Tikt tot `id` (max `limit`). Geeft het aantal gedane ticks of -1.
func until_state(f: Fighter, id: String, limit: int = 300, sx: int = 0, sy: int = 0, buttons: int = 0) -> int:
	for i in limit:
		if f.state_name() == id:
			return i
		step(f, sx, sy, buttons)
	return limit if f.state_name() == id else -1


## Rechter ledge (side +1): fighter komt van buiten vallen en kijkt naar de stage (facing −1).
func fall_to_right_ledge(id: String = "allrounder") -> Fighter:
	return make(Vector2(LEDGE_X + 6.0, 8.0), -1, id)


func fall_to_left_ledge(id: String = "allrounder") -> Fighter:
	return make(Vector2(-LEDGE_X - 6.0, 8.0), 1, id)


## Valt neutraal tot CliffCatch en daarna tot CliffWait. Geeft de fighter terug in CliffWait.
func hang(f: Fighter) -> Fighter:
	until_state(f, "CliffCatch", 100)
	until_state(f, "CliffWait", 20)
	return f


# --- tests -------------------------------------------------------------------------------------

func _test_grab_conditions() -> void:
	print("== ledge grab: voorwaarden ==")
	new_stage()
	var f := fall_to_right_ledge()
	check("start in Fall", f.state_name() == "Fall")
	var n: int = until_state(f, "CliffCatch", 100)
	check("grab vanuit vallen", n > 0 and f.state_name() == "CliffCatch", "state %s na %d" % [f.state_name(), n])
	var hp: Vector2 = f.ledge_hang_pos(Vector2(LEDGE_X, 0.0), 1)
	check("snap naar de hang-positie", near(f.pos.x, hp.x) and near(f.pos.y, hp.y) and hp.x > LEDGE_X and hp.y < 0.0,
		"pos %s hang %s" % [f.pos, hp])
	check("kijkt naar de stage", f.facing == -1)
	check("sprongen terug na grab", f.air_jumps_used == 0)
	check("niet meer grounded, vel 0", not f.grounded and f.vel == Vector2.ZERO)
	f.free()

	# Linker ledge (side -1) is gespiegeld.
	var l := fall_to_left_ledge()
	until_state(l, "CliffCatch", 100)
	var lh: Vector2 = l.ledge_hang_pos(Vector2(-LEDGE_X, 0.0), -1)
	check("linker ledge: grab + facing +1", l.state_name() == "CliffCatch" and l.facing == 1 and near(l.pos.x, lh.x),
		"state %s pos %s" % [l.state_name(), l.pos])
	l.free()

	# Niet tijdens stijgen: omhoog door de grab-box, geen grab zolang vy >= 0.
	new_stage()
	var r := make(Vector2(LEDGE_X + 6.0, -14.0), -1)
	r.vel = Vector2(0.0, 1.5)
	r.change_state("Jump")
	var grabbed_rising: bool = false
	var rising_frames: int = 0
	for i in 40:
		step(r)
		if r.vel.y > 0.0:
			rising_frames += 1
			if r.state_name() == "CliffCatch":
				grabbed_rising = true
	check("geen grab tijdens stijgen (vy > 0)", rising_frames > 5 and not grabbed_rising, "rising %d, grabbed %s" % [rising_frames, grabbed_rising])
	until_state(r, "CliffCatch", 150)
	check("wel grab zodra hij daarna valt", r.state_name() == "CliffCatch" or r.state_name() == "CliffWait", r.state_name())
	r.free()

	# Verkeerde kijkrichting: geen grab (rug naar de ledge).
	new_stage()
	var b := make(Vector2(LEDGE_X + 6.0, 8.0), 1)
	var ever: bool = false
	for i in 40:
		step(b)
		ever = ever or b.state_name() == "CliffCatch"
	check("geen grab met je rug naar de ledge", not ever)
	b.free()

	# Stick omlaag voorkomt de grab; loslaten van de stick laat hem wel grabben.
	new_stage()
	var d := fall_to_right_ledge()
	ever = false
	for i in 14:
		step(d, 0, -80)
		ever = ever or d.state_name() == "CliffCatch"
	check("stick omlaag in de lucht = geen grab", not ever and d.state_name() == "Fall", d.state_name())
	d.free()

	# Te ver weg (buiten de grab-box): geen grab.
	new_stage()
	var far := make(Vector2(LEDGE_X + 40.0, 8.0), -1)
	ever = false
	for i in 40:
		step(far)
		ever = ever or far.state_name() == "CliffCatch"
	check("buiten de grab-box = geen grab", not ever)
	far.free()

	# FallSpecial (helpless) mag wel grabben; air dodge zelf niet (alleen na de animatie).
	new_stage()
	var fs := make(Vector2(LEDGE_X + 6.0, 8.0), -1)
	fs.change_state("FallSpecial")
	until_state(fs, "CliffCatch", 100)
	check("grab vanuit FallSpecial", fs.state_name() == "CliffCatch")
	fs.free()
	new_stage()
	var ea := make(Vector2(LEDGE_X + 6.0, 8.0), -1)
	ea.change_state("EscapeAir")
	var dodge_frames: int = 0
	var grabbed_during: bool = false
	for i in ea.stats.airdodge_frames - 1:
		step(ea)
		if ea.state_name() == "EscapeAir":
			dodge_frames += 1
		elif ea.state_name() == "CliffCatch":
			grabbed_during = true
	check("geen grab tijdens de air dodge zelf", dodge_frames >= ea.stats.airdodge_frames - 3 and not grabbed_during, "frames %d grab %s" % [dodge_frames, grabbed_during])
	ea.free()


func _test_hang_and_catch() -> void:
	print("== CliffCatch / CliffWait ==")
	new_stage()
	var f := hang(fall_to_right_ledge())
	check("CliffCatch duurt ledge_catch_frames (7) -> CliffWait", f.state_name() == "CliffWait" and f.state_frame <= 1)
	var p0: Vector2 = f.pos
	idle(f, 30)
	check("hangen: positie blijft vast", f.pos == p0 and f.state_name() == "CliffWait")
	check("ledge bezet in het register", stage.get_meta("ledge_occupants").size() == 1)
	f.free()


func _test_max_hang() -> void:
	print("== max hangtijd ==")
	new_stage()
	var f := hang(fall_to_right_ledge())
	check("hang bereikt CliffWait", f.state_name() == "CliffWait")
	var f2 := fall_to_right_ledge()
	until_state(f2, "CliffCatch", 100)
	var ticks: int = 0
	while f2.state_name() != "Fall" and ticks < 900:
		step(f2)
		ticks += 1
	check("max hang low = 660 frames na de grab", absi(ticks - 660) <= 2, "ticks %d" % ticks)
	check("na auto-loslaten: sprongen terug en lock", f2.air_jumps_used == 0 and f2.ledge_cooldown_frames > 0 and f2.ledge_key == "")
	f.free()
	f2.free()
	new_stage()
	var h := fall_to_right_ledge()
	h.percent = 100.0
	until_state(h, "CliffCatch", 100)
	ticks = 0
	while h.state_name() != "Fall" and ticks < 900:
		step(h)
		ticks += 1
	check("max hang high (≥ 100%%) = 480 frames", absi(ticks - 480) <= 2, "ticks %d" % ticks)
	h.free()


## Hang + wacht 40 frames (ledge-intangibility is dan op), dan de optie.
func _getup_run(buttons: int, sx: int, sy: int) -> Dictionary:
	new_stage()
	var f := hang(fall_to_right_ledge())
	idle(f, 40)
	var states: Array = []
	var frames_in: int = 0
	step(f, sx, sy, buttons)
	var first: String = f.state_name()
	for i in 200:
		if f.state_name() != first:
			break
		frames_in += 1
		step(f)
	return {"f": f, "first": first, "frames": frames_in, "next": f.state_name()}


func _test_getups() -> void:
	print("== getups ==")
	# Normale getup: stick naar de stage.
	var r: Dictionary = _getup_run(0, -80, 0)
	var f: Fighter = r["f"]
	check("getup: stick naar de stage -> CliffClimb", r["first"] == "CliffClimb", r["first"])
	check("getup: duur = 33 frames", r["frames"] == 33, "frames %d" % r["frames"])
	check("getup: eindigt op de grond in Wait", f.state_name() == "Wait" and f.grounded, f.state_name())
	check("getup: x = ledge − 12, y = 0", near(f.pos.x, LEDGE_X - 12.0) and near(f.pos.y, 0.0), "pos %s" % f.pos)
	check("getup: ledge vrij", f.ledge_key == "" and stage.get_meta("ledge_occupants").is_empty())
	f.free()
	# Stick omhoog (zonder tap jump) = ook getup.
	new_stage()
	var u := hang(fall_to_right_ledge())
	u.tap_jump_override = 0
	idle(u, 40)
	step(u, 0, 80)
	check("stick omhoog zonder tap jump = getup", u.state_name() == "CliffClimb", u.state_name())
	u.free()
	# Roll: shield.
	r = _getup_run(SHIELD, 0, 0)
	f = r["f"]
	check("roll: shield -> CliffEscape", r["first"] == "CliffEscape", r["first"])
	check("roll: duur = 36 frames", r["frames"] == 36, "frames %d" % r["frames"])
	check("roll: verder de stage op (x = ledge − 28)", f.state_name() == "Wait" and f.grounded and near(f.pos.x, LEDGE_X - 28.0), "pos %s" % f.pos)
	f.free()
	# Ledge attack: A (hook, geen hitbox).
	r = _getup_run(ATTACK, 0, 0)
	f = r["f"]
	check("ledge attack: A -> CliffAttack", r["first"] == "CliffAttack", r["first"])
	check("ledge attack: duur = 55 frames, eindigt in Wait", r["frames"] == 55 and f.state_name() == "Wait" and f.grounded, "frames %d %s" % [r["frames"], f.state_name()])
	f.free()
	# Ledge jump: jump-knop; double jump blijft; landt weer op de stage.
	new_stage()
	var j := hang(fall_to_right_ledge())
	idle(j, 40)
	step(j, 0, 0, JUMP)
	check("ledge jump: knop -> CliffJump", j.state_name() == "CliffJump", j.state_name())
	until_state(j, "Jump", 30)
	check("ledge jump: daarna Jump, stijgend richting de stage", j.state_name() == "Jump" and j.vel.y > 0.0 and j.vel.x < 0.0,
		"%s vel %s" % [j.state_name(), j.vel])
	check("ledge jump: double jump beschikbaar", j.air_jumps_used == 0)
	check("ledge jump: lock op regrab", j.ledge_cooldown_frames > 0 and j.ledge_key == "")
	var landed: bool = false
	for i in 200:
		step(j, -30, 0)
		if j.grounded:
			landed = true
			break
	check("ledge jump: landt op de stage", landed and j.pos.x < LEDGE_X + 0.01, "pos %s" % j.pos)
	j.free()
	# Ledge jump met stick omhoog (tap jump).
	new_stage()
	var t := hang(fall_to_right_ledge())
	idle(t, 40)
	step(t, 0, 80)
	check("ledge jump: stick omhoog (flick) -> CliffJump", t.state_name() == "CliffJump", t.state_name())
	t.free()


func _test_high_percent() -> void:
	print("== getups ≥ 100% ==")
	new_stage()
	var f := hang(fall_to_right_ledge())
	f.percent = 120.0
	idle(f, 40)
	step(f, -80, 0)
	var n: int = 0
	while f.state_name() == "CliffClimb" and n < 200:
		step(f)
		n += 1
	check("getup ≥ 100%%: langzamer (43 frames)", n == 43, "frames %d" % n)
	f.free()
	new_stage()
	var g := hang(fall_to_right_ledge())
	idle(g, 40)
	step(g, -80, 0)
	var short_win: int = 0
	for i in 30:
		if g.state_name() == "CliffClimb" and g.is_intangible():
			short_win += 1
		step(g)
	var h := hang(fall_to_right_ledge())
	h.percent = 150.0
	idle(h, 40)
	step(h, -80, 0)
	var short_win_h: int = 0
	for i in 30:
		if h.state_name() == "CliffClimb" and h.is_intangible():
			short_win_h += 1
		step(h)
	check("getup ≥ 100%%: kortere intangibility (23 -> 13)", short_win == 23 and short_win_h == 13, "%d vs %d" % [short_win, short_win_h])
	g.free()
	h.free()


func _test_drop() -> void:
	print("== loslaten ==")
	# Van de stage af duwen (rechter ledge: naar rechts).
	new_stage()
	var f := hang(fall_to_right_ledge())
	idle(f, 5)
	step(f, 80, 0)
	check("loslaten: stick van de stage af -> Fall", f.state_name() == "Fall" and f.ledge_key == "", f.state_name())
	check("loslaten: lock + alle sprongen terug", f.ledge_cooldown_frames > 0 and f.air_jumps_used == 0)
	step(f, 0, 0, JUMP)
	check("loslaten: double jump nog beschikbaar", f.state_name() == "JumpAerial", f.state_name())
	f.free()
	# Stick omlaag.
	new_stage()
	var d := hang(fall_to_right_ledge())
	idle(d, 5)
	step(d, 0, -80)
	check("loslaten: stick omlaag -> Fall", d.state_name() == "Fall")
	d.free()


func _test_stale_stick() -> void:
	print("== stick die al vóór de grab werd vastgehouden ==")
	new_stage()
	var f := fall_to_right_ledge()
	until_state(f, "CliffCatch", 100, -80, 0)
	check("stale-test: gegrabt", f.state_name() == "CliffCatch", f.state_name())
	var stayed: bool = true
	for i in 30:
		step(f, -80, 0)
		if f.state_name() != "CliffWait" and f.state_name() != "CliffCatch":
			stayed = false
	check("vastgehouden stick naar de stage geeft geen directe getup", stayed, f.state_name())
	step(f)
	step(f, -80, 0)
	check("loslaten en opnieuw duwen = wel getup", f.state_name() == "CliffClimb", f.state_name())
	f.free()


func _test_intangibility() -> void:
	print("== ledge-intangibility ==")
	new_stage()
	var f := fall_to_right_ledge()
	var expect: int = f.stats.ledge_catch_frames + f.stats.ledge_grab_intangible
	until_state(f, "CliffCatch", 100)
	check("grab: 7 + 30 intangible frames", f.intangible_frames == expect and f.is_intangible(), "frames %d" % f.intangible_frames)
	var n: int = 0
	while f.is_intangible() and n < 100:
		step(f)
		n += 1
	check("intangible telt precies af (37 ticks)", n == expect, "n %d" % n)
	check("daarna kwetsbaar tijdens de hang", not f.is_intangible() and f.state_name() == "CliffWait")
	f.free()
	# Ledgestall: loslaten behoudt de resterende frames.
	new_stage()
	var s := hang(fall_to_right_ledge())
	idle(s, 10)
	var left: int = s.intangible_frames
	step(s, 80, 0)
	check("loslaten behoudt resterende intangibility (ledgestall)", s.state_name() == "Fall" and s.intangible_frames > 0 and s.intangible_frames <= left,
		"%d -> %d" % [left, s.intangible_frames])
	s.free()
	# Getup-intangibility (i0..i1 = 1..23) bovenop een verlopen ledge-timer.
	var r: Dictionary = _getup_run(0, -80, 0)
	var g: Fighter = r["f"]
	g.free()
	new_stage()
	var h := hang(fall_to_right_ledge())
	idle(h, 40)
	step(h, -80, 0)
	var counts: Array = []
	for i in 30:
		counts.append(h.is_intangible())
		step(h)
	var on: int = counts.count(true)
	check("getup: intangible op frames 1..23", on == 23 and counts[0] and counts[22] and not counts[23], "aan: %d" % on)
	h.free()


func _test_regrab_and_cooldown() -> void:
	print("== regrab, lock ==")
	new_stage()
	var f := hang(fall_to_right_ledge())
	idle(f, 40)
	check("ledge-timer is op", f.intangible_frames == 0)
	check("eerste grab gebruikt de intangibility", not f.ledge_intang_ready)
	step(f, 80, 0)
	var cd: int = f.ledge_cooldown_frames
	# Lock: elk frame terug in de grab-box zetten; pas na de lock mag hij weer grabben.
	var frames_blocked: int = 0
	var regrabbed: bool = false
	for i in 80:
		f.pos = Vector2(LEDGE_X + 6.0, -8.0)
		f.vel = Vector2(0.0, -0.3)
		if f.state_name() != "Fall":
			f.change_state("Fall")
			f.facing = -1
		step(f)
		if f.state_name() == "CliffCatch":
			regrabbed = true
			break
		frames_blocked += 1
	check("lock na loslaten: ±30 frames geen grab", regrabbed and absi(frames_blocked - cd) <= 2, "geblokkeerd %d, cd %d" % [frames_blocked, cd])
	check("regrab zonder landen = geen intangibility", f.intangible_frames == 0 and not f.is_intangible(), "frames %d" % f.intangible_frames)
	# Landen herstelt: getup (eindigt op de stage) -> volgende grab weer 37 frames.
	idle(f, 40)
	step(f, -80, 0)
	until_state(f, "Wait", 100)
	check("landen op de stage herstelt de ledge-intangibility", f.ledge_intang_ready)
	f.pos = Vector2(LEDGE_X + 6.0, 8.0)
	f.facing = -1
	f.leave_ground(Vector2.ZERO)
	f.change_state("Fall")
	until_state(f, "CliffCatch", 100)
	check("na landen weer ledge-intangibility", f.intangible_frames == 37, "frames %d" % f.intangible_frames)
	# Geraakt worden (hook) herstelt ook.
	idle(f, 5)
	check("na grab niet klaar", not f.ledge_intang_ready)
	f.on_hit_reset_ledge()
	check("on_hit_reset_ledge herstelt", f.ledge_intang_ready)
	f.free()


func _test_steal() -> void:
	print("== ledge-steal ==")
	new_stage()
	var a := hang(fall_to_right_ledge())
	idle(a, 10)
	var stolen_by: Array = []
	a.ledge_stolen.connect(func(by: Fighter) -> void: stolen_by.append(by))
	var b := fall_to_right_ledge("lightweight")
	b.player = 1
	until_state(b, "CliffCatch", 100)
	check("tweede speler grabt de bezette ledge", b.state_name() == "CliffCatch" and b.ledge_key != "")
	step(a)
	check("eerste hanger valt: Fall, geen ledge, sprongen terug", a.state_name() == "Fall" and a.ledge_key == "" and a.air_jumps_used == 0, a.state_name())
	check("ledge_stolen-signaal met de nieuwe hanger", stolen_by.size() == 1 and stolen_by[0] == b)
	check("slachtoffer krijgt lock en herstelde regrab-intangibility", a.ledge_cooldown_frames >= 50 and a.ledge_intang_ready)
	check("register wijst naar de nieuwe hanger", stage.get_meta("ledge_occupants").values() == [b])
	# De nieuwe hanger is niet per ongeluk ook losgelaten.
	idle(b, 20)
	check("nieuwe hanger blijft hangen", b.state_name() == "CliffWait")
	# Vrijgekomen ledge: grab zonder steal.
	step(b, 80, 0)
	var c := fall_to_right_ledge()
	c.player = 2
	var events: Array = []
	b.ledge_stolen.connect(func(by: Fighter) -> void: events.append(by))
	until_state(c, "CliffCatch", 100)
	check("vrije ledge: gewoon grabben, geen steal-event", c.state_name() == "CliffCatch" and events.is_empty())
	a.free()
	b.free()
	c.free()


func _test_teeter() -> void:
	print("== teeter ==")
	new_stage()
	var w := make(Vector2(80, 0), 1)
	idle(w, 2)
	for i in 80:
		step(w, 30, 0)
	check("langzaam lopen tegen de rand = Teeter", w.state_name() == "Teeter" and w.grounded and near(w.pos.x, LEDGE_X), "%s x %.3f" % [w.state_name(), w.pos.x])
	idle(w, 20)
	check("Teeter blijft op de rand staan", w.state_name() == "Teeter" and near(w.pos.x, LEDGE_X))
	step(w, 30, 0)
	check("naar de rand duwen blijft Teeter (geen flikker)", w.state_name() == "Teeter")
	step(w, -80, 0)
	check("stick weg van de rand = omdraaien", w.state_name() == "Turn", w.state_name())
	idle(w, 20)
	check("rug naar de afgrond = Wait (geen teeter)", w.state_name() == "Wait" and w.facing == -1, "%s facing %d" % [w.state_name(), w.facing])
	w.free()
	# Dash uit Teeter valt eraf.
	new_stage()
	var d := make(Vector2(LEDGE_X, 0), 1)
	idle(d, 3)
	check("staan op de rand kijkend naar de afgrond = Teeter", d.state_name() == "Teeter", d.state_name())
	step(d, 0, 0)
	step(d, 80, 0)
	for i in 6:
		step(d, 80, 0)
	check("dash vanuit Teeter valt van de rand", not d.grounded and d.pos.x > LEDGE_X, "%s %s" % [d.state_name(), d.pos])
	d.free()
	# Teeter-pose valt terug op walk zolang de rig geen teeter heeft.
	new_stage()
	var p := make(Vector2(LEDGE_X, 0), 1)
	idle(p, 3)
	check("pose-hook: walk als er geen teeter-pose is", p.state.pose() == "walk" or p.state.pose() == "teeter")
	p.free()


func _test_ko_signals() -> void:
	print("== blast_ko ==")
	var tmp_stage := SandboxStage.new()
	var bz: Rect2 = tmp_stage.blast_zone
	tmp_stage.free()
	var cases: Array = [
		[&"left", Vector2(bz.position.x - 5.0, 20.0)],
		[&"right", Vector2(bz.end.x + 5.0, 20.0)],
		[&"top", Vector2(10.0, bz.end.y + 5.0)],
		[&"bottom", Vector2(10.0, bz.position.y - 5.0)],
	]
	for c: Array in cases:
		new_stage()
		var f := make(Vector2(0, 20), 1)
		f.auto_respawn = false
		var got: Array = []
		f.blast_ko.connect(func(fi: Fighter, side: StringName) -> void: got.append([fi, side]))
		step(f)
		check("%s: nog geen KO binnen de blast zone" % c[0], got.is_empty() and f.active)
		f.pos = c[1]
		step(f)
		check("blast_ko side=%s op het frame van verlaten" % c[0], got.size() == 1 and got[0][0] == f and got[0][1] == c[0], str(got))
		check("%s: auto_respawn=false -> inactief en verborgen" % c[0], not f.active and not f.visible and f.state_name() == "Dead")
		var ticks: int = f.tick_count
		idle(f, 5)
		check("%s: inactieve fighter tikt niet en meldt niet opnieuw" % c[0], f.tick_count == ticks and got.size() == 1)
		f.free()
	# Hoek: grootste overschrijding wint.
	new_stage()
	var k := make(Vector2(0, 20), 1)
	k.auto_respawn = false
	var side_seen: Array = []
	k.blast_ko.connect(func(_fi: Fighter, side: StringName) -> void: side_seen.append(side))
	k.pos = Vector2(bz.end.x + 40.0, bz.position.y - 3.0)
	step(k)
	check("hoek: grootste overschrijding bepaalt de zijde", side_seen == [&"right"], str(side_seen))
	k.free()
	# Bonus: respawn_at brengt hem terug.
	new_stage()
	var r := make(Vector2(0, 20), 1)
	r.auto_respawn = false
	r.pos = Vector2(bz.end.x + 5.0, 0.0)
	step(r)
	r.respawn_at(Vector2(0.0, 80.0), 90)
	check("respawn_at na KO: actief, zichtbaar, op het punt, RebirthWait", r.active and r.visible and r.pos == Vector2(0.0, 80.0) and r.state_name() == "RebirthWait")
	check("respawn_at: intangible_frames = 90", r.intangible_frames == 90 and r.is_intangible())
	r.free()
	# Een handler die in het signaal al respawnt wordt niet overschreven door auto_respawn.
	new_stage()
	var h := make(Vector2(0, 20), 1)
	h.auto_respawn = true
	h.blast_ko.connect(func(fi: Fighter, _s: StringName) -> void: fi.respawn_at(Vector2(5.0, 70.0), 33))
	h.pos = Vector2(bz.end.x + 5.0, 0.0)
	step(h)
	check("handler-respawn in blast_ko wint van auto_respawn", h.pos == Vector2(5.0, 70.0) and h.intangible_frames == 33, "pos %s frames %d" % [h.pos, h.intangible_frames])
	h.free()


func _test_auto_respawn() -> void:
	print("== auto_respawn ==")
	new_stage()
	var f := make(Vector2(0, 20), 1)
	check("auto_respawn staat standaard aan", f.auto_respawn)
	var kos: Array = []
	f.blast_ko.connect(func(_fi: Fighter, side: StringName) -> void: kos.append(side))
	f.pos = Vector2(0.0, stage.blast_zone.position.y - 4.0)
	step(f)
	check("auto_respawn: KO gemeld én direct terug op het respawnpunt", kos == [&"bottom"] and f.active and f.visible and near(f.pos.x, 0.0) and near(f.pos.y, 80.0), "kos %s pos %s" % [kos, f.pos])
	check("auto_respawn: respawn-platform + invincibility 120", f.state_name() == "RebirthWait" and f.intangible_frames == 120, "%s %d" % [f.state_name(), f.intangible_frames])
	f.free()


func _test_respawn_platform() -> void:
	print("== respawn-platform ==")
	new_stage()
	var f := make(Vector2(0, 0), 1)
	f.respawn_at(Vector2(0.0, 80.0), 120)
	var p0: Vector2 = f.pos
	idle(f, 100)
	check("stilstaan op het platform (geen gravity)", f.state_name() == "RebirthWait" and f.pos == p0 and f.vel == Vector2.ZERO)
	check("invincibility telt af", f.intangible_frames == 20, "frames %d" % f.intangible_frames)
	idle(f, 20)
	check("invincibility op na 120 ticks", f.intangible_frames == 0 and not f.is_intangible(), "frames %d" % f.intangible_frames)
	f.free()
	# Input beëindigt het wachten (na de minimale wachttijd).
	new_stage()
	var g := make(Vector2(0, 0), 1)
	g.respawn_at(Vector2(0.0, 80.0), 120)
	idle(g, 5)
	step(g, 80, 0)
	check("input binnen de minimale wachttijd telt nog niet", g.state_name() == "RebirthWait")
	idle(g, 20)
	step(g, 80, 0)
	check("stick na de minimale wachttijd -> Fall met alle sprongen", g.state_name() == "Fall" and g.air_jumps_used == 0, g.state_name())
	check("invincibility loopt door na het platform", g.intangible_frames > 0)
	g.free()
	# Lengte van het wachten exact meten.
	new_stage()
	var h := make(Vector2(0, 0), 1)
	h.respawn_at(Vector2(0.0, 80.0), 120)
	var ticks: int = 0
	while h.state_name() == "RebirthWait" and ticks < 1000:
		step(h)
		ticks += 1
	check("RebirthWait duurt 300 frames zonder input", ticks == 300, "ticks %d" % ticks)
	h.free()


func _test_percent() -> void:
	print("== percent ==")
	new_stage()
	var f := make(Vector2(0, 0), 1)
	var seen: Array = []
	f.percent_changed.connect(func(p: float) -> void: seen.append(p))
	check("percent start 0", f.percent == 0.0)
	f.percent = 42.5
	check("setter meldt percent_changed", f.percent == 42.5 and seen == [42.5])
	f.percent = 42.5
	check("zelfde waarde meldt niets", seen.size() == 1)
	f.percent = -10.0
	check("percent klemt op ≥ 0", f.percent == 0.0 and seen == [42.5, 0.0])
	f.free()


func _test_real_stage() -> void:
	print("== echte stage: Eindpunt ==")
	var data: StageData = load("res://stages/eindpunt/eindpunt.tres")
	var st := DataStage.new(data)
	var rx: float = data.right()
	var f := make(Vector2(rx + 6.0, 8.0), -1, "allrounder", st)
	check("Eindpunt: fighter valt (geen grond onder)", f.state_name() == "Fall")
	until_state(f, "CliffCatch", 100)
	check("Eindpunt: grab aan de rechter ledge", f.state_name() == "CliffCatch" and f.ledge_side == 1 and near(f.ledge_pos.x, rx), "%s" % f.state_name())
	until_state(f, "CliffWait", 20)
	idle(f, 40)
	step(f, -80, 0)
	until_state(f, "Wait", 100)
	check("Eindpunt: getup landt op de stage", f.grounded and near(f.pos.y, 0.0) and near(f.pos.x, rx - 12.0, 0.01), "pos %s %s" % [f.pos, f.state_name()])
	f.free()
	var l := make(Vector2(data.left() - 6.0, 8.0), 1, "heavyweight", st)
	until_state(l, "CliffCatch", 100)
	check("Eindpunt: grab aan de linker ledge", l.state_name() == "CliffCatch" and l.ledge_side == -1 and l.facing == 1)
	l.free()
	# KO-zijden op de echte blast zone.
	var bz: Rect2 = st.get_blast_zone()
	var k := make(Vector2(0, 10), 1, "allrounder", st)
	k.auto_respawn = false
	var got: Array = []
	k.blast_ko.connect(func(_fi: Fighter, side: StringName) -> void: got.append(side))
	k.pos = Vector2(bz.position.x - 2.0, 0.0)
	step(k)
	check("Eindpunt: KO links", got == [&"left"], str(got))
	k.respawn_at(st.get_respawn(0), 60)
	check("Eindpunt: respawn_at op get_respawn", k.pos == st.get_respawn(0) and k.state_name() == "RebirthWait")
	k.free()


func _script_input(i: int) -> Array:
	# Valt naar de ledge, hangt, doet een getup, loopt, valt van de rand, double jump, ...
	if i < 80:
		return [0, 0, 0]
	if i == 120:
		return [-80, 0, 0]
	if i == 125 or i == 126:
		return [0, 0, 0]
	if i > 160 and i < 190:
		return [80, 0, 0]
	if i == 200:
		return [0, 0, JUMP]
	return [0, 0, 0]


func _test_determinism() -> void:
	print("== determinisme ==")
	var runs: Array = []
	for r in 2:
		new_stage()
		var f := fall_to_right_ledge()
		var trace: Array = []
		for i in 400:
			var inp: Array = _script_input(i)
			step(f, inp[0], inp[1], inp[2])
			trace.append(f.snapshot())
		runs.append(trace)
		f.free()
	var same: bool = runs[0] == runs[1]
	check("determinisme: zelfde inputreeks = identieke ledge-reeks (400 frames)", same)
	var saw_ledge: bool = false
	for snap: Array in runs[0]:
		if snap[0] == "CliffWait":
			saw_ledge = true
	check("determinisme-reeks bevat daadwerkelijk een ledge-hang", saw_ledge)
