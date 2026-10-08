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
