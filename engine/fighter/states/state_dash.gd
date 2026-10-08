class_name StateDash
extends FighterState
## Dash (initial dash). Bij binnenkomst direct ±dash_initial_velocity, eerste frame geen accel.
## Daarna de dash/run-formule. Omgekeerde flick = dash-dance (via een smash-turn van 1 frame).
## Einde (dash_frames): stick vooruit >= run-drempel -> Run, anders Wait (foxtrot = opnieuw flicken).


func id() -> String:
	return "Dash"


func enter(_args: Dictionary) -> void:
	var init: float = f.stats.dash_initial_velocity
	if f.gr_vel * f.facing < init:
		f.gr_vel = init * f.facing


func anim() -> void:
	if sf() >= f.stats.dash_frames:
		if f.stick_x() * f.facing >= MeleeStick.RUN_THRESHOLD - FighterConst.EPS:
			f.change_state("Run")
		else:
			f.change_state("Wait")


func iasa() -> void:
	if f.check_ground_jump():
		return
	# Dash-dance: omgekeerde dash-flick.
	if f.input.flick_x(MeleeStick.SMASH_THRESHOLD, MeleeStick.SMASH_WINDOW) == -f.facing:
		f.change_state("Turn", {"smash": true})


func phys() -> void:
	if sf() == 0:
		return
	f.apply_dash_run_accel(f.stick_x())


func stops_at_edge() -> bool:
	return false


func pose() -> String:
	return "dash"
