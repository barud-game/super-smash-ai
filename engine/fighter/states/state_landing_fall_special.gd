class_name StateLandingFallSpecial
extends FighterState
## LandingFallSpecial: landen uit air dodge (wavedash/waveland, 10 frames) of special fall.
## Horizontale snelheid is bij het landen omgezet in gr_vel en glijdt uit met traction (x2 boven walk speed).

const SLIDE_POSE_MIN_SPEED: float = 0.3

var lag: int = 10
var sliding: bool = false


func id() -> String:
	return "LandingFallSpecial"


func debug_name() -> String:
	return "LandingFallSpecial%s" % (" (wavedash)" if sliding else "")


func enter(args: Dictionary) -> void:
	lag = args.get("lag", f.stats.airdodge_landing_lag)
	sliding = absf(f.gr_vel) >= SLIDE_POSE_MIN_SPEED


func anim() -> void:
	if sf() >= lag:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func stops_at_edge() -> bool:
	return false


func pose() -> String:
	return "wavedash" if sliding else "landfall"
