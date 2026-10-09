class_name StateWait
extends FighterState
## Wait (stilstaan). Volledig actionable; wrijving met x2 boven walk speed (pivot/wavedash-slide).


func id() -> String:
	return "Wait"


func iasa() -> void:
	if not f.check_wait_interrupts():
		f.check_teeter()


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return "idle"
