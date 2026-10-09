extends SceneTree
## Headless test van de match-flow (M6): stocks, timer, tiebreak, sudden death, pauze-regels, training, Sim-debugtoetsen.
##   Godot_console.exe --headless --path . --script res://tests/test_match.gd
## Gebruikt fake fighters (signalen + respawn_at) zodat dit onafhankelijk van de fighter-states is; één integratietest
## met echte Fighters staat onderaan. Exit code 0 = alles geslaagd.

var _fails: int = 0
var _total: int = 0


class FakeFighter extends Node2D:
	signal blast_ko(fighter: Node2D, side: StringName)
	signal percent_changed(new_percent: float)
	var player: int = 0
	var auto_respawn: bool = true
	var active: bool = true
	var input: InputHistory
	var respawned: Array = []
	var spawned: Array = []
	var percent: float = 0.0:
		set(v):
			percent = v
			percent_changed.emit(v)

	func respawn_at(p: Vector2, inv: int) -> void:
		respawned.append([p, inv])
		active = true
		visible = true

	func spawn(p: Vector2, d: int) -> void:
		spawned.append([p, d])

	func ko() -> void:
		visible = false
		active = false
		blast_ko.emit(self, &"left")


class _Ent extends RefCounted:
	var id: String
	var log: Array
	var kill: Object = null

	func _init(i: String, l: Array) -> void:
		id = i
		log = l

	func sim_tick(_f: int) -> void:
		log.append(id)
		if kill != null:
			var sim: Node = Engine.get_main_loop().root.get_node("/root/Sim")
			sim.unregister(kill)
			kill = null


func _initialize() -> void:
	_run.call_deferred()


func check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _sim() -> Node:
	return root.get_node("/root/Sim")


func _make(mode: String, rules: MatchRules = null) -> MatchController:
	var c := MatchController.new()
	c.mode = mode
	c.rules = rules if rules != null else MatchRules.new()
	c.picks = ["_dummy", "_dummy"]
	c.build_hud = false
	c.auto_navigate = false
	c.auto_register = false
	c.fighter_factory = func(p: int) -> Node2D:
		var f := FakeFighter.new()
		f.player = p
		c.add_child(f)
		return f
	root.add_child(c)
	return c


func _ticks(c: MatchController, n: int) -> void:
	for i in n:
		c.sim_tick(i)


func _to_playing(c: MatchController) -> void:
	_ticks(c, MatchController.COUNT_FRAMES + 1)


func _fake(c: MatchController, p: int) -> FakeFighter:
	return c.fighters[p] as FakeFighter


func _btn(buttons: int, l: float = 0.0, r: float = 0.0) -> InputFrame:
	var f := InputFrame.new()
	f.buttons = buttons
	f.trigger_l = l
	f.trigger_r = r
	return f


func _run() -> void:
	_test_match_state()
	_test_hud_statics()
	_test_countdown_and_ko()
	_test_attribution()
	_test_elimination_end()
	_test_time_and_tiebreak()
	_test_sudden_death()
	_test_pause()
	_test_training()
	_test_sim_debug_keys()
	_test_sfx_volume()
	await _test_real_match()
	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


# --- pure logica ---

func _test_match_state() -> void:
	var s := MatchState.new()
	var rules := MatchRules.new()
	s.start(rules, false)
	var pc: Array[float] = [0.0, 0.0]
	check("state: 4 stocks per speler", s.stocks == [4, 4])
	check("state: niet voorbij bij start", not s.evaluate(pc)["over"])
	check("state: KO door tegenstander telt als KO", not s.lose_stock(0, 1) and s.kos[1] == 1 and s.falls[0] == 1 and s.stocks[0] == 3)
	check("state: zelfvernietiging telt als SD", not s.lose_stock(1, MatchState.NO_ONE) and s.sds[1] == 1 and s.kos[0] == 0)
	s.stocks = [1, 3]
	check("state: laatste stock = uitgeschakeld", s.lose_stock(0, 1))
	var ev: Dictionary = s.evaluate(pc)
	check("state: één over = winnaar, reden ko", ev["over"] and ev["winner"] == 1 and ev["reason"] == "ko")
	s.start(rules, false)
	s.stocks = [0, 0]
	ev = s.evaluate(pc)
	check("state: beide op 0 = sudden death", not ev["over"] and ev["sudden_death"])
	s.start(rules, false)
	check("state: timer 8 min = 28800 frames", s.time_left() == 8 * 60 * 60)
	s.elapsed = 8 * 60 * 60 - 1
	check("state: 1 frame voor tijd-op niet voorbij", not s.time_up() and not s.evaluate(pc)["over"])
	s.tick()
	check("state: tijd op", s.time_up())
	s.stocks = [3, 2]
	ev = s.evaluate([90.0, 10.0] as Array[float])
	check("state: tijd op, meeste stocks wint (ondanks %)", ev["over"] and ev["winner"] == 0 and ev["reason"] == "time")
	s.stocks = [2, 2]
	ev = s.evaluate([90.0, 10.0] as Array[float])
	check("state: gelijk stocks -> laagste % wint", ev["over"] and ev["winner"] == 1)
	ev = s.evaluate([50.0, 50.0] as Array[float])
	check("state: alles gelijk -> sudden death", not ev["over"] and ev["sudden_death"])
	var nsd := MatchRules.new()
	nsd.sudden_death = false
	s.start(nsd, false)
	s.elapsed = nsd.time_frames()
	ev = s.evaluate([50.0, 50.0] as Array[float])
	check("state: zonder sudden death -> gelijkspel", ev["over"] and ev["winner"] == -1 and ev["reason"] == "draw")
	s.begin_sudden_death()
	check("state: sudden death = 1 stock, geen timer", s.stocks == [1, 1] and s.time_left() == -1 and s.sudden_death)
	var nolimit := MatchRules.new()
	nolimit.time_minutes = 0
	s.start(nolimit, false)
	check("state: 0 minuten = geen limiet", s.time_left() == -1)
	s.start(rules, true)
	check("state: training verliest nooit stocks en eindigt nooit",
		not s.lose_stock(0, 1) and s.stocks[0] == 4 and not s.evaluate(pc)["over"] and s.time_left() == -1)


func _test_hud_statics() -> void:
	check("hud: 0% = wit", MatchHud.percent_color(0.0) == Color.WHITE)
	var mid: Color = MatchHud.percent_color(65.0)
	check("hud: 65% tussen geel en oranje", mid.r > 0.99 and mid.g < 0.9 and mid.g > 0.54 and mid.b < 0.36)
	var hi: Color = MatchHud.percent_color(999.0)
	check("hud: 999% = donkerrood", hi.r < 0.5 and hi.g < 0.1)
	check("hud: kleur wordt monotoon donkerder (g-kanaal)", MatchHud.percent_color(0).g >= MatchHud.percent_color(60).g
		and MatchHud.percent_color(60).g >= MatchHud.percent_color(130).g and MatchHud.percent_color(130).g >= MatchHud.percent_color(260).g)
	check("hud: tijd 8:00", MatchHud.format_time(8 * 3600) == "8:00")
	check("hud: tijd rondt omhoog af", MatchHud.format_time(1) == "0:01" and MatchHud.format_time(601) == "0:11" and MatchHud.format_time(0) == "0:00")


# --- controller ---

func _test_countdown_and_ko() -> void:
	var c := _make("fight")
	var im: Node = root.get_node("/root/InputManager")
	check("ctrl: start in countdown, stage + camera + 2 fighters",
		c.phase == MatchController.Phase.COUNTDOWN and c.fighters.size() == 2 and c.camera != null and c.stage != null)
	check("ctrl: countdown-input is blanco",
		_fake(c, 0).input != im.history(0) and _fake(c, 1).input != im.history(1))
	_ticks(c, 1)
	check("ctrl: countdown start op 3", c.countdown_number() == 3)
	_ticks(c, 60)
	check("ctrl: na 60 frames 2", c.countdown_number() == 2)
	_ticks(c, 60)
	check("ctrl: na 120 frames 1", c.countdown_number() == 1)
	_ticks(c, 59)
	check("ctrl: frame 180 nog countdown", c.phase == MatchController.Phase.COUNTDOWN)
	_ticks(c, 1)
	check("ctrl: frame 181 = PLAYING + GO", c.phase == MatchController.Phase.PLAYING and c.go_visible())
	check("ctrl: input hersteld bij GO", _fake(c, 0).input == im.history(0) and _fake(c, 1).input == im.history(1))
	_ticks(c, MatchController.GO_SHOW)
	check("ctrl: GO verdwijnt", not c.go_visible())
	_fake(c, 0).percent = 40.0
	_fake(c, 0).ko()
	_ticks(c, 1)
	check("ctrl: KO -> stock eraf, uit beeld", c.state.stocks[0] == 3 and c.is_dead(0) and not _fake(c, 0).visible)
	check("ctrl: tegenstander kreeg de KO", c.state.kos[1] == 1 and c.state.sds[0] == 0)
	_ticks(c, MatchController.RESPAWN_DELAY - 2)
	check("ctrl: nog niet terug voor de vertraging om is", c.is_dead(0) and _fake(c, 0).respawned.is_empty())
	_ticks(c, 2)
	check("ctrl: respawn_at op stage-respawn met onkwetsbaarheid",
		not c.is_dead(0) and _fake(c, 0).respawned.size() == 1
		and _fake(c, 0).respawned[0][0] == c.stage.get_respawn(0)
		and _fake(c, 0).respawned[0][1] == MatchController.RESPAWN_INVINCIBLE)
	check("ctrl: % terug op 0 na respawn", _fake(c, 0).percent == 0.0)
	c.queue_free()


func _test_attribution() -> void:
	var c := _make("fight")
	_to_playing(c)
	_fake(c, 1).percent = 30.0   # speler 2 wordt geraakt
	_ticks(c, 10)
	_fake(c, 1).ko()
	_ticks(c, 1)
	check("attributie: val kort na een klap = KO voor tegenstander", c.state.kos[0] == 1 and c.state.sds[1] == 0)
	_ticks(c, MatchController.RESPAWN_DELAY + MatchController.HIT_MEMORY + 10)
	_fake(c, 1).ko()
	_ticks(c, 1)
	check("attributie: val zonder recente klap = SD", c.state.sds[1] == 1 and c.state.kos[0] == 1 and c.state.falls[1] == 2)
	c.queue_free()


func _test_elimination_end() -> void:
	var c := _make("fight")
	_to_playing(c)
	var got: Array = []
	c.finished.connect(func(r: MatchResult) -> void: got.append(r))
	for i in 4:
		_fake(c, 0).percent = 20.0   # recent geraakt: de val is een KO
		_fake(c, 0).ko()
		_ticks(c, 1)
		if i < 3:
			_ticks(c, MatchController.RESPAWN_DELAY)
	check("einde: 4 stocks kwijt -> ENDING, GAME!", c.phase == MatchController.Phase.ENDING and c.end_banner() == "GAME!")
	check("einde: uitgeschakelde speler blijft weg", c.is_dead(0) and c.state.stocks[0] == 0)
	_ticks(c, MatchController.END_DELAY - 1)
	check("einde: nog niet klaar vóór END_DELAY", got.is_empty())
	_ticks(c, 1)
	check("einde: finished met resultaat", got.size() == 1 and MatchResult.last == got[0])
	var r: MatchResult = got[0]
	check("einde: winnaar P2, 4 KO's, 4 falls", r.winner == 1 and r.reason == "ko" and r.kos[1] == 4 and r.falls[0] == 4 and r.stocks[1] == 4)
	c.queue_free()


func _test_time_and_tiebreak() -> void:
	var rules := MatchRules.new()
	rules.time_minutes = 1
	var c := _make("fight", rules)
	_to_playing(c)
	_fake(c, 0).ko()
	_ticks(c, 1)
	_ticks(c, MatchController.RESPAWN_DELAY)
	_ticks(c, 3600 - MatchController.RESPAWN_DELAY - 3)
	check("timer: bijna op", c.phase == MatchController.Phase.PLAYING and c.state.time_left() > 0)
	_ticks(c, 4)
	check("timer: op -> TIME!, P2 wint op stocks (3 vs 4)",
		c.phase == MatchController.Phase.ENDING and c.end_banner() == "TIME!" and c.result.winner == 1 and c.result.reason == "time")
	c.queue_free()
	var c2 := _make("fight", rules)
	_to_playing(c2)
	_fake(c2, 0).percent = 80.0
	_fake(c2, 1).percent = 35.0
	_ticks(c2, 3600)
	check("tiebreak: gelijk stocks -> laagste % (P2) wint", c2.phase == MatchController.Phase.ENDING and c2.result.winner == 1)
	c2.queue_free()


func _test_sudden_death() -> void:
	var rules := MatchRules.new()
	rules.time_minutes = 1
	var c := _make("fight", rules)
	_to_playing(c)
	_fake(c, 0).percent = 50.0
	_fake(c, 1).percent = 50.0
	_ticks(c, 3600)
	check("SD: gelijk -> sudden death-countdown",
		c.phase == MatchController.Phase.COUNTDOWN and c.state.sudden_death and c.sudden_death_banner)
	check("SD: 1 stock, 300%, op spawn",
		c.state.stocks == [1, 1] and _fake(c, 0).percent == 300.0 and _fake(c, 1).percent == 300.0
		and _fake(c, 0).spawned.back()[0] == c.stage.get_spawn(0))
	check("SD: geen timer", c.state.time_left() == -1)
	_to_playing(c)
	check("SD: na countdown weer PLAYING", c.phase == MatchController.Phase.PLAYING)
	_ticks(c, 5000)
	check("SD: blijft doorgaan zonder timer", c.phase == MatchController.Phase.PLAYING)
	_fake(c, 1).ko()
	_ticks(c, 1)
	check("SD: eerste val beslist", c.phase == MatchController.Phase.ENDING and c.result.winner == 0 and c.result.sudden_death)
	c.queue_free()


func _test_pause() -> void:
	var sim: Node = _sim()
	var c := _make("fight")
	var start: InputFrame = _btn(InputFrame.BTN_START)
	var none: InputFrame = _btn(0)
	check("pauze: Start in countdown pauzeert niet", c.process_pause_input(0, start) == &"" and not sim.paused)
	c.process_pause_input(0, none)
	_to_playing(c)
	var quits: Array = []
	c.quit_requested.connect(func() -> void: quits.append(true))
	check("pauze: Start pauzeert (speler 2)", c.process_pause_input(1, start) == &"pause" and sim.paused and c.paused_by == 1)
	check("pauze: vastgehouden Start telt maar één keer", c.process_pause_input(1, start) == &"" and sim.paused)
	check("pauze: Start van de andere speler hervat niet", c.process_pause_input(0, start) == &"" and sim.paused)
	c.process_pause_input(0, none)
	c.process_pause_input(1, none)
	var combo: InputFrame = _btn(InputFrame.BTN_START | InputFrame.BTN_ATTACK, 1.0, 1.0)
	check("pauze: L+R+A+Start van de andere speler stopt niet", c.process_pause_input(0, combo) == &"" and quits.is_empty())
	c.process_pause_input(0, none)
	var almost: InputFrame = _btn(InputFrame.BTN_START | InputFrame.BTN_ATTACK, 1.0, 0.0)
	check("pauze: L+A+Start (zonder R) stopt niet maar hervat", c.process_pause_input(1, almost) == &"resume" and not sim.paused and quits.is_empty())
	c.process_pause_input(1, none)
	c.process_pause_input(0, start)
	c.process_pause_input(0, none)
	check("pauze: opnieuw pauzeren door speler 1", c.paused_by == 0 and sim.paused)
	check("pauze: L+R+A+Start door de pauzeerder = quit",
		c.process_pause_input(0, combo) == &"quit" and quits.size() == 1 and not sim.paused and MatchResult.last == null)
	c.queue_free()
	sim.set_paused(false)


func _test_training() -> void:
	var c := _make("training")
	var im: Node = root.get_node("/root/InputManager")
	check("training: dummy-input is blanco", _fake(c, 1).input != im.history(1))
	_to_playing(c)
	check("training: dummy krijgt ook na GO geen input, P1 wel", _fake(c, 1).input != im.history(1) and _fake(c, 0).input == im.history(0))
	check("training: Sim debug-toetsen aan", _sim().debug_context)
	_fake(c, 0).ko()
	_ticks(c, 1)
	check("training: val kost geen stock", c.state.stocks[0] == 4 and c.is_dead(0))
	_ticks(c, MatchController.TRAINING_RESPAWN_DELAY)
	check("training: snel terug", not c.is_dead(0))
	_ticks(c, 30000)
	check("training: eindigt nooit (geen timer)", c.phase == MatchController.Phase.PLAYING)
	c.training_action(&"pct_up")
	c.training_action(&"pct_up")
	c.training_action(&"pct_up")
	check("training: dummy-% +10 per stap", _fake(c, 1).percent == 30.0)
	c.training_action(&"pct_down")
	check("training: dummy-% -10", _fake(c, 1).percent == 20.0)
	for i in 5:
		c.training_action(&"pct_down")
	check("training: dummy-% niet onder 0", _fake(c, 1).percent == 0.0)
	c.training_action(&"pct_up")
	c.training_action(&"pct_zero")
	check("training: dummy-% naar 0", _fake(c, 1).percent == 0.0)
	_fake(c, 0).percent = 55.0
	_fake(c, 1).ko()
	_ticks(c, 1)
	var n0: int = _fake(c, 0).spawned.size()
	c.training_action(&"reset")
	check("training: reset zet beide op hun spawn (ook de dode) en revive't",
		_fake(c, 0).spawned.size() == n0 + 1 and _fake(c, 1).spawned.back()[0] == c.stage.get_spawn(1)
		and not c.is_dead(1) and _fake(c, 1).visible)
	check("training: reset laat het % staan", _fake(c, 0).percent == 55.0)
	var fight := _make("fight")
	fight.training_action(&"pct_up")
	check("fight: training-acties doen niets", _fake(fight, 1).percent == 0.0)
	fight.queue_free()
	c.queue_free()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _test_sim_debug_keys() -> void:
	var sim: Node = _sim()
	sim.set_paused(false)
	sim.debug_context = false
	sim._input(_key(KEY_P))
	check("Sim: P pauzeert niet buiten debug-context", not sim.paused)
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	sim._input(back)
	check("Sim: Back pauzeert niet buiten debug-context", not sim.paused)
	sim.debug_context = true
	sim._input(_key(KEY_P))
	check("Sim: P pauzeert in debug-context", sim.paused)
	sim._input(_key(KEY_P))
	check("Sim: P hervat in debug-context", not sim.paused)
	sim.debug_context = false
	# entities mogen zich tijdens een tick afmelden zonder dat een ander een tick mist
	var order: Array = []
	var a := _Ent.new("a", order)
	var b := _Ent.new("b", order)
	var d := _Ent.new("d", order)
	a.kill = b
	sim.register(a)
	sim.register(b)
	sim.register(d)
	var before: int = sim.frame
	sim._advance()
	check("Sim: afmelden tijdens een tick slaat niemand anders over (b weg, d tikt wel)", order == ["a", "d"])
	order.clear()
	sim._advance()
	check("Sim: volgend frame alleen a en d", order == ["a", "d"])
	sim.unregister(a)
	sim.unregister(d)
	check("Sim: frame telt door", sim.frame == before + 2)


func _test_sfx_volume() -> void:
	var settings: Node = root.get_node("/root/Settings")
	var sfx: Node = root.get_node("/root/Sfx")
	var old: float = settings.sfx_volume
	settings.sfx_volume = 0.25
	check("Sfx: volume komt uit Settings", is_equal_approx(sfx._settings_volume(), 0.25))
	settings.sfx_volume = 0.0
	check("Sfx: volume 0 = stil", sfx._settings_volume() == 0.0)
	settings.sfx_volume = old


# --- integratie met echte Fighters ---

func _test_real_match() -> void:
	var reg: Node = root.get_node("/root/CharacterRegistry")
	reg.include_dummy = true
	reg.rescan()
	var setup: Node = root.get_node("/root/MatchSetup")
	setup.reset()
	setup.mode = "fight"
	setup.picks[0] = "_dummy"
	setup.picks[1] = "_dummy"
	var sim: Node = _sim()
	var scene: Node = load("res://ui/match/match.tscn").instantiate()
	scene.auto_navigate = false
	root.add_child(scene)
	var c: MatchController = scene as MatchController
	await process_frame
	check("echt: 2 echte Fighters, camera, HUD", c.fighters.size() == 2 and c.fighters[0] is Fighter and c.camera != null and c.hud != null)
	check("echt: auto_respawn uit (controller regelt respawn)", not c.fighters[0].auto_respawn)
	for i in MatchController.COUNT_FRAMES + 30:
		sim._advance()
	check("echt: na de countdown PLAYING", c.phase == MatchController.Phase.PLAYING)
	var f0: Fighter = c.fighters[0] as Fighter
	f0.grounded = false
	f0.ground_seg = -1
	f0.change_state("Fall")
	f0.pos = Vector2(0, -500)    # ver onder de blast zone
	sim._advance()
	sim._advance()
	check("echt: blast zone -> stock eraf en fighter uit", c.state.stocks[0] == 3 and c.is_dead(0) and not f0.visible)
	for i in MatchController.RESPAWN_DELAY + 2:
		sim._advance()
	check("echt: respawn_at na vertraging", not c.is_dead(0) and f0.visible and f0.pos.y > 0.0)
	await process_frame
	await process_frame
	scene.queue_free()
	await process_frame
	check("echt: sim niet gepauzeerd en geen debug-context na afsluiten", not sim.paused and not sim.debug_context)
