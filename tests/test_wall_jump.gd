extends SceneTree
## Wall jump (Melee-stijl): vlag, smash weg van de muur, richting, special-reset, geen extra double jump, determinisme.
##   Godot_console.exe --headless --path . --script res://tests/test_wall_jump.gd

var _fails: int = 0
var _total: int = 0
var stage: SandboxStage


func _initialize() -> void:
	stage = SandboxStage.new()
	_test_flag()
	_test_directions()
	_test_requires_smash()
	_test_range()
	_test_effects()
	_test_cooldown()
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


func make(at: Vector2, wall_jump: bool = true) -> Fighter:
	var f := Fighter.new()
	f.use_visual = false
	f.auto_register = false
	f.stats = Archetypes.load_stats("fast_faller")
	f.stats.wall_jump = wall_jump
	if stage.has_meta("ledge_occupants"):
		stage.remove_meta("ledge_occupants")
	f.stage = stage
	f.input = InputHistory.new()
	f.pos = at
	f.setup()
	return f


func step(f: Fighter, sx: int = 0, sy: int = 0, buttons: int = 0) -> void:
	var fr := InputFrame.new()
	fr.stick = Vector2i(sx, sy)
	fr.buttons = buttons
	f.input.push(fr)
	f.sim_tick(0)


## Een frame neutraal (Fall), daarna een flick naar `sx`.
func flick(f: Fighter, sx: int) -> void:
	step(f)
	step(f, sx)


func _test_flag() -> void:
	var f := make(Vector2(-90.0, -24.0), true)
	step(f)
	check("fighter hangt in de lucht naast de muur", f.state_name() == "Fall", f.state_name())
	flick(f, -80)
	check("met vlag: smash weg van de muur = WallJump", f.state_name() == "WallJump", f.state_name())
	f.free()
	var g := make(Vector2(-90.0, -24.0), false)
	step(g)
	flick(g, -80)
	check("zonder vlag: geen WallJump", g.state_name() != "WallJump", g.state_name())
	g.free()


func _test_directions() -> void:
	for side: int in [-1, 1]:
		var f := make(Vector2(side * 90.0, -24.0))
		step(f)
		flick(f, side * 80)
		var ok: bool = f.state_name() == "WallJump"
		for i in 6:
			step(f, side * 80)
		check("muur %s: wegspringen naar %s (vx %.2f)" % ["links" if side < 0 else "rechts", "links" if side < 0 else "rechts", f.vel.x],
			ok and f.vel.x * side > 0.5 and f.vel.y > 0.0 and f.facing == side, "vel %s facing %d" % [f.vel, f.facing])
		# smash NAAR de muur toe doet niets
		var h := make(Vector2(side * 90.0, -24.0))
		step(h)
		flick(h, -side * 80)
		check("smash naar de muur toe = geen WallJump", h.state_name() != "WallJump", h.state_name())
		f.free()
		h.free()


func _test_requires_smash() -> void:
	var f := make(Vector2(-90.0, -24.0))
	step(f)
	for v in [25, 30, 35, 40, 48, 55, 62, 70, 78, 80]:
		step(f, -v)
	check("langzame duw weg van de muur (geen smash) = geen WallJump", f.state_name() != "WallJump", f.state_name())
	f.free()


func _test_range() -> void:
	var far := make(Vector2(-110.0, -24.0))
	step(far)
	flick(far, -80)
	check("te ver van de muur = geen WallJump", far.state_name() != "WallJump", far.state_name())
	far.free()
	var above := make(Vector2(-90.0, 15.0))
	step(above)
	flick(above, -80)
	check("boven de stage-rand (geen muur) = geen WallJump", above.state_name() != "WallJump", above.state_name())
	above.free()
	var inside := make(Vector2(-80.0, -24.0))
	step(inside)
	flick(inside, -80)
	check("onder de stage zelf (binnen het segment) = geen WallJump", inside.state_name() != "WallJump", inside.state_name())
	inside.free()


func _test_effects() -> void:
	var f := make(Vector2(-90.0, -24.0))
	step(f)
	var kit: SpecialKit = SpecialKit.of(f)
	kit.air_uses["side"] = 2
	f.air_jumps_used = 1
	flick(f, -80)
	check("WallJump reset de special-limieten", kit.air_uses.is_empty() and kit.last_reset == "wall_jump", "uses %s" % str(kit.air_uses))
	check("geen extra double jump terug", f.air_jumps_used == 1, "used %d" % f.air_jumps_used)
	var y0: float = f.pos.y
	var top: float = y0
	for i in 40:
		step(f, -80)
		top = maxf(top, f.pos.y)
	check("na ~30 frames terug in Fall, hoger dan de start", f.state_name() == "Fall" and top > y0 + 5.0, "%s top %.2f" % [f.state_name(), top - y0])
	f.free()
	# helpless (FallSpecial) kan niet
	var h := make(Vector2(-90.0, -24.0))
	step(h)
	h.change_state("FallSpecial")
	flick(h, -80)
	check("uit FallSpecial (helpless) geen WallJump", h.state_name() == "FallSpecial", h.state_name())
	h.free()


func _test_cooldown() -> void:
	var f := make(Vector2(-90.0, -24.0))
	step(f)
	flick(f, -80)
	for i in 31:
		step(f)
	check("na de wall jump weer in Fall", f.state_name() == "Fall", f.state_name())
	f.pos = Vector2(-90.0, -24.0)
	f.vel = Vector2.ZERO
	flick(f, -80)
	check("direct opnieuw wall jumpen is geblokkeerd (cooldown)", f.state_name() != "WallJump", f.state_name())
	for i in 20:
		f.pos = Vector2(-90.0, -24.0)
		step(f)
	f.pos = Vector2(-90.0, -24.0)
	flick(f, -80)
	check("na de cooldown kan het weer", f.state_name() == "WallJump", f.state_name())
	f.free()


func _test_determinism() -> void:
	var runs: Array = []
	for r in 2:
		var f := make(Vector2(90.0, -24.0))
		var trace: Array = []
		for i in 120:
			var sx: int = 80 if i == 3 else (0 if i < 3 else 40)
			step(f, sx)
			trace.append(f.snapshot())
		runs.append(trace)
		f.free()
	check("determinisme: identieke wall-jump-reeks", runs[0] == runs[1])
