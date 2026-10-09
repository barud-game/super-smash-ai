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
## Uitgezonden op het frame dat de fighter de blast zone verlaat. side ∈ &"left", &"right", &"top", &"bottom".
signal blast_ko(fighter: Fighter, side: StringName)
signal percent_changed(new_percent: float)
signal ledge_grabbed(side: int)

const EPS: float = 0.0001
## Afstand onder een genegeerd platform waarna het weer meetelt (platform drop).
const PLATFORM_CLEAR_DIST: float = 0.5
const DEFAULT_RESPAWN := Vector2(0.0, 60.0)
const SEG_SOLID: int = 0
const SEG_PLATFORM: int = 1

@export var player: int = 0
@export var stats: FighterStats
@export var character_id: String = "_dummy"
## Archetype van de moveset (engine/fighter/archetypes/<id>/moves). "" = afleiden uit de stats-preset,
## dan uit characters/<id>/character.json, anders "allrounder". Zie reload_moves().
@export var archetype_id: String = ""
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

## true = bij een blast-zone-KO zet de fighter zichzelf direct op het respawn-platform (sandbox-gedrag).
## false = hij zet zichzelf op `active = false` (verborgen, geen ticks) en wacht op `respawn_at()`.
var auto_respawn: bool = true
## false = uit de match (na KO met auto_respawn = false); sim_tick doet dan niets.
var active: bool = true
## Schadepercentage. Alleen via de setter gewijzigd (combat volgt in M3).
var percent: float = 0.0:
	set = set_percent
## Resterende intangible frames (ledge-grab, respawn). Leesbaar na elke tick; zie is_intangible().
var intangible_frames: int = 0
## Vanaf dit percentage gelden de "slow" ledge-getups en de korte max-hangtijd (Melee: 100%).
@export var ledge_high_percent: float = 100.0

# --- Ledge-toestand ---
## Sleutel van de bezette ledge ("" = niet aan een ledge); zie check_ledge_grab().
var ledge_key: String = ""
## Laatst gegrepen ledge (blijft staan na loslaten; getup-states gebruiken hem).
var ledge_pos: Vector2 = Vector2.ZERO
var ledge_side: int = 1
## Frames sinds de grab (alleen geldig terwijl ledge_key != "").
var ledge_hang_frames: int = 0
## Frames dat een nieuwe ledge grab nog geblokkeerd is.
var ledge_cooldown_frames: int = 0

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

# --- Gevecht (M3, docs/combat.md "M3-integratie") ---
## Move-naam -> MoveData (archetype + character-overrides + ingebouwd). Zie reload_moves().
var moves: Dictionary = {}
## Knockback-snelheid (apart van vel, zoals Melee): telt op bij de positie, neemt 0.051/frame af.
var kb_vel: Vector2 = Vector2.ZERO
## Resterende hitlag-frames (freeze). hitlag_victim = geraakt (SDI/ASDI/DI), anders aanvaller (hitfall).
var hitlag_frames: int = 0
var hitlag_victim: bool = false
## Sterkte van de hitlag-jitter op de sprite (px).
var hitlag_strength: float = 0.0
## Hitfall: in de hitlag van een eigen treffer (niet shield/clank) mag een omlaag-flick fast fall zetten.
var hitfall_allowed: bool = false
## Wachtende launch van het slachtoffer; wordt bij het einde van de hitlag (na DI/ASDI) toegepast.
var pending_kb: KnockbackResult = null
## Teller per gestarte aanval (HitResolver: owner+instance+group+target = al geraakt).
var move_instance: int = 0
var already_hit: Dictionary = {}
## Na een clank/rebound raakt de huidige move-instantie niets meer.
var hitboxes_off: bool = false
## Hitboxes van het laatste frame (voor de F2-weergave).
var last_hitboxes: Array[ActiveHitbox] = []
## Speler-index van de laatste aanvaller (-1 = niemand).
var last_hit_by: int = -1
## Optioneel: VfxLayer voor effecten. Leeg = eerste node in groep "vfx_layer".
var vfx: Node = null

# --- Verdediging (M4, docs/combat.md "M4-implementatie") ---
## Shield-HP (0..60). Slijt in GuardOn/Guard, herstelt daarbuiten; <= 0 = shield break.
var shield_hp: float = FighterConst.SHIELD_MAX_HP
## UCF shield drop: ook een schuine omlaag-flick (|x| >= UCF_SHIELD_DROP_MIN_X) zakt door een platform.
@export var ucf_shield_drop: bool = true
## Grab: de andere kant van de grab (holder <-> victim), anders null. Alleen geldig in de grab-familie-states.
var grab_partner: Fighter = null
## Holder: afstand (units, vooruit) van de voeten van de holder tot de voeten van de victim.
var grab_hold_dx: float = 0.0
## Victim: frames tot hij loskomt (mashen trekt eraf); in de lucht gegrepen = lucht-release.
var grab_timer: int = 0
var grabbed_airborne: bool = false
## Specials (B): de special-toolkit zet deze hook: Callable(fighter: Fighter, input: Dictionary) -> bool. Zie check_special().
var special_hook: Callable = Callable()
## SDI/ASDI in de huidige hitlag toegestaan (niet bij throws en pummels).
var _sdi_allowed: bool = true
## tick_count van de laatste digitale shield-klik (powershield).
var _ps_tick: int = -1000
## Grab-acties van deze frame (zie queue_pummel/queue_throw).
var _pending_pummel: bool = false
var _pending_throw: HitboxData = null
var _pending_throw_set: bool = false
var _shield_node: Node2D = null

var _states: Dictionary = {}
## Teller van state-wissels (visual: dezelfde pose opnieuw starten bij een nieuwe aanval).
var _serial: int = 0
var _vis_key: String = ""
var _debug_node: Node2D = null
## tick_count van de laatste L-cancel-druk (L/R/Z of analoge trigger) en van de laatste tech-druk.
var _lc_tick: int = -1000
var _tech_tick: int = -1000
var _prev_trigger: float = 0.0
## tick_count waarop deze fighter het laatst geraakt werd (trades: slachtoffer wint van aanvaller).
var _victim_tick: int = -1000
var _segments: Array = []
var _ledges: Array = []
var _consumed_tap_jump: int = -1000
## tick_count van de laatste omlaag-flick in de lucht (fast-fall-buffer).
var _ff_flick_tick: int = -1000


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
		# Herladen poses (hot reload) -> greeppunt aan de ledge opnieuw uit het rig berekenen.
		visual.reloaded.connect(func() -> void: LedgeGrip.clear_cache(character_id))
		add_child(visual)
	if use_visual and _debug_node == null:
		# Debug-tekenlaag (F2) boven de visual.
		_debug_node = Node2D.new()
		_debug_node.name = "CombatDebug"
		_debug_node.z_index = 100
		_debug_node.draw.connect(_draw_debug)
		add_child(_debug_node)
	if use_visual and _shield_node == null:
		# Shield-bubble (spelerskleur, krimpt met de HP) boven de visual, onder de debug-laag.
		_shield_node = Node2D.new()
		_shield_node.name = "ShieldBubble"
		_shield_node.z_index = 50
		_shield_node.draw.connect(_draw_shield)
		add_child(_shield_node)
	if moves.is_empty():
		reload_moves()
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
		StateTeeter.new(), StateCliffCatch.new(), StateCliffWait.new(), StateCliffClimb.new(),
		StateCliffEscape.new(), StateCliffAttack.new(), StateCliffJump.new(), StateRebirthWait.new(),
		StateDead.new(),
		StateAttack.new(), StateAttackAir.new(), StateDamage.new(), StateDamageFly.new(), StateDamageFall.new(),
		StateTech.new(), StateDownBound.new(), StateDownWait.new(), StateDownGetup.new(), StateRebound.new(),
		StateGuardOn.new(), StateGuard.new(), StateGuardSetOff.new(), StateGuardOff.new(),
		StateShieldBreak.new(), StateShieldBreakDown.new(), StateDizzy.new(), StateEscape.new(), StateEscapeN.new(),
		StateGrab.new(), StateGrabHold.new(), StatePummel.new(), StateThrow.new(), StateGrabbed.new(),
		StateThrown.new(), StateGrabRelease.new(),
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
	# Een state die de ledge niet vasthoudt geeft hem vrij (ook bij spawn/KO/ledge-steal).
	if ledge_key != "" and not next.holds_ledge():
		_free_ledge_slot()
	# Een state buiten de grab-familie verbreekt de grab (geraakt, KO, ...); de partner gaat naar zijn release-state.
	if grab_partner != null and not next.keeps_grab():
		_drop_grab()
	prev_state_name = old
	state = next
	state_frame = 0
	_serial += 1
	next.enter(args)
	state_changed.emit(old, id)
	_state_fx(old, id)


func state_name() -> String:
	return state.id() if state != null else ""


## Eén sim-frame. Aangeroepen door Sim (of direct door tests).
func sim_tick(_frame: int = 0) -> void:
	if not active:
		return
	tick_count += 1
	_track_presses()
	if hitlag_frames > 0:
		# Hitlag-freeze: geen beweging, state_frame en timers staan stil. Wel SDI/ASDI/DI of hitfall.
		_hitlag_tick()
		_update_visual()
		return
	if intangible_frames > 0:
		intangible_frames -= 1
	if ledge_cooldown_frames > 0:
		ledge_cooldown_frames -= 1
	if ledge_key != "":
		ledge_hang_frames += 1
	if not state.is_shielding():
		shield_hp = minf(shield_hp + FighterConst.SHIELD_REGEN, FighterConst.SHIELD_MAX_HP)
	_segments = _read_segments()
	_ledges = _read_ledges()
	state_frame += 1
	state.anim()
	state.iasa()
	state.phys()
	state.coll()
	if kb_vel != Vector2.ZERO:
		kb_vel = Knockback.decay_step(kb_vel)
	if not grounded and state.can_grab_ledge():
		check_ledge_grab()
	_post_coll()
	_update_visual()


## Plaats de fighter. Staat hij (bijna) op een segment, dan op de grond in Wait, anders Fall.
func spawn(at: Vector2, dir: int = 1) -> void:
	_segments = _read_segments()
	_ledges = _read_ledges()
	active = true
	visible = true
	pos = at
	vel = Vector2.ZERO
	gr_vel = 0.0
	facing = 1 if dir >= 0 else -1
	fastfalling = false
	air_jumps_used = 0
	ignore_platform = -1
	reset_combat()
	intangible_frames = 0
	ledge_cooldown_frames = 0
	shield_hp = FighterConst.SHIELD_MAX_HP
	var seg: int = _segment_at(at, 0.01)
	if seg >= 0:
		_set_grounded(seg, at.x)
		change_state("Wait")
	else:
		grounded = false
		ground_seg = -1
		change_state("Fall")


## Respawn op het stage-respawnpunt met de standaard Melee-invincibility (zie respawn_at).
func respawn() -> void:
	var at: Vector2 = DEFAULT_RESPAWN
	if stage != null and stage.has_method("get_respawn"):
		at = stage.get_respawn(player)
	respawn_at(at, FighterConst.REBIRTH_INVINCIBLE_FRAMES)


## Zet de fighter op `p` in RebirthWait (stilstaan op een respawn-platform tot input, max ~5 s, daarna vallen)
## met `invincible_frames` intangible frames (tellen af in alle volgende states). Maakt hem weer `active`.
func respawn_at(p: Vector2, invincible_frames: int) -> void:
	_segments = _read_segments()
	_ledges = _read_ledges()
	active = true
	visible = true
	pos = p
	vel = Vector2.ZERO
	gr_vel = 0.0
	grounded = false
	ground_seg = -1
	fastfalling = false
	air_jumps_used = 0
	ignore_platform = -1
	reset_combat()
	ledge_cooldown_frames = 0
	shield_hp = FighterConst.SHIELD_MAX_HP
	if absf(p.x) > 1.0:
		facing = -1 if p.x > 0.0 else 1
	reset_fast_fall_buffer()
	change_state("RebirthWait")
	intangible_frames = maxi(invincible_frames, 0)
	_sfx("respawn")
	_update_visual()


func set_percent(v: float) -> void:
	v = maxf(v, 0.0)
	if is_equal_approx(v, percent):
		return
	percent = v
	percent_changed.emit(v)


## Intangible door de ledge/respawn-teller of door de huidige state (air dodge, getups). Combat gebruikt dit.
func is_intangible() -> bool:
	return intangible_frames > 0 or (state != null and state.intangible())


func _sfx(sfx_name: String) -> void:
	if not is_inside_tree():
		return
	var s: Node = get_node_or_null("/root/Sfx")
	if s != null and s.has_method("play"):
		s.play(sfx_name, 0.03, 0.0, character_id)


func set_stats(s: FighterStats) -> void:
	stats = s
	reload_moves()


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
## Volgorde: special, grab, aanval (check_ground_attack), shield, sprong, dash, squat, turn, walk.
func check_wait_interrupts() -> bool:
	return check_ground_attack() or check_guard() or check_ground_jump() or check_dash() or check_squat() \
		or check_turn() or check_walk()


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
	var d: int = input.flick_x(MeleeStick.SMASH_THRESHOLD, MeleeStick.DASH_FLICK_WINDOW)
	if d == 0:
		return false
	if d == facing:
		change_state("Dash")
	else:
		change_state("Turn", {"smash": true})
	return true


## Wil de speler tijdens een run/skid omdraaien? Een flick tegen de run in, of een tegen-duw die RUN_TURN_DEBOUNCE
## frames wordt vastgehouden. Een korte terugveer-overshoot van de stick telt niet. ⚠️ leniency
func run_turn_intent() -> bool:
	var sx: float = stick_x()
	if sx * facing >= 0.0 or not MeleeStick.reaches(sx, MeleeStick.TURN_THRESHOLD):
		return false
	return MeleeStick.reaches(sx, MeleeStick.SMASH_THRESHOLD) \
		or input.stick_timer_x() >= MeleeStick.RUN_TURN_DEBOUNCE - 1


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
# Teeter en ledge (M2). Zie docs/movement.md, "M2-implementatie".
# =============================================================================================

## -1/+1 als de fighter op de grond precies aan een losse rand (links/rechts) van zijn segment staat, anders 0.
func edge_side() -> int:
	if not grounded or ground_seg < 0 or ground_seg >= _segments.size():
		return 0
	var s: Dictionary = _segments[ground_seg]
	if pos.x >= s["b"].x - 0.01 and _connected_segment(ground_seg, s["b"], 1) < 0:
		return 1
	if pos.x <= s["a"].x + 0.01 and _connected_segment(ground_seg, s["a"], -1) < 0:
		return -1
	return 0


## Wait -> Teeter als de fighter naar de rand kijkt waar hij op staat.
func check_teeter() -> bool:
	var e: int = edge_side()
	if e != 0 and e == facing:
		change_state("Teeter")
		return true
	return false


func ledge_high() -> bool:
	return percent >= ledge_high_percent


## Ledge-hoek t.o.v. de voeten tijdens het hangen, in units: x = vooruit (richting de stage), y = omhoog.
## Uit het rig berekend (LedgeGrip: handpalmen in de cliff_wait-pose) en geschaald met visual_height,
## zodat de handen bij elke lengte en bouw precies op de hoek liggen.
func ledge_grip() -> Vector2:
	var g: Vector2 = LedgeGrip.grip_px(character_id)
	var k: float = stats.visual_height / Rig.STAND_HEIGHT_PX
	return Vector2(g.x * k, -g.y * k)


## Hang-positie (voeten) bij de ledge `lpos` aan zijde `side` (kijkrichting = -side, naar de stage).
func ledge_hang_pos(lpos: Vector2, side: int) -> Vector2:
	var g: Vector2 = ledge_grip()
	return Vector2(lpos.x + side * g.x, lpos.y - g.y)


func _ledge_registry() -> Dictionary:
	if stage == null:
		return {}
	if not stage.has_meta("ledge_occupants"):
		stage.set_meta("ledge_occupants", {})
	return stage.get_meta("ledge_occupants")


static func _ledge_key(lpos: Vector2, side: int) -> String:
	return "%d:%d:%d" % [roundi(lpos.x * 100.0), roundi(lpos.y * 100.0), side]


## Bezet een andere (actieve, nog hangende) fighter deze ledge?
func ledge_occupied_by_other(lpos: Vector2, side: int) -> bool:
	var key: String = _ledge_key(lpos, side)
	var occ: Variant = _ledge_registry().get(key)
	return occ is Fighter and is_instance_valid(occ) and occ != self and occ.ledge_key == key


## Ledge grab (Melee: ftCliffCommon_80081298). Voorwaarden: luchtstate die grabben toestaat, dalend, geen lock,
## stick niet omlaag, kijkrichting naar de stage, ledge in de grab-box (× visual_height) en niet bezet
## (geen ledge-steal in Melee). Geeft true bij een grab.
func check_ledge_grab() -> bool:
	if ledge_cooldown_frames > 0 or ledge_key != "" or vel.y + kb_vel.y >= 0.0:
		return false
	if stick_y() <= -FighterConst.LEDGE_GRAB_DOWN_BLOCK + FighterConst.EPS:
		return false
	var front: float = stats.ledge_grab_front()
	var back: float = stats.ledge_grab_back()
	var y_min: float = stats.ledge_grab_y_min()
	var y_max: float = stats.ledge_grab_y_max()
	for l: Dictionary in _ledges:
		var side: int = l["side"]
		if facing != -side:
			continue
		var lp: Vector2 = l["pos"]
		var outward: float = (pos.x - lp.x) * side   # >= 0: fighter staat buiten de rand
		var above: float = lp.y - pos.y               # hoogte van de ledge boven de voeten
		if outward < -back or outward > front:
			continue
		if above < y_min or above > y_max:
			continue
		if ledge_occupied_by_other(lp, side):
			continue
		grab_ledge(lp, side)
		return true
	return false


## Hang aan de ledge: snap (handen op de hoek), jumps terug, knockback weg, intangibility (elke catch, max-regel).
func grab_ledge(lp: Vector2, side: int) -> void:
	var key: String = _ledge_key(lp, side)
	ledge_key = key
	ledge_pos = lp
	ledge_side = side
	ledge_hang_frames = 0
	_ledge_registry()[key] = self
	pos = ledge_hang_pos(lp, side)
	vel = Vector2.ZERO
	kb_vel = Vector2.ZERO
	gr_vel = 0.0
	grounded = false
	ground_seg = -1
	fastfalling = false
	air_jumps_used = 0
	reset_fast_fall_buffer()
	facing = -side
	intangible_frames = maxi(intangible_frames, stats.ledge_catch_frames + stats.ledge_grab_intangible)
	change_state("CliffCatch")
	ledge_grabbed.emit(side)
	_sfx("ledge_grab")


## Laat de ledge los: slot vrij + lock. De aanroeper wisselt zelf van state.
func release_ledge(cooldown: int) -> void:
	_free_ledge_slot()
	ledge_cooldown_frames = maxi(ledge_cooldown_frames, cooldown)


func _free_ledge_slot() -> void:
	if ledge_key == "":
		return
	var reg: Dictionary = _ledge_registry()
	if reg.get(ledge_key) == self:
		reg.erase(ledge_key)
	ledge_key = ""


## Loslaten (stick weg/omlaag, max hangtijd): Fall met alle sprongen terug. Intangible frames lopen door.
func ledge_drop() -> void:
	release_ledge(stats.ledge_cooldown)
	vel = Vector2.ZERO
	fastfalling = false
	air_jumps_used = 0
	change_state("Fall")


## Einde van een getup/roll/attack: zet de fighter op de stage-grond op `at` en ga naar Wait.
func finish_ledge_move(at: Vector2) -> void:
	_segments = _read_segments()
	var seg: int = _segment_at(at, 0.5)
	vel = Vector2.ZERO
	if seg >= 0:
		_set_grounded(seg, at.x)
		change_state("Wait")
	else:
		pos = at
		grounded = false
		change_state("Fall")


# =============================================================================================
# Gevecht (M3). Zie docs/combat.md, "M3-integratie".
# =============================================================================================

const MAX_PERCENT: float = 999.0


## (Her)laadt de moveset: archetype + character-overrides + ingebouwde moves (MoveSet).
func reload_moves() -> void:
	moves = MoveSet.load_for(resolved_archetype(), character_id, stats)


## Archetype-id: expliciet, anders de stats-preset, anders character.json, anders "allrounder".
func resolved_archetype() -> String:
	if archetype_id != "":
		return archetype_id
	var a: String = Archetypes.id_for_stats(stats)
	if a == "":
		a = Archetypes.id_for_character(character_id)
	return a if a != "" else "allrounder"


func get_move(move_name: String) -> MoveData:
	return moves.get(move_name)


func has_move(move_name: String) -> bool:
	return moves.has(move_name)


## Nieuwe move-instantie: elk doelwit mag weer één keer (per hit-groep) geraakt worden.
func start_move() -> void:
	move_instance += 1
	already_hit.clear()
	hitboxes_off = false


func reset_combat() -> void:
	kb_vel = Vector2.ZERO
	hitlag_frames = 0
	hitlag_victim = false
	hitfall_allowed = false
	pending_kb = null
	hitboxes_off = false
	already_hit.clear()
	last_hitboxes.clear()
	_pending_pummel = false
	_pending_throw = null
	_pending_throw_set = false


# --- input --------------------------------------------------------------------------------------

## Onthoud L-cancel- en tech-drukken (ook tijdens hitlag). LT/RT (digitaal of analoog >= 0.3) en RB/Z
## tellen voor L-cancel; alleen LT/RT voor tech (met lockout).
func _track_presses() -> void:
	var fr: InputFrame = input.get_frame(0)
	var trig: float = fr.shield_analog()
	var trig_press: bool = trig >= FighterConst.TRIGGER_PRESS and _prev_trigger < FighterConst.TRIGGER_PRESS
	_prev_trigger = trig
	if input.pressed(InputFrame.BTN_SHIELD):
		_ps_tick = tick_count
	var shield_press: bool = input.pressed(InputFrame.BTN_SHIELD) or trig_press
	if shield_press or input.pressed(InputFrame.BTN_Z):
		_lc_tick = tick_count
	if shield_press and tick_count - _tech_tick >= FighterConst.TECH_LOCKOUT:
		_tech_tick = tick_count


## L-cancel-druk binnen 7 frames vóór (en op) dit frame.
func lcancel_ready() -> bool:
	return tick_count - _lc_tick < FighterConst.LCANCEL_WINDOW


## Tech-druk binnen 20 frames vóór (en op) dit frame.
func tech_ready() -> bool:
	return tick_count - _tech_tick < FighterConst.TECH_WINDOW


## Verse C-stick-input (vorige frame onder de drempel): (±1, 0) of (0, ±1) langs de dominante as, anders ZERO.
func cstick_dir() -> Vector2i:
	var c: Vector2 = input.get_frame(0).cstick_f()
	var p: Vector2 = input.get_frame(1).cstick_f()
	var th: float = FighterConst.CSTICK_THRESHOLD - FighterConst.EPS
	if maxf(absf(c.x), absf(c.y)) < th or maxf(absf(p.x), absf(p.y)) >= th:
		return Vector2i.ZERO
	if absf(c.y) > absf(c.x):
		return Vector2i(0, 1 if c.y > 0.0 else -1)
	return Vector2i(1 if c.x > 0.0 else -1, 0)


## Grab-input: Z, of A terwijl de shield (analoog) vastgehouden wordt. Start de grab (dash = dash grab uit Dash/Run).
## Geeft true als de input een grab-input was (ook als de moveset geen grab heeft: dan geen jab).
func check_grab(dash: bool = false) -> bool:
	if not (input.pressed(InputFrame.BTN_Z) or (input.pressed(InputFrame.BTN_ATTACK) and shield_held())):
		return false
	start_grab(dash)
	return true


## Special-hook (B = BTN_SPECIAL). Aangeroepen in alle grond-actionable states (via check_ground_attack,
## check_dash_attack en check_jc_usmash, dus ook up-B uit shield via jumpsquat) en lucht-actionable states (via
## check_aerial), vóór grab en aanvallen. Doet nu niets: de special-toolkit zet `special_hook`
## (Callable(fighter, special_input()) -> bool, true = er is een special gestart) of vervangt deze body.
func check_special() -> bool:
	if not input.pressed(InputFrame.BTN_SPECIAL) or not special_hook.is_valid():
		return false
	return bool(special_hook.call(self, special_input()))


## Richting van een special-input t.o.v. de kijkrichting:
##   dir: "neutral" / "side" / "up" / "down" (dominante as; up/down vanaf SPECIAL_UPDOWN_THRESHOLD, side vanaf
##        SPECIAL_SIDE_THRESHOLD ⚠️), back: stick-x tegen de kijkrichting (side-B achteruit / B-reverse), grounded.
func special_input() -> Dictionary:
	var s: Vector2 = stick()
	var dir: String = "neutral"
	if absf(s.y) >= absf(s.x) and MeleeStick.reaches(s.y, FighterConst.SPECIAL_UPDOWN_THRESHOLD):
		dir = "up" if s.y > 0.0 else "down"
	elif MeleeStick.reaches(s.x, FighterConst.SPECIAL_SIDE_THRESHOLD):
		dir = "side"
	var back: bool = s.x * facing < 0.0 and MeleeStick.reaches(s.x, MeleeStick.TURN_THRESHOLD)
	return {"dir": dir, "back": back, "grounded": grounded}


## Grond-aanval zoals Melee: C-stick = smash; A + flick (teller < SMASH_ATTACK_WINDOW) = smash;
## A + stick = tilt (dominante as); A neutraal = jab. Smash/ftilt naar achteren draaien de fighter om.
## Eerst special en grab.
func check_ground_attack() -> bool:
	if check_special() or check_grab():
		return true
	var c: Vector2i = cstick_dir()
	if c != Vector2i.ZERO:
		return _start_smash(c, false)
	if not input.pressed(InputFrame.BTN_ATTACK):
		return false
	var fx: int = input.flick_x(MeleeStick.SMASH_THRESHOLD, FighterConst.SMASH_ATTACK_WINDOW)
	var fy: int = input.flick_y(MeleeStick.SMASH_THRESHOLD, FighterConst.SMASH_ATTACK_WINDOW)
	var s: Vector2 = stick()
	if fy != 0 and (fx == 0 or absf(s.y) >= absf(s.x)):
		return _start_smash(Vector2i(0, fy), true)
	if fx != 0:
		return _start_smash(Vector2i(fx, 0), true)
	if s == Vector2.ZERO:
		return start_attack("jab")
	if absf(s.y) > absf(s.x):
		return start_attack("utilt" if s.y > 0.0 else "dtilt")
	return start_attack("ftilt", {"facing": 1 if s.x > 0.0 else -1})


func _start_smash(dir: Vector2i, with_a: bool) -> bool:
	if dir.y > 0:
		return start_attack("usmash", {"charge": with_a})
	if dir.y < 0:
		return start_attack("dsmash", {"charge": with_a})
	return start_attack("fsmash", {"charge": with_a, "facing": dir.x})


## Dash/Run: A of C-stick = dash attack. In de initial dash ook usmash (A + omhoog-flick of C-stick omhoog). ⚠️
func check_dash_attack(allow_usmash: bool) -> bool:
	if check_special() or check_grab(true):
		return true
	var c: Vector2i = cstick_dir()
	var a: bool = input.pressed(InputFrame.BTN_ATTACK)
	if allow_usmash and (c.y > 0 \
			or (a and input.flick_y(MeleeStick.SMASH_THRESHOLD, FighterConst.SMASH_ATTACK_WINDOW) == 1)):
		return start_attack("usmash", {"charge": a})
	if a or c != Vector2i.ZERO:
		return start_attack("dash_attack")
	return false


## Jumpsquat: A + stick omhoog (of C-stick omhoog) = jump-cancelled usmash (de sprong vervalt). Ook special
## (up-B uit shield) en JC grab (staande grab; na usmash, zodat shield vast + A + omhoog een OoS-usmash blijft).
func check_jc_usmash() -> bool:
	if check_special():
		return true
	var a: bool = input.pressed(InputFrame.BTN_ATTACK)
	if cstick_dir().y > 0 or (a and stick_y() >= FighterConst.JC_USMASH_THRESHOLD - FighterConst.EPS):
		return start_attack("usmash", {"charge": a})
	return check_grab()


## Aerial: C-stick of A + stick (dominante as, t.o.v. facing): nair / fair / bair / uair / dair.
func check_aerial() -> bool:
	if check_special():
		return true
	var c: Vector2i = cstick_dir()
	var d: Vector2
	if c != Vector2i.ZERO:
		d = Vector2(c)
	elif input.pressed(InputFrame.BTN_ATTACK):
		d = stick()
	else:
		return false
	var n: String = "nair"
	if d != Vector2.ZERO:
		if absf(d.y) > absf(d.x):
			n = "uair" if d.y > 0.0 else "dair"
		else:
			n = "fair" if d.x * facing > 0.0 else "bair"
	return start_attack(n)


## Start een aanval (grond: Attack, lucht: AttackAir). args: facing, charge. false als de move niet bestaat.
func start_attack(move_name: String, args: Dictionary = {}) -> bool:
	var m: MoveData = moves.get(move_name)
	if m == null:
		return false
	var a: Dictionary = args.duplicate()
	a["move"] = move_name
	change_state("Attack" if grounded else "AttackAir", a)
	return true


# --- hitboxes / hurtboxes -----------------------------------------------------------------------

## Hitboxes van dit frame (leeg tijdens hitlag, na een clank, of buiten de match).
func active_hitboxes() -> Array[ActiveHitbox]:
	if not active or hitlag_frames > 0 or hitboxes_off or state == null:
		return []
	return state.hitboxes()


## Hurtbox-capsules (lokaal, voeten = oorsprong), geschaald met visual_height; vorm per state.
func hurtboxes() -> Array[HurtboxData]:
	var h: float = stats.visual_height
	var shape: String = state.hurtbox_shape() if state != null else "stand"
	if shape == "crouch":
		var c: Array[HurtboxData] = []
		c.append(HurtboxData.make(Vector2(0, h * 0.15), Vector2(0, h * 0.3), h * 0.17))
		c.append(HurtboxData.make(Vector2(h * 0.08, h * 0.42), Vector2(h * 0.08, h * 0.42), h * 0.15))
		return c
	if shape == "lie":
		var l: Array[HurtboxData] = []
		l.append(HurtboxData.make(Vector2(-h * 0.38, h * 0.12), Vector2(h * 0.38, h * 0.12), h * 0.13))
		return l
	return HurtboxData.default_for_height(h)


## Momentopname voor HitResolver.
func combat_target() -> CombatTarget:
	var t := CombatTarget.new()
	t.id = player
	t.origin = pos
	t.facing = facing
	t.hurtboxes = hurtboxes()
	t.percent = percent
	t.weight = stats.weight
	t.grounded = grounded
	t.crouching = grounded and state != null and state.is_crouching()
	t.intangible = is_intangible() or not active
	t.charging = state != null and state.id() == "Attack" and (state as StateAttack).charging
	t.shielding = state != null and state.is_shielding()
	if t.shielding:
		t.shield_center = pos + shield_center_local()
		t.shield_radius = shield_radius()
		t.shield_analog = shield_value()
	t.grabbable = grab_partner == null
	return t


# --- treffers toepassen (aangeroepen door CombatSystem) -------------------------------------------

## Aanvaller: eigen treffer (HIT of SHIELD). Hitlag; hitfall alleen bij een echte treffer.
func on_hit_landed(ev: HitEvent) -> void:
	already_hit[ev.key] = true
	hitlag_frames = maxi(hitlag_frames, ev.attacker_hitlag)
	if _victim_tick != tick_count:
		hitlag_victim = false
		hitlag_strength = 0.0
		hitfall_allowed = ev.attacker_hitfall_allowed


## Clank: hitlag voor beide; rebound = de move raakt niets meer, op de grond -> Rebound-state.
func on_clank(hitlag: int, rebound: bool) -> void:
	hitlag_frames = maxi(hitlag_frames, hitlag)
	if _victim_tick != tick_count:
		hitlag_victim = false
		hitlag_strength = 0.0
		hitfall_allowed = false
	if rebound:
		hitboxes_off = true
		if grounded and state != null and state.id() == "Attack":
			change_state("Rebound")


## Slachtoffer: percent, ledge-reset, damage-state, hitlag. De launch wacht tot het einde van de hitlag
## (SDI tijdens, ASDI en DI op het laatste hitlag-frame). Geeft true als de hit (vrijwel zeker) killt.
## allow_sdi = false bij throws: wel DI, geen SDI/ASDI.
func receive_hit(ev: HitEvent, allow_sdi: bool = true) -> bool:
	var kb: KnockbackResult = ev.knockback
	last_hit_by = ev.attacker
	_victim_tick = tick_count
	_sdi_allowed = allow_sdi
	set_percent(minf(percent + ev.damage, MAX_PERCENT))
	# Melee (ftCo_Damage): geraakt worden laat de ledge los en zet dezelfde ledge-lock (30) als loslaten.
	release_ledge(stats.ledge_cooldown)
	fastfalling = false
	reset_fast_fall_buffer()
	hitfall_allowed = false
	hitlag_victim = true
	hitlag_frames = ev.defender_hitlag
	hitlag_strength = clampf(1.5 + ev.damage * 0.35, 1.5, 9.0)
	var kill: bool = predict_ko(kb)
	var crouch_cc: bool = kb.crouch_cancelled and kb.stays_grounded and state != null and state.is_crouching()
	if not crouch_cc:
		change_state("DamageFly" if kb.tumble else "Damage", {"kb": kb})
	pending_kb = kb
	if hitlag_frames <= 0:
		hitlag_frames = 0
		_end_victim_hitlag(stick(), stick())
	_hit_fx(ev, kb, kill)
	return kill


func _hitlag_tick() -> void:
	hitlag_frames -= 1
	if hitlag_victim:
		var cur: Vector2 = stick()
		var off: Vector2 = Vector2.ZERO
		if _sdi_allowed:
			off = Knockback.sdi_offset(input.get_frame(1).stick_f(), cur)
		var asdi_stick: Vector2 = cur
		if hitlag_frames == 0 and _sdi_allowed:
			# ASDI: C-stick heeft voorrang op de stick (Melee).
			var cs: Vector2 = input.get_frame(0).cstick_f()
			if cs != Vector2.ZERO:
				asdi_stick = cs
			off += Knockback.asdi_offset(asdi_stick)
		if off != Vector2.ZERO:
			_nudge(off)
		if hitlag_frames == 0:
			_end_victim_hitlag(cur, asdi_stick if _sdi_allowed else Vector2.ZERO)
	elif hitfall_allowed and not grounded and not fastfalling \
			and input.flick_y(MeleeStick.FAST_FALL_THRESHOLD, MeleeStick.FAST_FALL_WINDOW) == -1:
		# Hitfall (Rivals-aanpak): ook tijdens het stijgen; vy wordt in de volgende phys() gezet.
		fastfalling = true


## SDI/ASDI-verschuiving met collision: op de grond alleen langs het segment, in de lucht niet door de vloer.
func _nudge(off: Vector2) -> void:
	if grounded and ground_seg >= 0 and ground_seg < _segments.size():
		var s: Dictionary = _segments[ground_seg]
		var x: float = clampf(pos.x + off.x, s["a"].x, s["b"].x)
		pos = Vector2(x, _seg_y(s, x))
		return
	var from: Vector2 = pos
	var to: Vector2 = pos + off
	for s: Dictionary in _segments:
		if s["platform"] or to.x < s["a"].x - EPS or to.x > s["b"].x + EPS:
			continue
		var y: float = _seg_y(s, to.x)
		if from.y >= _seg_y(s, from.x) - 0.01 and to.y < y:
			to.y = y + 0.01
	pos = to


func _end_victim_hitlag(di_stick: Vector2, asdi_stick: Vector2) -> void:
	var kb: KnockbackResult = pending_kb
	pending_kb = null
	if kb == null:
		return
	var lv: Vector2 = Knockback.apply_di(kb.launch_vel, di_stick)
	# ⚠️ ASDI omlaag op de grond zonder tumble: blijft staan (alleen de x-component als glijden).
	var stay: bool = kb.stays_grounded \
		or (grounded and not kb.tumble and asdi_stick.y <= -FighterConst.ASDI_DOWN_THRESHOLD + FighterConst.EPS)
	_launch(kb, lv, stay)


func _launch(kb: KnockbackResult, lv: Vector2, stay_grounded: bool) -> void:
	vel = Vector2.ZERO
	if grounded and stay_grounded:
		gr_vel = lv.x
		kb_vel = Vector2.ZERO
		return
	if grounded:
		if lv.y < 0.0:
			lv.y = -lv.y * FighterConst.GROUND_BOUNCE_FACTOR   # ⚠️ grond-bounce
		grounded = false
		ground_seg = -1
		gr_vel = 0.0
	fastfalling = false
	kb_vel = lv
	if kb.tumble:
		var v: Node = get_vfx()
		if v != null and v.has_method("spawn_launch_trail"):
			v.spawn_launch_trail(self, clampi(kb.hitstun, 12, 60))


## Neerkomen in tumble (DamageFly/DamageFall): tech-druk binnen 20 frames -> Tech (stick-x >= 0.5 = roll die kant
## op, anders in place); anders missed tech (DownBound).
func land_in_tumble() -> void:
	if tech_ready():
		var sx: float = stick_x()
		var d: int = 0
		if absf(sx) >= FighterConst.TECH_ROLL_THRESHOLD - FighterConst.EPS:
			d = 1 if sx > 0.0 else -1
		change_state("Tech", {"dir": d})
	else:
		change_state("DownBound")


## Zou deze launch (zonder DI én met ±18° DI) de fighter uit de blast zone brengen? Voor de kill-flash/-SFX.
func predict_ko(kb: KnockbackResult) -> bool:
	if not kb.tumble or stage == null or not stage.has_method("get_blast_zone"):
		return false
	var bz: Rect2 = stage.get_blast_zone()
	if bz.size == Vector2.ZERO:
		return false
	for deg: float in [0.0, Knockback.MAX_DI_DEG, -Knockback.MAX_DI_DEG]:
		if not _flies_out(kb.launch_vel.rotated(deg_to_rad(deg)), kb.hitstun, bz):
			return false
	return true


func _flies_out(launch: Vector2, hitstun: int, bz: Rect2) -> bool:
	var p: Vector2 = pos
	var v: Vector2 = Vector2.ZERO
	var k: Vector2 = launch
	for i in 300:
		p += v + k
		if not bz.has_point(p):
			return true
		k = Knockback.decay_step(k)
		v.y = maxf(v.y - stats.gravity, -stats.terminal_velocity)
		if k == Vector2.ZERO and i > hitstun:
			return false
	return false


# =============================================================================================
# Verdediging (M4): shield, OoS, rolls/spotdodge, grab/pummel/throws. Zie docs/combat.md, "M4-implementatie".
# =============================================================================================

## Analoge shield-stand s (0..1): de digitale klik telt als vol (1.0), anders de sterkste trigger.
func shield_value() -> float:
	var fr: InputFrame = input.get_frame(0)
	if fr.has(InputFrame.BTN_SHIELD):
		return 1.0
	return fr.shield_analog()


## Shield vastgehouden (analoog >= 0.3 of digitaal).
func shield_held() -> bool:
	return shield_value() >= FighterConst.SHIELD_ON_THRESHOLD - FighterConst.EPS


## Lichtheid van de shield: 0 = vol (digitaal), 1 = lichtste (s = 0.3). = 1 - Knockback.shield_norm(s).
func shield_lightness() -> float:
	return 1.0 - Knockback.shield_norm(shield_value())


## Grond-actionable: shield vast -> GuardOn.
func check_guard() -> bool:
	if not grounded or not shield_held():
		return false
	change_state("GuardOn")
	return true


## Shield-middelpunt t.o.v. de voeten (units, y omhoog).
func shield_center_local() -> Vector2:
	return Vector2(0.0, stats.shield_center_ratio * stats.visual_height)


## Straal van de shield-bubble: krimpt met de HP, groter bij een lightshield. ⚠️ (zie FighterConst)
func shield_radius() -> float:
	var hp: float = clampf(shield_hp / FighterConst.SHIELD_MAX_HP, 0.0, 1.0)
	var k: float = FighterConst.SHIELD_MIN_SCALE + (1.0 - FighterConst.SHIELD_MIN_SCALE) * hp
	return stats.shield_size_ratio * stats.visual_height * k * (1.0 + FighterConst.SHIELD_LIGHT_GROW * shield_lightness())


## Vasthouden in GuardOn/Guard: shield slijt; <= 0 -> shield break. Geeft true bij een break (state gewisseld).
func drain_shield() -> bool:
	shield_hp -= FighterConst.SHIELD_DEPLETION
	if shield_hp <= 0.0:
		break_shield()
		return true
	return false


## Powershield: digitale klik in de eerste POWERSHIELD_WINDOW frames van GuardOn.
func powershield_active() -> bool:
	return state != null and state.id() == "GuardOn" and state_frame < FighterConst.POWERSHIELD_WINDOW \
		and tick_count - _ps_tick < FighterConst.POWERSHIELD_WINDOW


## Verdediger: treffer op de shield (CombatSystem). Shield-schade × (0.7 .. 1.35), hitlag (met shield-SDI), dan
## GuardSetOff met shieldstun + pushback weg van de hitbox. Powershield: niets daarvan. HP <= 0 = shield break.
func on_shield_hit(ev: HitEvent) -> void:
	last_hit_by = ev.attacker
	var light: float = shield_lightness()
	var dir: float = signf(pos.x - ev.hitbox.pos.x)
	if dir == 0.0:
		dir = float(ev.hitbox.facing)
	var v: Node = get_vfx()
	if powershield_active():
		if v != null and v.has_method("spawn_shield_hit"):
			v.spawn_shield_hit(ev.hitbox.pos, 1.0, Color.WHITE, 0.0 if dir < 0.0 else 180.0)
		_sfx("shield_hit")
		return
	shield_hp -= ev.shield_damage * (FighterConst.SHIELD_DAMAGE_MULT + FighterConst.SHIELD_DAMAGE_LIGHT_EXTRA * light)
	_victim_tick = tick_count
	_sdi_allowed = true
	hitlag_victim = true
	hitfall_allowed = false
	pending_kb = null
	hitlag_frames = ev.defender_hitlag
	hitlag_strength = clampf(1.0 + ev.damage * 0.2, 1.0, 5.0)
	if v != null and v.has_method("spawn_shield_hit"):
		v.spawn_shield_hit(ev.hitbox.pos, clampf(ev.damage / 20.0, 0.1, 1.0), player_color(), 0.0 if dir < 0.0 else 180.0)
	if shield_hp <= 0.0:
		break_shield()
		return
	_sfx("shield_hit")
	var push: float = FighterConst.SHIELD_PUSH_BASE \
		+ ev.damage * (0.65 * light + 0.3) * FighterConst.SHIELD_PUSH_PER_DAMAGE
	change_state("GuardSetOff", {"stun": ev.shield_stun, "push": dir * minf(push, FighterConst.SHIELD_PUSH_MAX)})


## Shield break: HP terug op 30, omhoog gelanceerd (ShieldBreak -> ShieldBreakDown -> Dizzy).
func break_shield() -> void:
	shield_hp = FighterConst.SHIELD_BREAK_RESET_HP
	_sfx("shield_break")
	var v: Node = get_vfx()
	if v != null and v.has_method("spawn_shield_hit"):
		v.spawn_shield_hit(pos + shield_center_local(), 1.0, player_color(), 90.0)
	change_state("ShieldBreak")


## Uit shield (Guard/GuardOn): grab (A/Z), sprong (JC: usmash/up-B/grab volgen in KneeBend), shield drop,
## spotdodge (omlaag-flick), roll (x-flick). Geeft true bij een wissel.
func check_oos() -> bool:
	if input.pressed(InputFrame.BTN_ATTACK) or input.pressed(InputFrame.BTN_Z):
		start_grab(false)
		return true
	if check_ground_jump():
		return true
	if check_shield_drop():
		return true
	if input.flick_y(FighterConst.SPOTDODGE_THRESHOLD, FighterConst.SPOTDODGE_WINDOW) == -1:
		change_state("EscapeN")
		return true
	var fx: int = input.flick_x(MeleeStick.SMASH_THRESHOLD, MeleeStick.DASH_FLICK_WINDOW)
	if fx != 0:
		change_state("Escape", {"dir": fx * facing})
		return true
	return false


## Shield drop (Melee ftCo_8009A080: shield vast + verse omlaag-flick, op een platform). Vanilla: alleen in de smalle
## band -0.7 < y <= -0.6875 (anders wint spotdodge); UCF: ook schuin omlaag (|x| >= UCF_SHIELD_DROP_MIN_X).
func check_shield_drop() -> bool:
	if not grounded or not _is_platform(ground_seg):
		return false
	if input.flick_y(MeleeStick.PLATFORM_DROP_THRESHOLD, MeleeStick.PLATFORM_DROP_WINDOW) != -1:
		return false
	var s: Vector2 = stick()
	var notch: bool = s.y > -FighterConst.SPOTDODGE_THRESHOLD + FighterConst.EPS
	var ucf: bool = ucf_shield_drop and MeleeStick.reaches(s.x, FighterConst.UCF_SHIELD_DROP_MIN_X)
	if not notch and not ucf:
		return false
	ignore_platform = ground_seg
	leave_ground(Vector2(gr_vel, 0.0))
	change_state("Fall")
	return true


func player_color() -> Color:
	return Color(Rig.PLAYER_PALETTES[posmod(player, Rig.PLAYER_PALETTES.size())]["main"])


# --- grab / throws ------------------------------------------------------------------------------

## Start een (dash) grab met de move "grab" uit de moveset. false als die er niet is.
func start_grab(dash: bool) -> bool:
	if not grounded or not moves.has("grab"):
		return false
	change_state("Grab", {"dash": dash})
	return true


## Mag een grab-treffer van deze frame nog vastpakken? (De grab-state loopt nog en er is geen partner.)
func can_land_grab() -> bool:
	return state != null and state.id() == "Grab" and grab_partner == null


## Verste grab-hitbox vooruit (units): de vasthoudpositie (afspraak 3: de throw-hitbox zit op de grab-tip).
func grab_tip() -> float:
	var m: MoveData = get_move("grab")
	var tip: float = 0.0
	if m != null:
		for h: HitboxData in m.hitboxes:
			tip = maxf(tip, h.offset.x)
	return tip


## Grab raakt (CombatSystem): holder -> GrabHold, victim -> Grabbed op de grab-tip, timer volgens % (mashen verkort).
func on_grab_landed(victim: Fighter, _ev: HitEvent = null) -> void:
	grab_partner = victim
	grab_hold_dx = grab_tip() + FighterConst.GRAB_HOLD_BODY_RATIO * victim.stats.visual_height
	victim.grab_partner = self
	victim.grabbed_airborne = not victim.grounded
	victim.last_hit_by = player
	victim.grab_timer = int(FighterConst.GRAB_TIMER_BASE + FighterConst.GRAB_TIMER_PER_PERCENT * victim.percent)
	victim.reset_combat()
	victim.release_ledge(victim.stats.ledge_cooldown)
	victim.fastfalling = false
	victim.facing = -facing
	change_state("GrabHold")
	victim.change_state("Grabbed")
	place_grab_victim()
	_sfx("grab")


## Holder: zet de victim op de vasthoudpositie (voeten op grab-tip + lijf), kijkend naar de holder.
## Staat daar grond, dan grounded (voor throws: 361/grond-bounce), anders hangt hij in de lucht (lucht-release).
func place_grab_victim() -> void:
	var v: Fighter = grab_partner
	if v == null or not is_instance_valid(v):
		return
	var p := Vector2(pos.x + facing * grab_hold_dx, pos.y)
	v.vel = Vector2.ZERO
	v.kb_vel = Vector2.ZERO
	v.gr_vel = 0.0
	v.facing = -facing
	var seg: int = _segment_at(p, 0.5) if grounded else -1
	if seg >= 0:
		v._segments = _segments
		v._set_grounded(seg, p.x)
	else:
		v.pos = p
		v.grounded = false
		v.ground_seg = -1
	v._update_visual()


## Victim: mash-input (nieuwe knop of verse stickrichting) verkort de grab-timer.
func grab_mash_input() -> bool:
	for b: int in [InputFrame.BTN_ATTACK, InputFrame.BTN_SPECIAL, InputFrame.BTN_JUMP, InputFrame.BTN_Z,
			InputFrame.BTN_SHIELD]:
		if input.pressed(b):
			return true
	return input.stick_timer_x() == 0 or input.stick_timer_y() == 0 or cstick_dir() != Vector2i.ZERO


## Victim: grab-timer op -> loskomen. Holder -> GrabRelease (kleine pushback), victim -> grond- of lucht-release.
func grab_escape() -> void:
	var g: Fighter = grab_partner
	grab_partner = null
	if g != null and is_instance_valid(g) and g.grab_partner == self:
		g.grab_partner = null
		g.change_state("GrabRelease", {"push": -g.facing * FighterConst.GRAB_RELEASE_PUSH * 0.5})
	_release_victim()


## Victim komt los: in de lucht gegrepen (of hangend boven de afgrond) = lucht-release (omhoog, direct actionable),
## anders grond-release (GrabRelease, weggeduwd van de holder).
func _release_victim() -> void:
	var away: float = -float(facing)
	if grabbed_airborne or not grounded:
		leave_ground(Vector2(away * 0.5, FighterConst.GRAB_AIR_RELEASE_VY))
		change_state("Fall")
	else:
		change_state("GrabRelease", {"push": away * FighterConst.GRAB_RELEASE_PUSH})


## Verbreek de grab omdat deze fighter de grab-familie verlaat (geraakt, KO, ...). De partner gaat naar zijn release.
func _drop_grab() -> void:
	var p: Fighter = grab_partner
	grab_partner = null
	if p == null or not is_instance_valid(p) or p.grab_partner != self:
		return
	p.grab_partner = null
	if p.state == null or not p.state.keeps_grab():
		return
	if p.state.id() == "Grabbed" or p.state.id() == "Thrown":
		p._release_victim()
	else:
		p.change_state("GrabRelease", {"push": 0.0})


## Holder in GrabHold: throw-richting uit stick (dominante as >= THROW_STICK_THRESHOLD) of verse C-stick,
## t.o.v. de kijkrichting. "" = geen throw-input.
func throw_input() -> String:
	var d: Vector2 = Vector2(cstick_dir())
	if d == Vector2.ZERO:
		var s: Vector2 = stick()
		if maxf(absf(s.x), absf(s.y)) < FighterConst.THROW_STICK_THRESHOLD - FighterConst.EPS:
			return ""
		d = s
	if absf(d.y) > absf(d.x):
		return "uthrow" if d.y > 0.0 else "dthrow"
	return "fthrow" if d.x * facing > 0.0 else "bthrow"


## Holder: pummel-treffer / throw-launch van deze frame klaarzetten. CombatSystem.step past ze toe ná alle
## fighter-ticks (apply_grab_actions), zodat holder en victim hun hitlag symmetrisch krijgen, net als bij hits.
func queue_pummel() -> void:
	_pending_pummel = true


func queue_throw(hb: HitboxData) -> void:
	_pending_throw = hb
	_pending_throw_set = true


## Aangeroepen door CombatSystem.step (post-tick, fighters op volgorde van `player`).
func apply_grab_actions() -> void:
	if _pending_pummel:
		_pending_pummel = false
		pummel_hit()
	if _pending_throw_set:
		var hb: HitboxData = _pending_throw
		_pending_throw_set = false
		_pending_throw = null
		if grab_partner != null and hb != null:
			throw_victim(hb)
		elif grab_partner != null and state != null and state.id() == "Throw":
			change_state("Wait")   # throw zonder hitbox: grab verbreekt zonder launch


## Holder: pummel-treffer (kan niet missen): damage op de victim, hitlag voor beiden (geen SDI).
func pummel_hit() -> void:
	var v: Fighter = grab_partner
	if v == null or not is_instance_valid(v):
		return
	var d: float = stats.pummel_damage
	v.set_percent(minf(v.percent + d, MAX_PERCENT))
	v.last_hit_by = player
	var hl: int = Knockback.hitlag_frames(d)
	hitlag_frames = hl
	hitlag_victim = false
	hitfall_allowed = false
	v.hitlag_frames = hl
	v.hitlag_victim = true
	v._sdi_allowed = false
	v.pending_kb = null
	v._victim_tick = v.tick_count
	v.hitlag_strength = clampf(1.5 + d * 0.35, 1.5, 9.0)
	var fx: Node = get_vfx()
	if fx != null and fx.has_method("spawn_hit"):
		fx.spawn_hit(v.pos + Vector2(0.0, v.stats.visual_height * 0.55), 0.08, 0, 0.0, false, 2.0)
	_sfx("hit_weak")


## Holder: de throw lanceert (launch-frame van de throw-hitbox). Throws kunnen niet missen: de knockback van de
## throw-hitbox wordt direct op de victim toegepast (gewicht/percent van de victim, hoek t.o.v. de holder, DI wel,
## SDI/ASDI niet). Achterwaartse throws (hoek 90..270) zetten de victim eerst achter de holder.
func throw_victim(hb: HitboxData) -> void:
	var v: Fighter = grab_partner
	if v == null or not is_instance_valid(v) or hb == null:
		return
	grab_partner = null
	v.grab_partner = null
	if hb.angle > 90.0 and hb.angle < 270.0:
		var p := Vector2(pos.x - facing * grab_hold_dx, pos.y)
		var seg: int = _segment_at(p, 0.5) if grounded else -1
		if seg >= 0:
			v._segments = _segments
			v._set_grounded(seg, p.x)
		else:
			v.pos = p
			v.grounded = false
			v.ground_seg = -1
	var kb: KnockbackResult = Knockback.compute(hb, hb.damage, v.percent, v.stats.weight, v.grounded, false, facing)
	var ev := HitEvent.new()
	ev.kind = HitEvent.Kind.HIT
	ev.attacker = player
	ev.defender = v.player
	ev.damage = hb.damage
	ev.knockback = kb
	ev.hitbox = ActiveHitbox.make(hb, player, move_instance, v.pos + Vector2(0.0, v.stats.visual_height * 0.5), facing)
	ev.attacker_hitlag = 0
	ev.defender_hitlag = Knockback.hitlag_frames(hb.damage, hb.element, hb.hitlag_mult, true, false)
	v.receive_hit(ev, false)
	_sfx("throw")


# --- effecten (alleen presentatie) --------------------------------------------------------------

## VfxLayer: `vfx` als die gezet is, anders de eerste node in groep "vfx_layer".
func get_vfx() -> Node:
	if vfx != null and is_instance_valid(vfx):
		return vfx
	if is_inside_tree():
		return get_tree().get_first_node_in_group("vfx_layer")
	return null


func _hit_fx(ev: HitEvent, kb: KnockbackResult, kill: bool) -> void:
	var v: Node = get_vfx()
	if v != null and v.has_method("spawn_hit"):
		v.spawn_hit(ev.hitbox.pos, clampf(kb.kb / 160.0, 0.05, 1.0), int(ev.hitbox.data.element), kb.angle, kill,
			ev.hitbox.data.radius)
	var s: String = "hit_weak"
	if kill:
		s = "hit_kill"
	elif kb.tumble:
		s = "hit_strong"
	elif ev.damage >= 7.0 or kb.kb >= 40.0:
		s = "hit_medium"
	_sfx(s)


func _land_fx(heavy: bool) -> void:
	_sfx("land_heavy" if heavy else "land")
	var v: Node = get_vfx()
	if v != null and v.has_method("spawn_land_dust"):
		v.spawn_land_dust(pos, heavy)


func _state_fx(old: String, id: String) -> void:
	if not is_inside_tree():
		return
	var v: Node = get_vfx()
	match id:
		"Jump":
			if old == "KneeBend":
				_sfx("jump")
				if v != null:
					v.spawn_jump_dust(pos)
		"JumpAerial":
			_sfx("double_jump")
		"Dash":
			_sfx("dash")
			if v != null:
				v.spawn_dash_dust(pos, facing)
		"EscapeAir":
			_sfx("airdodge")
			if v != null:
				v.spawn_airdodge_trail(pos + Vector2(0, stats.visual_height * 0.5),
					NAN if vel == Vector2.ZERO else rad_to_deg(atan2(vel.y, vel.x)))


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
	# ⚠️ Een omlaag-flick wordt FAST_FALL_BUFFER frames onthouden (short hop: flick vlak vóór de apex telt).
	if allow_fastfall and input.flick_y(MeleeStick.FAST_FALL_THRESHOLD, MeleeStick.FAST_FALL_WINDOW) == -1:
		_ff_flick_tick = tick_count
	# ⚠️ Afwijking van Melee (speeltest-wens): met fast_fall_while_rising mag fast fall ook vóór de apex.
	var past_apex: bool = vel.y < 0.0 or MeleeStick.fast_fall_while_rising
	if allow_fastfall and not fastfalling and past_apex \
			and tick_count - _ff_flick_tick <= MeleeStick.FAST_FALL_BUFFER:
		fastfalling = true
	if fastfalling:
		vel.y = -stats.fast_fall_velocity
	else:
		vel.y = maxf(vel.y - stats.gravity, -stats.terminal_velocity)


## Vergeet de onthouden omlaag-flick (nieuwe sprong / landing).
func reset_fast_fall_buffer() -> void:
	_ff_flick_tick = -1000


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
	_ff_flick_tick = -1000


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
	var heavy: bool = fastfalling or vel.y + kb_vel.y <= -2.8
	vel += kb_vel
	kb_vel = Vector2.ZERO
	_set_grounded(seg, x)
	_land_fx(heavy)
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
			state.on_edge_stop(side)
		else:
			pos = Vector2(nx, edge.y)
			leave_ground(Vector2(gr_vel, 0.0))
			change_state("Fall")
		return


## Lucht-coll: verplaats met vel; land als de ECB-onderkant een segment van boven kruist (alleen vy <= 0).
func air_coll() -> void:
	var from: Vector2 = pos
	var to: Vector2 = pos + vel + kb_vel
	pos = to
	if vel.y + kb_vel.y > 0.0:
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
			_blast_ko(bz)


## Blast zone verlaten: bepaal de zijde (grootste overschrijding), zet de fighter uit de match, meld het via
## `blast_ko` en respawn bij auto_respawn (tenzij een handler hem in de tussentijd al heeft teruggezet).
func _blast_ko(bz: Rect2) -> void:
	var over: Dictionary = {
		&"left": bz.position.x - pos.x, &"right": pos.x - bz.end.x,
		&"top": pos.y - bz.end.y, &"bottom": bz.position.y - pos.y,
	}
	var side: StringName = &"left"
	var best: float = -INF
	for k: StringName in [&"left", &"right", &"top", &"bottom"]:
		if over[k] > best:
			best = over[k]
			side = k
	vel = Vector2.ZERO
	gr_vel = 0.0
	grounded = false
	ground_seg = -1
	reset_combat()
	intangible_frames = 0
	change_state("Dead")
	active = false
	visible = false
	blast_ko.emit(self, side)
	if auto_respawn and not active:
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


func _read_ledges() -> Array:
	var out: Array = []
	if stage == null or not stage.has_method("get_ledges"):
		return out
	for raw: Variant in stage.get_ledges():
		var p: Variant = null
		var s: Variant = null
		if raw is Dictionary:
			p = raw.get("position")
			s = raw.get("side")
		elif raw is Object:
			p = raw.get("position")
			s = raw.get("side")
		if p is Vector2 and (s is int or s is float) and int(s) != 0:
			out.append({"pos": p, "side": 1 if int(s) > 0 else -1})
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
		# Rig is getekend op STAND_HEIGHT_PX; schaal naar de lengte van dit character.
		var sc: float = stats.visual_height * Units.UNIT_TO_PX / Rig.STAND_HEIGHT_PX
		visual.scale = Vector2.ONE * sc
		visual.facing = facing
		var p: String = state.pose()
		var key: String = "%d|%s" % [_serial, p]
		var timing: Array = state.pose_timing()
		if key != _vis_key and timing.size() == 3:
			# Aanvalspose: fases geschaald naar de frame-data (docs/rig.md 6b), bij elke nieuwe aanval opnieuw.
			visual.play_timed(p, int(timing[0]), int(timing[1]), int(timing[2]), true)
		elif timing.size() != 3:
			visual.play(p, false)
		_vis_key = key
		visual.tick(state.pose_frame(), state.pose_speed())
		var off: Vector2 = state.visual_offset_px() * sc
		if hitlag_frames > 0 and hitlag_victim:
			off += VfxConst.hitlag_jitter(hitlag_frames, hitlag_strength)
		visual.position = off
	if is_inside_tree():
		queue_redraw()
		if _debug_node != null:
			_debug_node.queue_redraw()
		if _shield_node != null:
			_shield_node.queue_redraw()


func _draw() -> void:
	if state != null and state.id() == "RebirthWait" and stats != null:
		# Respawn-platform onder de voeten (presentatie).
		var k0: float = Units.UNIT_TO_PX
		var w: float = 14.0 * k0
		draw_rect(Rect2(Vector2(-w, 0.0), Vector2(2.0 * w, 3.0 * k0)), Color(0.55, 0.85, 1.0, 0.85))
		draw_rect(Rect2(Vector2(-w, 3.0 * k0), Vector2(2.0 * w, 1.0 * k0)), Color(0.3, 0.5, 0.9, 0.6))


## Shield-bubble: cirkel in de spelerskleur op shield_center_local() met shield_radius() (krimpt met de HP, groter
## bij een lightshield). Doorschijnender bij een lightshield; wit tijdens het powershield-venster.
func _draw_shield() -> void:
	if state == null or not active or not state.is_shielding() or stats == null:
		return
	var c: Color = player_color()
	if powershield_active():
		c = c.lerp(Color.WHITE, 0.7)
	var k: float = Units.UNIT_TO_PX
	var ctr: Vector2 = Units.to_px(shield_center_local())
	var r: float = shield_radius() * k
	var alpha: float = 0.42 - 0.17 * shield_lightness()
	var hp: float = clampf(shield_hp / FighterConst.SHIELD_MAX_HP, 0.0, 1.0)
	_shield_node.draw_circle(ctr, r, Color(c.r, c.g, c.b, alpha))
	_shield_node.draw_circle(ctr + Vector2(-0.3, -0.35) * r, r * 0.28, Color(1, 1, 1, 0.18 * alpha / 0.42))
	_shield_node.draw_arc(ctr, r, 0.0, TAU, 48, Color(c.lightened(0.35), 0.55 + 0.35 * hp), 2.5, true)


## F2 (Sim.debug_hitboxes): ECB, hurtboxes en hitboxes, boven de visual (CombatDebug-node, z 100).
func _draw_debug() -> void:
	var sim: Node = get_node_or_null("/root/Sim")
	if sim == null or not sim.debug_hitboxes or stats == null or state == null or not active:
		return
	var c: Node2D = _debug_node
	HitboxDraw.draw_hurtboxes(c, combat_target(), pos)
	HitboxDraw.draw_hitboxes(c, last_hitboxes, pos)
	# ECB-diamant (presentatie in px, t.o.v. de voeten)
	var k: float = Units.UNIT_TO_PX
	var pts := PackedVector2Array([
		Vector2(0, 0), Vector2(stats.ecb_half_width * k, -stats.ecb_mid_y * k),
		Vector2(0, -stats.ecb_height * k), Vector2(-stats.ecb_half_width * k, -stats.ecb_mid_y * k), Vector2(0, 0)])
	c.draw_polyline(pts, Color(1.0, 0.55, 0.1, 0.9), 2.0)
	c.draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 0.2))


## Hook voor de debug overlay.
func get_debug_state_name() -> String:
	var s: String = "%s  %s f%d  pos(%.2f, %.2f)  %.1f%%" % [
		stats.display_name if stats != null else "?", state.debug_name() if state != null else "-",
		state_frame, pos.x, pos.y, percent]
	if grounded:
		s += "  gr_vel %.3f" % gr_vel
	else:
		s += "  vel(%.3f, %.3f)" % [vel.x, vel.y]
	if kb_vel != Vector2.ZERO:
		s += "  kb(%.2f, %.2f)" % [kb_vel.x, kb_vel.y]
	s += "  jumps %d/%d" % [stats.air_jumps - air_jumps_used, stats.air_jumps]
	if fastfalling:
		s += "  FF"
	if hitlag_frames > 0:
		s += "  HITLAG %d%s" % [hitlag_frames, " (hitfall)" if hitfall_allowed else ""]
	if is_intangible():
		s += "  INTANGIBLE"
		if intangible_frames > 0:
			s += "(%d)" % intangible_frames
	if shield_hp < FighterConst.SHIELD_MAX_HP or (state != null and state.is_shielding()):
		s += "  shield %.1f" % shield_hp
		if state != null and state.is_shielding():
			s += " (s %.2f%s)" % [shield_value(), ", POWERSHIELD" if powershield_active() else ""]
	if grab_partner != null and state != null and (state.id() == "Grabbed" or state.id() == "Thrown"):
		s += "  grab-timer %d" % grab_timer
	return s


## Momentopname voor tests/determinisme.
func snapshot() -> Array:
	return [state_name(), state_frame, pos, vel, gr_vel, facing, grounded, air_jumps_used, fastfalling,
		intangible_frames, ledge_key, active, percent, kb_vel, hitlag_frames, snappedf(shield_hp, 0.0001), grab_timer]
