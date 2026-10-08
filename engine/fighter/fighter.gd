class_name Fighter
extends Node2D
## Eén fighter: Melee-movement met een state machine (één class per state in engine/fighter/states/).
##
## - Rekent in Melee-units per frame; de node-positie (px) is alleen presentatie.
## - Geen Godot-physics: grondcontact en landen via een eigen ECB tegen de stage-segmenten.
## - Per sim-frame, in de Melee-volgorde (doldecomp): Anim -> IASA -> Phys -> Coll.
##     anim(): tijd-gestuurde overgangen (einde animatie, jumpsquat klaar, landing lag op)
##     iasa(): input-overgangen (draait voor de state die er NA anim() is)
##     phys(): snelheden (gravity, drift, traction, dash/run-accel)
##     coll(): positie bijwerken + grond/landen/van de rand af
## - Deterministisch: alleen input + vorige toestand bepalen de volgende toestand.
##
## Stage-interface (minimaal): `get_ground_segments()` -> lijst lijnstukken met `a`, `b` (Vector2, units)
## en `type` (StageSegment.Type-int 0 = solid / 1 = platform, of "solid"/"platform"); als Object of
## Dictionary. `get_blast_zone()` -> Rect2 (position = links/onder). Optioneel `get_respawn(i)`.
## Zie docs/movement.md, sectie "M1-implementatie".

signal state_changed(old_state: String, new_state: String)

const EPS: float = 0.0001
## Afstand onder een genegeerd platform waarna het weer meetelt (platform drop).
const PLATFORM_CLEAR_DIST: float = 0.5
const DEFAULT_RESPAWN := Vector2(0.0, 60.0)
const SEG_SOLID: int = 0
const SEG_PLATFORM: int = 1

@export var player: int = 0
@export var stats: FighterStats
@export var character_id: String = "_dummy"
@export var use_visual: bool = true
## Registreert zich in _ready bij het Sim-autoload (uit voor headless tests die zelf sim_tick aanroepen).
@export var auto_register: bool = true
## UCF dashback: een tilt-turn die op frame 1 alsnog de dash-drempel haalt (binnen het venster) wordt een dash.
@export var ucf_dashback: bool = true
## -1 = Settings-autoload volgen (standaard aan), 0 = tap jump uit, 1 = aan.
var tap_jump_override: int = -1

## Object met get_ground_segments()/get_blast_zone(); zie boven.
var stage: Object
## Inputbron. Standaard InputManager.history(player); tests geven hun eigen InputHistory.
var input: InputHistory

# --- Physics-toestand (Melee-units, y omhoog) ---
## Positie = onderpunt van de ECB (voeten).
var pos: Vector2 = Vector2.ZERO
## Luchtsnelheid (self_vel).
var vel: Vector2 = Vector2.ZERO
## Grondsnelheid langs het segment.
var gr_vel: float = 0.0
var facing: int = 1
var grounded: bool = false
var ground_seg: int = -1
var air_jumps_used: int = 0
var fastfalling: bool = false
var ignore_platform: int = -1

# --- State machine ---
var state: FighterState
var state_frame: int = 0
var prev_state_name: String = ""
var tick_count: int = 0

var visual: CharacterVisual

var _states: Dictionary = {}
var _segments: Array = []
var _consumed_tap_jump: int = -1000


func _init() -> void:
	_register_default_states()


func _ready() -> void:
	setup()


## Initialiseert input/stats/visual en spawnt op `pos`. Idempotent; tests mogen dit direct aanroepen
## zonder de fighter in de boom te hangen.
func setup() -> void:
	if state != null:
		return
	if input == null and is_inside_tree():
		var im: Node = get_node_or_null("/root/InputManager")
		if im != null:
			input = im.history(player)
	if input == null:
		input = InputHistory.new()
	if stats == null:
		stats = FighterStats.new()
	if use_visual and visual == null:
		visual = CharacterVisual.new()
		visual.character_id = character_id
		visual.player_index = player
		add_child(visual)
	if auto_register and is_inside_tree():
		var sim: Node = get_node_or_null("/root/Sim")
		if sim != null:
			sim.register(self)
	spawn(pos, facing)
	_update_visual()


func _exit_tree() -> void:
	var sim: Node = get_node_or_null("/root/Sim")
	if sim != null:
		sim.unregister(self)


func _to_string() -> String:
	return "P%d" % (player + 1)


# =============================================================================================
# State machine
# =============================================================================================

func _register_default_states() -> void:
	for s: FighterState in [
		StateWait.new(), StateWalk.new(), StateDash.new(), StateRun.new(), StateRunBrake.new(),
		StateTurn.new(), StateRunTurn.new(), StateSquat.new(), StateSquatWait.new(), StateSquatRv.new(),
		StateKneeBend.new(), StateJump.new(), StateJumpAerial.new(), StateFall.new(),
		StateEscapeAir.new(), StateFallSpecial.new(), StateLanding.new(), StateLandingFallSpecial.new(),
	]:
		register_state(s)


## Voeg een state toe of vervang er een (latere mijlpalen: Guard, Attack*, CliffWait, ...).
func register_state(s: FighterState) -> void:
	s.f = self
	_states[s.id()] = s


func has_state(id: String) -> bool:
	return _states.has(id)


func change_state(id: String, args: Dictionary = {}) -> void:
	var next: FighterState = _states.get(id)
	if next == null:
		push_error("Fighter: onbekende state '%s'" % id)
		return
	var old: String = ""
	if state != null:
		state.exit()
		old = state.id()
	prev_state_name = old
	state = next
	state_frame = 0
	next.enter(args)
	state_changed.emit(old, id)


func state_name() -> String:
	return state.id() if state != null else ""


## Eén sim-frame. Aangeroepen door Sim (of direct door tests).
func sim_tick(_frame: int = 0) -> void:
	tick_count += 1
	_segments = _read_segments()
	state_frame += 1
	state.anim()
	state.iasa()
	state.phys()
	state.coll()
	_post_coll()
	_update_visual()


## Plaats de fighter. Staat hij (bijna) op een segment, dan op de grond in Wait, anders Fall.
func spawn(at: Vector2, dir: int = 1) -> void:
	_segments = _read_segments()
	pos = at
	vel = Vector2.ZERO
	gr_vel = 0.0
	facing = 1 if dir >= 0 else -1
	fastfalling = false
	air_jumps_used = 0
	ignore_platform = -1
	var seg: int = _segment_at(at, 0.01)
	if seg >= 0:
		_set_grounded(seg, at.x)
		change_state("Wait")
	else:
		grounded = false
		ground_seg = -1
		change_state("Fall")


func respawn() -> void:
	var at: Vector2 = DEFAULT_RESPAWN
	if stage != null and stage.has_method("get_respawn"):
		at = stage.get_respawn(player)
	spawn(at, facing)
	# Respawn-punt ligt meestal op de grond; tijdelijk: altijd vallend vanaf iets erboven.
	if grounded:
		grounded = false
		ground_seg = -1
		pos.y += 40.0
		change_state("Fall")


func set_stats(s: FighterStats) -> void:
	stats = s


# =============================================================================================
# Input-helpers
# =============================================================================================

func stick() -> Vector2:
	return input.get_frame(0).stick_f()


func stick_x() -> float:
	return stick().x


func stick_y() -> float:
	return stick().y


func tap_jump_enabled() -> bool:
	if tap_jump_override >= 0:
		return tap_jump_override == 1
	if is_inside_tree():
		var s: Node = get_node_or_null("/root/Settings")
		if s != null and s.has_method("tap_jump_enabled"):
			return s.tap_jump_enabled(player)
	return true


## 0 = geen sprong-input, 1 = knop (nieuw ingedrukt), 2 = tap jump (stick omhoog-flick, nog niet gebruikt).
func jump_source() -> int:
	if input.pressed(InputFrame.BTN_JUMP):
		return 1
	if tap_jump_enabled() \
			and input.flick_y(MeleeStick.TAP_JUMP_THRESHOLD, MeleeStick.TAP_JUMP_WINDOW) == 1 \
			and _y_excursion() != _consumed_tap_jump:
		return 2
	return 0


## Markeer de huidige stick-omhoog-beweging als gebruikt (één flick = één sprong).
func consume_tap_jump() -> void:
	_consumed_tap_jump = _y_excursion()


func _y_excursion() -> int:
	return tick_count - input.stick_timer_y()


# =============================================================================================
# Interrupt-checks (Melee ftCo_*_CheckInput). Geven true als er van state gewisseld is.
# =============================================================================================

## Volledige lijst van Wait (en states die "actionable" zijn zoals Wait).
func check_wait_interrupts() -> bool:
	return check_ground_jump() or check_dash() or check_squat() or check_turn() or check_walk()


func check_ground_jump() -> bool:
	var src: int = jump_source()
	if src == 0:
		return false
	if src == 2:
		consume_tap_jump()
	change_state("KneeBend", {"tap": src == 2})
	return true


## Dash-flick vooruit -> Dash; achteruit -> smash-turn (die op het volgende frame een dash wordt).
func check_dash() -> bool:
	var d: int = input.flick_x(MeleeStick.SMASH_THRESHOLD, MeleeStick.SMASH_WINDOW)
	if d == 0:
		return false
	if d == facing:
		change_state("Dash")
	else:
		change_state("Turn", {"smash": true})
	return true


func check_squat() -> bool:
	if stick_y() <= -MeleeStick.CROUCH_THRESHOLD + EPS:
		change_state("Squat")
		return true
	return false


func check_turn() -> bool:
	var sx: float = stick_x()
	if sx * facing < 0.0 and MeleeStick.reaches(sx, MeleeStick.TURN_THRESHOLD):
		change_state("Turn", {"smash": false})
		return true
	return false


func check_walk() -> bool:
	if stick_x() * facing > 0.0:
		change_state("Walk")
		return true
	return false


## Lucht: air dodge (digitale L/R) en double jump.
func check_air_interrupts() -> bool:
	if input.pressed(InputFrame.BTN_SHIELD):
		change_state("EscapeAir")
		return true
	if air_jumps_used < stats.air_jumps:
		var src: int = jump_source()
		if src != 0:
			if src == 2:
				consume_tap_jump()
			change_state("JumpAerial")
			return true
	return false


## Platform drop: op een platform + stick-omlaag-flick binnen het venster.
func check_platform_drop() -> bool:
	if not grounded or not _is_platform(ground_seg):
		return false
	if input.flick_y(MeleeStick.PLATFORM_DROP_THRESHOLD, MeleeStick.PLATFORM_DROP_WINDOW) != -1:
		return false
	ignore_platform = ground_seg
	# ⚠️ Melee zet vy = x46C (onbekend); wij beginnen op 0 en laten gravity het werk doen.
	leave_ground(Vector2(gr_vel, 0.0))
	change_state("Fall")
	return true


# =============================================================================================
# Physics-helpers (Melee-formules, zie docs/movement.md)
# =============================================================================================

## Deaccel: traction richting 0; ×2 boven walk speed (friction_when_above_walk_speed = 2.0).
func apply_ground_friction(double_above_walk: bool = true) -> void:
	var fr: float = stats.traction
	if double_above_walk and absf(gr_vel) > stats.walk_max_velocity:
		fr *= 2.0
	gr_vel = move_toward(gr_vel, 0.0, fr)


## Dash/run (CalcGroundAccel_DashRun): accel = sx*additional + sign*base, target = sx*run_speed.
## Boven target (of stick neutraal): met traction terug naar target, zonder erdoorheen te schieten.
func apply_dash_run_accel(sx: float) -> void:
	var target: float = sx * stats.run_speed
	if sx == 0.0 or (target > 0.0 and gr_vel > target) or (target < 0.0 and gr_vel < target):
		gr_vel = move_toward(gr_vel, target, stats.traction)
	else:
		var accel: float = sx * stats.dash_accel_additional + signf(sx) * stats.dash_accel_base
		gr_vel += accel
		if (accel > 0.0 and gr_vel > target) or (accel < 0.0 and gr_vel < target):
			gr_vel = target
	gr_vel = clampf(gr_vel, -stats.ground_max_horizontal_velocity, stats.ground_max_horizontal_velocity)


## ⚠️ Walk: versnel met walk_acceleration richting sx*walk_max; sneller dan dat -> traction.
func apply_walk(sx: float) -> void:
	var target: float = sx * stats.walk_max_velocity
	if (target > 0.0 and gr_vel > target) or (target < 0.0 and gr_vel < target):
		gr_vel = move_toward(gr_vel, target, stats.traction)
	else:
		gr_vel = move_toward(gr_vel, target, stats.walk_acceleration)


## Air drift (CalcSelfAccel_AccelToVelClamped): stick stuurt naar sx*max_air_speed;
## boven die target of zonder stick: air_friction.
func apply_air_drift(sx: float, mobility: float = 1.0) -> void:
	var max_speed: float = stats.max_air_speed * mobility
	var vx: float = vel.x
	if sx != 0.0:
		var target: float = sx * max_speed
		if (target > 0.0 and vx > target) or (target < 0.0 and vx < target):
			vx = move_toward(vx, target, stats.air_friction)
		else:
			var accel: float = (sx * stats.air_accel_additional + signf(sx) * stats.air_accel_base) * mobility
			vx += accel
			if (accel > 0.0 and vx > target) or (accel < 0.0 and vx < target):
				vx = target
	else:
		vx = move_toward(vx, 0.0, stats.air_friction)
	vel.x = clampf(vx, -stats.air_max_horizontal_velocity, stats.air_max_horizontal_velocity)


## Verticaal in de lucht: fast-fall-check (alleen na de apex, vy < 0), dan gravity / fast fall.
func apply_air_vertical(allow_fastfall: bool = true) -> void:
	if allow_fastfall and not fastfalling and vel.y < 0.0 \
			and input.flick_y(MeleeStick.FAST_FALL_THRESHOLD, MeleeStick.FAST_FALL_WINDOW) == -1:
		fastfalling = true
	if fastfalling:
		vel.y = -stats.fast_fall_velocity
	else:
		vel.y = maxf(vel.y - stats.gravity, -stats.terminal_velocity)


## Standaard lucht-physics (Fall, Jump, JumpAerial).
func apply_air_physics(mobility: float = 1.0) -> void:
	apply_air_vertical()
	apply_air_drift(stick_x(), mobility)


# =============================================================================================
# Grond / lucht-overgangen
# =============================================================================================

## Van de grond af met gegeven luchtsnelheid. Luchtsprongen weer beschikbaar (grondsprong telt niet).
func leave_ground(air_vel: Vector2) -> void:
	grounded = false
	ground_seg = -1
	vel = air_vel
	air_jumps_used = 0
	fastfalling = false


## Grondsprong (einde KneeBend). vx = gr_vel*g2a + sx*h_initial, begrensd op ±h_max.
func ground_jump(short_hop: bool) -> void:
	var vx: float = gr_vel * stats.ground_to_air_jump_momentum_multiplier + stick_x() * stats.jump_h_initial_velocity
	vx = clampf(vx, -stats.jump_h_max_velocity, stats.jump_h_max_velocity)
	var vy: float = stats.hop_v_initial_velocity if short_hop else stats.jump_v_initial_velocity
	leave_ground(Vector2(vx, vy))


func _set_grounded(seg: int, x: float) -> void:
	grounded = true
	ground_seg = seg
	pos = Vector2(x, _seg_y(_segments[seg], x))


## Landen: gr_vel = vx (begrensd), verticale snelheid vervalt, sprongen terug.
func _land(seg: int, x: float) -> void:
	_set_grounded(seg, x)
	gr_vel = clampf(vel.x, -stats.ground_max_horizontal_velocity, stats.ground_max_horizontal_velocity)
	vel = Vector2.ZERO
	air_jumps_used = 0
	fastfalling = false
	ignore_platform = -1
	state.on_land()


# =============================================================================================
# Collision (alleen detectie; eigen respons)
# =============================================================================================

## Grond-coll: schuif langs het segment met gr_vel; aan de rand stoppen of eraf vallen (per state).
func ground_coll() -> void:
	if ground_seg < 0 or ground_seg >= _segments.size():
		leave_ground(Vector2(gr_vel, 0.0))
		change_state("Fall")
		return
	var nx: float = pos.x + gr_vel
	var seg: int = ground_seg
	var guard: int = 0
	while guard < 8:
		guard += 1
		var s: Dictionary = _segments[seg]
		var side: int = 0
		if nx < s["a"].x - EPS:
			side = -1
		elif nx > s["b"].x + EPS:
			side = 1
		if side == 0:
			_set_grounded(seg, nx)
			return
		var edge: Vector2 = s["a"] if side < 0 else s["b"]
		var next: int = _connected_segment(seg, edge, side)
		if next >= 0:
			seg = next
			continue
		if state.stops_at_edge():
			gr_vel = 0.0
			_set_grounded(seg, edge.x)
		else:
			pos = Vector2(nx, edge.y)
			leave_ground(Vector2(gr_vel, 0.0))
			change_state("Fall")
		return


## Lucht-coll: verplaats met vel; land als de ECB-onderkant een segment van boven kruist (alleen vy <= 0).
func air_coll() -> void:
	var from: Vector2 = pos
	var to: Vector2 = pos + vel
	pos = to
	if vel.y > 0.0:
		return
	var best: int = -1
	var best_y: float = -INF
	for i in _segments.size():
		var s: Dictionary = _segments[i]
		if s["platform"] and (i == ignore_platform or not state.lands_on_platforms()):
			continue
		if to.x < s["a"].x - EPS or to.x > s["b"].x + EPS:
			continue
		var y_to: float = _seg_y(s, to.x)
		var y_from: float = _seg_y(s, from.x)
		if from.y >= y_from - 0.01 and to.y <= y_to and y_to > best_y:
			best = i
			best_y = y_to
	if best >= 0:
		_land(best, clampf(to.x, _segments[best]["a"].x, _segments[best]["b"].x))


func _post_coll() -> void:
	if ignore_platform >= 0:
		if ignore_platform >= _segments.size() or grounded \
				or pos.y < _seg_y(_segments[ignore_platform], pos.x) - PLATFORM_CLEAR_DIST:
			ignore_platform = -1
	if stage != null and stage.has_method("get_blast_zone"):
		var bz: Rect2 = stage.get_blast_zone()
		if bz.size != Vector2.ZERO and not bz.has_point(pos):
			respawn()


# --- segmenten ---

func _read_segments() -> Array:
	var out: Array = []
	if stage == null or not stage.has_method("get_ground_segments"):
		return out
	for raw: Variant in stage.get_ground_segments():
		var n: Dictionary = normalize_segment(raw)
		if not n.is_empty():
			out.append(n)
	return out


## Zet een stage-segment (StageSegment-Resource, Object of Dictionary) om naar {a, b, platform}, a.x <= b.x.
static func normalize_segment(raw: Variant) -> Dictionary:
	var a: Variant = null
	var b: Variant = null
	var t: Variant = SEG_SOLID
	if raw is Dictionary:
		a = raw.get("a")
		b = raw.get("b")
		t = raw.get("type", SEG_SOLID)
	elif raw is Object:
		a = raw.get("a")
		b = raw.get("b")
		var tt: Variant = raw.get("type")
		t = tt if tt != null else SEG_SOLID
	if not (a is Vector2) or not (b is Vector2):
		return {}
	var platform: bool = false
	if t is int:
		platform = t == SEG_PLATFORM
	elif t is String or t is StringName:
		platform = String(t).to_lower() == "platform"
	var pa: Vector2 = a
	var pb: Vector2 = b
	if pa.x > pb.x:
		var tmp: Vector2 = pa
		pa = pb
		pb = tmp
	return {"a": pa, "b": pb, "platform": platform}


func _seg_y(s: Dictionary, x: float) -> float:
	var a: Vector2 = s["a"]
	var b: Vector2 = s["b"]
	if absf(b.x - a.x) < EPS:
		return maxf(a.y, b.y)
	return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))


func _is_platform(seg: int) -> bool:
	return seg >= 0 and seg < _segments.size() and _segments[seg]["platform"]


## Segment dat aan `edge` vastzit en verder loopt in richting `side`.
func _connected_segment(seg: int, edge: Vector2, side: int) -> int:
	for i in _segments.size():
		if i == seg:
			continue
		var s: Dictionary = _segments[i]
		var start: Vector2 = s["a"] if side > 0 else s["b"]
		if start.distance_to(edge) < 0.01:
			return i
	return -1


func _segment_at(p: Vector2, tol: float) -> int:
	for i in _segments.size():
		var s: Dictionary = _segments[i]
		if p.x >= s["a"].x - EPS and p.x <= s["b"].x + EPS and absf(p.y - _seg_y(s, p.x)) <= tol:
			return i
	return -1


# =============================================================================================
# Presentatie en debug
# =============================================================================================

func _update_visual() -> void:
	position = Units.to_px(pos)
	if visual != null and state != null:
		visual.facing = facing
		visual.play(state.pose(), false)
		visual.tick(state.pose_frame(), state.pose_speed())
	if is_inside_tree():
		queue_redraw()


func _draw() -> void:
	var sim: Node = get_node_or_null("/root/Sim")
	if sim == null or not sim.debug_hitboxes or stats == null:
		return
	# ECB-diamant (presentatie in px, t.o.v. de voeten)
	var k: float = Units.UNIT_TO_PX
	var pts := PackedVector2Array([
		Vector2(0, 0), Vector2(stats.ecb_half_width * k, -stats.ecb_mid_y * k),
		Vector2(0, -stats.ecb_height * k), Vector2(-stats.ecb_half_width * k, -stats.ecb_mid_y * k), Vector2(0, 0)])
	draw_polyline(pts, Color(1.0, 0.55, 0.1, 0.9), 2.0)
	draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 0.2))


## Hook voor de debug overlay.
func get_debug_state_name() -> String:
	var s: String = "%s  %s f%d  pos(%.2f, %.2f)" % [
		stats.display_name if stats != null else "?", state.debug_name() if state != null else "-",
		state_frame, pos.x, pos.y]
	if grounded:
		s += "  gr_vel %.3f" % gr_vel
	else:
		s += "  vel(%.3f, %.3f)" % [vel.x, vel.y]
	s += "  jumps %d/%d" % [stats.air_jumps - air_jumps_used, stats.air_jumps]
	if fastfalling:
		s += "  FF"
	if state != null and state.intangible():
		s += "  INTANGIBLE"
	return s


## Momentopname voor tests/determinisme.
func snapshot() -> Array:
	return [state_name(), state_frame, pos, vel, gr_vel, facing, grounded, air_jumps_used, fastfalling]
