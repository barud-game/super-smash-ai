class_name StateDead
extends FighterState
## Dead: buiten de match na een blast-zone-KO (Fighter.active = false). Doet niets tot respawn_at()/spawn().


func id() -> String:
	return "Dead"


func is_grounded() -> bool:
	return false


func coll() -> void:
	pass
