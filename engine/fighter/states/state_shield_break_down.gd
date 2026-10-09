class_name StateShieldBreakDown
extends FighterState
## ShieldBreakDown: na de shield-break-vlucht neerkomen en liggen (SHIELD_BREAK_DOWN_FRAMES ⚠️), daarna Dizzy.


func id() -> String:
	return "ShieldBreakDown"


func anim() -> void:
	if sf() >= FighterConst.SHIELD_BREAK_DOWN_FRAMES:
		f.change_state("Dizzy")


func phys() -> void:
	f.apply_ground_friction()


func hurtbox_shape() -> String:
	return "lie"


func pose() -> String:
	return pick_pose("missed_tech_lie", "idle")
