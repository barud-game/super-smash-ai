class_name StateFallSpecial
extends FighterState
## FallSpecial (helpless). Gravity/fast fall, drift beperkt met een mobility-factor, geen acties.
## Stick omlaag laat je door platforms vallen. Landen -> LandingFallSpecial.

var mobility: float = 1.0
var landing_lag: int = 10


func id() -> String:
	return "FallSpecial"


func enter(args: Dictionary) -> void:
	mobility = args.get("mobility", f.stats.special_fall_mobility)
	landing_lag = args.get("landing_lag", f.stats.airdodge_landing_lag)


func phys() -> void:
	f.apply_air_physics(mobility)


func is_grounded() -> bool:
	return false


func lands_on_platforms() -> bool:
	return f.stick_y() > -MeleeStick.PLATFORM_FALL_THROUGH_THRESHOLD + FighterConst.EPS


func on_land() -> void:
	f.change_state("LandingFallSpecial", {"lag": landing_lag})


func pose() -> String:
	return "fastfall" if f.fastfalling else "fall"


func can_grab_ledge() -> bool:
	return true
