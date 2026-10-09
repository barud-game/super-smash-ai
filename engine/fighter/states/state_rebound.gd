class_name StateRebound
extends FighterState
## Rebound: grondaanval botste (clank) met een andere aanval. Geen acties tot het einde (⚠️ REBOUND_FRAMES).


func id() -> String:
	return "Rebound"


func anim() -> void:
	if sf() >= FighterConst.REBOUND_FRAMES:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return "damage_low"
