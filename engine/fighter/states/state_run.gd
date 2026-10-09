class_name StateRun
extends FighterState
## Run: dash/run-formule. Stick onder run-drempel -> RunBrake; echte terug-input -> RunTurn.
## ⚠️ Een korte terugveer-overshoot van de stick (stick los) draait niet om: zie Fighter.run_turn_intent().


func id() -> String:
	return "Run"


func iasa() -> void:
	if f.check_dash_attack(false) or f.check_guard():
		return
	if f.check_ground_jump():
		return
	var d: float = f.stick_x() * f.facing
	if f.run_turn_intent():
		f.change_state("RunTurn")
	elif d < MeleeStick.RUN_THRESHOLD - FighterConst.EPS:
		f.change_state("RunBrake")


func phys() -> void:
	f.apply_dash_run_accel(f.stick_x())


func stops_at_edge() -> bool:
	return false


func pose() -> String:
	return "run"


func pose_speed() -> float:
	return clampf(absf(f.gr_vel) / maxf(f.stats.run_speed, 0.1), 0.4, 1.6)
