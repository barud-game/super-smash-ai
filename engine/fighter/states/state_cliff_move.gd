class_name StateCliffMove
extends FighterState
## Basis voor de getups die de fighter van de hang naar de stage brengen (CliffClimb, CliffEscape, CliffAttack).
## Positie = functie van het state-frame (deterministisch): eerst `rise` frames omhoog langs de muur naar het
## ledge-niveau, dan lineair `dx` units de stage op. Intangible op frames i0..i1 (zie FighterStats.ledge_option).
## Aan het eind: op de grond in Wait. De ledge is bij binnenkomst al vrijgegeven (geen lock nodig).

var opt: Dictionary = {}
var high: bool = false
var start: Vector2 = Vector2.ZERO
var end: Vector2 = Vector2.ZERO


## "getup" / "roll" / "attack" (sleutel in FighterStats.ledge_option).
func kind() -> String:
	return "getup"


func debug_name() -> String:
	return "%s%s" % [id(), "Slow" if high else "Quick"]


func enter(_args: Dictionary) -> void:
	high = f.ledge_high()
	opt = f.stats.ledge_option(kind(), high)
	start = f.pos
	end = Vector2(f.ledge_pos.x - f.ledge_side * float(opt["dx"]), f.ledge_pos.y)
	f.release_ledge(0)
	f.vel = Vector2.ZERO


func anim() -> void:
	if sf() >= int(opt["frames"]):
		f.finish_ledge_move(end)


func phys() -> void:
	var total: int = int(opt["frames"])
	var rise: int = mini(int(opt["rise"]), total - 1)
	var t: int = sf() + 1   # voortgang na dit frame
	if rise > 0 and t <= rise:
		f.pos = Vector2(start.x, lerpf(start.y, end.y, float(t) / float(rise)))
	else:
		var u: float = clampf(float(t - rise) / float(maxi(total - rise, 1)), 0.0, 1.0)
		f.pos = Vector2(lerpf(start.x, end.x, u), end.y)
	_on_frame()


## Hook per frame (aanvallen).
func _on_frame() -> void:
	pass


func coll() -> void:
	pass


func is_grounded() -> bool:
	return false


func intangible() -> bool:
	var n: int = sf() + 1
	return n >= int(opt["i0"]) and n <= int(opt["i1"])


## Pose over de hele getup uitgesmeerd (pose-lengte / duur).
func pose_speed() -> float:
	if f.visual == null:
		return 1.0
	return f.visual.pose_length(pose()) / float(maxi(int(opt.get("frames", 1)), 1))


## Begint in de hang-houding: de offset naar de ledge verdwijnt tijdens het omhoogklimmen.
func visual_offset_px() -> Vector2:
	var rise: int = maxi(int(opt.get("rise", 0)), 1)
	return StateCliffWait.hang_offset(f) * clampf(1.0 - float(sf()) / float(rise), 0.0, 1.0)
