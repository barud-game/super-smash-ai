extends SceneTree
## Vergelijkingstests M1-movement tegen Melee-waarden. Headless, gescripte input (eigen InputHistory).
##   Godot_console.exe --headless --path . --script res://tests/test_movement.gd
## Exit code 0 = alles geslaagd, 1 = minstens één FAIL.

const TOL: float = 0.001
const JUMP: int = InputFrame.BTN_JUMP
const SHIELD: int = InputFrame.BTN_SHIELD
## Wavedash-stick: down-forward, binnen de cirkel (75² + 27² <= 6400), ~-19.8°.
const WD_STICK := Vector2i(75, -27)

## Gepubliceerde Melee-hoogtes (docs/melee-referentie.md, tabel B1) per archetype-referentie.
const REF: Dictionary = {
	"fast_faller": {"char": "Fox", "fh": 31.28, "sh": 10.65},
	"allrounder": {"char": "Marth", "fh": 35.09, "sh": 13.995},
	"heavyweight": {"char": "Ganondorf", "fh": 27.3, "sh": 16.4},
	"floaty": {"char": "Peach", "fh": 31.36, "sh": 16.8},
	"lightweight": {"char": "Pikachu", "fh": 32.04, "sh": 14.0},
}

var _fails: int = 0
var _total: int = 0
var stage: SandboxStage


func _initialize() -> void:
	stage = SandboxStage.new()
	for id: String in Archetypes.IDS:
		print("")
		print("== archetype: %s (%s) ==" % [id, REF[id]["char"]])
		_test_jumps(id)
		_test_fast_fall(id)
		_test_terminal_and_drift(id)
		_test_dash(id)
		_test_wavedash(id)
		_test_platforms(id)
	print("")
	print("== algemeen ==")
	_test_wavedash_compare()
	_test_tap_jump()
	_test_momentum()
	_test_edges()
	_test_airdodge_timing()
	_test_crouch()
	_test_run_turn()
	_test_special_fall_platform()
	_test_xbox_dash_dance()
	_test_xbox_fast_fall()
	_test_xbox_run_turn()
	_test_xbox_run_stop_overshoot()
	_test_determinism()
	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	stage.free()
	quit(1 if _fails > 0 else 0)


func check(name: String, cond: bool, detail: String = "") -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, ("   (" + detail + ")") if detail != "" else "")


func near(a: float, b: float, tol: float = TOL) -> bool:
	return absf(a - b) <= tol


# --- harnas ------------------------------------------------------------------------------------

func make(id: String, at: Vector2 = Vector2.ZERO, dir: int = 1) -> Fighter:
	var f := Fighter.new()
	f.use_visual = false
	f.auto_register = false
	f.stats = Archetypes.load_stats(id)
	f.stage = stage
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


## Tikt tot de state `id` is (max `limit` frames). Geeft het aantal frames of -1.
func until_state(f: Fighter, id: String, limit: int = 300, sx: int = 0, sy: int = 0, buttons: int = 0) -> int:
	for i in limit:
		if f.state_name() == id:
			return i
		step(f, sx, sy, buttons)
	return limit if f.state_name() == id else -1


## Grondsprong met de knop `held` frames vast (het indrukframe telt mee). Meet hoogte tot landen.
## Geeft {js: frames in KneeBend, height: max hoogte, landing: frames in Landing, short: bool}.
func do_jump(f: Fighter, held: int) -> Dictionary:
	var y0: float = f.pos.y
	var js: int = 0
	var max_y: float = y0
	var short: bool = false
	var frame: int = 0
	while frame < 400:
		var b: int = JUMP if frame < held else 0
		step(f, 0, 0, b)
		frame += 1
		if f.state_name() == "KneeBend":
			js += 1
		if f.state_name() == "Jump" and f.state_frame == 0:
			short = (f.state as StateJump).short_hop
		max_y = maxf(max_y, f.pos.y)
		if f.state_name() == "Landing":
			break
	var landing: int = 0
	while f.state_name() == "Landing" and landing < 100:
		landing += 1
		step(f)
	return {"js": js, "height": max_y - y0, "landing": landing, "short": short}


# --- per archetype -----------------------------------------------------------------------------

func _test_jumps(id: String) -> void:
	var s: FighterStats = Archetypes.load_stats(id)
	var ref: Dictionary = REF[id]
	var f := make(id, Vector2(0, 0))
	check("%s: spawnt op de grond in Wait" % id, f.grounded and f.state_name() == "Wait")
	var full: Dictionary = do_jump(f, 400)
	check("%s: jumpsquat = %d frames" % [id, s.jumpsquat_frames], full["js"] == s.jumpsquat_frames, "kreeg %d" % full["js"])
	check("%s: full hop hoogte = stats (%.3f)" % [id, s.full_hop_height()], near(full["height"], s.full_hop_height()), "kreeg %.4f" % full["height"])
	check("%s: full hop = Melee %s %.3f" % [id, ref["char"], ref["fh"]], near(full["height"], ref["fh"], 0.01), "kreeg %.4f" % full["height"])
	check("%s: landing lag = %d frames" % [id, s.normal_landing_lag], full["landing"] == s.normal_landing_lag, "kreeg %d" % full["landing"])
	check("%s: na landing lag actionable (Wait)" % id, f.state_name() == "Wait")
	# Short hop: losgelaten op het laatste frame van het venster (jumpsquat − 1 frames vastgehouden).
	idle(f, 5)
	var sh: Dictionary = do_jump(f, s.jumpsquat_frames - 1)
	check("%s: short hop als losgelaten binnen venster (%d frames vast)" % [id, s.jumpsquat_frames - 1], sh["short"])
	check("%s: short hop hoogte = stats (%.3f)" % [id, s.short_hop_height()], near(sh["height"], s.short_hop_height()), "kreeg %.4f" % sh["height"])
	check("%s: short hop = Melee %s %.3f" % [id, ref["char"], ref["sh"]], near(sh["height"], ref["sh"], 0.01), "kreeg %.4f" % sh["height"])
	idle(f, 5)
	var late: Dictionary = do_jump(f, s.jumpsquat_frames)
	check("%s: losgelaten op het afzetframe = full hop" % id, not late["short"] and near(late["height"], s.full_hop_height()), "kreeg %.4f" % late["height"])
	# Double jump: vy op het eerste frame = v_dj − gravity (gravity werkt al), daarna geen derde sprong.
	idle(f, 5)
	step(f, 0, 0, JUMP)
	until_state(f, "Fall", 200, 0, 0, JUMP)
	step(f)
	step(f, 0, 0, JUMP)
	check("%s: double jump" % id, f.state_name() == "JumpAerial")
	check("%s: double jump vy = v*mult − g" % id, near(f.vel.y, s.air_jump_velocity(0) - s.gravity), "vy %.4f" % f.vel.y)
	step(f)
	step(f, 0, 0, JUMP)
	check("%s: geen extra luchtsprong (max %d)" % [id, s.air_jumps], f.state_name() == "JumpAerial" and f.air_jumps_used == s.air_jumps)
	f.free()


func _test_fast_fall(id: String) -> void:
	var s: FighterStats = Archetypes.load_stats(id)
	var f := make(id)
	step(f, 0, 0, JUMP)
	until_state(f, "Jump", 20, 0, 0, JUMP)
	step(f, 0, 0, JUMP)
	step(f, 0, 0, JUMP)
	# flick omlaag tijdens het stijgen: geen fast fall
	step(f, 0, -80)
	step(f)
	check("%s: geen fast fall vóór de apex" % id, not f.fastfalling and f.vel.y > 0.0)
	var guard: int = 0
	while f.vel.y >= 0.0 and guard < 200:
		step(f)
		guard += 1
	step(f, 0, -80)
	check("%s: fast fall na de apex" % id, f.fastfalling)
	check("%s: fast fall snelheid = %.2f" % [id, s.fast_fall_velocity], near(f.vel.y, -s.fast_fall_velocity), "vy %.4f" % f.vel.y)
	step(f)
	check("%s: fast fall blijft (geen gravity meer)" % id, near(f.vel.y, -s.fast_fall_velocity))
	# langzaam omlaag (teller >= venster) geeft geen fast fall
	var g := make(id)
	step(g, 0, 0, JUMP)
	until_state(g, "Fall", 200, 0, 0, JUMP)
	# drempel (-53) pas gehaald op teller 5 >= venster 4
	for v in [-30, -30, -40, -40, -50, -60, -80]:
		step(g, 0, v)
	check("%s: langzaam omlaag = geen fast fall" % id, not g.fastfalling)
	f.free()
	g.free()


func _test_terminal_and_drift(id: String) -> void:
	var s: FighterStats = Archetypes.load_stats(id)
	var f := make(id, Vector2(70, 150))
	check("%s: spawn in de lucht = Fall" % id, f.state_name() == "Fall" and not f.grounded)
	idle(f, 40)
	check("%s: terminal velocity %.2f bereikt" % [id, s.terminal_velocity], near(f.vel.y, -s.terminal_velocity), "vy %.4f" % f.vel.y)
	var g := make(id, Vector2(-70, 190))
	for i in 60:
		step(g, 80, 0)
	check("%s: air drift naar max air speed %.2f" % [id, s.max_air_speed], near(g.vel.x, s.max_air_speed), "vx %.4f" % g.vel.x)
	for i in 3:
		step(g)
	check("%s: zonder stick remt air friction" % id, near(g.vel.x, s.max_air_speed - 3.0 * s.air_friction), "vx %.4f" % g.vel.x)
	f.free()
	g.free()


func _test_dash(id: String) -> void:
	var s: FighterStats = Archetypes.load_stats(id)
	var f := make(id, Vector2(-80, 0))
	idle(f, 2)
	var x0: float = f.pos.x
	step(f, 80, 0)
	check("%s: flick = Dash" % id, f.state_name() == "Dash")
	check("%s: initial dash snelheid %.2f" % [id, s.dash_initial_velocity], near(f.gr_vel, s.dash_initial_velocity), "gr_vel %.4f" % f.gr_vel)
	check("%s: eerste dash-frame verplaatst initial dash" % id, near(f.pos.x - x0, s.dash_initial_velocity))
	var dash_frames: int = 1
	while f.state_name() == "Dash" and dash_frames < 100:
		step(f, 80, 0)
		if f.state_name() == "Dash":
			dash_frames += 1
	check("%s: initial dash duurt %d frames, dan Run" % [id, s.dash_frames], dash_frames == s.dash_frames and f.state_name() == "Run", "%d frames, %s" % [dash_frames, f.state_name()])
	for i in 50:
		step(f, 80, 0)
	check("%s: run speed %.2f" % [id, s.run_speed], near(f.gr_vel, s.run_speed), "gr_vel %.4f" % f.gr_vel)
	step(f)
	check("%s: stick los tijdens run = RunBrake" % id, f.state_name() == "RunBrake")
	var v0: float = f.gr_vel
	step(f)
	check("%s: RunBrake remt met traction (geen x2)" % id, near(v0 - f.gr_vel, s.traction), "delta %.4f" % (v0 - f.gr_vel))
	f.free()

	# Dash-dance: binnen de initial dash terugtikken.
	var d := make(id, Vector2(0, 0))
	idle(d, 2)
	step(d, 80, 0)
	step(d, 80, 0)
	step(d, 80, 0)
	step(d, -80, 0)
	check("%s: dash-dance: terugflick = smash-turn" % id, d.state_name() == "Turn" and d.facing == -1)
	step(d, -80, 0)
	check("%s: dash-dance: volgende frame Dash links met initial dash" % id,
		d.state_name() == "Dash" and d.facing == -1 and near(d.gr_vel, -s.dash_initial_velocity), "%s gr_vel %.3f" % [d.state_name(), d.gr_vel])
	step(d, 80, 0)
	step(d, 80, 0)
	check("%s: dash-dance terug naar rechts" % id, d.state_name() == "Dash" and d.facing == 1)
	# Foxtrot: dash uit laten lopen (stick neutraal) -> Wait, opnieuw flicken -> Dash.
	until_state(d, "Wait", 60)
	step(d, 80, 0)
	check("%s: foxtrot (dash na dash)" % id, d.state_name() == "Dash")
	d.free()

	# Dashback vanuit stilstand: smash-turn (1 frame) -> Dash.
	var b := make(id, Vector2(0, 0), 1)
	idle(b, 3)
	step(b, -80, 0)
	step(b, -80, 0)
	check("%s: dashback (snelle flick) = Dash links na 1 turn-frame" % id, b.state_name() == "Dash" and b.facing == -1)
	b.free()
	# UCF dashback: eerste frame in tilt-gebied (Turn), tweede frame vol binnen venster -> Dash.
	var u := make(id, Vector2(0, 0), 1)
	idle(u, 3)
	step(u, -40, 0)
	check("%s: tilt terug = Turn" % id, u.state_name() == "Turn" and not (u.state as StateTurn).smash)
	step(u, -80, 0)
	check("%s: UCF dashback: tilt-turn wordt alsnog Dash" % id, u.state_name() == "Dash" and u.facing == -1)
	u.free()
	var v := make(id, Vector2(0, 0), 1)
	v.ucf_dashback = false
	idle(v, 3)
	step(v, -40, 0)
	step(v, -80, 0)
	check("%s: zonder UCF blijft dezelfde input een Turn (vanilla)" % id, v.state_name() == "Turn")
	v.free()


func _wavedash(f: Fighter) -> Dictionary:
	# Jump, op het afzetframe air dodge diagonaal omlaag (frame-perfect wavedash).
	var js: int = f.stats.jumpsquat_frames
	var x0: float = f.pos.x
	step(f, 0, 0, JUMP)
	for i in js - 1:
		step(f, 0, 0, JUMP)
	step(f, WD_STICK.x, WD_STICK.y, SHIELD)
	var landed: bool = f.state_name() == "LandingFallSpecial"
	var lag: int = 0
	var start_vel: float = f.gr_vel
	while f.state_name() == "LandingFallSpecial" and lag < 100:
		lag += 1
		step(f)
	var slide_x: float = f.pos.x
	idle(f, 60)
	return {"landed": landed, "lag": lag, "slide": f.pos.x - x0, "in_lag": slide_x - x0, "v": start_vel}


func _test_wavedash(id: String) -> void:
	var s: FighterStats = Archetypes.load_stats(id)
	var f := make(id, Vector2(-60, 0))
	idle(f, 2)
	var r: Dictionary = _wavedash(f)
	check("%s: wavedash landt direct in LandingFallSpecial" % id, r["landed"])
	check("%s: wavedash landing lag = %d frames" % [id, s.airdodge_landing_lag], r["lag"] == s.airdodge_landing_lag, "kreeg %d" % r["lag"])
	check("%s: wavedash glijdt (afstand > 0)" % id, r["slide"] > 1.0, "%.3f" % r["slide"])
	var expect_v: float = s.airdodge_force * cos(atan2(float(WD_STICK.y), float(WD_STICK.x)))
	check("%s: wavedash grondsnelheid = air dodge vx" % id, near(r["v"], expect_v), "%.4f vs %.4f" % [r["v"], expect_v])
	check("%s: na wavedash actionable (Wait)" % id, f.state_name() == "Wait")
	print("      wavedash %s: afstand %.2f units" % [id, r["slide"]])
	f.free()


func _test_platforms(id: String) -> void:
	# Waveland op het rechterplatform (y = 27.2).
	var f := make(id, Vector2(38, 31))
	step(f)
	step(f, WD_STICK.x, WD_STICK.y, SHIELD)
	check("%s: air dodge boven platform" % id, f.state_name() == "EscapeAir" or f.state_name() == "LandingFallSpecial")
	var n: int = until_state(f, "LandingFallSpecial", 30)
	check("%s: waveland op platform" % id, n >= 0 and f.grounded and near(f.pos.y, 27.2), "%s y %.3f" % [f.state_name(), f.pos.y])
	f.free()
	# Platform drop: op platform, flick omlaag -> door het platform vallen.
	var p := make(id, Vector2(38, 27.2))
	check("%s: spawn op platform" % id, p.grounded and p.state_name() == "Wait")
	idle(p, 2)
	step(p, 0, -80)
	step(p, 0, -80)
	check("%s: platform drop (flick omlaag)" % id, not p.grounded and p.state_name() == "Fall", p.state_name())
	idle(p, 10)
	check("%s: valt onder het platform door" % id, p.pos.y < 27.2 - 1.0, "y %.3f" % p.pos.y)
	until_state(p, "Wait", 200)
	check("%s: landt daarna op de hoofdstage" % id, p.grounded and near(p.pos.y, 0.0))
	p.free()
	# Langzaam hurken op een platform: geen drop.
	var q := make(id, Vector2(38, 27.2))
	idle(q, 2)
	for v in [-30, -40, -50, -60, -60, -60, -60]:
		step(q, 0, v)
	check("%s: langzaam hurken = blijft op platform" % id, q.grounded and near(q.pos.y, 27.2), q.state_name())
	q.free()
	# Door een platform omhoog springen en erop landen.
	var j := make(id, Vector2(38, 0))
	idle(j, 2)
	var landed_on_plat: bool = false
	step(j, 0, 0, JUMP)
	for i in 200:
		step(j, 0, 0, JUMP)
		if j.grounded and j.state_name() in ["Landing", "Wait"]:
			landed_on_plat = near(j.pos.y, 27.2)
			break
	var s: FighterStats = j.stats
	if s.full_hop_height() > 27.2:
		check("%s: springt door platform omhoog en landt erop" % id, landed_on_plat, "y %.3f" % j.pos.y)
	j.free()


# --- algemeen ----------------------------------------------------------------------------------

func _test_wavedash_compare() -> void:
	var fox := make("fast_faller", Vector2(-60, 0))
	var peach := make("floaty", Vector2(-60, 0))
	idle(fox, 2)
	idle(peach, 2)
	var a: Dictionary = _wavedash(fox)
	var b: Dictionary = _wavedash(peach)
	check("fast-faller glijdt verder dan floaty (%.2f > %.2f)" % [a["slide"], b["slide"]], a["slide"] > b["slide"])
	fox.free()
	peach.free()


func _test_tap_jump() -> void:
	var f := make("fast_faller")
	idle(f, 2)
	step(f, 0, 80)
	check("tap jump: stick omhoog-flick = KneeBend (tap)", f.state_name() == "KneeBend" and (f.state as StateKneeBend).tap)
	until_state(f, "Jump", 10, 0, 80)
	check("tap jump: stick omhoog houden = full hop", not (f.state as StateJump).short_hop)
	# zelfde flick geeft geen double jump
	step(f, 0, 80)
	step(f, 0, 80)
	check("tap jump: dezelfde flick geeft geen double jump", f.state_name() == "Jump" and f.air_jumps_used == 0)
	f.free()
	var s := make("fast_faller")
	idle(s, 2)
	step(s, 0, 80)
	step(s, 0, 40)
	until_state(s, "Jump", 10)
	check("tap jump: stick zakt tijdens jumpsquat = short hop", (s.state as StateJump).short_hop)
	s.free()
	var o := make("fast_faller")
	o.tap_jump_override = 0
	idle(o, 2)
	step(o, 0, 80)
	check("tap jump uit: stick omhoog springt niet", o.state_name() != "KneeBend")
	o.free()


func _test_momentum() -> void:
	var f := make("fast_faller", Vector2(-80, 0))
	idle(f, 2)
	for i in 40:
		step(f, 80, 0)
	var gv: float = f.gr_vel
	var st: FighterStats = f.stats
	step(f, 80, 0, JUMP)
	until_state(f, "Jump", 10, 80, 0, JUMP)
	var expect: float = clampf(gv * st.ground_to_air_jump_momentum_multiplier + 1.0 * st.jump_h_initial_velocity,
		-st.jump_h_max_velocity, st.jump_h_max_velocity)
	# gr_vel verandert tijdens jumpsquat door wrijving; herbereken met de gr_vel net voor afzet is lastig,
	# dus check dat vx de formule volgt binnen de grens.
	check("run-jump: vx begrensd op jump_h_max (%.2f)" % st.jump_h_max_velocity, f.vel.x <= st.jump_h_max_velocity + TOL and f.vel.x > 0.0, "vx %.4f (verwacht ~%.4f)" % [f.vel.x, expect])
	until_state(f, "Fall", 100)
	step(f, -80, 0, JUMP)
	# vx = -air_jump_h_multiplier, daarna nog één frame drift (max één accel- of friction-stap).
	var drift_step: float = maxf(st.air_friction, st.air_accel_base + st.air_accel_additional)
	check("double jump vervangt momentum: vx = stick*air_jump_h (ondanks run-momentum naar rechts)",
		f.state_name() == "JumpAerial" and near(f.vel.x, -st.air_jump_h_multiplier, drift_step + TOL), "vx %.4f" % f.vel.x)
	f.free()
	# Staande sprong zonder stick: vx = 0.
	var g := make("allrounder")
	idle(g, 2)
	until_state(g, "Jump", 10, 0, 0, JUMP)
	check("stilstaande sprong: vx = 0", near(g.vel.x, 0.0))
	g.free()


func _test_edges() -> void:
	# Run van de rand af -> Fall met horizontale snelheid; luchtsprong blijft over.
	var f := make("fast_faller", Vector2(60, 0))
	idle(f, 2)
	var n: int = 0
	while f.grounded and n < 100:
		step(f, 80, 0)
		n += 1
	check("van de rand af rennen = Fall", f.state_name() == "Fall" and f.vel.x > 1.0)
	check("na van de rand lopen: luchtsprong beschikbaar", f.air_jumps_used == 0)
	f.free()
	# Langzaam lopen stopt aan de rand.
	var w := make("allrounder", Vector2(80, 0))
	idle(w, 2)
	for i in 80:
		step(w, 30, 0)
	check("langzaam lopen stopt aan de rand", w.grounded and near(w.pos.x, SandboxStage.MAIN_HALF_WIDTH), "x %.3f %s" % [w.pos.x, w.state_name()])
	w.free()
	# Onder de blast zone: respawn bovenaan.
	var b := make("fast_faller", Vector2(120, 0))
	var respawned: bool = false
	var lowest: float = 0.0
	for i in 200:
		var prev_y: float = b.pos.y
		step(b, 0, -80)
		lowest = minf(lowest, prev_y)
		if b.pos.y > prev_y + 50.0:
			respawned = true
			break
	check("onder blast zone (-108.8) = respawn bovenaan", respawned and lowest > -108.8 - 4.0 and near(b.pos.x, 0.0) and b.state_name() == "Fall",
		"respawned %s, laagste y %.2f, pos %s" % [respawned, lowest, b.pos])
	b.free()


func _test_airdodge_timing() -> void:
	var f := make("fast_faller", Vector2(70, 120))
	step(f)
	step(f, 0, 0, SHIELD)
	check("air dodge neutraal = vel 0", f.state_name() == "EscapeAir" and f.vel == Vector2.ZERO)
	var intang: Array[int] = []
	var frames: int = 0
	while f.state_name() == "EscapeAir" and frames < 100:
		frames += 1
		if f.state.intangible():
			intang.append(f.state_frame + 1)
		step(f)
	check("air dodge duurt 49 frames", frames == 49, "kreeg %d" % frames)
	check("intangible frames 4-29", intang.size() == 26 and intang[0] == 4 and intang[-1] == 29, str(intang.size()))
	check("na air dodge = FallSpecial", f.state_name() == "FallSpecial")
	step(f, 0, 0, JUMP)
	check("FallSpecial: geen double jump", f.state_name() == "FallSpecial")
	until_state(f, "Wait", 300)
	check("FallSpecial landt via LandingFallSpecial -> Wait", f.state_name() == "Wait" and f.prev_state_name == "LandingFallSpecial")
	f.free()


func _test_crouch() -> void:
	var f := make("allrounder")
	idle(f, 2)
	step(f, 0, -80)
	check("stick omlaag = Squat", f.state_name() == "Squat")
	until_state(f, "SquatWait", 20, 0, -80)
	check("Squat -> SquatWait", f.state_name() == "SquatWait")
	step(f)
	check("stick los = SquatRv", f.state_name() == "SquatRv")
	until_state(f, "Wait", 20)
	check("SquatRv -> Wait", f.state_name() == "Wait")
	# Walk
	step(f, 40, 0)
	check("halve stick = Walk", f.state_name() == "Walk")
	for i in 60:
		step(f, 40, 0)
	check("walk-snelheid = stick*walk_max", near(f.gr_vel, 0.5 * f.stats.walk_max_velocity), "%.4f" % f.gr_vel)
	f.free()


func _test_run_turn() -> void:
	var f := make("allrounder", Vector2(-70, 0))
	idle(f, 2)
	for i in 30:
		step(f, 80, 0)
	check("run voor turnaround", f.state_name() == "Run")
	step(f, -80, 0)
	check("stick terug tijdens run = RunTurn", f.state_name() == "RunTurn")
	var frames: int = 0
	var flipped_at: int = -1
	while f.state_name() == "RunTurn" and frames < 120:
		step(f, -80, 0)
		frames += 1
		if flipped_at < 0 and f.facing == -1:
			flipped_at = frames
	check("RunTurn: remt eerst af (traction) en draait dan om", flipped_at >= int(f.stats.run_speed / f.stats.traction) - 1, "omgedraaid na %d frames" % flipped_at)
	check("RunTurn -> Run in de nieuwe richting", f.state_name() == "Run" and f.facing == -1 and f.gr_vel < 0.0, "%s na %d frames" % [f.state_name(), frames])
	step(f, 0, -80)
	check("stick omlaag tijdens run -> RunBrake", f.state_name() == "RunBrake")
	step(f, 0, -80)
	check("crouch na 1 frame RunBrake", f.state_name() == "Squat")
	f.free()


func _test_special_fall_platform() -> void:
	# Helpless boven een platform: omlaag houden = erdoorheen, neutraal = landen.
	for hold_down in [true, false]:
		var f := make("fast_faller", Vector2(38, 110))
		step(f)
		step(f, 0, 0, SHIELD)
		until_state(f, "FallSpecial", 60)
		check("helpless boven platform (%s)" % ("omlaag" if hold_down else "neutraal"), f.state_name() == "FallSpecial" and f.pos.y > 30.0, "%s y %.2f" % [f.state_name(), f.pos.y])
		var sy: int = -80 if hold_down else 0
		var landed_y: float = -999.0
		for i in 200:
			step(f, 0, sy)
			if f.grounded:
				landed_y = f.pos.y
				break
		if hold_down:
			check("special fall + omlaag = door het platform", near(landed_y, 0.0), "y %.3f" % landed_y)
		else:
			check("special fall zonder stick = landt op platform", near(landed_y, 27.2), "y %.3f" % landed_y)
		f.free()


# --- Xbox-stickprofielen (speeltest-feedback M1) ---------------------------------------------------
## Een echte analoge stick doet ~1-4 frames over 0 -> vol; links -> rechts gaat in 0-3 frames door de
## deadzone. Waarden zijn al rasterwaarden (-80..80); |v| < 23 is deadzone.
const FLICK_1: Array = [80]
const FLICK_2: Array = [45, 80]
const FLICK_3: Array = [30, 50, 80]
const FLICK_4: Array = [26, 40, 60, 80]
## Een echt langzame duw: veel frames, nooit een flick.
const PUSH_SLOW: Array = [25, 30, 35, 40, 48, 55, 62, 70, 78, 80]


## Flick-profiel in richting dir (+1/-1), `hold` frames op vol, optioneel `gap` deadzone-frames ervoor.
func flick_profile(profile: Array, dir: int, hold: int, gap: int = 0) -> Array:
	var out: Array = []
	for i in gap:
		out.append(0)
	for v: int in profile:
		out.append(v * dir)
	for i in hold:
		out.append(80 * dir)
	return out


func play_x(f: Fighter, seq: Array, sy: int = 0, buttons: int = 0) -> void:
	for v: int in seq:
		step(f, v, sy, buttons)


## Dash-dance: n keer afwisselend flicken met het gegeven profiel; telt hoeveel flicks een Dash gaven.
## `hold` = frames op vol na de flick, `gap` = deadzone-frames bij het omklappen.
func dash_dance_hits(id: String, profile: Array, hold: int, gap: int, n: int = 8) -> int:
	var f := make(id, Vector2(0, 0))
	idle(f, 3)
	var hits: int = 0
	var dir: int = 1
	for i in n:
		var seq: Array = flick_profile(profile, dir, hold, gap if i > 0 else 0)
		var dashed: bool = false
		for v: int in seq:
			step(f, v, 0)
			if f.state_name() == "Dash" and f.facing == dir:
				dashed = true
		if dashed:
			hits += 1
		dir = -dir
	f.free()
	return hits


func _test_xbox_dash_dance() -> void:
	print("-- Xbox dash-dance --")
	var profs: Dictionary = {"F1": FLICK_1, "F2": FLICK_2, "F3": FLICK_3, "F4": FLICK_4}
	for id in ["fast_faller", "allrounder", "floaty"]:
		for pname: String in profs:
			for gap in [0, 1, 2]:
				for hold in [1, 3]:
					var hits: int = dash_dance_hits(id, profs[pname], hold, gap)
					check("dash-dance %s flick %s gap %d hold %d: 8/8 dashes" % [id, pname, gap, hold], hits == 8, "%d/8" % hits)
	# Eerste dash uit Wait met elke Xbox-flick.
	for prof: Array in [FLICK_1, FLICK_2, FLICK_3, FLICK_4]:
		var f := make("allrounder")
		idle(f, 3)
		play_x(f, flick_profile(prof, 1, 0))
		check("dash uit Wait met flick van %d frames" % prof.size(), f.state_name() == "Dash")
		f.free()
	# Langzaam duwen blijft walk (geen dash)
	var s := make("allrounder")
	idle(s, 3)
	play_x(s, PUSH_SLOW)
	check("langzame duw = Walk, geen Dash", s.state_name() == "Walk", s.state_name())
	s.free()
	var t := make("allrounder")
	idle(t, 3)
	play_x(t, PUSH_SLOW.map(func(v: int) -> int: return -v))
	check("langzame duw achteruit = tilt-turn/walk, geen Dash", t.state_name() != "Dash", t.state_name())
	t.free()
	# Momentum kwijt (na run + stick los): flick terug/vooruit moet direct werken.
	var r := make("fast_faller", Vector2(-60, 0))
	idle(r, 3)
	play_x(r, flick_profile(FLICK_3, 1, 40))
	check("run voor 'momentum kwijt'", r.state_name() == "Run")
	play_x(r, [0, 0])
	check("stick los = RunBrake", r.state_name() == "RunBrake")
	play_x(r, flick_profile(FLICK_3, -1, 0))
	play_x(r, [-80])
	check("flick terug uit RunBrake geeft een dash (geen lock)", r.state_name() == "Dash" and r.facing == -1, r.state_name())
	r.free()
	var b := make("fast_faller", Vector2(-60, 0))
	idle(b, 3)
	play_x(b, flick_profile(FLICK_2, 1, 30))
	play_x(b, [0, 0])
	play_x(b, flick_profile(FLICK_2, 1, 0))
	check("flick vooruit uit RunBrake = Dash", b.state_name() == "Dash", b.state_name())
	b.free()
	# Dashback na een tilt-turn met een 2-4-frames flick (UCF-leniency)
	for prof: Array in [FLICK_2, FLICK_3, FLICK_4]:
		var u := make("allrounder")
		idle(u, 3)
		play_x(u, [-30])
		play_x(u, flick_profile(prof, -1, 1, 1))
		check("tilt-turn dan flick (%d fr) = Dash" % prof.size(), u.state_name() == "Dash" and u.facing == -1, u.state_name())
		u.free()


## Frame (sinds eerste step) waarop vy voor het eerst < 0 is.
func _apex_frame(id: String, sh: bool) -> int:
	var f := make(id)
	var held: int = f.stats.jumpsquat_frames - 1 if sh else 400
	var frame: int = 0
	while frame < 200:
		step(f, 0, 0, JUMP if frame < held else 0)
		frame += 1
		if f.state_name() in ["Jump", "Fall"] and f.vel.y < 0.0:
			f.free()
			return frame
	f.free()
	return -1


## Jump (short/full hop) met een y-flick-profiel dat begint `onset` frames t.o.v. de apex
## (negatief = vóór de apex). true als er fast fall wordt bereikt vóór het landen.
func _ff_after_jump(id: String, sh: bool, prof: Array, onset: int, hold_after: bool = true) -> bool:
	var apex: int = _apex_frame(id, sh)
	var f := make(id)
	var held: int = f.stats.jumpsquat_frames - 1 if sh else 400
	var frame: int = 0
	var got: bool = false
	var start: int = apex + onset
	while frame < 300:
		var sy: int = 0
		var k: int = frame - start
		if k >= 0:
			sy = -prof[k] if k < prof.size() else (-80 if hold_after else 0)
		step(f, 0, sy, JUMP if frame < held else 0)
		frame += 1
		if f.fastfalling:
			got = true
		if f.state_name() == "Landing":
			break
	f.free()
	return got


func _test_xbox_fast_fall() -> void:
	print("-- Xbox fast fall --")
	for id in Archetypes.IDS:
		for sh in [true, false]:
			var tag: String = "short hop" if sh else "full hop"
			var profs: Dictionary = {"F1": [80], "F3": [30, 50, 80]}
			for pname: String in profs:
				for onset in ([0, 1, 3] if sh else [0, 1, 3, 6]):
					check("%s %s: fast fall flick (%s) %d fr na apex" % [id, tag, pname, onset], _ff_after_jump(id, sh, profs[pname], onset))
				for onset in [-1, -2, -3]:
					check("%s %s: fast fall flick (%s) %d fr vóór apex (leniency)" % [id, tag, pname, -onset], _ff_after_jump(id, sh, profs[pname], onset))
			check("%s %s: flick ver vóór de apex en losgelaten = geen fast fall" % [id, tag], not _ff_after_jump(id, sh, [80], -12, false))
			# Echte tap (korte flick, stick veert terug naar neutraal): telt tot FAST_FALL_BUFFER frames vóór de apex.
			for onset in [-5, -3, -1, 0, 2]:
				check("%s %s: omlaag-tik (stick veert terug) %d fr t.o.v. apex = fast fall" % [id, tag, onset], _ff_after_jump(id, sh, [60, 80, 80, 40], onset, false))
		check("%s: stick omlaag al lang vóór de apex vastgehouden = geen fast fall" % id, not _ff_after_jump(id, true, [80], -12, true))


func _run_right(id: String) -> Fighter:
	var f := make(id, Vector2(-80, 0))
	idle(f, 3)
	play_x(f, flick_profile(FLICK_2, 1, 40))
	return f


func _test_xbox_run_turn() -> void:
	print("-- Xbox run turnaround --")
	for id in ["fast_faller", "allrounder", "heavyweight"]:
		var s: FighterStats = Archetypes.load_stats(id)
		for gap in [0, 1, 3]:
			var f := _run_right(id)
			check("%s: run voor turnaround" % id, f.state_name() == "Run")
			var frames: int = 0
			var ran_left: bool = false
			for v: int in flick_profile(FLICK_2, -1, 80, gap):
				step(f, v, 0)
				frames += 1
				if f.state_name() == "Run" and f.facing == -1 and f.gr_vel < -0.5:
					ran_left = true
					break
			check("%s: run-turn (gap %d) eindigt in Run naar links, %d frames (limiet %d)" % [id, gap, frames, s.run_turn_frames + 20], ran_left and frames <= s.run_turn_frames + 20, "%s f%d gr_vel %.2f" % [f.state_name(), f.facing, f.gr_vel])
			f.free()
		# Stick terug en dan loslaten: komt tot rust, zonder lock.
		var g := _run_right(id)
		play_x(g, [-80, -80])
		play_x(g, [0, 0, 0])
		check("%s: run-turn + stick los: komt in Wait terecht" % id, until_state(g, "Wait", 120) >= 0, g.state_name())
		g.free()
		# Terug naar de oorspronkelijke richting tijdens de turn (bedacht): geen lange lock.
		var h := _run_right(id)
		play_x(h, [-80, -80])
		var back: bool = false
		for i in 40:
			step(h, 80, 0)
			if h.state_name() == "Run" and h.facing == 1 and h.gr_vel > 0.5:
				back = true
				break
		check("%s: run-turn heen en terug: weer Run rechts" % id, back, "%s f%d gr %.2f" % [h.state_name(), h.facing, h.gr_vel])
		h.free()
		# Flick tegen de run in direct na RunBrake-begin = dash/pivot, niet de lange RunTurn
		var k := _run_right(id)
		play_x(k, [0])
		play_x(k, flick_profile(FLICK_2, -1, 2))
		check("%s: stick los en dan flick terug = Dash links (RunBrake-dash)" % id, k.state_name() == "Dash" and k.facing == -1, k.state_name())
		k.free()


func _script_input(i: int) -> Array:
	# Gevarieerde maar vaste inputreeks: dash-dance, run, jump, double jump, drift, fast fall, wavedash.
	var t: int = i % 120
	if t < 5: return [80, 0, 0]
	if t < 9: return [-80, 0, 0]
	if t < 25: return [80, 0, 0]
	if t < 28: return [80, 0, JUMP]
	if t < 40: return [-60, 0, 0]
	if t < 41: return [0, 0, JUMP]
	if t < 60: return [40, 0, 0]
	if t < 61: return [0, -80, 0]
	if t < 80: return [0, 0, 0]
	if t < 84: return [0, 0, JUMP]
	if t < 85: return [-75, -27, SHIELD]
	return [0, 0, 0]


func _test_determinism() -> void:
	var runs: Array = []
	for r in 2:
		var f := make("fast_faller", Vector2(-20, 0))
		var trace: Array = []
		for i in 600:
			var inp: Array = _script_input(i)
			step(f, inp[0], inp[1], inp[2])
			trace.append(f.snapshot())
		runs.append(trace)
		f.free()
	var same: bool = runs[0].size() == runs[1].size()
	for i in runs[0].size():
		if runs[0][i] != runs[1][i]:
			same = false
			print("      verschil op frame ", i, ": ", runs[0][i], " vs ", runs[1][i])
			break
	check("determinisme: zelfde inputreeks = identieke posities/states (600 frames)", same)
	var states: Dictionary = {}
	for snap: Array in runs[0]:
		states[snap[0]] = true
	print("      states in de reeks: ", ", ".join(PackedStringArray(states.keys())))


## Run stoppen met een Xbox-stick: de terugveer-overshoot (kort de andere kant op) mag niet omdraaien.
func _test_xbox_run_stop_overshoot() -> void:
	print("-- Xbox run-stop overshoot --")
	for id in ["fast_faller", "allrounder", "heavyweight"]:
		for over in [[-30, -30], [-30, -45, -30], [-40, -40, -25, 0], [-35, -45, -40, -30, 0]]:
			var f := _run_right(id)
			play_x(f, [60, 20])
			play_x(f, over)
			check("%s: run stoppen + overshoot %s = geen RunTurn/facing blijft" % [id, str(over)], f.state_name() == "RunBrake" and f.facing == 1, "%s f%d" % [f.state_name(), f.facing])
			f.free()
		# Zelfde overshoot na een dash-stop in Wait: facing mag omdraaien (tilt-turn), maar een nieuwe flick
		# vooruit moet direct een Dash geven (geen lock).
		var g := make(id, Vector2(-80, 0))
		idle(g, 3)
		play_x(g, flick_profile(FLICK_2, 1, 2))
		play_x(g, [0, 0, -30, -30, 0])
		play_x(g, flick_profile(FLICK_3, 1, 0))
		check("%s: dash, stick los + overshoot, dan flick vooruit = Dash (geen tilt-turn-lock)" % id, g.state_name() == "Dash", g.state_name())
		g.free()
