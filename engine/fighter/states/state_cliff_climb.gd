class_name StateCliffClimb
extends StateCliffMove
## CliffClimb (normale getup): omhoog en de stage op. < 100% Quick, ≥ 100% Slow (langer, korter intangible).


func id() -> String:
	return "CliffClimb"


func kind() -> String:
	return "getup"


func pose() -> String:
	return pick_pose("ledge_getup", "jump")
