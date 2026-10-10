extends SceneTree
## Performance-bench + determinisme-check (docs/performance.md).
##
##   <godot_console> --headless --path . --script res://tools/bench/bench.gd -- [opties]
##
## Opties:
##   --frames N        aantal sim-frames na de countdown (standaard 3600)
##   --p1 ID --p2 ID   characters (standaard _dummy vs _dummy: alleen die heeft vaste specials; zie docs/performance.md)
##   --no-hud          zonder HUD
##   --write-golden    schrijf de snapshot-hash naar tools/bench/golden.json (alleen na een BEWUSTE gedragswijziging)
##   --check           vergelijk met golden.json; exit 1 bij verschil (ook zonder: toont het resultaat)
##   --skip-real       sla de controlerun met de echte Sim._advance() over
##   --json PATH       schrijf de metingen als JSON
##
## Twee runs: (1) echte `Sim._advance()` (alleen hash), (2) gespiegelde loop met tijdmeting per subsysteem.
## Beide moeten dezelfde hash geven. Input is volledig gescript en state-onafhankelijk (vooraf berekend).
## Headless gebruikt een dummy-renderer: GPU-kosten (draw calls) zijn dus NIET gemeten, wel alle script-,
## scene-tree- en draw-recording-kosten. Zie docs/performance.md voor de beperkingen.

const GOLDEN_PATH: String = "res://tools/bench/golden.json"
const SEED: int = 20260710

var frames_to_run: int = 3600
var p1: String = "_dummy"
var p2: String = "_dummy"
var use_hud: bool = true
var write_golden: bool = false
var check: bool = false
var skip_real: bool = true
var json_path: String = ""

var _script_inputs: Array = []   # [player][frame] -> InputFrame
var _runs: Array = []            # werklijst: {"mode": "real"|"timed"}
var _ctl: MatchController
var _run: Dictionary = {}
var _n: int = 0                  # frames gesimuleerd in deze run (incl. countdown)
var _total_frames: int = 0
var _ctx: HashingContext
var _prev_start: int = 0
var _prev_sim: int = 0
var _prev_over: int = 0
var _samples: Dictionary = {}    # key -> PackedInt32Array (usec per frame)
var _hash_real: String = ""
var _hash_timed: String = ""
var _counters: Dictionary = {}
var _obj_start: int = 0
var _obj_peak: int = 0
var _mem_start: float = 0.0
var _state_hits: Dictionary = {}
var _max_entities: int = 0
var _exit_code: int = 0
var _sim: Node
var _im: Node
var _finished: bool = false
var _cov_near: int = 0
var _cov_frames: int = 0
var _cov_hits: int = 0
var _cov_prev_pct: Array[float] = [0.0, 0.0]
var _calib_left: int = 0
var _calib_last: int = 0
var _calib_sum: int = 0
var _calib_n: int = 0
var _idle_us: float = 0.0


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	_sim = root.get_node("/root/Sim")
	_im = root.get_node("/root/InputManager")
	_parse()
	_runs = ([] if skip_real else [{"mode": "real"}]) + [{"mode": "timed"}]
	_script_inputs = _make_inputs(frames_to_run + MatchController.COUNT_FRAMES + 8)
	_total_frames = frames_to_run + MatchController.COUNT_FRAMES + 2
	_sim.set_physics_process(false)   # de bench bepaalt zelf wanneer een sim-frame loopt
	_calib_left = 130


func _parse() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	skip_real = false
	var i: int = 0
	while i < a.size():
		match a[i]:
			"--frames":
				frames_to_run = int(a[i + 1])
				i += 1
			"--p1":
				p1 = a[i + 1]
				i += 1
			"--p2":
				p2 = a[i + 1]
				i += 1
			"--json":
				json_path = a[i + 1]
				i += 1
			"--no-hud":
				use_hud = false
			"--write-golden":
				write_golden = true
			"--check":
				check = true
			"--skip-real":
				skip_real = true
		i += 1


# =============================================================================================
# Gescripte input
# =============================================================================================

func _make_inputs(n: int) -> Array:
	var out: Array = [[], []]
	for p in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + p * 101
		var f: int = 0
		while f < n:
			var action: int = _pick_action(rng)
			var dur: int = rng.randi_range(6, 24)
			# Naderen: de twee spelers lopen om en om naar elkaar toe (vaste cyclus, state-onafhankelijk).
			var approach: int = (1 if p == 0 else -1) * (1 if (f / 600) % 2 == 0 else -1)
			for k in dur:
				if f >= n:
					break
				out[p].append(_input_for(action, k, approach, rng))
				f += 1
	return out


func _input_for(action: int, k: int, dir: int, rng: RandomNumberGenerator) -> InputFrame:
	var fr := InputFrame.new()
	var press: bool = k % 14 < 2
	match action:
		0:
			pass
		1, 2:
			fr.stick = Vector2i(60 * dir, 0)
		3:
			fr.stick = Vector2i(80 * dir, 0) if k % 10 < 3 else Vector2i(0, 0)
		4:
			fr.stick = Vector2i(-60 * dir, 0)
		5:
			fr.stick = Vector2i(50 * dir, 0)
			if press:
				fr.buttons |= InputFrame.BTN_JUMP
		6:
			fr.stick = Vector2i(30 * dir, 0)
			if press:
				fr.buttons |= InputFrame.BTN_ATTACK
		7:
			fr.stick = Vector2i(80 * dir, 0) if k % 14 < 2 else Vector2i(20 * dir, 0)
			if press:
				fr.buttons |= InputFrame.BTN_ATTACK
		8:
			if press:
				fr.buttons |= InputFrame.BTN_SPECIAL
		9:
			fr.stick = Vector2i(70 * dir, 0)
			if press:
				fr.buttons |= InputFrame.BTN_SPECIAL
		10:
			fr.stick = Vector2i(0, 75)
			if press:
				fr.buttons |= InputFrame.BTN_SPECIAL
		11:
			fr.stick = Vector2i(0, -75)
			if press:
				fr.buttons |= InputFrame.BTN_SPECIAL
		12:
			fr.trigger_l = 1.0
			fr.buttons |= InputFrame.BTN_SHIELD
		13:
			if k < 2:
				fr.buttons |= InputFrame.BTN_Z
			elif k >= 10 and k < 14:
				fr.stick = Vector2i(80 * dir, 0)
			elif k == 6:
				fr.buttons |= InputFrame.BTN_ATTACK
		14:
			fr.stick = Vector2i(40 * dir, 0)
			if press:
				fr.buttons |= InputFrame.BTN_JUMP
			if k % 14 == 8:
				fr.cstick = Vector2i(80 * dir, 0)
		15:
			fr.stick = Vector2i(0, -80) if k % 6 < 3 else Vector2i(0, 0)
			if k % 16 < 2:
				fr.buttons |= InputFrame.BTN_JUMP
		16:
			fr.stick = Vector2i(45 * dir, rng.randi_range(-40, 40))
			if press:
				fr.buttons |= InputFrame.BTN_ATTACK
		17:
			fr.trigger_l = 0.45
	return fr


func _scripted(p: int, frame: int) -> InputFrame:
	var arr: Array = _script_inputs[p]
	return arr[mini(_n, arr.size() - 1)]


# =============================================================================================
# Run-beheer
# =============================================================================================

func _begin_run() -> void:
	_run = _runs.pop_front()
	_n = 0
	_sim.frame = 0
	for p in 2:
		_im._histories[p] = InputHistory.new()
	_im.scripted_source = _scripted
	_ctl = MatchController.new()
	_ctl.mode = "fight"
	var rules := MatchRules.new()
	rules.stocks = 99
	_ctl.rules = rules
	_ctl.picks = [p1, p2]
	_ctl.build_hud = use_hud
	_ctl.auto_navigate = false
	root.add_child(_ctl)
	_ctx = HashingContext.new()
	_ctx.start(HashingContext.HASH_SHA256)
	_samples = {}
	_counters = {}
	_state_hits = {}
	_cov_near = 0
	_cov_frames = 0
	_cov_hits = 0
	_max_entities = 0
	_prev_start = 0
	_prev_sim = 0
	_prev_over = 0
	for p in 2:
		var f: Fighter = _ctl.fighters[p] as Fighter
		f.state_changed.connect(_on_state_changed)
	Perf.enabled = _run["mode"] == "timed"
	Perf.take()
	_obj_start = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_obj_peak = _obj_start
	_mem_start = Performance.get_monitor(Performance.MEMORY_STATIC)


func _on_state_changed(_old: String, id: String) -> void:
	_state_hits[id] = int(_state_hits.get(id, 0)) + 1


func _process(_delta: float) -> bool:
	if _finished:
		return true
	var t_now: int = Time.get_ticks_usec()
	if _calib_left > 0:
		# Kalibratie: duur van een lege engine-iteratie (headless dummy-loop), wordt apart gerapporteerd.
		if _calib_left < 120 and _calib_last > 0:
			_calib_sum += t_now - _calib_last
			_calib_n += 1
		_calib_last = t_now
		_calib_left -= 1
		if _calib_left == 0:
			_idle_us = float(_calib_sum) / float(maxi(_calib_n, 1))
			_begin_run()
		return false
	if _run.is_empty():
		return false
	var timed: bool = _run["mode"] == "timed"
	# Metingen van het vorige frame (engine-process, draws en Perf-sleutels zijn nu bekend).
	if timed and _n > MatchController.COUNT_FRAMES + 2:
		var wall: int = t_now - _prev_start
		var perf: Dictionary = Perf.take()
		_add(&"engine_rest", maxi(wall - _prev_sim - _prev_over, 0))
		for k: Variant in perf:
			_add(StringName(k), int(perf[k]))
		_add(&"frame_total", maxi(wall - _prev_over, 0))
		_obj_peak = maxi(_obj_peak, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	elif timed:
		Perf.take()
	_prev_start = t_now
	if _n >= _total_frames:
		_end_run()
		return _finished
	_advance(timed)
	return false


func _add(key: StringName, usec: int) -> void:
	if not _samples.has(key):
		_samples[key] = PackedInt32Array()
	var arr: PackedInt32Array = _samples[key]
	arr.append(usec)
	_samples[key] = arr


func _advance(timed: bool) -> void:
	var measure: bool = timed and _n > MatchController.COUNT_FRAMES + 1
	var t0: int = Time.get_ticks_usec()
	var parts: Dictionary = {}
	if _n > MatchController.COUNT_FRAMES and _n % 240 == 0 and _ctl.phase == MatchController.Phase.PLAYING:
		_ctl.set_percent(_n / 240 % 2, 90.0 + float(_n % 7) * 15.0)   # genoeg % voor launches/KO-effecten
	if _n > MatchController.COUNT_FRAMES and _n % 100 == 50 and _ctl.phase == MatchController.Phase.PLAYING and not _ctl.is_dead(0) and not _ctl.is_dead(1):
		var f0: Fighter = _ctl.fighters[0] as Fighter
		var f1: Fighter = _ctl.fighters[1] as Fighter
		if absf(f0.pos.x - f1.pos.x) > 30.0 or f0.pos.y < -5.0 or f1.pos.y < -5.0:
			f0.spawn(Vector2(-9.0, 0.0), 1)   # houd het gevecht bij elkaar (bench-ingreep, deterministisch)
			f1.spawn(Vector2(9.0, 0.0), -1)
	if _run["mode"] == "real":
		_sim._advance()
	else:
		var t: int = Time.get_ticks_usec()
		_im.sample(_sim.frame)
		parts[&"input"] = Time.get_ticks_usec() - t
		var ents: Array[Object] = _sim.entities()
		for e: Object in ents.duplicate():
			if is_instance_valid(e) and ents.has(e):
				t = Time.get_ticks_usec()
				e.sim_tick(_sim.frame)
				var key: StringName = &"other"
				if e is Fighter:
					key = &"fighters"
				elif e is SpecialWorld:
					key = &"specials"
				elif e is VfxLayer:
					key = &"vfx"
				elif e is MatchController:
					key = &"match"
				parts[key] = int(parts.get(key, 0)) + Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		_sim.combat.step(ents)
		parts[&"combat"] = Time.get_ticks_usec() - t
		var k: int = ents.size() - 1
		while k >= 0:
			if not is_instance_valid(ents[k]):
				ents.remove_at(k)
			k -= 1
		_sim.frame += 1
		_sim.frame_advanced.emit(_sim.frame)
	var sim_total: int = Time.get_ticks_usec() - t0
	if sim_total > 5000 and measure:
		print("HITCH frame %d: %d us parts=%s states=%s,%s" % [_n, sim_total, str(parts), (_ctl.fighters[0] as Fighter).state_name(), (_ctl.fighters[1] as Fighter).state_name()])
	if measure:
		for key: Variant in parts:
			_add(StringName(key), int(parts[key]))
		_add(&"sim_total", sim_total)
	# --- bookkeeping buiten de meting ---
	var t1: int = Time.get_ticks_usec()
	_hash_frame()
	_n += 1
	_prev_sim = sim_total
	_prev_over = Time.get_ticks_usec() - t1


func _hash_frame() -> void:
	var data: Array = []
	for p in 2:
		var f: Fighter = _ctl.fighters[p] as Fighter
		data.append(f.snapshot())
		data.append(f.hitlag_frames)
		data.append(f.visible)
	var dxs: float = absf((_ctl.fighters[0] as Fighter).pos.x - (_ctl.fighters[1] as Fighter).pos.x)
	_cov_near += 1 if dxs < 25.0 else 0
	_cov_frames += 1
	for p in 2:
		var pc: float = (_ctl.fighters[p] as Fighter).percent
		if pc > _cov_prev_pct[p]:
			_cov_hits += 1
		_cov_prev_pct[p] = pc
	data.append(_ctl.state.stocks)
	data.append(_ctl.phase)
	var w: Variant = (_ctl.stage as Object).get_meta(SpecialWorld.META) if (_ctl.stage as Object).has_meta(SpecialWorld.META) else null
	if w is SpecialWorld:
		var sw: SpecialWorld = w
		_max_entities = maxi(_max_entities, sw.entities.size())
		for e: SpecialEntity in sw.entities:
			data.append([e.serial, e.pos, e.vel, e.alive, e.age])
	_ctx.update(var_to_bytes(data))


func _end_run() -> void:
	var hash: String = _ctx.finish().hex_encode()
	var mode: String = _run["mode"]
	if mode == "real":
		_hash_real = hash
	else:
		_hash_timed = hash
	var mem_delta: float = Performance.get_monitor(Performance.MEMORY_STATIC) - _mem_start
	var obj_end: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var res: Dictionary = {"mode": mode, "hash": hash, "objects_start": _obj_start, "objects_end": obj_end,
		"objects_peak": _obj_peak, "static_mem_delta_kb": mem_delta / 1024.0, "max_entities": _max_entities,
		"states": _state_hits.duplicate(), "stats": _stats()}
	_counters[mode] = res
	# opruimen
	_im.scripted_source = Callable()
	root.remove_child(_ctl)
	_ctl.free()
	if _runs.is_empty():
		_finish()
	else:
		_begin_run()


func _stats() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in _samples:
		var arr: PackedInt32Array = _samples[k]
		var total: int = (_samples[&"frame_total"] as PackedInt32Array).size() if _samples.has(&"frame_total") else arr.size()
		if arr.size() < total:
			arr = arr.duplicate()   # frames zonder deze sleutel (bv. HUD zonder redraw) tellen als 0
			arr.resize(total)
		var sorted: PackedInt32Array = arr.duplicate()
		sorted.sort()
		var sum: float = 0.0
		for v in arr:
			sum += v
		var n: int = arr.size()
		out[String(k)] = {"avg": sum / float(maxi(n, 1)), "p99": float(sorted[mini(int(n * 0.99), n - 1)]) if n > 0 else 0.0,
			"max": float(sorted[n - 1]) if n > 0 else 0.0, "n": n}
	return out


func _finish() -> void:
	_finished = true
	var timed: Dictionary = _counters.get("timed", {})
	var stats: Dictionary = timed.get("stats", {})
	print("")
	print("=== Bench: %d frames, %s vs %s, hud=%s ===" % [frames_to_run, p1, p2, str(use_hud)])
	print("%-14s %9s %9s %9s   (ms per frame)" % ["subsysteem", "gem.", "p99", "max"])
	var order: Array = ["input", "fighters", "visual", "combat", "specials", "vfx", "match", "other", "sim_total",
		"hud", "vfx_draw", "fx_draw", "entity_draw", "engine_rest", "frame_total"]
	for k: String in order:
		if stats.has(k):
			var s: Dictionary = stats[k]
			print("%-14s %9.3f %9.3f %9.3f" % [k, s["avg"] / 1000.0, s["p99"] / 1000.0, s["max"] / 1000.0])
	for k: Variant in stats:
		if not order.has(String(k)):
			var s2: Dictionary = stats[k]
			# Tellers (geen tijden): gemiddelde per frame.
			print("%-14s %9.3f %9.3f %9.0f   (teller per frame)" % [String(k), s2["avg"], s2["p99"], s2["max"]])
	print("lege engine-iteratie (kalibratie, zit in engine_rest): %.3f ms" % [_idle_us / 1000.0])
	print("fighters-tijd bevat 'visual' (pose + rig) en overlays; 'combat' bevat visual-updates van geraakte fighters.")
	print("objecten: start %d, einde %d, piek %d; statisch geheugen %+.0f KB; max entities %d" % [
		timed.get("objects_start", 0), timed.get("objects_end", 0), timed.get("objects_peak", 0),
		timed.get("static_mem_delta_kb", 0.0), timed.get("max_entities", 0)])
	var st: Dictionary = timed.get("states", {})
	var keys: Array = ["Attack", "AttackAir", "Special", "Grab", "GrabHold", "Throw", "Guard", "DamageFly", "Damage", "Dead"]
	var parts: PackedStringArray = PackedStringArray()
	for k: String in keys:
		parts.append("%s=%d" % [k, int(st.get(k, 0))])
	print("dekking (state-wissels): ", ", ".join(parts))
	print("dekking: fighters binnen 25 units op %.0f%% van de frames; treffers (%%-stijgingen) %d" % [100.0 * _cov_near / maxf(_cov_frames, 1), _cov_hits])
	print("hash timed: ", _hash_timed)
	if not skip_real:
		print("hash real : ", _hash_real)
		if _hash_real != _hash_timed:
			print("FAIL  hash van gespiegelde loop wijkt af van de echte Sim._advance (of state lekt tussen runs)")
			_exit_code = 1
	var golden: Dictionary = _read_golden()
	var key: String = _golden_key()
	if write_golden:
		golden[key] = _hash_timed
		var fa := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		fa.store_string(JSON.stringify(golden, "\t"))
		fa.close()
		print("golden geschreven voor ", key)
	elif golden.has(key):
		var ok: bool = golden[key] == _hash_timed
		print(("PASS" if ok else "FAIL"), "  determinisme t.o.v. golden (", key, ")")
		if not ok:
			_exit_code = 1
	elif check:
		print("FAIL  geen golden voor ", key, " (draai met --write-golden)")
		_exit_code = 1
	else:
		print("(geen golden voor ", key, ")")
	if json_path != "":
		var jf := FileAccess.open(json_path, FileAccess.WRITE)
		jf.store_string(JSON.stringify(_counters, "\t"))
		jf.close()
	quit(_exit_code)


func _golden_key() -> String:
	return "%s|%s|%d" % [p1, p2, frames_to_run]


func _read_golden() -> Dictionary:
	if not FileAccess.file_exists(GOLDEN_PATH):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	return d if d is Dictionary else {}


## Gewogen keuze: veel naderen en aanvallen, zodat er voortdurend treffers, specials, grabs en shields zijn.
func _pick_action(rng: RandomNumberGenerator) -> int:
	const POOL: Array[int] = [3, 3, 3, 3, 1, 1, 5, 6, 6, 6, 6, 7, 7, 7, 8, 8, 9, 9, 10, 11, 11, 12, 13, 13, 14, 14, 15, 16, 16, 16, 17]
	return POOL[rng.randi_range(0, POOL.size() - 1)]
