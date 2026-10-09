class_name StateCliffCatch
extends FighterState
## CliffCatch: de grab-animatie (ledge_catch_frames = 7, Link 3). Geen input; de fighter hangt op de snap-positie.
## Daarna CliffWait. De ledge-intangibility zit in Fighter.intangible_frames (gezet in grab_ledge).


func id() -> String:
	return "CliffCatch"


func anim() -> void:
	if sf() >= f.stats.ledge_catch_frames:
		f.change_state("CliffWait")


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
	return pick_pose("ledge_catch", pick_pose("ledge_hang", "fall"))
