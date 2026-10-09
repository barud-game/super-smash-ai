class_name StateCliffJump
extends FighterState
## CliffJump (ledge jump): `frames` (startup) nog aan de muur, dan een sprong omhoog en naar de stage toe
## (vy = jump_v_initial_velocity × ledge_jump_vy_mult, vx = ledge_jump_vx richting de stage) -> Jump.
## De dubbele sprong blijft beschikbaar. Intangible op frames i0..i1. Na de sprong geldt de ledge-lock.

var opt: Dictionary = {}
var high: bool = false


func id() -> String:
	return "CliffJump"


func debug_name() -> String:
	return "CliffJump%s" % ("Slow" if high else "Quick")


func enter(_args: Dictionary) -> void:
	high = f.ledge_high()
	opt = f.stats.ledge_option("jump", high)
	f.vel = Vector2.ZERO
	f.release_ledge(f.stats.ledge_cooldown)


func anim() -> void:
	if sf() >= int(opt["frames"]):
		f.vel = Vector2(-f.ledge_side * f.stats.ledge_jump_vx, f.stats.jump_v_initial_velocity * f.stats.ledge_jump_vy_mult)
		f.air_jumps_used = 0
		f.fastfalling = false
		f.reset_fast_fall_buffer()
		f.change_state("Jump")


func phys() -> void:
	f.pos = f.ledge_hang_pos(f.ledge_pos, f.ledge_side)


func coll() -> void:
	pass


func is_grounded() -> bool:
	return false


func intangible() -> bool:
	var n: int = sf() + 1
	return n >= int(opt["i0"]) and n <= int(opt["i1"])


func pose() -> String:
	return pick_pose("cliff_jump", "jumpsquat")
