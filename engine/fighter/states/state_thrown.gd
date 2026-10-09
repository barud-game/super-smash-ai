class_name StateThrown
extends FighterState
## Thrown: de victim tijdens de throw-animatie van de holder (volgt de grab-tip) tot de launch
## (Fighter.throw_victim -> receive_hit -> Damage/DamageFly). Geen acties, geen grab-timer. Intangible: alleen de
## throw zelf raakt hem.


func id() -> String:
	return "Thrown"


func anim() -> void:
	if f.grab_partner == null:
		f.change_state("Wait" if f.grounded else "Fall")


func phys() -> void:
	pass


func coll() -> void:
	pass


func is_grounded() -> bool:
	return f.grounded


func keeps_grab() -> bool:
	return true


func intangible() -> bool:
	return true


func pose() -> String:
	return pick_pose("thrown", "grabbed")
