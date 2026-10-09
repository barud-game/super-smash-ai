class_name StatePummel
extends FighterState
## Pummel (Melee CatchAttack): A in GrabHold. Op PUMMEL_HIT_FRAME krijgt de victim stats.pummel_damage (kan niet
## missen, hitlag voor beiden, geen knockback). Na PUMMEL_FRAMES terug naar GrabHold. Alle timings ⚠️.


func id() -> String:
	return "Pummel"


func anim() -> void:
	if f.grab_partner == null:
		f.change_state("Wait")
		return
	if sf() == FighterConst.PUMMEL_HIT_FRAME:
		f.queue_pummel()
	if sf() >= FighterConst.PUMMEL_FRAMES:
		f.change_state("GrabHold")


func phys() -> void:
	f.apply_ground_friction()


func coll() -> void:
	super.coll()
	f.place_grab_victim()


func keeps_grab() -> bool:
	return true


func pose() -> String:
	return pick_pose("atk_pummel", "atk_grab_hold")


func pose_timing() -> Array:
	return [FighterConst.PUMMEL_HIT_FRAME, 1, FighterConst.PUMMEL_FRAMES]
