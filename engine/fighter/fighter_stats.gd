class_name FighterStats
extends Resource
## Movement-attributen van één character, 1-op-1 de Melee-attributen (ftCo_DatAttrs, zie
## docs/melee-referentie.md). Eenheden: Melee-units per frame (snelheid), per frame² (accel/gravity/
## traction), frames (timings). Waarden met ⚠️ in een preset hebben geen bron en zijn geschat.
## Presets: engine/fighter/archetypes/*.tres (zie docs/movement.md, "Archetype-presets").

@export var display_name: String = "Allrounder"
## Op welk Melee-character de waarden gebaseerd zijn (alleen documentatie).
@export var reference: String = ""

@export_group("Gewicht en verticaal")
@export var weight: float = 87.0
@export var gravity: float = 0.085
@export var terminal_velocity: float = 2.2
@export var fast_fall_velocity: float = 2.5

@export_group("Springen")
## Jumpsquat (jump_startup_time) in frames.
@export var jumpsquat_frames: int = 4
## Full hop: jump_v_initial_velocity.
@export var jump_v_initial_velocity: float = 2.4
## Short hop: hop_v_initial_velocity.
@export var hop_v_initial_velocity: float = 1.5
## Double jump: vy = jump_v_initial_velocity * air_jump_v_multiplier.
@export var air_jump_v_multiplier: float = 0.88
## Optioneel vaste krachten per luchtsprong (Jigglypuff-stijl). Leeg = multiplier gebruiken.
@export var air_jump_forces: PackedFloat32Array = PackedFloat32Array()
## Aantal luchtsprongen (Melee "number of jumps" − 1).
@export var air_jumps: int = 1
## ⚠️ vx bij grondsprong = gr_vel * dit + stick_x * jump_h_initial_velocity, begrensd op jump_h_max_velocity.
@export var ground_to_air_jump_momentum_multiplier: float = 0.7
@export var jump_h_initial_velocity: float = 0.9
@export var jump_h_max_velocity: float = 1.5
## ⚠️ vx bij double jump = stick_x * dit (momentum wordt vervangen).
@export var air_jump_h_multiplier: float = 1.0

@export_group("Grond")
@export var dash_initial_velocity: float = 1.5
## Duur initial dash (animatielengte) in frames.
@export var dash_frames: int = 15
## Dash/run: accel = stick*additional + sign*base, target = stick*run_speed.
@export var dash_accel_base: float = 0.0
@export var dash_accel_additional: float = 0.06
## dash_max_velocity = run speed bij volle stick.
@export var run_speed: float = 1.8
## ⚠️ Walk: accel per frame richting stick*walk_max_velocity (vanaf walk_initial_velocity).
@export var walk_initial_velocity: float = 0.15
@export var walk_acceleration: float = 0.08
@export var walk_max_velocity: float = 1.6
@export var traction: float = 0.06
## ⚠️ ground_max_horizontal_velocity: absolute grens op gr_vel.
@export var ground_max_horizontal_velocity: float = 3.5
## ⚠️ standing turn (Turn) in frames.
@export var turn_frames: int = 11
## ⚠️ max_run_brake_frames (RunBrake/skid).
@export var run_brake_frames: int = 20
## ⚠️ minimale duur run turnaround (TurnRun); duurt minstens tot de snelheid is omgedraaid.
@export var run_turn_frames: int = 25
## ⚠️ Squat (hurken in) en SquatRv (opstaan) in frames.
@export var squat_frames: int = 7
@export var squat_rv_frames: int = 10

@export_group("Lucht")
## Air accel a/b: accel = stick*additional + sign*base, target = stick*max_air_speed.
@export var air_accel_base: float = 0.02
@export var air_accel_additional: float = 0.03
@export var max_air_speed: float = 0.9
@export var air_friction: float = 0.005
## ⚠️ air_max_horizontal_velocity: absolute grens op vx in de lucht.
@export var air_max_horizontal_velocity: float = 3.5
## ⚠️ drift-factor in special fall (helpless) na een air dodge.
@export var special_fall_mobility: float = 1.0

@export_group("Landing en air dodge")
## ⚠️ normal_landing_lag (frames).
@export var normal_landing_lag: int = 4
## Wavedash/waveland: LandingFallSpecial na air dodge. ✅ 10
@export var airdodge_landing_lag: int = 10
## ⚠️ escapeair_force / escapeair_decay (waarde uit community, structuur uit decomp).
@export var airdodge_force: float = 3.1
@export var airdodge_decay: float = 0.9
## ⚠️ Frame (state-frame, 0 = eerste) waarop het afremmen stopt en gravity weer werkt.
@export var airdodge_decay_end: int = 30
## Totale duur air dodge-animatie. ✅ 49
@export var airdodge_frames: int = 49
## Intangible frames (Melee-nummering, 1 = eerste frame). ✅ 4–29 (Peach 4–19, Bowser 3–29)
@export var airdodge_intangible_start: int = 4
@export var airdodge_intangible_end: int = 29

@export_group("Uiterlijk")
## ⚠️ Getekende lengte (vloer -> kruin) in Melee-units. Melee-characters zijn grofweg 11–20 units;
## het rig is 22 units, dus de visual wordt hierop geschaald. Toegestaan: VISUAL_HEIGHT_MIN..MAX (8-30); hurtboxes,
## ledge-grab-box, hang-positie en getup-afstanden schalen mee.
@export var visual_height: float = 15.0

const VISUAL_HEIGHT_MIN: float = 8.0
const VISUAL_HEIGHT_MAX: float = 30.0

@export_group("Verdediging")
## Shield-bubble bij volle HP en volle shield: straal = dit × visual_height, middelpunt op shield_center_ratio × visual_height
## boven de voeten. ⚠️ (Melee: per-character shield_size; hier zo dat de volle bubble het hele lijf dekt.)
@export var shield_size_ratio: float = 0.62
@export var shield_center_ratio: float = 0.5
## Spotdodge (EscapeN): totale duur en intangible frames (1-based). ⚠️ Melee-referentie per archetype, zie docs/combat.md.
@export var spotdodge_frames: int = 27
@export var spotdodge_intangible_start: int = 2
@export var spotdodge_intangible_end: int = 16
## Roll (EscapeF/B): totale duur, intangible frames (1-based) en afstand als factor op visual_height. ⚠️
@export var roll_frames: int = 35
@export var roll_intangible_start: int = 4
@export var roll_intangible_end: int = 19
@export var roll_distance_ratio: float = 1.9
## Damage per pummel (afspraak 4: 2–3). ⚠️
@export var pummel_damage: float = 3.0


## Roll-afstand in units.
func roll_distance() -> float:
	return roll_distance_ratio * visual_height


@export_group("ECB / hurtbox")
## ⚠️ ECB-diamant: onderpunt = voeten (positie), bovenpunt op ecb_height, zijpunten op ecb_mid_y.
@export var ecb_height: float = 16.0
@export var ecb_mid_y: float = 8.0
@export var ecb_half_width: float = 4.0


## Hoogte van een sprong met beginsnelheid v0 (Melee: eerste frame zonder gravity).
## = Σ_{n≥0, v0−g·n>0} (v0 − g·n)
func jump_height(v0: float) -> float:
	var h: float = 0.0
	var v: float = v0
	while v > 0.0:
		h += v
		v -= gravity
	return h


func full_hop_height() -> float:
	return jump_height(jump_v_initial_velocity)


func short_hop_height() -> float:
	return jump_height(hop_v_initial_velocity)


## Beginsnelheid van de n-de luchtsprong (0-based).
func air_jump_velocity(index: int) -> float:
	if index < air_jump_forces.size():
		return air_jump_forces[index]
	return jump_v_initial_velocity * air_jump_v_multiplier



# =============================================================================================
# Ledge. Zie docs/movement.md, "Ledge (M2 + ledge-fix)". Alle afmetingen schalen met visual_height (8-30 units):
# Melee: per-character cliff-box (ftData+0x44 ledge_snap_x/y/height) × modelschaal.
# =============================================================================================
@export_group("Ledge")
## Grab-box als factor op visual_height. Melee Fox (fast_faller, 12 units): ledge tot 11 vóór het midden,
## hoogte 8.5..17.5 boven de voeten (midden 13, hoogte 9) [N]. ⚠️ omrekening naar onze lengtes.
@export var ledge_grab_front_ratio: float = 0.917
## Zoveel × visual_height mag het midden van de fighter al voorbij (onder de stage) de rand zijn (geen muur-collision). ⚠️
@export var ledge_grab_back_ratio: float = 0.27
## y_min = 0 (⚠️ afwijking van de Melee-box 0.708): in Melee ligt de lucht-ECB-onderkant hoger dan de voeten, zodat
## je na van de rand glijden (wavedash/run achteruit) vrijwel meteen grabt. Wij meten vanaf de voeten, dus 0.
@export var ledge_grab_y_min_ratio: float = 0.0
@export var ledge_grab_y_max_ratio: float = 1.458
## CliffCatch-animatie in frames. ✅ 7 (Link 3)
@export var ledge_catch_frames: int = 7
## Intangible frames bij elke catch: intangible = max(intangible, catch + dit) (Melee: 30 bij CliffWait-start,
## `ftColl_8007B760` = max-regel, dus ook bij een regrab; ledgestall mogelijk). ✅ 30
@export var ledge_grab_intangible: int = 30
## Max hangtijd in frames: < 100% / ≥ 100%. 660 ❓ (wiki 11 s; NOTES 640) / 480 ✅
@export var ledge_max_hang_low: int = 660
@export var ledge_max_hang_high: int = 480
## Regrab-lock na loslaten, na een getup/ledge jump én na geraakt worden: één constante (Melee `ledge_cooldown`). ✅ 30
@export var ledge_cooldown: int = 30
## Ledge jump: horizontale snelheid richting de stage en verticale snelheid als factor op jump_v_initial_velocity. ⚠️
@export var ledge_jump_vx: float = 1.1
@export var ledge_jump_vy_mult: float = 1.0
## Per getup-optie en per variant (low = < 100%, high = ≥ 100%): frames (totale duur; bij "jump" = wachttijd aan de
## muur), rise (frames omhoog langs de muur), dx (afstand de stage op, × visual_height), i0..i1 (intangible,
## 1 = eerste frame), hit (frame van de hitbox; alleen "attack"). Leeg = LEDGE_OPTION_DEFAULTS.
@export var ledge_options: Dictionary = {}

## Bron: [P] frame-data (gemiddeld Marth/Fox/Peach/Pikachu), zie docs/verificatie.md sectie 3. rise/dx ⚠️.
const LEDGE_OPTION_DEFAULTS: Dictionary = {
	"getup": {
		"low": {"frames": 34, "rise": 16, "dx": 0.8, "i0": 1, "i1": 31},
		"high": {"frames": 60, "rise": 30, "dx": 0.8, "i0": 1, "i1": 56},
	},
	"roll": {
		"low": {"frames": 50, "rise": 14, "dx": 1.9, "i0": 1, "i1": 35},
		"high": {"frames": 80, "rise": 24, "dx": 1.9, "i0": 1, "i1": 60},
	},
	"attack": {
		"low": {"frames": 55, "rise": 16, "dx": 0.8, "i0": 1, "i1": 21, "hit": 24},
		"high": {"frames": 70, "rise": 26, "dx": 0.8, "i0": 1, "i1": 45, "hit": 40},
	},
	"jump": {
		"low": {"frames": 15, "rise": 0, "dx": 0.0, "i0": 1, "i1": 15},
		"high": {"frames": 21, "rise": 0, "dx": 0.0, "i0": 1, "i1": 21},
	},
}


## Parameters van een getup-optie ("getup", "roll", "attack", "jump") voor < 100% (high = false) of ≥ 100%.
func ledge_option(kind: String, high: bool) -> Dictionary:
	var tbl: Dictionary = ledge_options if ledge_options.has(kind) else LEDGE_OPTION_DEFAULTS[kind]
	return tbl["high" if high else "low"]


func ledge_max_hang(high: bool) -> int:
	return ledge_max_hang_high if high else ledge_max_hang_low


## Grab-box in units (geschaald met visual_height).
func ledge_grab_front() -> float:
	return ledge_grab_front_ratio * visual_height


func ledge_grab_back() -> float:
	return ledge_grab_back_ratio * visual_height


func ledge_grab_y_min() -> float:
	return ledge_grab_y_min_ratio * visual_height


func ledge_grab_y_max() -> float:
	return ledge_grab_y_max_ratio * visual_height


# =============================================================================================
# Movement-aanvullingen per character (CharacterLoader, docs/balans.md sectie 2). Alleen vlaggen: de bijbehorende
# mechaniek hangt aan de vlag (zie docs/movement.md, "Character-aanvullingen").
# =============================================================================================
@export_group("Aanvullingen")
## Glide (vasthouden van de sprongknop in de val houdt hoogte). ⚠️ Vlag; mechaniek nog niet gebouwd.
@export var glide: bool = false
## Wall jump (afzetten tegen een stage-muur). ⚠️ Vlag; mechaniek nog niet gebouwd (stages hebben nog geen muren).
@export var wall_jump: bool = false
