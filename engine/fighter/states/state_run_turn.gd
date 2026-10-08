class_name StateRunTurn
extends FighterState
## RunTurn (TurnRun, run turnaround): remt met traction tot stilstand, draait dan om en versnelt met de
## run-formule. Duurt minstens run_turn_frames ⚠️ en tot de snelheid is omgedraaid. Alleen jump onderbreekt.

var new_dir: int = 1
var flipped: bool = false
var flip_frame: int = 0


func id() -> String:
	return "RunTurn"


func enter(_args: Dictionary) -> void:
	new_dir = -f.facing
	flipped = false
	flip_frame = 0


func anim() -> void:
	if flipped and sf() >= f.stats.run_turn_frames:
		if f.stick_x() * f.facing >= MeleeStick.RUN_THRESHOLD - FighterConst.EPS:
			f.change_state("Run")
		else:
			f.change_state("Wait")


func iasa() -> void:
	f.check_ground_jump()


func phys() -> void:
	if not flipped:
		f.gr_vel = move_toward(f.gr_vel, 0.0, f.stats.traction)
		if f.gr_vel == 0.0 or signf(f.gr_vel) == float(new_dir):
			flipped = true
			flip_frame = sf()
			f.facing = new_dir
	elif f.stick_x() * f.facing > 0.0:
		f.apply_dash_run_accel(f.stick_x())
	else:
		f.apply_ground_friction(false)


func pose() -> String:
	return "turn" if flipped else "skid"


func pose_frame() -> int:
	return sf() - flip_frame if flipped else sf()
