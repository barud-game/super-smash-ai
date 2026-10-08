class_name StateLanding
extends FighterState
## Landing (normale landing lag). gr_vel = vx is al gezet bij het landen; wrijving x2 boven walk speed.
## Na `lag` frames (normal_landing_lag) -> Wait (actionable op hetzelfde frame).

var lag: int = 4


func id() -> String:
	return "Landing"


func enter(args: Dictionary) -> void:
	lag = args.get("lag", f.stats.normal_landing_lag)


func anim() -> void:
	if sf() >= lag:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func stops_at_edge() -> bool:
	return false


func pose() -> String:
	return "land"
