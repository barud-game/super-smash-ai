class_name StateSquatWait
extends FighterState
## SquatWait (gehurkt). Stick los -> SquatRv.


func id() -> String:
	return "SquatWait"


func iasa() -> void:
	if f.check_ground_attack():
		return
	if f.check_ground_jump() or f.check_platform_drop():
		return
	if f.stick_y() > -MeleeStick.CROUCH_THRESHOLD + FighterConst.EPS:
		f.change_state("SquatRv")


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return "crouch"


func pose_frame() -> int:
	return 1000  # laatste key van de crouch-pose vasthouden


func is_crouching() -> bool:
	return true


func hurtbox_shape() -> String:
	return "crouch"
