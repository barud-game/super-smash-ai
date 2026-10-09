class_name StateSquat
extends FighterState
## Squat (hurken in). Platform drop met een omlaag-flick binnen het venster. Daarna SquatWait.


func id() -> String:
	return "Squat"


func anim() -> void:
	if sf() >= f.stats.squat_frames:
		f.change_state("SquatWait")


func iasa() -> void:
	if f.check_ground_attack():
		return
	if f.check_ground_jump():
		return
	f.check_platform_drop()


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return "crouch"


func is_crouching() -> bool:
	return true


func hurtbox_shape() -> String:
	return "crouch"
