class_name StateGuardOff
extends FighterState
## GuardOff: shield loslaten (Melee: 15 frames, geen acties, shield staat niet meer op). Daarna Wait.


func id() -> String:
	return "GuardOff"


func anim() -> void:
	if sf() >= FighterConst.GUARD_OFF_FRAMES:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return pick_pose("shield", "idle")


func pose_frame() -> int:
	return 0
