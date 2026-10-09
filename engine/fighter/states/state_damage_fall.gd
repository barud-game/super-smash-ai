class_name StateDamageFall
extends FighterState
## DamageFall (tumble na de hitstun): vallen met drift en fast fall; alleen aerials, double jump en air dodge.
## Grondcontact: tech of missed tech (Fighter.land_in_tumble()). Ledge grab mag (Melee).


func id() -> String:
	return "DamageFall"


func iasa() -> void:
	if not f.check_aerial():
		f.check_air_interrupts()


func phys() -> void:
	f.apply_air_physics()


func is_grounded() -> bool:
	return false


func on_land() -> void:
	f.land_in_tumble()


func can_grab_ledge() -> bool:
	return true


func pose() -> String:
	return "tumble"
