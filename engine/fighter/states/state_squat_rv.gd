class_name StateSquatRv
extends FighterState
## SquatRv (opstaan uit crouch). Actionable zoals Wait; einde -> Wait.


func id() -> String:
	return "SquatRv"


func anim() -> void:
	if sf() >= f.stats.squat_rv_frames:
		f.change_state("Wait")


func iasa() -> void:
	f.check_wait_interrupts()


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return "crouch"


func pose_frame() -> int:
	# crouch-pose achterstevoren afspelen (8 frames lang)
	return maxi(0, 8 - sf())
