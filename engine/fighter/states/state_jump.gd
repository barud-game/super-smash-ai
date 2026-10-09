class_name StateJump
extends FighterState
## Jump (opwaarts na een grondsprong). Snelheid is gezet door Fighter.ground_jump().
## Op het eerste frame geen gravity/drift. Daarna gewone lucht-physics; vy < 0 -> Fall.

var short_hop: bool = false
var backward: bool = false


func id() -> String:
	return "Jump"


func debug_name() -> String:
	return "Jump%s%s" % ["B" if backward else "F", " (SH)" if short_hop else ""]


func enter(args: Dictionary) -> void:
	short_hop = args.get("short", false)
	backward = f.vel.x * f.facing < 0.0


func anim() -> void:
	if sf() >= 1 and f.vel.y < 0.0:
		f.change_state("Fall")


func iasa() -> void:
	f.check_air_interrupts()


func phys() -> void:
	if sf() == 0:
		return
	f.apply_air_physics()


func is_grounded() -> bool:
	return false


func pose() -> String:
	return "jump"


func can_grab_ledge() -> bool:
	return true
