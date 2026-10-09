class_name MatchController
extends Node2D
## De wedstrijd (M6): stage Eindpunt, twee fighters, camera, HUD, countdown, stocks, respawn, timer, einde,
## sudden death, pauze en training. Alles loopt op sim-frames: de controller is zelf een Sim-entity
## (`sim_tick`), registreert zich ná de fighters en tikt dus als laatste per frame. Zie docs/ui.md.
##
## Alleen de pauze/quit-input en de training-knoppen lopen in `_physics_process` (ze moeten ook werken
## terwijl de Sim gepauzeerd is; dan sampelt de controller de input zelf).

signal finished(result: MatchResult)
signal quit_requested
signal ko_happened(player: int)

enum Phase { COUNTDOWN, PLAYING, ENDING }

const MODE_TRAINING: String = "training"
const SCENE_SELECT: String = "res://ui/character_select/character_select.tscn"
const SCENE_RESULTS: String = "res://ui/results/results.tscn"
const STAGE_SCENE: String = "res://stages/eindpunt/eindpunt.tscn"

## 3-2-1: 60 frames per cijfer; daarna GO.
const COUNT_STEP: int = 60
const COUNT_FRAMES: int = COUNT_STEP * 3
## Hoe lang "GO!" in beeld blijft.
const GO_SHOW: int = 45
## Frames tussen blast zone-KO en terugkomst op het respawn-punt. ⚠️ geschat (Melee: ruim 2 s inclusief KO-effect).
const RESPAWN_DELAY: int = 120
## Onkwetsbare frames na respawn (Melee: 120 op het platform, ⚠️).
const RESPAWN_INVINCIBLE: int = 120
const TRAINING_RESPAWN_DELAY: int = 45
## Frames tussen "GAME!"/"TIME!" en het results-scherm.
const END_DELAY: int = 150
## Een klap telt als KO-bron als hij hooguit zo lang geleden viel (5 s); anders is de val een zelfvernietiging.
const HIT_MEMORY: int = 300
const SUDDEN_DEATH_PERCENT: float = 300.0
const TRIGGER_ON: float = 0.7
const DUMMY_PERCENT_STEP: float = 10.0
const MAX_PERCENT: float = 999.0
const ARCHETYPE_IDS: Dictionary = {
	"Zwaargewicht": "heavyweight", "Allrounder": "allrounder", "Fast-faller": "fast_faller",
	"Floaty": "floaty", "Lichtgewicht": "lightweight",
}

var mode: String = "fight"
var picks: Array[String] = ["_dummy", "_dummy"]
var rules: MatchRules
var state := MatchState.new()
var phase: Phase = Phase.COUNTDOWN
var fighters: Array[Node2D] = []
var stage: Node2D
var camera: MatchCamera
var hud: Node
## Speler die de pauze startte (-1 = niet gepauzeerd). Alleen die speler kan hervatten of stoppen.
var paused_by: int = -1
var sudden_death_banner: bool = false
var result: MatchResult

## Tests zetten deze uit/aan.
var build_hud: bool = true
var auto_navigate: bool = true
var auto_register: bool = true
## Maakt de fighter van speler p. Standaard een echte `Fighter`; tests geven fakes.
var fighter_factory: Callable = Callable()

var _mf: int = 0                       # sim-ticks sinds het begin van de scène
var _phase_frame: int = 0
var _play_frame: int = 0
var _dead: Array[bool] = [false, false]
var _respawn_frame: Array[int] = [-1, -1]
var _last_hit_frame: Array[int] = [-100000, -100000]
var _last_pct: Array[float] = [0.0, 0.0]
var _hit_tracking: bool = false
var _pending_ko: Array = []
var _end_info: Dictionary = {}
var _blank := InputHistory.new()
var _prev_start: Array[bool] = [false, false]
var _prev_combo: Array[bool] = [false, false]
var _prev_train: Dictionary = {}
var _frozen_by_end: bool = false


func is_training() -> bool:
	return mode == MODE_TRAINING


func _ready() -> void:
	if rules == null:
		_read_match_setup()
	state.start(rules, is_training())
	_build_stage()
	_build_fighters()
	_build_camera()
	if build_hud:
		_build_hud()
	var sim: Node = _sim()
	if sim != null:
		sim.debug_context = is_training()
		if auto_register:
			sim.register(self)
	_begin_countdown(false)


func _exit_tree() -> void:
	var sim: Node = _sim()
	if sim != null:
		sim.unregister(self)
		sim.debug_context = false
		if sim.paused:
			sim.set_paused(false)


func _read_match_setup() -> void:
	var ms: Node = get_node_or_null("/root/MatchSetup")
	if ms == null:
		rules = MatchRules.new()
		return
	mode = ms.mode
	rules = ms.rules
	var ids: Array[String] = []
	for i in 2:
		var id: String = String(ms.picks[i])
		if id == "":
			id = _fallback_character()
		ids.append(id)
	picks = ids


## Een leeg pick (bv. direct gestart zonder select) valt terug op het eerste character.
func _fallback_character() -> String:
	var reg: Node = get_node_or_null("/root/CharacterRegistry")
	if reg != null and not reg.ids().is_empty():
		return String(reg.ids()[0])
	return "_dummy"


# =============================================================================================
# Opbouw
# =============================================================================================

func _build_stage() -> void:
	stage = (load(STAGE_SCENE) as PackedScene).instantiate() as Node2D
	add_child(stage)


func _build_fighters() -> void:
	for p in 2:
		var f: Node2D = fighter_factory.call(p) if fighter_factory.is_valid() else _make_fighter(p)
		fighters.append(f)
		if f.has_signal("blast_ko"):
			f.connect("blast_ko", _on_blast_ko)
		if f.has_signal("percent_changed"):
			_hit_tracking = true
			f.connect("percent_changed", _on_percent_changed.bind(p))
	_assign_inputs()


func _make_fighter(p: int) -> Node2D:
	var f := Fighter.new()
	f.player = p
	f.character_id = picks[p]
	f.stats = stats_for(picks[p])
	f.stage = stage
	f.pos = stage.get_spawn(p)
	f.facing = 1 if p == 0 else -1
	if "auto_respawn" in f:
		f.set("auto_respawn", false)
	add_child(f)
	return f


## Movement-stats van een character via zijn archetype (character.json); onbekend = Allrounder.
static func stats_for(character_id: String) -> FighterStats:
	var arch_id: String = "allrounder"
	var reg: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("CharacterRegistry")
	if reg != null:
		var info: CharacterInfo = reg.get_info(character_id)
		if info != null:
			arch_id = String(ARCHETYPE_IDS.get(info.archetype, "allrounder"))
	return Archetypes.load_stats(arch_id)


func _build_camera() -> void:
	camera = MatchCamera.new()
	add_child(camera)
	camera.make_current()
	if stage != null and stage.has_method("get_camera_bounds"):
		camera.set_bounds_units(stage.get_camera_bounds())
	_update_camera_targets()
	camera.snap_next()


func _build_hud() -> void:
	var script: GDScript = load("res://ui/hud/match_hud.gd")
	hud = script.new()
	hud.set("controller", self)
	add_child(hud)


func _update_camera_targets() -> void:
	if camera == null:
		return
	var list: Array[Node2D] = []
	for p in fighters.size():
		if not _dead[p]:
			list.append(fighters[p])
	if list.is_empty():
		list.assign(fighters)
	camera.set_targets(list)


# =============================================================================================
# Sim-tick
# =============================================================================================

func sim_tick(_frame: int = 0) -> void:
	_mf += 1
	_phase_frame += 1
	match phase:
		Phase.COUNTDOWN:
			_tick_countdown()
		Phase.PLAYING:
			_tick_playing()
		Phase.ENDING:
			_pending_ko.clear()
			if _phase_frame >= END_DELAY:
				_finish()


func _begin_countdown(sudden: bool) -> void:
	phase = Phase.COUNTDOWN
	_phase_frame = 0
	sudden_death_banner = sudden
	_set_blank_inputs(true)


func _tick_countdown() -> void:
	_pending_ko.clear()
	if _phase_frame <= COUNT_FRAMES and (_phase_frame - 1) % COUNT_STEP == 0:
		_sfx("countdown_tick")
	if _phase_frame > COUNT_FRAMES:
		phase = Phase.PLAYING
		_play_frame = 0
		_phase_frame = 0
		sudden_death_banner = false
		_assign_inputs()
		_sfx("go")


## 3, 2, 1 tijdens de countdown; 0 daarbuiten.
func countdown_number() -> int:
	if phase != Phase.COUNTDOWN or _phase_frame < 1:
		return 0
	return 3 - mini((_phase_frame - 1) / COUNT_STEP, 2)


## Frames sinds het cijfer wisselde (0..59), voor de pop-animatie.
func countdown_age() -> int:
	return maxi(_phase_frame - 1, 0) % COUNT_STEP


func go_visible() -> bool:
	return phase == Phase.PLAYING and _play_frame < GO_SHOW


func go_age() -> int:
	return _play_frame


func end_banner() -> String:
	if phase != Phase.ENDING:
		return ""
	return "TIME!" if _end_info.get("reason", "") == "time" else "GAME!"


func _tick_playing() -> void:
	_play_frame += 1
	state.tick()
	_process_kos()
	_process_respawns()
	var ev: Dictionary = state.evaluate(percents())
	if ev["over"]:
		_end_match(ev)
	elif ev["sudden_death"]:
		_start_sudden_death()


func percents() -> Array[float]:
	return [get_percent(0), get_percent(1)]


func get_percent(p: int) -> float:
	var v: Variant = fighters[p].get("percent")
	return float(v) if v != null else 0.0


func set_percent(p: int, value: float) -> void:
	var v: float = clampf(value, 0.0, MAX_PERCENT)
	_last_pct[p] = v   # eerst: dit is geen klap, dus geen "laatste treffer"
	fighters[p].set("percent", v)


func is_dead(p: int) -> bool:
	return _dead[p]


# --- KO's en respawns ---

func _on_blast_ko(f: Node2D, _side: StringName = &"") -> void:
	if phase == Phase.PLAYING:
		_pending_ko.append(f)


func _on_percent_changed(new_percent: float, p: int) -> void:
	if new_percent > _last_pct[p]:
		_last_hit_frame[p] = _mf
	_last_pct[p] = new_percent


func _process_kos() -> void:
	var queue: Array = _pending_ko
	_pending_ko = []
	for f: Node2D in queue:
		var p: int = fighters.find(f)
		if p < 0 or _dead[p]:
			continue
		_kill(p)


func _kill(p: int) -> void:
	var other: int = 1 - p
	var by: int = other
	if _hit_tracking and _mf - _last_hit_frame[p] > HIT_MEMORY:
		by = MatchState.NO_ONE
	var eliminated: bool = state.lose_stock(p, by)
	_dead[p] = true
	var f: Node2D = fighters[p]
	f.visible = false
	_unregister(f)
	_sfx("ko_blast")
	if not eliminated:
		_respawn_frame[p] = _mf + (TRAINING_RESPAWN_DELAY if is_training() else RESPAWN_DELAY)
	else:
		_respawn_frame[p] = -1
	_update_camera_targets()
	ko_happened.emit(p)


func _process_respawns() -> void:
	for p in fighters.size():
		if _dead[p] and _respawn_frame[p] >= 0 and _mf >= _respawn_frame[p]:
			_respawn(p)


func _respawn(p: int) -> void:
	var f: Node2D = fighters[p]
	_dead[p] = false
	_respawn_frame[p] = -1
	f.visible = true
	_register(f)
	f.set("percent", 0.0)
	_last_pct[p] = 0.0
	_last_hit_frame[p] = -100000
	var at: Vector2 = stage.get_respawn(p)
	if f.has_method("respawn_at"):
		f.call("respawn_at", at, RESPAWN_INVINCIBLE)   # speelt zelf het respawn-geluid
	else:
		f.call("spawn", at, 1 if p == 0 else -1)
		_sfx("respawn")
	_update_camera_targets()


func _register(f: Node2D) -> void:
	var sim: Node = _sim()
	if sim != null and auto_register:
		sim.register(f)


func _unregister(f: Node2D) -> void:
	var sim: Node = _sim()
	if sim != null:
		sim.unregister(f)


# --- einde ---

func _end_match(ev: Dictionary) -> void:
	_end_info = ev
	phase = Phase.ENDING
	_phase_frame = 0
	_set_blank_inputs(false)
	result = _make_result(ev)


func _make_result(ev: Dictionary) -> MatchResult:
	var r := MatchResult.new()
	r.winner = int(ev["winner"])
	r.reason = String(ev["reason"])
	r.sudden_death = state.sudden_death
	r.picks = picks.duplicate()
	r.stocks = state.stocks.duplicate()
	r.percents = percents()
	r.kos = state.kos.duplicate()
	r.falls = state.falls.duplicate()
	r.sds = state.sds.duplicate()
	r.frames = state.elapsed
	return r


func _finish() -> void:
	MatchResult.last = result
	finished.emit(result)
	if auto_navigate and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(SCENE_RESULTS)


func _start_sudden_death() -> void:
	state.begin_sudden_death()
	for p in fighters.size():
		var f: Node2D = fighters[p]
		if _dead[p]:
			_revive(f)
		_respawn_frame[p] = -1
		f.call("spawn", stage.get_spawn(p), 1 if p == 0 else -1)
		set_percent(p, SUDDEN_DEATH_PERCENT)
		_last_hit_frame[p] = -100000
	_pending_ko.clear()
	_update_camera_targets()
	camera.snap_next()
	_begin_countdown(true)


# =============================================================================================
# Input-omschakeling (countdown/einde = geen besturing; dummy = nooit besturing)
# =============================================================================================

func _assign_inputs() -> void:
	_set_blank_inputs(false)


## `all` = iedereen blanco (countdown/einde); anders alleen de dummy in training.
func _set_blank_inputs(all: bool) -> void:
	var im: Node = get_node_or_null("/root/InputManager")
	for p in fighters.size():
		var h: InputHistory = _blank
		var dummy: bool = is_training() and p == 1
		if not all and not dummy and im != null:
			h = im.history(p)
		fighters[p].set("input", h)


# =============================================================================================
# Pauze (Melee): Start pauzeert; alleen die speler hervat; L+R+A+Start (pauzeerder) stopt de match
# =============================================================================================

func _physics_process(_delta: float) -> void:
	var sim: Node = _sim()
	var im: Node = get_node_or_null("/root/InputManager")
	if sim != null and im != null and sim.paused:
		im.sample(sim.frame)   # de Sim doet dat niet meer zolang hij gepauzeerd is
	for p in 2:
		var f: InputFrame = im.latest(p) if im != null else InputFrame.new()
		var kb_start: bool = p == 0 and (Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_ESCAPE))
		var kb_quit: bool = p == 0 and Input.is_physical_key_pressed(KEY_Q)
		process_pause_input(p, f, kb_start, kb_quit)
	if is_training() and phase == Phase.PLAYING and paused_by < 0:
		_poll_training()


## Verwerkt het input-frame van speler p. Geeft "pause", "resume", "quit" of "" terug.
func process_pause_input(p: int, f: InputFrame, kb_start: bool = false, kb_quit: bool = false) -> StringName:
	var start_now: bool = f.has(InputFrame.BTN_START) or kb_start
	var start_edge: bool = start_now and not _prev_start[p]
	_prev_start[p] = start_now
	var combo: bool = start_now and f.has(InputFrame.BTN_ATTACK) and f.trigger_l >= TRIGGER_ON and f.trigger_r >= TRIGGER_ON
	var combo_edge: bool = combo and not _prev_combo[p]
	_prev_combo[p] = combo
	if paused_by < 0:
		if start_edge and phase == Phase.PLAYING:
			_set_paused(p)
			return &"pause"
		return &""
	if p != paused_by:
		return &""
	if combo_edge or kb_quit:
		quit_match()
		return &"quit"
	if start_edge:
		_set_paused(-1)
		return &"resume"
	return &""


func _set_paused(p: int) -> void:
	paused_by = p
	var sim: Node = _sim()
	if sim != null:
		sim.set_paused(p >= 0)
	_sfx("menu_confirm")


func quit_match() -> void:
	paused_by = -1
	var sim: Node = _sim()
	if sim != null:
		sim.set_paused(false)
	MatchResult.last = null
	quit_requested.emit()
	if auto_navigate and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(SCENE_SELECT)


# =============================================================================================
# Training
# =============================================================================================

## Acties: "pct_up", "pct_down", "pct_zero" (dummy-%) en "reset" (posities).
func training_action(act: StringName) -> void:
	if not is_training():
		return
	match act:
		&"pct_up":
			set_percent(1, get_percent(1) + DUMMY_PERCENT_STEP)
		&"pct_down":
			set_percent(1, get_percent(1) - DUMMY_PERCENT_STEP)
		&"pct_zero":
			set_percent(1, 0.0)
		&"reset":
			reset_positions()


func reset_positions() -> void:
	for p in fighters.size():
		var f: Node2D = fighters[p]
		if _dead[p]:
			_dead[p] = false
			_respawn_frame[p] = -1
			_revive(f)
		f.call("spawn", stage.get_spawn(p), 1 if p == 0 else -1)
	_pending_ko.clear()
	_update_camera_targets()
	if camera != null:
		camera.snap_next()


func _poll_training() -> void:
	var im: Node = get_node_or_null("/root/InputManager")
	var dev: int = im.devices[0] if im != null else -1
	var keys: Dictionary = {
		&"pct_up": [KEY_F7, JOY_BUTTON_DPAD_UP], &"pct_down": [KEY_F6, JOY_BUTTON_DPAD_DOWN],
		&"pct_zero": [KEY_F9, JOY_BUTTON_DPAD_RIGHT], &"reset": [KEY_F8, JOY_BUTTON_DPAD_LEFT],
	}
	for act: StringName in keys:
		var spec: Array = keys[act]
		var down: bool = Input.is_physical_key_pressed(spec[0])
		if dev >= 0 and dev != im.NO_DEVICE:
			down = down or Input.is_joy_button_pressed(dev, spec[1])
		if down and not _prev_train.get(act, false):
			training_action(act)
		_prev_train[act] = down


# =============================================================================================
# Hulpjes
# =============================================================================================

func _sim() -> Node:
	return get_node_or_null("/root/Sim")


func _sfx(sound_name: String) -> void:
	var s: Node = get_node_or_null("/root/Sfx")
	if s != null:
		s.call("play", sound_name)


## Haalt een uitgeschakelde fighter terug in het spel (zichtbaar, actief, in de Sim); positie zet de aanroeper.
func _revive(f: Node2D) -> void:
	var p: int = fighters.find(f)
	if p >= 0:
		_dead[p] = false
	f.visible = true
	if "active" in f:
		f.set("active", true)
	_register(f)


func display_name(p: int) -> String:
	var reg: Node = get_node_or_null("/root/CharacterRegistry")
	if reg != null:
		var info: CharacterInfo = reg.get_info(picks[p])
		if info != null:
			return info.display_name
	return picks[p]
