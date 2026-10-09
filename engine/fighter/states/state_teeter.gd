class_name StateTeeter
extends FighterState
## Teeter: aan de rand van de stage staan en naar de afgrond kijken (Melee: wankelen). Komt uit Walk (langzaam
## lopen stopt aan de rand, zie StateWalk) en Wait. Actionable zoals Wait; naar de rand lopen blijft Teeter
## (een Walk zou meteen weer stoppen); dashen/rennen valt er gewoon af.
## ⚠️ Eigen teeter-pose bestaat nog niet in de rig: tot die er is, de walk-pose op frame 0.


func id() -> String:
	return "Teeter"


func iasa() -> void:
	if f.check_ground_attack() or f.check_ground_jump() or f.check_dash() or f.check_squat() or f.check_turn():
		return
	var e: int = f.edge_side()
	if e == 0 or e != f.facing:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return pick_pose("teeter", "walk")


func pose_frame() -> int:
	return 0 if pose() == "walk" else f.state_frame
