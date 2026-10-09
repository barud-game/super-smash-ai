class_name StateLanding
extends FighterState
## Landing (normale landing lag, of aerial landing lag na een aerial). gr_vel = vx is al gezet bij het landen;
## wrijving x2 boven walk speed. Na `lag` frames -> Wait (actionable op hetzelfde frame).
## args: lag (frames), aerial (move-naam, alleen debug), lcancel (bool, alleen debug).

var lag: int = 4
var aerial: String = ""
var lcancel: bool = false


func id() -> String:
	return "Landing"


func debug_name() -> String:
	if aerial == "":
		return "Landing"
	return "Landing (%s %d%s)" % [aerial, lag, ", L-cancel" if lcancel else ""]


func enter(args: Dictionary) -> void:
	lag = args.get("lag", f.stats.normal_landing_lag)
	aerial = args.get("aerial", "")
	lcancel = args.get("lcancel", false)


func anim() -> void:
	if sf() >= lag:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func stops_at_edge() -> bool:
	return false


func pose() -> String:
	return "land"


func pose_speed() -> float:
	# De land-pose duurt ~ normale landing lag; lange aerial-lag houdt de laatste key vast.
	return 1.0
