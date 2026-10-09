class_name StateTech
extends FighterState
## Tech (Melee Passive / PassiveStandF/B): geteched bij het neerkomen in tumble. dir 0 = tech in place,
## -1/+1 = tech roll in die wereldrichting. Intangible aan het begin; daarna Wait. Alle waarden ⚠️ (FighterConst).

var dir: int = 0


func id() -> String:
	return "Tech"


func debug_name() -> String:
	return "Tech" if dir == 0 else ("TechRoll%s" % ("F" if dir == f.facing else "B"))


func enter(args: Dictionary) -> void:
	dir = int(args.get("dir", 0))
	f.gr_vel = 0.0
	f.vel = Vector2.ZERO
	f.kb_vel = Vector2.ZERO


func total() -> int:
	return FighterConst.TECH_FRAMES if dir == 0 else FighterConst.TECH_ROLL_FRAMES


func anim() -> void:
	if sf() >= total():
		f.change_state("Wait")


func phys() -> void:
	if dir != 0 and sf() >= 1 and sf() <= FighterConst.TECH_ROLL_MOVE_FRAMES:
		f.gr_vel = dir * FighterConst.TECH_ROLL_DISTANCE / float(FighterConst.TECH_ROLL_MOVE_FRAMES)
	else:
		f.gr_vel = 0.0


func intangible() -> bool:
	var end: int = FighterConst.TECH_INTANGIBLE_END if dir == 0 else FighterConst.TECH_ROLL_INTANGIBLE_END
	return sf() + 1 <= end


func pose() -> String:
	return "tech" if dir == 0 else "tech_roll"


func pose_speed() -> float:
	if dir == 0:
		return 22.0 / float(FighterConst.TECH_FRAMES)
	return 26.0 / float(FighterConst.TECH_ROLL_FRAMES)
