class_name StateDownBound
extends FighterState
## DownBound: missed tech, stuiteren op de grond (niet intangible: tech chase). Daarna DownWait (liggen).


func id() -> String:
	return "DownBound"


func enter(_args: Dictionary) -> void:
	f.kb_vel = Vector2.ZERO


func anim() -> void:
	if sf() >= FighterConst.DOWN_BOUND_FRAMES:
		f.change_state("DownWait")


func phys() -> void:
	f.apply_ground_friction()


func hurtbox_shape() -> String:
	return "lie"


func pose() -> String:
	return "missed_tech_lie"
