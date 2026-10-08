class_name MatchRules
extends Resource
## Match-regels: alleen data, geen logica. De match-scène (M6) leest dit.
## Standaard volgens PLAN.md: 4 stocks, 8 minuten, geen items, sudden death bij gelijkspel.

@export_range(1, 99) var stocks: int = 4
## Tijdslimiet in minuten; 0 = geen tijdslimiet.
@export_range(0, 99) var time_minutes: int = 8
@export var items: bool = false
@export var sudden_death: bool = true


## Tijdslimiet in sim-frames (60 Hz); 0 = onbeperkt.
func time_frames() -> int:
	return time_minutes * 60 * 60


func summary() -> String:
	var t: String = "%d min" % time_minutes if time_minutes > 0 else "geen tijdslimiet"
	return "%d stocks · %s · items %s · sudden death %s" % [
		stocks, t, "aan" if items else "uit", "aan" if sudden_death else "uit"]
