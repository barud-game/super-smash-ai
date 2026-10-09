class_name StateDizzy
extends FighterState
## Dizzy (Melee FuraFura): na een shield break wankelend stilstaan, geen acties.
## Duur = max(DIZZY_BASE − percent, DIZZY_MIN) frames (hoger % = korter ⚠️), daarna Wait.

var frames: int = 0


func id() -> String:
	return "Dizzy"


func debug_name() -> String:
	return "Dizzy (%d)" % maxi(frames - sf(), 0)


static func duration_for(percent: float) -> int:
	return maxi(int(FighterConst.DIZZY_BASE - percent), FighterConst.DIZZY_MIN)


func enter(_args: Dictionary) -> void:
	frames = duration_for(f.percent)


func anim() -> void:
	if sf() >= frames:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return pick_pose("shield_break_dizzy", "idle")
