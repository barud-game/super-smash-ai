class_name StateWalk
extends FighterState
## Walk: snelheid naar stick_x * walk_max_velocity. Slow/Middle/Fast alleen voor animatie/debug.
## Stopt aan de rand, behalve met |stick_x| >= teeter-walk-drempel (0.75).


func id() -> String:
	return "Walk"


func debug_name() -> String:
	var ax: float = absf(f.stick_x())
	if ax >= MeleeStick.WALK_FAST_THRESHOLD:
		return "WalkFast"
	if ax >= MeleeStick.WALK_MIDDLE_THRESHOLD:
		return "WalkMiddle"
	return "WalkSlow"


func enter(_args: Dictionary) -> void:
	# ⚠️ walk_initial_velocity als beginsnelheid wanneer we langzamer gaan.
	var init: float = f.stats.walk_initial_velocity * absf(f.stick_x())
	if f.gr_vel * f.facing < init:
		f.gr_vel = init * f.facing


func iasa() -> void:
	if f.check_ground_attack() or f.check_guard() or f.check_ground_jump() or f.check_dash() or f.check_squat() \
			or f.check_turn():
		return
	if f.stick_x() * f.facing <= 0.0:
		f.change_state("Wait")


func phys() -> void:
	f.apply_walk(f.stick_x())


func stops_at_edge() -> bool:
	return not MeleeStick.reaches(f.stick_x(), MeleeStick.TEETER_WALK_THRESHOLD)


func pose() -> String:
	return "walk"


func pose_speed() -> float:
	return clampf(absf(f.gr_vel) / 0.9, 0.25, 2.0)


func on_edge_stop(side: int) -> void:
	# Langzaam lopen tegen de rand aan: wankelen (alleen als we naar de afgrond kijken).
	if side == f.facing:
		f.change_state("Teeter")
