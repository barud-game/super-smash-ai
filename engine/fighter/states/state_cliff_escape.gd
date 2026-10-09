class_name StateCliffEscape
extends StateCliffMove
## CliffEscape (ledge roll): omhoog en een stuk de stage op, intangible zolang de roll duurt.


func id() -> String:
	return "CliffEscape"


func kind() -> String:
	return "roll"


func pose() -> String:
	return pick_pose("cliff_roll", "dash")
