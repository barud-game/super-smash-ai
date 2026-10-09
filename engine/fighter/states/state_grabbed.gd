class_name StateGrabbed
extends FighterState
## Grabbed (Melee CaptureWait): vastgehouden door Fighter.grab_partner. De holder zet de positie (grab-tip, kijkt naar
## de holder); geen eigen beweging of acties. Grab-timer telt af (niet tijdens hitlag); mashen (nieuwe knop of verse
## stickrichting) trekt GRAB_MASH_FRAMES af. Op 0 -> Fighter.grab_escape() (grond- of lucht-release).


func id() -> String:
	return "Grabbed"


func debug_name() -> String:
	return "Grabbed (%d)" % f.grab_timer


func anim() -> void:
	if f.grab_partner == null:
		f.change_state("Wait" if f.grounded else "Fall")
		return
	f.grab_timer -= 1
	if f.grab_timer <= 0:
		f.grab_escape()


func iasa() -> void:
	if f.grab_partner != null and f.grab_mash_input():
		f.grab_timer -= FighterConst.GRAB_MASH_FRAMES
		if f.grab_timer <= 0:
			f.grab_escape()


func phys() -> void:
	pass


func coll() -> void:
	pass


func is_grounded() -> bool:
	return f.grounded


func keeps_grab() -> bool:
	return true


func pose() -> String:
	return pick_pose("grabbed", "damage_low")
