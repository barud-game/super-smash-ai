class_name StateDownWait
extends FighterState
## DownWait: liggen na een missed tech. Opties (⚠️ volgorde/drempels gekozen):
##   A                        -> getup attack (DownGetup "attack")
##   stick links/rechts       -> getup roll in die richting (DownGetup "roll")
##   stick omhoog / jump      -> opstaan (DownGetup "stand")
## Stick-richtingen tellen alleen als ze ná het gaan liggen zijn ingeduwd. Na DOWN_WAIT_MAX vanzelf opstaan.


func id() -> String:
	return "DownWait"


func anim() -> void:
	if sf() >= FighterConst.DOWN_WAIT_MAX:
		f.change_state("DownGetup", {"kind": "stand"})


func iasa() -> void:
	if f.input.pressed(InputFrame.BTN_ATTACK):
		f.change_state("DownGetup", {"kind": "attack"})
		return
	var sx: float = f.stick_x()
	var sy: float = f.stick_y()
	var fresh_x: bool = f.input.stick_timer_x() <= sf()
	var fresh_y: bool = f.input.stick_timer_y() <= sf()
	if fresh_x and absf(sx) >= FighterConst.TECH_ROLL_THRESHOLD - FighterConst.EPS:
		f.change_state("DownGetup", {"kind": "roll", "dir": 1 if sx > 0.0 else -1})
		return
	if (fresh_y and sy >= FighterConst.TECH_ROLL_THRESHOLD - FighterConst.EPS) or f.input.pressed(InputFrame.BTN_JUMP):
		f.change_state("DownGetup", {"kind": "stand"})


func phys() -> void:
	f.apply_ground_friction()


func hurtbox_shape() -> String:
	return "lie"


func pose() -> String:
	return "missed_tech_lie"
