class_name FighterState
extends RefCounted
## Basis voor één fighter-state (Melee: één action state met Anim/IASA/Phys/Coll-callbacks).
## Subclasses in engine/fighter/states/. Nieuwe states (shield, aanvallen, ledge) erven hiervan en
## worden met Fighter.register_state() toegevoegd.

## De fighter (Node; geen RefCounted-cyclus).
var f: Fighter


## Unieke naam, gelijk aan de Melee-statenaam (Wait, Dash, KneeBend, ...).
func id() -> String:
	return "State"


## Naam voor de debug overlay (mag een variant tonen, bv. WalkSlow / JumpB).
func debug_name() -> String:
	return id()


func enter(_args: Dictionary) -> void:
	pass


func exit() -> void:
	pass


## Tijd-gestuurde overgangen (einde animatie). Draait als eerste in het frame.
func anim() -> void:
	pass


## Input-overgangen (interrupts).
func iasa() -> void:
	pass


## Snelheden bijwerken.
func phys() -> void:
	pass


## Positie bijwerken + grond/landen.
func coll() -> void:
	if is_grounded():
		f.ground_coll()
	else:
		f.air_coll()


func is_grounded() -> bool:
	return true


## Grondstates: stoppen aan de rand (true) of eraf vallen (false).
func stops_at_edge() -> bool:
	return true


## Luchtstates: landt op pass-through platforms.
func lands_on_platforms() -> bool:
	return true


## Aangeroepen door Fighter._land() (gr_vel/positie zijn dan al gezet).
func on_land() -> void:
	f.change_state("Landing")


func intangible() -> bool:
	return false


## Luchtstates waarin een ledge grab mogelijk is (naast de voorwaarde vy < 0, zie Fighter.check_ledge_grab).
func can_grab_ledge() -> bool:
	return false


## True voor CliffCatch/CliffWait: de fighter bezet dan de ledge.
func holds_ledge() -> bool:
	return false


## Aangeroepen door Fighter.ground_coll() als de fighter aan de rand tot stilstand komt (side = -1 links, +1 rechts).
func on_edge_stop(_side: int) -> void:
	pass


# --- Gevecht (M3) ---

## Actieve hitboxes op dit frame (aanvallen). Wordt na alle fighter-ticks door CombatSystem opgevraagd.
func hitboxes() -> Array[ActiveHitbox]:
	return []


## Vorm van de hurtboxes: "stand", "crouch" of "lie" (Fighter.hurtboxes()).
func hurtbox_shape() -> String:
	return "stand"


## Gehurkt voor crouch cancel (KB × 2/3). Alleen Squat/SquatWait.
func is_crouching() -> bool:
	return false


## [startup, active, total] voor CharacterVisual.play_timed (aanvalsposes), leeg = gewone play().
func pose_timing() -> Array:
	return []


## Verschuiving van de visual t.o.v. de voeten, in rig-px (vóór schaal), bv. hang-poses aan de ledge.
func visual_offset_px() -> Vector2:
	return Vector2.ZERO


## Kies `wanted` als de visual die pose heeft, anders `fallback` (pose-hooks die nog niet getekend zijn).
func pick_pose(wanted: String, fallback: String) -> String:
	if f.visual == null or f.visual.has_pose(wanted):
		return wanted
	return fallback


## Pose-naam voor CharacterVisual (docs/rig.md §6).
func pose() -> String:
	return "idle"


func pose_frame() -> int:
	return f.state_frame


func pose_speed() -> float:
	return 1.0


## Hulp: frame in de state.
func sf() -> int:
	return f.state_frame
