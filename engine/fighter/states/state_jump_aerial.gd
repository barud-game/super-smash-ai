class_name StateJumpAerial
extends FighterState
## JumpAerial (double jump). vy = jump_v * air_jump_v_multiplier (of vaste kracht per sprong);
## vx = stick_x * air_jump_h_multiplier: horizontaal momentum wordt VERVANGEN. Gravity werkt al op frame 0.

const ANIM_FRAMES: int = 30  # ⚠️ lengte van de jump_aerial-animatie, daarna Fall

var backward: bool = false


func id() -> String:
	return "JumpAerial"


func debug_name() -> String:
	return "JumpAerial%s" % ("B" if backward else "F")


func enter(_args: Dictionary) -> void:
	var sx: float = f.stick_x()
	backward = sx * f.facing < 0.0
	f.vel = Vector2(sx * f.stats.air_jump_h_multiplier, f.stats.air_jump_velocity(f.air_jumps_used))
	f.air_jumps_used += 1
	f.fastfalling = false
	f.reset_fast_fall_buffer()


func anim() -> void:
	if sf() >= ANIM_FRAMES:
		f.change_state("Fall")


func iasa() -> void:
	if not f.check_aerial():
		f.check_air_interrupts()


func phys() -> void:
	f.apply_air_physics()


func is_grounded() -> bool:
	return false


func pose() -> String:
	return "jump_aerial"


func can_grab_ledge() -> bool:
	return true
