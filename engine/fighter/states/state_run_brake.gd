class_name StateRunBrake
extends FighterState
## RunBrake (skid): alleen traction (x1.0, geen verdubbeling). Crouch vanaf frame 1,
## stick terug -> RunTurn, sprong altijd. Einde na run_brake_frames -> Wait.


func id() -> String:
	return "RunBrake"


func anim() -> void:
	if sf() >= f.stats.run_brake_frames:
		f.change_state("Wait")


func iasa() -> void:
	if f.check_ground_jump():
		return
	if sf() >= 1 and f.check_squat():
		return
	var d: float = f.stick_x() * f.facing
	if d < 0.0 and MeleeStick.reaches(d, MeleeStick.TURN_THRESHOLD):
		f.change_state("RunTurn")


func phys() -> void:
	f.apply_ground_friction(false)


func pose() -> String:
	return "skid"
