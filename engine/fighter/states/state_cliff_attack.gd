class_name StateCliffAttack
extends StateCliffMove
## CliffAttack (ledge attack, A). Beweegt als een getup; de hitbox komt in M3.
## TODO M3: in `_on_frame()` op het frame `opt["hit"]` de ledge-attack-hitbox starten (damage/knockback uit
## MoveData); bij ≥ 100% (Slow) is de hitbox later en de intangibility korter.


func id() -> String:
	return "CliffAttack"


func kind() -> String:
	return "attack"


func _on_frame() -> void:
	if sf() == int(opt["hit"]):
		pass   # TODO M3: hitbox


func pose() -> String:
	return pick_pose("ledge_attack", "jump")
