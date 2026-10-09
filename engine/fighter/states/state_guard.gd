class_name StateGuard
extends FighterState
## Guard: shield vasthouden. Shield-HP slijt (0.28/frame); <= 0 = shield break. OoS: grab, sprong (JC usmash/up-B),
## shield drop, spotdodge, roll (Fighter.check_oos()). Loslaten -> GuardOff.


func id() -> String:
	return "Guard"


func debug_name() -> String:
	return "Guard (%.0f%%)" % (f.shield_value() * 100.0)


func anim() -> void:
	f.drain_shield()


func iasa() -> void:
	if f.check_oos():
		return
	if not f.shield_held():
		f.change_state("GuardOff")


func phys() -> void:
	f.apply_ground_friction()


func is_shielding() -> bool:
	return true


func pose() -> String:
	return pick_pose("shield", "crouch")
