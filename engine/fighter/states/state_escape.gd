class_name StateEscape
extends FighterState
## Escape (Melee EscapeF/EscapeB): roll uit shield. args: dir = +1 vooruit / -1 achteruit (t.o.v. de kijkrichting).
## Verplaatsing = stats.roll_distance() (× visual_height), gelijkmatig over de eerste (roll_frames − ROLL_STAND_FRAMES)
## frames; stopt aan de rand. Intangible op roll_intangible_start..end (1-based). Een forward roll eindigt omgedraaid.

## ⚠️ Laatste frames van de roll zonder verplaatsing (opstaan).
const ROLL_STAND_FRAMES: int = 8

var rel: int = 1
var dir_world: int = 1


func id() -> String:
	return "Escape"


func debug_name() -> String:
	return "EscapeF" if rel > 0 else "EscapeB"


func enter(args: Dictionary) -> void:
	rel = 1 if int(args.get("dir", 1)) >= 0 else -1
	dir_world = rel * f.facing
	f.gr_vel = 0.0


func total() -> int:
	return f.stats.roll_frames


func move_frames() -> int:
	return maxi(total() - ROLL_STAND_FRAMES, 1)


func anim() -> void:
	if sf() >= total():
		if rel > 0:
			f.facing = -f.facing
		f.change_state("Wait")


func phys() -> void:
	if sf() < move_frames():
		f.gr_vel = dir_world * f.stats.roll_distance() / float(move_frames())
	else:
		f.gr_vel = 0.0


func intangible() -> bool:
	var n: int = sf() + 1
	return n >= f.stats.roll_intangible_start and n <= f.stats.roll_intangible_end


func pose() -> String:
	return "roll_forward" if rel > 0 else "roll_back"


func pose_speed() -> float:
	return 28.0 / float(maxi(total(), 1))
