class_name StateEscapeN
extends FighterState
## EscapeN (spotdodge): omlaag-flick uit shield. Blijft staan; intangible op spotdodge_intangible_start..end (1-based).
## Daarna Wait.


func id() -> String:
	return "EscapeN"


func enter(_args: Dictionary) -> void:
	f.gr_vel = 0.0


func anim() -> void:
	if sf() >= f.stats.spotdodge_frames:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func intangible() -> bool:
	var n: int = sf() + 1
	return n >= f.stats.spotdodge_intangible_start and n <= f.stats.spotdodge_intangible_end


func pose() -> String:
	return "spotdodge"


func pose_speed() -> float:
	return 26.0 / float(maxi(f.stats.spotdodge_frames, 1))
