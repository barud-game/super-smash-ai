class_name StateCliffMove
extends FighterState
## Basis voor de getups die de fighter van de hang naar de stage brengen (CliffClimb, CliffEscape, CliffAttack).
## Positie = functie van het state-frame (deterministisch): eerst `rise` frames omhoog langs de muur naar het
## ledge-niveau, dan lineair `dx` × visual_height de stage op. Intangible op frames i0..i1 (zie FighterStats.ledge_option).
## Aan het eind: op de grond in Wait. De ledge wordt bij binnenkomst vrijgegeven met de ledge-lock (Melee: ook na getup).

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
	end = Vector2(f.ledge_pos.x - f.ledge_side * float(opt["dx"]) * f.stats.visual_height, f.ledge_pos.y)
	f.release_ledge(f.stats.ledge_cooldown)
	f.vel = Vector2.ZERO


func anim() -> void:
	if sf() >= int(opt["frames"]):
		f.finish_ledge_move(end)


func phys() -> void:
	var total: int = int(opt["frames"])
	var rise: int = mini(int(opt["rise"]), total - 1)
	var t: int = sf() + 1   # voortgang na dit frame
	if rise > 0 and t <= rise:
		# Omhoog langs de muur en tegelijk naar de hoek: aan het eind van de rise staan de voeten op de rand.
		f.pos = start.lerp(Vector2(f.ledge_pos.x, end.y), float(t) / float(rise))
	else:
		var u: float = clampf(float(t - rise) / float(maxi(total - rise, 1)), 0.0, 1.0)
		var from_x: float = f.ledge_pos.x if rise > 0 else start.x
		f.pos = Vector2(lerpf(from_x, end.x, u), end.y)
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
