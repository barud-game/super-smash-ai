class_name StateRunBrake
extends FighterState
## RunBrake (skid): alleen traction (x1.0, geen verdubbeling). Crouch vanaf frame 1,
## dash-flick -> Dash (vooruit) of smash-turn -> Dash (achteruit) ⚠️, echte terug-input -> RunTurn,
## sprong altijd. Einde na run_brake_frames -> Wait.


func id() -> String:
	return "RunBrake"


func anim() -> void:
	if sf() >= f.stats.run_brake_frames:
		f.change_state("Wait")


func iasa() -> void:
	if f.check_guard() or f.check_ground_jump():
		return
	if f.check_dash():
		return
	if sf() >= 1 and f.check_squat():
		return
	if f.run_turn_intent():
		f.change_state("RunTurn")


func phys() -> void:
	f.apply_ground_friction(false)


## Glijdt over de rand en valt eraf (Melee: alleen langzaam lopen/stilstaan stopt aan de rand). ⚠️
func stops_at_edge() -> bool:
	return false


func pose() -> String:
	return "skid"
