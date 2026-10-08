class_name StateFall
extends FighterState
## Fall: gravity tot terminal velocity, fast fall (flick omlaag na de apex), air drift.


func id() -> String:
	return "Fall"


func debug_name() -> String:
	return "Fall (FF)" if f.fastfalling else "Fall"


func iasa() -> void:
	f.check_air_interrupts()


func phys() -> void:
	f.apply_air_physics()


func is_grounded() -> bool:
	return false


func pose() -> String:
	return "fastfall" if f.fastfalling else "fall"
