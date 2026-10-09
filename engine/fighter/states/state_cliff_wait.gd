class_name StateCliffWait
extends FighterState
## CliffWait: hangen aan de ledge. Max hangtijd (11 s < 100%, 8 s ≥ 100%) -> automatisch loslaten.
## Opties (volgorde = prioriteit, ⚠️ Melee-volgorde onbekend):
##   jump (knop of omhoog-flick)      -> CliffJump
##   attack (A)                       -> CliffAttack   (hitbox komt in M3)
##   shield (L/R)                     -> CliffEscape   (roll)
##   stick naar de stage / omhoog     -> CliffClimb    (getup)
##   stick omlaag / van de stage af   -> loslaten (Fall, alle sprongen terug)
## Stick-richtingen tellen alleen als de stick ná de grab is ingeduwd (anders zou vasthouden tijdens het
## vallen meteen een getup/drop geven); knoppen zijn edge-gestuurd.


func id() -> String:
	return "CliffWait"


func anim() -> void:
	if f.ledge_hang_frames >= f.stats.ledge_max_hang(f.ledge_high()):
		f.ledge_drop()


func iasa() -> void:
	var src: int = f.jump_source()
	if src != 0:
		if src == 2:
			f.consume_tap_jump()
		f.change_state("CliffJump")
		return
	if f.input.pressed(InputFrame.BTN_ATTACK):
		f.change_state("CliffAttack")
		return
	if f.input.pressed(InputFrame.BTN_SHIELD):
		f.change_state("CliffEscape")
		return
	var sx: float = f.stick_x()
	var sy: float = f.stick_y()
	var fresh_x: bool = f.input.stick_timer_x() <= f.ledge_hang_frames
	var fresh_y: bool = f.input.stick_timer_y() <= f.ledge_hang_frames
	var toward: float = sx * -f.ledge_side
	if (fresh_x and toward >= FighterConst.LEDGE_GETUP_THRESHOLD - FighterConst.EPS) \
			or (fresh_y and sy >= FighterConst.LEDGE_UP_THRESHOLD - FighterConst.EPS):
		f.change_state("CliffClimb")
		return
	if (fresh_y and sy <= -FighterConst.LEDGE_DROP_THRESHOLD + FighterConst.EPS) \
			or (fresh_x and -toward >= FighterConst.LEDGE_DROP_THRESHOLD - FighterConst.EPS):
		f.ledge_drop()


func phys() -> void:
	f.pos = f.ledge_hang_pos(f.ledge_pos, f.ledge_side)
	f.vel = Vector2.ZERO


func coll() -> void:
	pass


func is_grounded() -> bool:
	return false


func holds_ledge() -> bool:
	return true


func pose() -> String:
	return pick_pose("cliff_wait", "fall")
